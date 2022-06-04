#!/bin/sh

usage () {
cat << EOF
${LIGHT_WHITE}XiPkg Version $VERSION

${BLUE}Available Options:
    ${BLUE}-r ${LIGHT_BLUE}[path]
        ${LIGHT_CYAN}specify the installation root ${LIGHT_WHITE}[default: /]
    ${BLUE}-c [path]
        ${LIGHT_CYAN}specify the config file to use ${LIGHT_WHITE}[default: /etc/xipkg.conf]
    ${BLUE}-q
        ${LIGHT_CYAN}supress unecessary outputs
    ${BLUE}-v
        ${LIGHT_CYAN}be more verbose
    ${BLUE}-n
        ${LIGHT_CYAN}do not resolve package dependenceies
    ${BLUE}-l
        ${LIGHT_CYAN}do not sync databases (ignored when explicitly running sync)
    ${BLUE}-u
        ${LIGHT_CYAN}do not validate against keychain
    ${BLUE}-y
        ${LIGHT_CYAN}skip prompts
    ${BLUE}-h 
        ${LIGHT_CYAN}show help and exists

${BLUE}Available Commands:
    ${LIGHT_GREEN}sync
        ${LIGHT_CYAN}sync the local package database with the remote repositories

    ${LIGHT_GREEN}install ${LIGHT_BLUE}[packages..]
        ${LIGHT_CYAN}install package(s) into the system
    ${LIGHT_GREEN}update
        ${LIGHT_CYAN}update all packages on the system
    ${LIGHT_GREEN}remove ${LIGHT_BLUE}[packages...]
        ${LIGHT_CYAN}remove packages from the system
    ${LIGHT_GREEN}reinstall ${LIGHT_BLUE}[packages..]
        ${LIGHT_CYAN}remove and reinstall package(s) into the system
    ${LIGHT_GREEN}fetch ${LIGHT_BLUE}[package]
        ${LIGHT_CYAN}download a .xipkg file
    ${LIGHT_GREEN}keyimport ${LIGHT_BLUE}[name] [url]
        ${LIGHT_CYAN}import a key from a url
    ${LIGHT_GREEN}clean
        ${LIGHT_CYAN}clean cached files and data
    ${LIGHT_GREEN}build
        ${LIGHT_CYAN}build a package from source

    ${LIGHT_GREEN}search ${LIGHT_BLUE}[query]
        ${LIGHT_CYAN}search the database for a package
    ${LIGHT_GREEN}files ${LIGHT_BLUE}[package]
        ${LIGHT_CYAN}list files belonging to a package
    ${LIGHT_GREEN}verify ${LIGHT_BLUE}[package]
        ${LIGHT_CYAN}verify that a package's files are intact
    ${LIGHT_GREEN}list
        ${LIGHT_CYAN}list available packages
    ${LIGHT_GREEN}installed
        ${LIGHT_CYAN}lists installed packages
    ${LIGHT_GREEN}list-installed
        ${LIGHT_CYAN}list packages showing the installed ones
    ${LIGHT_GREEN}file ${LIGHT_BLUE}[path]
        ${LIGHT_CYAN}shows which package a file belongs to
    ${LIGHT_GREEN}info ${LIGHT_BLUE}[package]
        ${LIGHT_CYAN}show info about an installed package

    ${LIGHT_GREEN}bootstrap ${LIGHT_BLUE}[additional packages...]
        ${LIGHT_CYAN}installs base packages and system files to an empty system

    ${LIGHT_GREEN}help
        ${LIGHT_CYAN}shows this message${RESET}

${RED}Usage: xi [options] command...
EOF
}


[ -z "${LIBDIR}" ] && LIBDIR=/usr/lib/xipkg
[ -f "/usr/lib/xilib.sh" ] && . /usr/lib/xilib.sh

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
. ${LIBDIR}/build.sh
. ${LIBDIR}/get.sh
. ${LIBDIR}/remove.sh

shift $((OPTIND-1))

if [ "$#" = "0" ]; then
    . ${LIBDIR}/stats.sh
    show_xipkg_stats
else 
    case "$1" in
        "sync")
            checkroot
            sync
            ;;
        "install" | "update")
            shift
            checkroot

            [ "$#" = "0" ] && set -- $(list_installed)

            toinstall=${CACHE_DIR}/toinstall

            echo "" > $toinstall
            tofetch=""
            for f in $@; do
                [ -f "$f" ] && echo $f >> $toinstall || tofetch="$tofetch$f "
            done

            get $tofetch
            install $(cat $toinstall)
            ;;
        "build")
            shift
            checkroot

            [ "$#" = "0" ] && set -- $(installed)

            build $@
            ;;
        "search")
            shift
            search $@
            ;;
        "fetch")
            shift
            checkroot
            $DO_SYNC && sync
            fetch $@
            ;;
        "remove")
            shift
            checkroot
            remove $@
            ;;
        "reinstall")
            shift
            checkroot
            reinstall $@
            ;;
        "files")
            shift
            files $@
            ;;
        "keyimport")
            shift
            checkroot
            set -o noglob
            keyimport $@
            ;;
        "clean")
            shift
            checkroot
            . ${LIBDIR}/remove.sh
            clean $@
            ;;
        "list")
            list
            ;;
        "list-installed")
            list_installed
            ;;
        "installed")
            installed
            ;;
        "file")
            shift
            file_info $@
            ;;
        "info")
            shift
            for package in $@; do 
                infofile=${INSTALLED_DIR}/$package/info
                [ -f $infofile ] && {
                    cat $infofile
                } || {
                    printf "Package info for $package could not be found!"
                }
            done
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
            checkroot
            . ${LIBDIR}/bootstrap.sh
            bootstrap $@
            ;;
        "help")
            usage
            ;;
        *)

            sudo $0 ${DEFAULT_OPTION:-install} $@
            ;;
    esac
fi

${QUIET} || printf "${RESET}"
