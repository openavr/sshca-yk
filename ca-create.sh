#!/bin/bash
#
# Script to create a CA private keys that can be used for signing openssh
# certificates while storing the private key in a Yubikey PIV slot.
# Use ED25519 and ECDSA key types for user and host CA keys.
#

function usage() {
    echo "Usage: $0 <org> <common_name>"
    exit 1
}

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

ORGANIZATION="$1"
COMMON_NAME="$2"

if [[ -z "${ORGANIZATION}" ]] || [[ -z "${COMMON_NAME}" ]]
then
    usage
fi

TTL_DAYS="90"

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
    # CA Type: Force CT to be fully lower case with ${VAR,,}
    local CT="${1,,}"

    # Key Type
    local KT="${2}"

    local OPENSSH_KEY="keys-ca/${ORGANIZATION}/ssh_ca_${CT}_${KT}"
    local OPENSSH_PUB="keys-ca/${ORGANIZATION}/ssh_ca_${CT}_${KT}.pub"
    local OPENSSL_KEY="keys-ca/${ORGANIZATION}/ssh_ca_${CT}_${KT}_key.pem"
    local OPENSSL_PUB="keys-ca/${ORGANIZATION}/ssh_ca_${CT}_${KT}_pub.pem"

    # Capitalize with ${VAR^}
    # Upper case with ${VAR^^}

    local SUBJECT="CN=${COMMON_NAME} ${CT^} SSH CA,O=${ORGANIZATION}"
    local SLOT="${SLOTS[${KT}-${CT}]}"

    if [[ ! -f ${OPENSSH_KEY} ]]; then
        create_ca_key ${KT} ${OPENSSH_KEY} -C "${COMMON_NAME} ${CT^} SSH CA" || exit 1
    fi

    # Convert private key to a format that can imported into Yubikey
    cp ${OPENSSH_KEY} ${OPENSSL_KEY} || exit 1
    ssh-keygen -p -m PKCS8 -N "${PASSPHRASE}" -P "${PASSPHRASE}" -f ${OPENSSL_KEY} || exit 1

    yk_import_key ${SLOT} ${OPENSSL_KEY} || exit 1
    yk_export_key ${SLOT} ${OPENSSL_PUB} || exit 1
    yk_generate_cert "${SUBJECT}" ${TTL_DAYS} ${SLOT} ${OPENSSL_PUB} || exit 1
}

set -x

mkdir -p keys-ca/${ORGANIZATION}

for ca_type in "${CA_TYPES[@]}"
do
    for key_type in "${KEY_TYPES[@]}"
    do
        init_key "${ca_type}" "${key_type}"
    done
done

ykman piv info
