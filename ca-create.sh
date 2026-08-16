#!/bin/bash
#
# Script to create a CA private keys that can be used for signing openssh
# certificates while storing the private key in a Yubikey PIV slot.
# Use ED25519 and ECDSA key types for user and host CA keys.
#

function usage() {
    echo "Usage: $0 <org-domain> <org-common-name>"
    exit 1
}

# NOTE: Putting commas (',') in these will cause the certificate generation in
#       the Yubikey to fail, so remove them here.
ORGANIZATION="${1//,/}"
COMMON_NAME="${2//,/}"

if [[ -z "${ORGANIZATION}" ]] || [[ -z "${COMMON_NAME}" ]]
then
    usage
fi

TTL_DAYS="90"

KEY_TYPES=(
    ed25519
    ecdsa
)

CA_TYPES=(
    user
    host
)

declare -A SLOTS=(
    [ecdsa-user]="82"
    [ecdsa-host]="83"
    [ed25519-user]="84"
    [ed25519-host]="85"
)

source ./yk-utils.sh

IFS= read -s -p "Enter Passphrase: " PASSPHRASE
echo ""
IFS= read -s -p "Enter Passphrase again: " PASSPHRASE_VERIFY
echo ""

if [[ "${PASSPHRASE}" != "${PASSPHRASE_VERIFY}" ]]
then
    echo "ERROR: passphrases do not match"
    exit 1
fi

function create_ca_key()
{
    local KEY_TYPE="${1}"
    local KEY_PATH="${2}"
    shift 2

    local KEYGEN_ARGS=(
        -N "${PASSPHRASE}"
    )

    case "${KEY_TYPE}" in
        ed25519)
            KEYGEN_ARGS+=( -t ed25519 )
            ;;
        ecdsa)
            KEYGEN_ARGS+=( -t ecdsa -b 384 )
            ;;
        *)
            ;;
    esac

    ssh-keygen "${KEYGEN_ARGS[@]}" -f ${KEY_PATH} "${@}"
}

function init_key()
{
    local CT="${1}"   # CA Type
    local KT="${2}"   # Key Type
    local KEY_BASE="${3}"

    local OPENSSH_KEY="${KEY_BASE}"
    local OPENSSH_PUB="${KEY_BASE}.pub"
    local YK_KEY="${KEY_BASE}_key.pem"
    local YK_PUB="${KEY_BASE}_pub.pem"

    local SUBJECT="CN=${COMMON_NAME} ${CT^} SSH CA,O=${ORGANIZATION}"
    local SLOT="${SLOTS[${KT}-${CT}]}"

    if [[ ! -f ${OPENSSH_KEY} ]]; then
        # Capitalize with ${VAR^}
        # Upper case with ${VAR^^}
        create_ca_key ${KT} ${OPENSSH_KEY} -C "${COMMON_NAME} ${CT^} SSH CA" \
            || exit 1
    else
        echo "NOTE: Using existing key: ${OPENSSH_KEY}" 1>&2
    fi

    # Convert private key to a format that can imported into Yubikey
    cp ${OPENSSH_KEY} ${YK_KEY} || exit 1
    ssh-keygen -p -m PKCS8 -N "${PASSPHRASE}" -P "${PASSPHRASE}" -f ${YK_KEY} \
        || exit 1

    yk_import_key ${SLOT} ${YK_KEY} || exit 1
    yk_export_key ${SLOT} ${YK_PUB} || exit 1
    yk_generate_cert "${SUBJECT}" ${TTL_DAYS} ${SLOT} ${YK_PUB} || exit 1
}

if yk_select
then
    KEY_DIR="keys-ca/${ORGANIZATION}"
    mkdir -p "${KEY_DIR}"

    for ca_type in "${CA_TYPES[@]}"
    do
        for key_type in "${KEY_TYPES[@]}"
        do
            key_base="${KEY_DIR}/ssh_ca_${ca_type}_${key_type}"

            init_key "${ca_type}" "${key_type}" "${key_base}"
        done
    done

    ykman piv info
fi
