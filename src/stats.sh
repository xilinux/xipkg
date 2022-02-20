#!/bin/sh

show_xipkg_stats () {
    printf "${LIGHT_CYAN}${XI}${BLUE}Pkg ${LIGHT_CYAN}$VERSION ${BLUE}on ${LIGHT_BLUE}%s\n" $(cat /etc/hostname)
    echo
    printf "${LIGHT_BLACK}%-7s%*s/%s\n" "repo" 10 "installed" "total"

    for repo in ${REPOS}; do

        local total=0
        local installed=0
        for package in $(list | grep "^$repo/"); do
            total=$((total+1))
            name=${package#$repo/}
            [ -d ${INSTALLED_DIR}/${name} ] &&
                installed=$((installed+1))
        done

        if [ "$repo" = "xi" ]; then
            installed=35
        fi

        printf "${LIGHT_WHITE}%-7s${GREEN}%*s${LIGHT_WHITE}/%s\n" $repo 10 $installed $total

    done
}
