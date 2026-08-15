#!/bin/bash
#
# Simple script to change the access codes (PIN, PUK, MGMT) in a Yubikey.
#
# Automates the creation of random PIN, PUK and MGMT codes for a given Yubikey
# serial number and stores those values in a file for later reuse.
#

source ./yk-utils.sh

if yk_select
then
    yk_cmd info
    yk_get_access_codes
    yk_cmd piv info
    yk_cmd piv reset
    yk_change_access
fi
