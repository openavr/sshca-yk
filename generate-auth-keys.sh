#!/bin/bash

PUB_KEYS=(
    keys-ca/id_ecdsa_user_ca.pub
    keys-ca/id_ecdsa_host_ca.pub
    keys-ca/id_ed25519_user_ca.pub
    keys-ca/id_ed25519_host_ca.pub
)

cat "${PUB_KEYS[@]}" | awk '{print $1 " " $2}'> authorized_keys_ca

ssh-keygen -D /usr/lib/x86_64-linux-gnu/libykcs11.so -e | grep Retired | awk '{print $1 " " $2}' > authorized_keys_yk

set -x
if ! diff -u authorized_keys_ca authorized_keys_yk
then
    echo "ERROR: pub keys don't match those in yubikey"
    exit 1
fi

sed -i -e 's/^/cert-authority /' authorized_keys_ca
cat authorized_keys_ca
