#!/bin/sh


# list all direct dependencies of a package
#
list_deps() {
    local name=$1
    local tree_file="${DEP_DIR}/$name"
    [ -f $tree_file ] &&
        for dep in $(cat "$tree_file"); do
            echo $dep
        done | sort -u
}

# list all dependencies and sub dependencies of a package
#
resolve_deps () {
    local deps=()
    local to_check=($@)
    if ${RESOLVE_DEPS}; then
        while [ "${#to_check[@]}" != "0" ]; do
            local package=${to_check[-1]}
            unset to_check[-1]

            deps+=($package)
            for dep in $(list_deps $package); do
                # if not already checked
                if echo ${deps[*]} | grep -qv "\b$dep\b"; then
                    to_check+=($dep)
                fi
            done
        done
        echo ${deps[@]}
    else
        echo $@
    fi

}

get_package_download_info() {
    tail -1 ${PACKAGES_DIR}/*/$1
}

get_available_version () {
    echo "${info[1]}"
}

is_installed() {
    [ -f "${INSTALLED_DIR}/$1/checksum" ]
}

get_installed_version () {
    local name=$1
    local file="${INSTALLED_DIR}/$name/checksum"
    [ -f $file ] &&
        cat $file
}

# bad implementation
exists () {
    [ "$(find ${PACKAGES_DIR} -mindepth 2 -name "$1" | wc -l)" != "0" ]
}

download () {
    local requested=($@)

    local missing=()
    local install=()
    local update=()
    local urls=()

    local total_download=0

    for package in $(resolve_deps $@); do
        if exists $package; then
            info=($(get_package_download_info $package))
            url=${info[0]}
            checksum=${info[1]}
            size=${info[2]}
            files=${info[3]}
            
            if is_installed $package; then
                if [ "$(get_installed_version $package)" != "$(get_available_version $package)" ]; then
                    update+=($package)
                    total_download=$((total_download+size))
                fi
            else
                install+=($package)
                total_download=$((total_download+size))
            fi
        else
            missing+=($package)
        fi
    done

    if [ "${#missing[@]}" != "0" ]; then
        printf "${LIGHT_RED}The following packages could not be located:"
        for package in ${missing[*]}; do
            printf "${RED} $package"
        done
        printf "${RESET}\n"
    fi
    if [ "${#update[@]}" != "0" ]; then
        printf "${LIGHT_GREEN}The following packages will be updated:\n\t"
        for package in ${update[*]}; do
            printf "${GREEN} $package"
        done
        printf "${RESET}\n"
    fi
    if [ "${#install[@]}" != "0" ]; then
        printf "${LIGHT_BLUE}The following packages will be updated:\n\t"
        for package in ${install[*]}; do
            printf "${BLUE} $package"
        done
        printf "${RESET}\n"
    fi

    echo "total download size: ${total_download} bytes"
}


