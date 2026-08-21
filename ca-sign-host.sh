#!/bin/bash

ORG_DOMAIN="${1}"
HOST="${2}"
PUBLIC_KEY="${3}"

if [[ -z "${HOST}" ]] || [[ -z "${ORG_DOMAIN}" ]] || [[ -z "${PUBLIC_KEY}" ]]
then
    echo "Usage: $0 <org-domain> <hostname> <server-pub-key>"
    exit 1
fi

CA_PUB="${CA_PUB:-keys-ca/${ORG_DOMAIN}/ssh_ca_host_ed25519.pub}"
PKCS11_MODULE="${PKCS11_MODULE:-/usr/lib/x86_64-linux-gnu/libykcs11.so}"

CERT_IDENTITY="${CERT_IDENTITY:-${HOST}.${ORG_DOMAIN}}"
PRINCIPALS="${PRINCIPALS:-${HOST}.${ORG_DOMAIN},${HOST}}"
VALIDITY="${VALIDITY:-+52w}"

if ssh-add -T "${CA_PUB}" 2>/dev/null
then
    SIGN_OPTS_EXTRA=( -U )
else
    SIGN_OPTS_EXTRA=( -D "${PKCS11_MODULE}" )
fi

SIGN_OPTS=(
    -h
    "${SIGN_OPTS_EXTRA[@]}"
    -s "${CA_PUB}"
    -I "${CERT_IDENTITY}"
    -n "${PRINCIPALS}"
    -V "${VALIDITY}"

    -O no-user-rc
    # -O no-pty
    # -O no-agent-forwarding
    # -O no-port-forwarding
    # -O no-x11-forwarding
    # -O force-command='/usr/bin/uptime'
    "${PUBLIC_KEY}"
)

set -x

# Sign a certificate for the new key
ssh-keygen "${SIGN_OPTS[@]}"
