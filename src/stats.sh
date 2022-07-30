#!/bin/sh

show_xipkg_stats () {
    printf "${LIGHT_CYAN}${XI}${BLUE}Pkg ${LIGHT_CYAN}$VERSION ${BLUE}on ${LIGHT_BLUE}%s\n" $(cat /etc/hostname)
    echo
    printf "${LIGHT_BLACK}%-7s%*s/%s\n" " " 10 "installed" "total"

    local total=0
    local installed=0
    for package in $(list); do
        total=$((total+1))
        [ -d ${SYSROOT}${INSTALLED_DIR}/${package} ] &&
            installed=$((installed+1))
    done

    printf "${LIGHT_WHITE}%-7s${GREEN}%*s${LIGHT_WHITE}/%s\n" "packages" 10 $installed $total
}
