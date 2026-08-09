#!/bin/bash
#
#
#

DEF_PIN="123456"
DEF_PUK="12345678"
DEF_MGMT="010203040506070801020304050607080102030405060708"

declare NEW_PIN
declare NEW_PUK
declare NEW_MGMT

declare YK_SN

readonly YK_CFG_FMT='./yubikey-cfg.d/yk-%s.cfg'
mkdir -p ./yubikey-cfg.d
declare YK_CFG

readonly YKMAN=$(which ykman)

function yk_cmd() {
    echo ""
    echo "+ ${YKMAN} -d ${YK_SN:?ERR: No Yubikey selected} ${@}"
    ${YKMAN} -d "${YK_SN}" "${@}"
}

function yk_select() {
    declare -A YK_DEVICES

    while read -a ykdevice
    do
        YK_DEVICES["${ykdevice[*]}"]="${ykdevice[-1]}"
    done < <(ykman list)

    if [[ ${#YK_DEVICES[@]} -eq 0 ]]; then
        echo "Please insert a Yubikey, none found"
        return 1
    elif [[ ${#YK_DEVICES[@]} -eq 1 ]]; then
        YK_SN="${YK_DEVICES[@]}"
        printf -v YK_CFG "${YK_CFG_FMT}" "${YK_SN}"
        return 0
    fi

    local ykdev

    PS3="Please select a Yubikey: "
    while [[ -z "${ykdev}" ]]
    do
        select ykdev in "${!YK_DEVICES[@]}" quit
        do
            echo "selected: ${ykdev}"
            if [[ -n "${ykdev}" ]]; then
                case "${ykdev}" in
                    quit)
                        return 2
                        ;;
                    *)
                        YK_SN="${YK_DEVICES[${ykdev}]}"
                        printf -v YK_CFG "${YK_CFG_FMT}" "${YK_SN}"
                        return 0
                        ;;
                esac
            fi
        done
    done
}

function yk_generate_access_codes() {
    local RAND_DEC=''
    local RAND_HEX=''

    while [[ ${#RAND_DEC} -le 16 ]] \
        || [[ "${NEW_PIN}" == "${DEF_PIN}" ]] \
        || [[ "${NEW_PUK}" == "${DEF_PUK}" ]]
    do
        RAND_HEX=$(openssl rand -hex 16)  # Generates 32 chars in [0-9a-f] set
        RAND_DEC="${RAND_HEX//[^0-9]/}"   # Remove non-decimal digits
        NEW_PIN="${RAND_DEC:0:8}"         # Grab the first 8 decimal digits
        NEW_PUK="${RAND_DEC: -8}"         # Grab the last 8 decimal digits
    done

    NEW_MGMT="${DEF_MGMT}"
    while [[ "${NEW_MGMT}" == "${DEF_MGMT}" ]]; do
        NEW_MGMT="$(openssl rand -hex 24)"
    done
}

function yk_load_access_codes() {
    if [[ -e ${YK_CFG} ]]; then
        source ${YK_CFG}
    else
        return 1
    fi
}

function yk_save_access_codes() {
    echo "YK_CFG: ${YK_CFG:?ERR: No Yubikey selected}"
    cat <<EOF > "${YK_CFG}"
export NEW_PIN="${NEW_PIN}"
export NEW_PUK="${NEW_PUK}"
export NEW_MGMT="${NEW_MGMT}"
EOF
}

function yk_get_access_codes() {
    if ! yk_load_access_codes
    then
        yk_generate_access_codes
        yk_save_access_codes
    fi
}

function yk_change_access() {
    # Only try to set the PIN/PUK/MGMT if it is not already set and is
    # using the defaults

    while read line
    do
        if [[ $line =~ "Using default PIN" ]]
        then
            yk_cmd piv access change-pin \
                -P "${DEF_PIN}" -n "${NEW_PIN}" \
                || exit $?
        elif [[ $line =~ "Using default PUK" ]]
        then
            yk_cmd piv access change-puk \
                -p "${DEF_PUK}" -n "${NEW_PUK}" \
                || exit $?
        elif [[ $line =~ "Using default Management" ]]
        then
            yk_cmd piv access change-management-key \
                -m "${DEF_MGMT}" -n "${NEW_MGMT}" \
                || exit $?
        fi
    done < <(yk_cmd piv info \
        | grep -E 'WARNING: Using default (PIN|PUK|Management)')
}

function yk_import_key() {
    SLOT="${1}"
    PRIV_KEY="${2}"

    # Import the private key into the yubikey.
    yk_cmd piv keys import \
        -m "${DEF_MGMT}" \
        -p "${PASSPHRASE}" \
        ${SLOT} ${PRIV_KEY}
}

function yk_export_key() {
    SLOT="${1}"
    PUBLIC_KEY="${2}"

    # Extract the public key from the yubikey.
    yk_cmd piv keys export \
        ${SLOT} ${PUBLIC_KEY}
}

function yk_generate_cert() {
    SUBJECT="${1}"
    TTL_DAYS="${2}"
    SLOT="${3}"
    PUBLIC_KEY="${4}"

    # Create a self-signed cert in the yubikey.
    # This cert is not used by ssh tools, is only needed by the PIV
    # application in the yubikey.
    yk_cmd piv certificates generate \
        -P "${DEF_PIN}" \
        -m "${DEF_MGMT}" \
        -s "${SUBJECT}" \
        -d ${TTL_DAYS} \
        ${SLOT} ${OPENSSL_PUB}
}

function yk_main() {
    # Not sourced, so perform the yk selection
    if yk_select
    then
        set -x
        yk_cmd piv info
    else
        rc=$?
        echo "Goodbye!"
        exit ${rc}
    fi
}

#
# Call main if not sourced from another script.
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
    yk_main "${@}"
fi
