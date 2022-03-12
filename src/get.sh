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
    local out="${CACHE_DIR}/deps"
    local deps=""
    local i=0
    if ${RESOLVE_DEPS}; then
        hbar
        while [ "$#" != "0" ]; do

            # pop a value from the args
            local package=$1

            #only add if not already added
            if ! echo ${deps} | grep -q "\b$package\b"; then
                deps="$deps $package"
                i=$((i+1))
            fi

            for dep in $(list_deps $package); do
                # if not already checked
                if echo $@ | grep -qv "\b$dep\b"; then
                    set -- $@ $dep
                fi
            done
            shift
            ${QUIET} || hbar -T "${CHECKMARK} resolving dependencies" $i $((i + $#))
        done
        ${QUIET} || hbar -t ${HBAR_COMPLETE} -T "${CHECKMARK} resolved dependencies" $i $((i + $#))
        echo ${deps} > $out
    else
        echo $@ > $out
    fi

}

get_package_download_info() {
    sed 1q ${PACKAGES_DIR}/*/$1
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
package_exists () {
    [ "$(find ${PACKAGES_DIR} -mindepth 2 -name "$1" | wc -l)" != "0" ]
}

download_package () {
    local package=$1
    local output=$2

    local info=$(get_package_download_info $package)
    set -- $info

    local url=$1
    local checksum=$2

    local output_info="${output}.info"

    if validate_checksum $output $checksum; then
        ${VERBOSE} && printf "${LIGHT_BLACK}skipping download for %s already exists with checksum %s${RESET}\n" $package $checksum
    else
        ${VERBOSE} && printf "${LIGHT_BLACK}downloading $package from $url\n" $package $checksum
        touch $output

        (curl ${CURL_OPTS} -o "$output_info" "$url.info" || printf "${RED}Failed to download info for %s\n" $package) &
        (curl ${CURL_OPTS} -o "$output" "$url" || printf "${RED}Failed to download %s\n" $package) &
    fi

}

download_packages () {
    local total_download=$1; shift
    local packages=$@
    local outputs=""

    local out_dir="${PACKAGE_CACHE}"
    mkdir -p "$out_dir"

    for package in $packages; do 
        local output="${out_dir}/${checksum}.${package}.xipkg"
        download_package $package $output
        outputs="$outputs $output"
    done

    wait_for_download $total_download ${outputs}
    echo 

    set -- $outputs
    if ! ${UNSAFE}; then
        local i=0
        for pkg_file in ${outputs}; do 

            ${QUIET} || hbar -T "${LARGE_CIRCLE} validating downloads..." $i $#

            info_file="${pkg_file}.info"
            if ! validate_sig $pkg_file $info_file; then
                printf "${RED}Failed to verify signature for ${LIGHT_RED}%s${RED}\n" $(basename $pkg_file .xipkg)
                mv "$pkg_file" "${pkg_file}.invalid"
            else
                i=$((i+1))
            fi
        done
        ${QUIET} || hbar -t ${HBAR_COMPLETE} -T "${CHECKMARK} validated downloads" $i $#
    fi
    install $@

}

get () {
    local requested=$@

    local missing=""
    local already=""
    local install=""
    local update=""
    local urls=""

    local total_download=0

    local out="${CACHE_DIR}/deps"
    touch $out
    resolve_deps $@

    for package in $(cat $out); do
        if package_exists $package; then
            set -- $(get_package_download_info $package)
            checksum=$2
            size=$3
            
            if is_installed $package; then
                if [ "$(get_installed_version $package)" != "$checksum" ]; then
                    update="$update $package"
                    total_download=$((total_download+size))
                else
                    already="$already $package"
                fi
            else
                install="$install $package"
                total_download=$((total_download+size))
            fi
        else
            missing="$missing $package"
        fi
    done

    # TODO tidy this
    if ! ${QUIET}; then
        if [ "${#missing}" != "0" ]; then
            printf "${LIGHT_RED}The following packages could not be located:"
            for package in ${missing}; do
                printf "${RED} $package"
            done
            printf "${RESET}\n"
        fi
        if [ "${#update}" != "0" ]; then
            printf "${LIGHT_GREEN}The following packages will be updated:\n\t"
            for package in ${update}; do
                printf "${GREEN} $package"
            done
            printf "${RESET}\n"
        fi
        if [ "${#install}" != "0" ]; then
            printf "${LIGHT_BLUE}The following packages will be installed:\n\t"
            for package in ${install}; do
                printf "${BLUE} $package"
            done
            printf "${RESET}\n"
        fi
        if [ "${#install}" = "0" ] && [ "${#update}" = 0 ] && [ "${#already}" != "0" ]; then
            printf "${LIGHT_WHITE}The following packages are already up to date:\n\t"
            for package in ${already}; do
                printf "${WHITE} $package"
            done
            printf "${RESET}\n"
        fi
    fi

    [ "${#install}" = "0" ] && [ "${#update}" = 0 ] && printf "${LIGHT_RED}Nothing to do!\n" && return 0

         
    ${QUIET} || [ "${SYSROOT}" = "/" ] || printf "${WHITE}To install to ${LIGHT_WHITE}${SYSROOT}${RESET}\n"
    ${QUIET} || printf "${WHITE}Total download size:${LIGHT_WHITE} $(format_bytes $total_download)\n"

    if prompt_question "${WHITE}Continue?"; then
        download_packages $total_download ${install} ${update}
    else
        ${QUIET} || printf "${RED}Action canceled by user\n"
    fi
}

fetch () {
    local packages=$@
    local outputs=""

    local total_download=0
    for package in $packages; do 
        if package_exists $package; then
            set -- $(get_package_download_info $package)
            size=$3
            total_download=$((total_download+size))

            local output="${package}.xipkg"
            download_package $package $output
            outputs="$outputs $output"
        fi
    done

    wait_for_download $total_download ${outputs}
}
