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

CERT_IDENTITY="${CERT_IDENTITY:-${HOST}.${ORG_DOMAIN}}"
PRINCIPALS="${PRINCIPALS:-${HOST}.${ORG_DOMAIN},${HOST}}"
VALIDITY="${VALIDITY:-+52w}"

SIGN_OPTS=(
    -h
)

source _ca-sign-common.sh
