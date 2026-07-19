#!/bin/bash

CA_PUB="${1:-keys-ca/id_ed25519_user_ca.pub}"

PKCS11="/usr/lib/x86_64-linux-gnu/libykcs11.so"
USER_KEY="keys-user/id_ed25519_${USER}"
USER_PUB="${USER_KEY}.pub"

mkdir -p keys-user

OPTS=(
    -O no-user-rc
    # -O no-pty
    #-O no-agent-forwarding
    #-O no-port-forwarding
    #-O no-x11-forwarding
    #-O force-command='/home/troth/bin/ollama-run.sh'

    -s "${CA_PUB}" \
    -D "${PKCS11}" \
    -I "${USER}@bozoland.org" \
    -n troth \
    -V '+1d' \
)

set -x

ssh-keygen -t ed25519 -f ${USER_KEY}
ssh-keygen "${OPTS[@]}" "${USER_PUB}"
