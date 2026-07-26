#!/bin/bash

DOMAIN="${1}"
USR="${2}"
USER_KEY="${3:-keys-user/id_ed25519_${USR}}"

if [ -z "${DOMAIN}" ] || [ -z "${USR}" ]
then
    echo "Usage: $0 <domain> <user> [<user-key>]"
    exit 1
fi

CA_PUB="${CA_PUB:-keys-ca/${DOMAIN}/id_ed25519_user_ca.pub}"

PKCS11="/usr/lib/x86_64-linux-gnu/libykcs11.so"
USER_PUB="${USER_KEY}.pub"

mkdir -p keys-user

SIGN_OPTS=(
    -s "${CA_PUB}"
    -D "${PKCS11}"
    -I "${USR}@${DOMAIN}"
    -n ${USR}
    -V '+1d'

    -O no-user-rc
    # -O no-pty
    # -O no-agent-forwarding
    # -O no-port-forwarding
    # -O no-x11-forwarding
    # -O force-command='/usr/bin/uptime'
    "${USER_PUB}"
)

set -x

# Generate a new key
ssh-keygen -t ed25519 -f ${USER_KEY}

# Sign a certificate for the new key
ssh-keygen "${SIGN_OPTS[@]}"
