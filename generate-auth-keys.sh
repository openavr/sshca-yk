#!/bin/bash

ORGANIZATION=${1:?Usage: $0 <org-domain>}

PUB_KEYS=(
    keys-ca/${ORGANIZATION}/ssh_ca_user_ecdsa.pub
    keys-ca/${ORGANIZATION}/ssh_ca_host_ecdsa.pub
    keys-ca/${ORGANIZATION}/ssh_ca_user_ed25519.pub
    keys-ca/${ORGANIZATION}/ssh_ca_host_ed25519.pub
)

AUTH_KEYS_FILE=keys-ca/${ORGANIZATION}/authorized_keys_ca

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
done < <(ssh-keygen -D /usr/lib/x86_64-linux-gnu/libykcs11.so) >${AUTH_KEYS_FILE}
