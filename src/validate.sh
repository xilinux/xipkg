#!/bin/sh

validate_checksum () {
    local file=$1
    local checksum=$2
    [ ! -f $file ] && return 1
    [ "$(sha512sum $file | awk '{ print $1; }')" = "$checksum" ] ||
    [ "$(md5sum $file | awk '{ print $1; }')" = "$checksum" ]
    # allow md5sum for backwards compatibility 
    # TODO remove once all repos have sha512 sums
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


keyimport () {
    local keychain=${SYSROOT}${KEYCHAIN_DIR}
    mkdir -p $keychain
    case "$#" in 
        "2")
            local name=$1
            local url=$2
            
            local keyfile=$keychain/$name.pub
            printf "${BLUE}Importing $name...${GREEN}"
            download_file $keyfile $url && 
                printf "${CHECKMARK}\n" || 
                printf "${RED}Error occured!\n"      
            ;;
        "1")
            local keyname=$1

            # account for a glob input
            set +o noglob
            for key in ${KEYCHAIN_DIR}/$keyname.pub; do 
                name=$(basename -s .pub $key)
                cp $key $keychain
                printf "${GREEN}Imported ${LIGHT_GREEN}$name ${GREEN}to ${SYSROOT}\n" 
            done
            ;;
        *)
            ls $keychain
            ;;
    esac
    set +o noglob
}

validate_files () {
    local package=$1
    local ret=0

    # TODO ensure that all checksums are the same
    for file in $(files $package); do
        if [ -f "${SYSROOT}$file" ]; then
            ${VERBOSE} && printf "${GREEN}%s is present\n" $file
        else
            ret=$((ret+1))
            ${QUIET} || printf "${RED}%s is missing\n" $file
        fi
    done
    ${QUIET} || printf "${RESET}"
    return $ret
}
