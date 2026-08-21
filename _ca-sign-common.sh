#
# Reusable snippet for use by host and user signing scripts.
#

PKCS11_MODULE="${PKCS11_MODULE:-/usr/lib/x86_64-linux-gnu/libykcs11.so}"

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
