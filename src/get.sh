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

            #only add if not already added
            echo ${deps[*]} | grep -q "\b$dep\b" || deps+=($package)

            for dep in $(list_deps $package); do
                # if not already checked
                if echo ${deps[@]} | grep -qv "\b$dep\b"; then
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

download_packages () {
    local total_download=$1; shift
    local packages=($@)
    local outputs=()

    local out_dir="${PACKAGE_CACHE}"
    mkdir -p "$out_dir"

    for package in ${packages[*]}; do 
        local info=($(get_package_download_info $package))
        local url=${info[0]}
        local checksum=${info[1]}

        local output="${out_dir}/${checksum}.${package}.xipkg"
        local output_info="${output}.info"

        if validate_checksum $output $checksum; then
            ${VERBOSE} && printf "${LIGHT_BLACK}skipping download for %s already exists with checksum %s${RESET}\n" $package $checksum
        else
            touch $output

            curl ${CURL_OPTS} -o "$output_info" "$url.info" &
            curl ${CURL_OPTS} -o "$output" "$url" &
        fi

        outputs+=($output)
    done

    wait_for_download $total_download ${outputs[*]}

    
    local i=0
    for pkg_file in ${outputs[*]}; do 

        ${QUIET} || hbar -T "${LARGE_CIRCLE} validating downloads..." $i ${#outputs[*]}

        info_file="${pkg_file}.info"
        if ! validate_sig $pkg_file $info_file; then
            printf "${RED}Failed to verify signature for ${LIGHT_RED}%s${RED}\n" $(basename -s .xipkg $pkg_file)
            mv "$pkg_file" "${pkg_file}.invalid"
        else
            i=$((i+1))
        fi
    done
    ${QUIET} || hbar -t ${HBAR_COMPLETE} -T "${CHECKMARK} validated downloads" $i ${#outputs[*]}

    install ${outputs[*]}

}

fetch () {
    local requested=($@)

    local missing=()
    local already=()
    local install=()
    local update=()
    local urls=()

    local total_download=0

    for package in $(resolve_deps $@); do
        if package_exists $package; then
            info=($(get_package_download_info $package))
            url=${info[0]}
            checksum=${info[1]}
            size=${info[2]}
            files=${info[3]}
            
            if is_installed $package; then
                if [ "$(get_installed_version $package)" != "$checksum" ]; then
                    update+=($package)
                    total_download=$((total_download+size))
                else
                    already+=($package)
                fi
            else
                install+=($package)
                total_download=$((total_download+size))
            fi
        else
            missing+=($package)
        fi
    done

    if ! ${QUIET}; then
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
            printf "${LIGHT_BLUE}The following packages will be installed:\n\t"
            for package in ${install[*]}; do
                printf "${BLUE} $package"
            done
            printf "${RESET}\n"
        fi
        if [ "${#already[@]}" != "0" ]; then
            printf "${LIGHT_WHITE}The following packages are already up to date:\n\t"
            for package in ${already[*]}; do
                printf "${WHITE} $package"
            done
            printf "${RESET}\n"
        fi
    fi

    [ "${#install[@]}" = "0" ] && [ "${#update[@]}" = 0 ] && printf "${LIGHT_RED}Nothing to do!\n" && return 0

         
    ${QUIET} || [ "${SYSROOT}" = "/" ] || printf "${WHITE}To install to ${LIGHT_WHITE}${SYSROOT}${RESET}\n"
    ${QUIET} || printf "${WHITE}Total download size:${LIGHT_WHITE} $(format_bytes $total_download)\n"

    if prompt_question "${WHITE}Continue?"; then
        download_packages $total_download ${install[*]} ${update[*]}
    else
        ${QUIET} || printf "${RED}Action canceled by user\n"
    fi
}


