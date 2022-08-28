#!/bin/sh

#include xilib.sh
#include profile.sh
#include util.sh
#include validate.sh

#include query.sh
#include sync.sh
#include install.sh
#include build.sh
#include get.sh
#include remove.sh
#include stats.sh
#include bootstrap.sh
#>echo "VERSION=$(git describe --always)"

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
    ${LIGHT_GREEN}verify ${LIGHT_BLUE}[package...]
        ${LIGHT_CYAN}verify that a package's files are intact
    ${LIGHT_GREEN}size ${LIGHT_BLUE}[package...]
        ${LIGHT_CYAN}get the Total installed size of a package
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

shift $((OPTIND-1))

if [ "$#" = "0" ]; then
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
            do_install $@
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
            remove $@
            do_install $@
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
        "size")
            shift
            [ "$#" = "0" ] && set -- $(installed)

            total=$(for p in $@; do
                echo "$(size_of $p) $p"
            done | sort -n | while read f; do 
                set -- $f
                $QUIET  || printf "${WHITE}Size of ${BLUE}%s${WHITE}: ${LIGHT_WHITE}%s\n" "$2" "$(format_bytes $1)" >/dev/stderr
                echo $1
            done | paste -s -d+ - | bc)

            $QUIET && echo $total || {
                [ "$total" != "$size" ] &&
                    printf "${WHITE}Total size: ${LIGHT_WHITE}%s\n" "$(format_bytes $total)"
            }
            ;;
        "file")
            shift
            file_info $@
            ;;
        "info")
            shift
            info $@
            ;;
        "verify")
            shift
            [ -z "$*" ] && set -- $(ls ${SYSROOT}${INSTALLED_DIR})
            while [ ! -z "$*" ]; do
                validate_files $1 || {
                   ${QUIET} && printf "%s\n" $1 || printf "${LIGHT_RED}Failed to verify $1\n"
                    
                }
                shift
            done
            ;;
        "bootstrap")
            shift
            checkroot
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
