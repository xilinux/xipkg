#!/bin/sh

usage () {
cat << "EOF"
Usage: xi [options] command...

Available Options:
    -r [path]
        specify the installation root [default: /]
    -c [path]
        specify the config file to use [default: /etc/xipkg.conf]
    -q
        supress unecessary outputs
    -v
        be more verbose
    -n
        do not resolve package dependenceies
    -l
        do not sync databases (ignored when explicitly running sync)
    -u
        do not validate against keychain
    -y
        skip prompts
    -h 
        show help and exists

Available Commands:
    sync
        sync the local package database with the remote repositories

    install [packages..]
        install package(s) into the system
    update
        update all packages on the system
    remove [packages...]
        remove packages from the system
    reinstall [packages..]
        remove and reinstall package(s) into the system
    fetch [package]
        download a .xipkg file
    keyimport [name] [url]
        import a key from a url
    clean
        clean cached files and data

    search [query]
        search the database for a package
    files [package]
        list files belonging to a package
    verify [package]
        verify that a package's files are intact
    list
        list available packages
    list-installed
        lists installed packages
    file [path]
        shows which package a file belongs to

    bootstrap [additional packages...]
        installs base packages and system files to an empty system

    help
        shows this message
EOF
}

[ -z "${LIBDIR}" ] && LIBDIR=/usr/lib/xipkg

[ -f ${LIBDIR}/VERSION ] && VERSION=$(cat ${LIBDIR}/VERSION) || VERSION=
export VERSION

export SYSROOT=/
export CONF_FILE="/etc/xipkg.conf"
export VERBOSE=false
export QUIET=false
export RESOLVE_DEPS=true
export DO_SYNC=true
export UNSAFE=false
export NOCONFIRM=false

while getopts ":r:c:qnluyvh" opt; do
    case "${opt}" in
        r)
            SYSROOT=$(realpath ${OPTARG})
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
        h)
            usage
            exit 0
            ;;
    esac
done

# TODO only load these modules when needed
. ${LIBDIR}/profile.sh
. ${LIBDIR}/util.sh
. ${LIBDIR}/validate.sh

. ${LIBDIR}/query.sh
. ${LIBDIR}/sync.sh
. ${LIBDIR}/install.sh
. ${LIBDIR}/get.sh
. ${LIBDIR}/remove.sh

shift $((OPTIND-1))

if [ "$#" = "0" ]; then
    . ${LIBDIR}/stats.sh
    show_xipkg_stats
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
        "search")
            shift
            search $@
            ;;
        "fetch")
            shift
            $DO_SYNC && sync
            fetch $@
            ;;
        "remove")
            shift
            remove $@
            ;;
        "reinstall")
            shift
            reinstall $@
            ;;
        "files")
            shift
            files $@
            ;;
        "keyimport")
            shift
            set -o noglob
            keyimport $@
            ;;
        "clean")
            shift
            . ${LIBDIR}/remove.sh
            clean $@
            ;;
        "list")
            list
            ;;
        "list-installed")
            list_installed
            ;;
        "file")
            shift
            file_info $@
            ;;
        "verify")
            shift
            [ -z "$*" ] && set -- $(ls ${INSTALLED_DIR})
            while [ ! -z "$*" ]; do
                validate_files $1 || printf "${LIGHT_RED}Failed to verify $1\n"
                shift
            done
            ;;
        "bootstrap")
            shift
            . ${LIBDIR}/bootstrap.sh
            bootstrap $@
            ;;
        "help")
            usage
            ;;
        *)
            $DO_SYNC && sync
            install $@
            ;;
    esac
fi
printf "${RESET}"
