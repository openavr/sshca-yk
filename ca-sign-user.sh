#!/bin/bash

ORG_DOMAIN="${1}"
ORG_USER="${2}"
PUBLIC_KEY="${3:-keys-user/id-ed25519-${ORG_USER}.pub}"

if [[ -z "${ORG_DOMAIN}" ]] || [[ -z "${ORG_USER}" ]]
then
    echo "Usage: $0 <org-domain> <user> [<public-key>]"
    exit 1
fi

CA_PUB="${CA_PUB:-keys-ca/${ORG_DOMAIN}/ssh_ca_user_ed25519.pub}"
PKCS11_MODULE="${PKCS11_MODULE:-/usr/lib/x86_64-linux-gnu/libykcs11.so}"

CERT_IDENTITY="${CERT_IDENTITY:-${ORG_USER}@${ORG_DOMAIN}}"
PRINCIPALS="${PRINCIPALS:-${ORG_USER}}"
VALIDITY="${VALIDITY:-+1d}"

SIGN_OPTS=(
    -O no-user-rc
    # -O no-pty
    # -O no-agent-forwarding
    # -O no-port-forwarding
    # -O no-x11-forwarding
    # -O force-command='/usr/bin/uptime'
)

if ssh-add -T "${CA_PUB}" 2>/dev/null
then
    SIGN_OPTS+=( -U )
else
    SIGN_OPTS+=( -D "${PKCS11_MODULE}" )
fi

SIGN_OPTS+=(
    -s "${CA_PUB}"
    -I "${CERT_IDENTITY}"
    -n "${PRINCIPALS}"
    -V "${VALIDITY}"

    "${PUBLIC_KEY}"
)

set -x

# Sign a certificate for the new key
ssh-keygen "${SIGN_OPTS[@]}"
