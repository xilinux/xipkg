#!/bin/bash

[ -z "${LIBDIR}" ] && LIBDIR=/usr/lib/xipkg
. ${LIBDIR}/profile.sh
. ${LIBDIR}/sync.sh
. ${LIBDIR}/get.sh

export SYSROOT=/
export CONF_FILE="/etc/xipkg.conf"
export VERBOSE=false
export RESOLVE_DEPS=true
export DO_SYNC=true
export UNSAFE=false
export NOCONFIRM=false

while getopts ":r:c:nluyv" opt; do
    case "${opt}" in
        r)
            SYSROOT="${OPTARG}"
            ;;
        c)
            CONF_FILE="${OPTARG}"
            ;;
        n)
            RESOLVE_DEPS=false
            ;;
        l)
            DO_SYNC=false
            ;;
        u)
            UNSAFE=true
            ;;
        y)
            NOCONFIRM=true
            ;;
        v)
            VERBOSE=true
            ;;
    esac
done

shift $((OPTIND-1))

download $@
