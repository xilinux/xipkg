#!/bin/sh

validate_checksum () {
    local file=$1
    local checksum=$2
    [ ! -f $file ] && return 1
    [ "$(md5sum $file | awk '{ print $1; }')" = "$checksum" ]
}

validate_sig () {
    local pkg_file=$1
    local info_file=$2
    local keychain

    local sig_encoded=$(sed -rn "s/^SIGNATURE=(.*)/\1/p" $info_file)
    local sig_file="${pkg_file}.sig"

    echo $sig_encoded | tr ' ' '\n' | base64 -d > $sig_file

    for key in ${KEYCHAIN_DIR}/*.pub; do
        ${VERBOSE} && printf "${LIGHT_BLACK}Checking verification against $(basename $key) for $(basename $pkg_file)\n${RESET}"
        openssl dgst -verify $key -signature $sig_file $pkg_file | grep -q "OK" && return 0
    done
    return 1
}
