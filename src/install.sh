#!/bin/sh

extract () {
    tar -h --no-overwrite-dir -vvxf $1 -C ${SYSROOT} | grep ^- | tr -s " " | cut -d" " -f6 | cut -c2-
}

install_package () {
    local pkg_file="$1"
    local name="$2"
    local info_file="$pkg_file.info"

    local installed_dir="${INSTALLED_DIR}/$name"
    local info="$installed_dir/info"
    local files="$installed_dir/files"
    local checksum="$installed_dir/checksum"

    local package_checksum=$(md5sum $pkg_file | cut -d' ' -f1)
    if [ ! -f $checksum ] || [ "$(cat $checksum)" != "$package_checksum" ]; then
        mkdir -p "$installed_dir"
        [ -f $files ] && mv $files $files.old
        extract $1 > $files

        [ -f $info_file ] && cp $info_file $info

        echo $package_checksum > $checksum


        if [ -f "$files.old" ]; then
            for file in $(diff $files $files.old | grep ^\> | cut -d' ' -f2); do
                rm -f ${SYSROOT}$file
            done
            rm $files.old
        fi
    fi
}

get_package_filecount() {
    local info=$(get_package_download_info $1)
    set -- $info
    echo $4
}

total_filecount() {
    local packages=$@
    local count=0
    for package in $packages; do
        local name=$(basename -s .xipkg $package | cut -d. -f2)
        local c=$(get_package_filecount $name)
        count=$((count+c))
    done
    echo $count
}

run_postinstall () {
    postinstall="${SYSROOT}/var/lib/xipkg/postinstall"
    if [ -d $postinstall ]; then
        for file in $(ls $postinstall/*.sh); do
            f=$(basename $file)

            # run the postinstall file
            #
            chmod 755 $file
            [ "${SYSROOT}" = "/" ] &&
                sh "/var/lib/xipkg/postinstall/$f"  &&
                rm $file &&
                printf "${GREEN}run postinstall for $f!\n"
        done 
        rmdir $postinstall 2> /dev/null
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
            local name=$(basename -s .xipkg $package | cut -d. -f2)
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
