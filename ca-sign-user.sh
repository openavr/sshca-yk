#!/bin/bash

DOMAIN="${1}"
USR="${2}"
USER_KEY="${3:-keys-user/id_ed25519_${USR}}"

if [[ -z "${DOMAIN}" ]] || [[ -z "${USR}" ]]
then
    echo "Usage: $0 <domain> <user> [<user-key>]"
    exit 1
fi

CA_PUB="${CA_PUB:-keys-ca/${DOMAIN}/ssh_ca_user_ed25519.pub}"
PKCS11_MODULE="${PKCS11_MODULE:-/usr/lib/x86_64-linux-gnu/libykcs11.so}"

PRINCIPALS="${PRINCIPALS:-${USR}}"
VALIDITY="${VALIDITY:-+1d}"

USER_PUB="${USER_KEY}.pub"

mkdir -p keys-user

if ssh-add -T "${CA_PUB}"
then
    SIGN_OPTS_EXTRA=( -U )
else
    SIGN_OPTS_EXTRA=( -D "${PKCS11_MODULE}" )
fi

SIGN_OPTS=(
    "${SIGN_OPTS_EXTRA[@]}"
    -s "${CA_PUB}"
    -I "${USR}@${DOMAIN}"
    -n "${PRINCIPALS}"
    -V "${VALIDITY}"

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
