#!/bin/sh

extract () {
    tar -h --no-overwrite-dir -vvxf $1 -C ${SYSROOT} | grep ^-
}

install_package () {
    local pkg_file="$1"
    local name="$2"
    local info_file="$pkg_file.info"

    local installed_dir="${INSTALLED_DIR}/$name"
    local info="$installed_dir/info"
    local files="$installed_dir/files"
    local checksum="$installed_dir/checksum"

    mkdir -p "$installed_dir"
    extract $1 > $files
    cp $info_file $info

    md5sum $pkg_file | cut -d' ' -f1 > $checksum
}

get_package_filecount() {
    set -- $(get_package_download_info $1)
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

install () {
    local packages=$@

    local missing=""
    for package in $packages; do
        [ ! -f $package ] && missing="$missing $(basename $package)"
    done

    if [ "${#missing}" != "0" ]; then
        # warning: potential recursion loop here
        fetch $missing
    else
        
        local total=$(total_filecount $packages)
        local files_files=""
        for package in $packages; do
            local name=$(basename -s .xipkg $package | cut -d. -f2)
            install_package $package $name &

            mkdir -p "${INSTALLED_DIR}/$name/"
            filelist="${INSTALLED_DIR}/$name/files"
            touch $filelist
            files_files="$files_files $filelist"
        done
        wait_for_extract $total ${files_files}
    fi
}
