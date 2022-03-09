#!/bin/sh

DEFAULT_KEYS="davidovski https://xi.davidovski.xyz/keychain/xi.pub"

create_directories () {
    mkdir -p ${SYSROOT}
    mkdir -p ${SYSROOT}/dev
    mkdir -p ${SYSROOT}/tmp
    mkdir -p ${SYSROOT}/sys
    mkdir -p ${SYSROOT}/run
    mkdir -p ${SYSROOT}/proc
    mkdir -p ${SYSROOT}/usr
    mkdir -p ${SYSROOT}/root
    mkdir -p ${SYSROOT}/usr/bin
    mkdir -p ${SYSROOT}/usr/lib

    ln -s usr/bin ${SYSROOT}/bin
    ln -s usr/bin ${SYSROOT}/sbin
    ln -s bin ${SYSROOT}/usr/sbin

    ln -s usr/lib ${SYSROOT}/lib
    ln -s usr/lib ${SYSROOT}/lib64
    ln -s usr/lib ${SYSROOT}/usr/lib64

    ln -s usr ${SYSROOT}/usr/local
}

import_keys () {
    # import all keys
    set -o noglob
    if [ -d ${KEYCHAIN_DIR} ] && [ "$(ls ${KEYCHAIN_DIR} | wc -w)" != "0" ]; then
        keyimport *
    else
        keyimport $DEFAULT_KEYS
    fi
}

bootstrap () {
    if [ "${SYSROOT}" = "/" ]; then
        printf "${RED}Error! Cannot bootstrap on existing system! Use ${LIGHT_RED}--root${RED} to specify new root filesystem\n"
        return 1
    fi

    if [ -e ${SYSROOT} ] && [ "$(ls -1 ${SYSROOT})" != "0" ]; then
        if prompt_question "${WHITE}System already exists on ${SYSROOT}, clear?"; then
            rm -rf ${SYSROOT}/*
        fi
    fi
    
    printf "${BLUE}Creating directories..."
    create_directories
    printf "${GREEN}${CHECKMARK}\n"

    ${DO_SYNC} && sync

    [ "$#" != "0" ] && install $@

    import_keys 
}
