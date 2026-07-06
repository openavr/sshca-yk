#!/bin/bash

PKCS11="/usr/lib/x86_64-linux-gnu/libykcs11.so"
KEY="keys/id_ed25519_${USER}"
PUB="${KEY}.pub"

CA_PUB="keys/id_ec384_user_ca.pub"

mkdir -p keys

ssh-keygen -t ed25519 -f ${KEY}

ssh-keygen \
    -s "${CA_PUB}" \
    -D "${PKCS11}" \
    -I foo \
    -V '-4d:+8d' \
    -n ${USER} "${PUB}"
