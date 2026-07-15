#!/bin/bash
#
# Script to create a CA private keys that can be used for signing openssh
# certificates while storing the private key ina Yubikey PIV slot.
# Use ED25519 and ECDSA key types for user and host CA keys.
#

KEY_TYPES=(
    ed25519
    ecdsa
)

CA_TYPES=(
    user
    host
)

declare -A SLOTS=(
    [user-ed25519]="82"
    [user-ecdsa]="83"
    [host-ed25519]="84"
    [host-ecdsa]="85"
)

TTL_DAYS="90"

DEF_PIN="123456"
DEF_PUK="12345678"
DEF_MGMT="010203040506070801020304050607080102030405060708"

function create_ca_key_ed25519()
{
    local KEY="${1}"
    ssh-keygen -t ed25519 -N '' -m PKCS8 -f ${KEY}
}

function create_ca_key_ecdsa()
{
    local KEY="${1}"
    ssh-keygen -t ecdsa -b 384 -N '' -m PKCS8 -f ${KEY}
}

function init_key()
{
    local CT=$1
    local KT=$2

    local OPENSSH_KEY="keys-ca/id_${KT}_${CT}_ca"
    local OPENSSH_PUB="keys-ca/id_${KT}_${CT}_ca.pub"
    local OPENSSL_PUB="keys-ca/id_${KT}_${CT}_ca_pub.pem"

    local SUBJECT="CN=SSH ${CT} CA"
    local SLOT="${SLOTS[${CT}-${KT}]}"

    if [ ! -f ${OPENSSH_KEY} ]; then
        create_ca_key_${KT} "${OPENSSH_KEY}" || exit 1
    fi

    # Import the private key into the yubikey.
    ykman piv keys import \
        -m "${DEF_MGMT}" \
        ${SLOT} ${OPENSSH_KEY}

    # Extract the public key from the yubikey.
    ykman piv keys export \
        ${SLOT} ${OPENSSL_PUB}

    # Convert openssl pub to openssh pub format.
    #ssh-keygen -i -m PKCS8 -f ${OPENSSL_PUB} > ${OPENSSH_PUB}

    # Create a self-signed cert in the yubikey.
    # This cert is not used by ssh tools, is only needed by the PIV
    # application in the yubikey.
    ykman piv certificates generate \
        -P "${DEF_PIN}" \
        -m "${DEF_MGMT}" \
        -s "${SUBJECT}" \
        -d ${TTL_DAYS} \
        ${SLOT} ${OPENSSL_PUB}
}

set -x

mkdir -p keys-ca

for CT in "${CA_TYPES[@]}"
do
    for KT in "${KEY_TYPES[@]}"
    do
        init_key "${CT}" "${KT}"
    done
done

ykman piv info
