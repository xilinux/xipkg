#!/bin/sh

extract () {
    tar -h --keep-old-files -p -vvxf $1 -C ${SYSROOT} 2>${LOG_FILE} | grep ^- | tr -s " " | cut -d" " -f6 | cut -c2- 
}

install_package () {
    local pkg_file="$1"
    local name="$2"
    local info_file="$pkg_file.info"

    local installed_dir="${INSTALLED_DIR}/$name"
    local info="$installed_dir/info"
    local files="$installed_dir/files"
    local checksum="$installed_dir/checksum"

    set -- $(md5sum $pkg_file)
    local package_checksum=$1
    if [ ! -f $checksum ] || [ "$(cat $checksum)" != "$package_checksum" ]; then
        [ ! -d $installed_dir ] && mkdir -p "$installed_dir"

        [ -f "$files" ] && {
            for file in $(cat $files); do
                rm -f ${SYSROOT}$file
            done
            rm $files
        }

        ${VERBOSE} && printf "${BLACK}Extracting $name...\n"
        extract $pkg_file > $files

        [ -f $info_file ] && cp $info_file $info
        echo $package_checksum > $checksum
        return 0
    fi
    ${VERBOSE} && printf "${BLACK}Skipping $name; already installed...\n"
    return 1
}

get_package_filecount() {
    set -- $(get_package_download_info $1)
    echo $4
}

total_filecount() {
    local packages=$@
    local count=0
    for package in $packages; do
        local name=$(basename $package .xipkg | cut -d. -f2)
        local c=$(get_package_filecount $name)
        count=$((count+c))
    done
    echo $count
}

run_postinstall () {
    postinstall="${SYSROOT}/var/lib/xipkg/postinstall"
    if [ -d $postinstall ]; then
        for f in $(ls $postinstall); do
            file=$postinstall/$f

            # run the postinstall file
            #
            chmod 755 $file
            if [ "${SYSROOT}" = "/" ]; then
                sh "/var/lib/xipkg/postinstall/$f" 
            else
                xichroot ${SYSROOT} "/var/lib/xipkg/postinstall/$f" 
            fi
            if [ "$?" = "0" ]; then
                rm $file &&
                printf "${GREEN}${CHECKMARK} run postinstall for $f!\n"
            else
                printf "${RED}${CROSSMARK} failed running postinstall for $f!\n"
            fi
        done 
    fi
}


install () {
    local packages=$@
    ${VERBOSE} && printf "${BLACK}Requested to install: $@\n${RESET}"

    if [ "$#" = "0" ]; then
        packages=$(ls ${INSTALLED_DIR})
    fi

    local missing=""
    for package in $packages; do
        [ ! -f $package ] && missing="$missing $(basename $package)"
    done

    if [ "${#missing}" != "0" ]; then
        ${VERBOSE} && printf "${BLACK}couldnt find: $missing\n${RESET}"
        # warning: potential recursion loop here
        get $missing
    else
        
        local total=$(total_filecount $packages 2>/dev/null || echo 1)
        local files_files=""
        for package in $packages; do
            local name=$(basename $package .xipkg | cut -d. -f2)
            ${VERBOSE} && printf "${BLACK}installing $name from $package \n${RESET}"
            install_package $package $name &

            mkdir -p "${INSTALLED_DIR}/$name/"
            filelist="${INSTALLED_DIR}/$name/files"
            touch $filelist
            files_files="$files_files $filelist"
        done
        wait_for_extract $total ${files_files}
        run_postinstall
    fi
}

reinstall () {  
    local packages=$@
    remove $@
    install $@
}

