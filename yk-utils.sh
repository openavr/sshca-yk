#!/bin/bash
#
# Utility functions for interacting with a Yubikey with the ykman tool.
#

DEF_PIN="123456"
DEF_PUK="12345678"
DEF_MGMT="010203040506070801020304050607080102030405060708"

declare YK_PIN
declare YK_PUK
declare YK_MGMT

declare YK_SERNUM="${YK_SERNUM}"

readonly YK_CFG_FMT='./yubikey-cfg.d/yk-%s.cfg'
mkdir -p ./yubikey-cfg.d
declare YK_CFG

readonly YKMAN=$(which ykman)

function ykman_cmd() {
    echo ""
    echo "+ ${YKMAN} -d ${YK_SERNUM:?ERR: No Yubikey selected} ${@}"
    ${YKMAN} -d "${YK_SERNUM}" "${@}"
}

function yk_select() {
    declare -A YK_DEVICES

    while read -a ykdevice
    do
        # Serial number provided in environment, verify that the Yubikey with
        # that serial number is actually plugged in to the system.
        if [[ -n ${YK_SERNUM} ]] && [[ ${YK_SERNUM} == ${ykdevice[-1]} ]]
        then
            printf -v YK_CFG "${YK_CFG_FMT}" "${YK_SERNUM}"
            export YK_SERNUM
            export YK_CFG
            return 0
        fi

        YK_DEVICES["${ykdevice[*]}"]="${ykdevice[-1]}"
    done < <(${YKMAN} list)

    unset YK_SERNUM
    declare -g YK_SERNUM

    if [[ ${#YK_DEVICES[@]} -eq 0 ]]; then
        echo "Please insert a Yubikey, none found" 1>&2
        return 1
    elif [[ ${#YK_DEVICES[@]} -eq 1 ]]; then
        export YK_SERNUM="${YK_DEVICES[@]}"
        printf -v YK_CFG "${YK_CFG_FMT}" "${YK_SERNUM}"
        export YK_CFG
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
                        export YK_SERNUM="${YK_DEVICES[${ykdev}]}"
                        printf -v YK_CFG "${YK_CFG_FMT}" "${YK_SERNUM}"
                        export YK_CFG
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
        || [[ "${YK_PIN}" == "${DEF_PIN}" ]] \
        || [[ "${YK_PUK}" == "${DEF_PUK}" ]]
    do
        RAND_HEX=$(openssl rand -hex 16)  # Generates 32 chars in [0-9a-f] set
        RAND_DEC="${RAND_HEX//[^0-9]/}"   # Remove non-decimal digits
        YK_PIN="${RAND_DEC:0:8}"          # Grab the first 8 decimal digits
        YK_PUK="${RAND_DEC: -8}"          # Grab the last 8 decimal digits
    done

    YK_MGMT="${DEF_MGMT}"
    while [[ "${YK_MGMT}" == "${DEF_MGMT}" ]]; do
        YK_MGMT="$(openssl rand -hex 24)"
    done
}

function yk_load_access_codes() {
    if [[ -e ${YK_CFG} ]]; then
        source ${YK_CFG}
    else
        echo "ERROR: Config not found: ${YK_CFG}" 1>&2
        return 1
    fi
}

function yk_save_access_codes() {
    echo "YK_CFG: ${YK_CFG:?ERR: No Yubikey selected}"
    cat <<EOF > "${YK_CFG}"
export YK_PIN="${YK_PIN}"
export YK_PUK="${YK_PUK}"
export YK_MGMT="${YK_MGMT}"
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

    if [[ -z ${YK_PIN} ]] || [[ -z ${YK_PUK} ]] || [[ -z ${YK_MGMT} ]]
    then
        echo "ERROR: None of the following variables should be empty:"
        echo "  YK_PIN='${YK_PIN}'"
        echo "  YK_PUK='${YK_PUK}'"
        echo "  YK_MGMT='${YK_MGMT}'"
        exit 1
    fi

    while read line
    do
        if [[ $line =~ "Using default PIN" ]]
        then
            ykman_cmd piv access change-pin \
                -P "${DEF_PIN}" -n "${YK_PIN}" \
                || exit $?
        elif [[ $line =~ "Using default PUK" ]]
        then
            ykman_cmd piv access change-puk \
                -p "${DEF_PUK}" -n "${YK_PUK}" \
                || exit $?
        elif [[ $line =~ "Using default Management" ]]
        then
            ykman_cmd piv access change-management-key \
                -m "${DEF_MGMT}" -n "${YK_MGMT}" \
                || exit $?
        fi
    done < <(ykman_cmd piv info \
        | grep -E 'WARNING: Using default (PIN|PUK|Management)')
}

# If the access codes have been loaded from the cfg file, try to use those
# access codes unless the Yubikey device has been reset and the default access
# codes are still active.

function yk_select_access_codes() {
    declare -g YK_AC_PIN=${YK_PIN}
    declare -g YK_AC_PUK=${YK_PUK}
    declare -g YK_AC_MGMT=${YK_MGMT}

    while read line
    do
        if [[ $line =~ "Using default PIN" ]]
        then
            YK_AC_PIN=${DEF_PIN}
        elif [[ $line =~ "Using default PUK" ]]
        then
            YK_AC_PUK=${DEF_PUK}
        elif [[ $line =~ "Using default Management" ]]
        then
            YK_AC_MGMT=${DEF_MGMT}
        fi
    done < <(ykman_cmd piv info \
        | grep -E 'WARNING: Using default (PIN|PUK|Management)')

    export YK_AC_PIN
    export YK_AC_PUK
    export YK_AC_MGMT
}

function yk_import_key() {
    SLOT="${1}"
    PRIV_KEY="${2}"

    # Import the private key into the yubikey.
    ykman_cmd piv keys import \
        -m "${YK_AC_MGMT:-${DEF_MGMT}}" \
        -p "${PASSPHRASE}" \
        ${SLOT} ${PRIV_KEY}
}

function yk_export_key() {
    SLOT="${1}"
    PUBLIC_KEY="${2}"

    # Extract the public key from the yubikey.
    ykman_cmd piv keys export \
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
    ykman_cmd piv certificates generate \
        -P "${YK_AC_PIN:-${DEF_PIN}}" \
        -m "${YK_AC_MGMT:-${DEF_MGMT}}" \
        -s "${SUBJECT}" \
        -d ${TTL_DAYS} \
        ${SLOT} ${OPENSSL_PUB}
}

function yk_main() {
    # Not sourced, so perform the yk selection
    if yk_select
    then
        set -x
        ykman_cmd piv info \
            && yk_load_access_codes \
            && yk_select_access_codes \
            && env | grep YK_
    fi
    rc=$?
    echo "Goodbye!"
    exit ${rc}
}

#
# Call main if not sourced from another script.
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
    yk_main "${@}"
fi
