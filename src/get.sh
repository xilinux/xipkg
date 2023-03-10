#!/bin/sh

# list all direct dependencies of a package
#
list_deps() {
    local name=$1
    local tree_file="${DEP_DIR}/$name"
    [ -f $tree_file ] &&
        for dep in $(cat "$tree_file"); do
            echo $dep
        done 
}

# list all dependencies and sub dependencies of a package
#
resolve_deps () {
    local out="$1"; shift
    local deps=""
    local i=0

    if ! ${RESOLVE_DEPS}; then
        echo $@ > $out
        return 0
    fi

    hbar
    while [ "$#" != "0" ]; do

        # pop a value from the args
        local package=$1

        #only add if not already added
        case "  $deps " in 
                *" $package "*);;
                *)
            deps="$deps $package"
            i=$((i+1))
            ;;
        esac

        for dep in $(list_deps $package); do
            # if not already checked
            case " $@ $deps " in 
                *" $dep "*) ;;
                *) set -- $@ $dep;;
            esac
        done
        shift

        ${QUIET} || hbar -T "${CHECKMARK} resolving dependencies" $i $((i + $#))
    done

    ${QUIET} || hbar -t ${HBAR_COMPLETE} -T "${CHECKMARK} resolved dependencies" $i $((i + $#)) 
    echo ${deps} > $out
}

# get the download info for a package ($1)
#
# in format:
#  url checksum size files 
#
get_package_download_info() {
    sed 1q ${PACKAGES_DIR}/$1
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
        return 0
    fi
    ${VERBOSE} && printf "${LIGHT_BLACK}downloading $package from $url\n" $package $checksum
    echo > $output

    (curl ${CURL_OPTS} -o "$output_info" "$url.info" 2>> ${LOG_FILE} || printf "${RED}Failed to download info for %s\n" $package) 
    (curl ${CURL_OPTS} -o "$output" "$url" 2>> ${LOG_FILE} || printf "${RED}Failed to download %s\n" $package) 
}

# download a list of packages
# will download, verify and install the packages
#
# total_download: total number of bytes to download
# packages: list of packages by name to download
#
download_packages () {
    local total_download=$1; shift
    local outputs=""

    local out_dir="${PACKAGE_CACHE}"
    mkdir -p "$out_dir"

    for package in $@; do 
        # TODO if pacakge is local, just symlink instead
        set -- $(get_package_download_info $package)
        checksum=$2
        size=$3
        outputs="$outputs ${out_dir}/${checksum}.${package}.xipkg" 
    done
    fetch_serial $total_download $outputs
    ${UNSAFE} || validate_downloads $outputs
    echo $outputs >> "${CACHE_DIR}/toinstall"
}

# validate signatures of downloaded packages
#
validate_downloads () {
    local i=0
    for pkg_file in $@; do 

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
}

# fetch requested packages
# and ultimately write the list of package files to toinstall
#
get () {
    local requested=$@
    local missing="" already="" install="" update="" urls=""
    local total_download=0
    local out="${CACHE_DIR}/deps"

    [ "$#" = "0" ] && return 0

    $DO_SYNC && sync
 
    touch $out
    resolve_deps $out $@

    for package in $(cat $out); do
        package_exists $package || {
            missing="$missing $package" 
            continue
        }

        set -- $(get_package_download_info $package)
        checksum=$2
        size=$3
        
        if is_installed $package; then
            if [ "$(get_installed_version $package)" = "$checksum" ]; then
                already="$already $package"
                continue
            fi
        else
            install="$install $package"
            total_download=$((total_download+size))
            continue
        fi

        update="$update $package"
        total_download=$((total_download+size))
    done

    ${QUIET} || {
        [ "${missing}" ] && 
            printf "${LIGHT_RED}The following packages could not be located:${RED} $missing\n${RESET}"

        [ "${update}" ] &&
            printf "${LIGHT_GREEN}The following packages will be updated:\n\t${GREEN}$update\n${RESET}"

        [ "${install}" ] &&
            printf "${LIGHT_BLUE}The following packages will be installed:\n\t${BLUE}$install\n${RESET}"

        [ ! "${install}" ] && [ ! "${update}" ] && [ "${already}" ] &&
            printf "${LIGHT_WHITE}The following packages are already up to date:\n\t${WHITE}$already\n${RESET}"
    }

    [ "${#install}" = "0" ] && [ "${#update}" = 0 ] && {
        printf "${LIGHT_RED}Nothing to do!\n"
        return 0
    }
    
    ${QUIET} || {
        [ "${SYSROOT}" = "/" ] || printf "${WHITE}To install to ${LIGHT_WHITE}${SYSROOT}${RESET}\n"
        printf "${WHITE}Total download size:${LIGHT_WHITE} $(format_bytes $total_download)\n"
    }

    prompt_question "${WHITE}Continue?" &&
    download_packages $total_download ${install} ${update} || {
        ${QUIET} || printf "${RED}Action canceled by user\n"
    }
}

# just fetch the xipkg files of requested packages
#
fetch () {
    local outputs=""
    local total_download=0
    for package in $@; do 
        package_exists $package && {
            set -- $(get_package_download_info $package)
            total_download=$((total_download+$3))
            outputs="$outputs ${package}.xipkg"
        }
    done

    fetch_serial $total_download $outputs
}

# fetch package files in serial
#
# total_download: total number of bytes to download
# outputs: list of package files to output to
#
fetch_serial () {
    wait_for_download $@ &
    shift
    for output in $@; do 
        download_package $(basename ${output%.*} | cut -d. -f2) $output 
    done
}

# fetch package files in parallel
#
# total_download: total number of bytes to download
# outputs: list of package files to output to
#
fetch_parallel () {
    local total_download=$1
    shift
    for output in $@; do 
        download_package $(basename ${output%.*} | cut -d. -f2) $output &
    done
    wait_for_download total_download $@ &
}

