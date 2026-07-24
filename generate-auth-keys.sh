#!/bin/bash

PUB_KEYS=(
    keys-ca/id_ecdsa_user_ca.pub
    keys-ca/id_ecdsa_host_ca.pub
    keys-ca/id_ed25519_user_ca.pub
    keys-ca/id_ed25519_host_ca.pub
)

declare -A CA_KEYS
declare -A CA_COMMENTS

function process_ca_key() {
    local FN="$1"
    local KT="$2"
    local KEY="$3"
    shift 3
    local COMMENT="$*"

    CA_KEYS["${KEY}"]="${FN}"
    CA_COMMENTS["${KEY}"]="${COMMENT}"
}

for key_file in "${PUB_KEYS[@]}"
do
    while read -a key_info
    do
        process_ca_key "${key_file}" "${key_info[@]}"
    done < "${key_file}"
done

function process_yk_key() {

    local KEY_TYPE="${1}"
    local KEY="${2}"
    shift 2
    local COMMENT="${*}"

    local FN="${CA_KEYS[${KEY}]}"
    if [ -n "${FN}" ]; then
        echo "'${FN}' is in Yubikey (${COMMENT}: ${CA_COMMENTS[${KEY}]}): ${KEY_TYPE}" 1>&2
        echo "cert-authority ${KEY_TYPE} ${KEY} ${CA_COMMENTS[${KEY}]}"
    fi
}

while read -a key_info
do
    process_yk_key "${key_info[@]}"
done < <(ssh-keygen -D /usr/lib/x86_64-linux-gnu/libykcs11.so) >authorized_keys_ca
