#!/bin/bash

HOST="${1}"
DOMAIN="${2}"
HOST_PUB="${3}"

if [[ -z "${HOST}" ]] || [[ -z "${DOMAIN}" ]] || [[ -z "${HOST_PUB}" ]]
then
    echo "Usage: $0 <hostname> <domain> <server-pub-key>"
    exit 1
fi

CA_PUB="${CA_PUB:-keys-ca/${DOMAIN}/ssh_ca_host_ed25519.pub}"
PKCS11_MODULE="${PKCS11_MODULE:-/usr/lib/x86_64-linux-gnu/libykcs11.so}"

SIGN_OPTS=(
    -h
    -s "${CA_PUB}"
    -D "${PKCS11_MODULE}"
    -I "${HOST}.${DOMAIN}"
    -n "${HOST}.${DOMAIN},${HOST}"
    -V '+52w'

    -O no-user-rc
    # -O no-pty
    # -O no-agent-forwarding
    # -O no-port-forwarding
    # -O no-x11-forwarding
    # -O force-command='/usr/bin/uptime'
    "${HOST_PUB}"
)

set -x

# Sign a certificate for the new key
ssh-keygen "${SIGN_OPTS[@]}"
