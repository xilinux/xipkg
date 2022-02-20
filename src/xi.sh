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
    fetch [package]
        download a .xipkg file
    keyimport [name] [url]
        import a key from a url

    search [query]
        search the database for a package
    files [package]
        list files belonging to a package
    list
        list available packagesa
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

. ${LIBDIR}/profile.sh
. ${LIBDIR}/util.sh
. ${LIBDIR}/validate.sh

. ${LIBDIR}/query.sh
. ${LIBDIR}/sync.sh
. ${LIBDIR}/install.sh
. ${LIBDIR}/bootstrap.sh
. ${LIBDIR}/remove.sh
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
        "files")
            shift
            files $@
            ;;
        "keyimport")
            shift
            set -o noglob
            keyimport $@
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
        "bootstrap")
            shift
            bootstrap $@
            ;;
        "help")
            usage
            ;;
        *)
            $DO_SYNC && sync
            fetch $@
            ;;
    esac
fi
printf "${RESET}"
