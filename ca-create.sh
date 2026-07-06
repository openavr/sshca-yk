#!/bin/bash

OPENSSL_KEY="keys/id_ec384_user_ca_key.pem"
OPENSSL_PUB="keys/id_ec384_user_ca_pub.pem"
OPENSSH_PUB="keys/id_ec384_user_ca.pub"
# OPENSSL_CRT="keys/id_ec384_user_ca_piv-cert.pem"
SLOT="9a"

SUBJECT="CN=SSH USER CA"
TTL_DAYS="30"

DEF_PIN="123456"
DEF_PUK="12345678"
DEF_MGMT="010203040506070801020304050607080102030405060708"

mkdir -p keys

set -x

ykman piv reset || exit 1

# Generate the key pair
if [ ! -f ${OPENSSL_KEY} ]; then
    openssl ecparam -genkey -name secp384r1 -noout -out ${OPENSSL_KEY}
fi

ykman piv keys import \
    -m "${DEF_MGMT}" \
    ${SLOT} ${OPENSSL_KEY}

ykman piv keys export \
    ${SLOT} ${OPENSSL_PUB}

ykman piv certificates generate \
    -P "${DEF_PIN}" \
    -m "${DEF_MGMT}" \
    -s "${SUBJECT}" \
    -d ${TTL_DAYS} \
    ${SLOT} ${OPENSSL_PUB}

ykman piv info

# Convert openssl pub to openssh pub format
ssh-keygen -i -m PKCS8 -f ${OPENSSL_PUB} > ${OPENSSH_PUB}
