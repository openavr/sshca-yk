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

if [[ ! -e ${PUBLIC_KEY} ]]
then
    KEY=${PUBLIC_KEY%%.pub}
    echo "ERROR: Missing public key: ${PUBLIC_KEY}"
    echo "Consider creating keypair with:"
    if [[ ${PUBLIC_KEY} =~ ed25519 ]]; then
        echo "    ssh-keygen -t ed25519 -f ${PUBLIC_KEY%%.pub}"
    elif [[ ${PUBLIC_KEY} =~ ecdsa ]]; then
        echo "    ssh-keygen -t ecdsa -b 384 -f ${PUBLIC_KEY%%.pub}"
    else
        echo "    ssh-keygen -f ${PUBLIC_KEY%%.pub}"
    fi
    exit 1
fi

set -x

# Sign a certificate for the new key
ssh-keygen "${SIGN_OPTS[@]}"
