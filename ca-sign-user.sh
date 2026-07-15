#!/bin/bash

CA_PUB="${1:-keys-ca/id_ed25519_user_ca.pub}"

PKCS11="/usr/lib/x86_64-linux-gnu/libykcs11.so"
USER_KEY="keys-user/id_ed25519_${USER}"
USER_PUB="${USER_KEY}.pub"

mkdir -p keys-user

ssh-keygen -t ed25519 -f ${USER_KEY}

ssh-keygen \
    -s "${CA_PUB}" \
    -D "${PKCS11}" \
    -I foo \
    -V '-4d:+8d' \
    -n ${USER} "${USER_PUB}"
