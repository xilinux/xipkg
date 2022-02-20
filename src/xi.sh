#!/bin/sh

[ -z "${LIBDIR}" ] && LIBDIR=/usr/lib/xipkg

export SYSROOT=/
export CONF_FILE="/etc/xipkg.conf"
export VERBOSE=false
export QUIET=false
export RESOLVE_DEPS=true
export DO_SYNC=true
export UNSAFE=false
export NOCONFIRM=false

while getopts ":r:c:qnluyv" opt; do
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
        q)
            QUIET=true
            ;;
    esac
done

. ${LIBDIR}/profile.sh
. ${LIBDIR}/util.sh
. ${LIBDIR}/validate.sh

. ${LIBDIR}/sync.sh
. ${LIBDIR}/install.sh
. ${LIBDIR}/get.sh

shift $((OPTIND-1))

if [ "$#" = "0" ]; then
    echo "xilinux running xipkg (palceholder text)"
else 
    case "$1" in
        "sync")
            sync
            ;;
        "install" | "update")
            shift
            $DO_SYNC && sync
            install $@
            ;;
        *)
            $DO_SYNC && sync
            fetch $@
            ;;
    esac
fi
printf "${RESET}"
