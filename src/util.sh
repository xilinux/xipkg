#!/bin/sh

download_file() {
    curl ${CURL_OPTS} -o $1 -w "%{http_code}" $2 2>> ${LOG_FILE}
}

# this function is broken
wait_for_jobs () {
    local text=$1
    local end=$2
    shift 2
    joblist="-e $(echo $@ | sed "s/ / -e /g")"

    echo "$joblist"

    if ! $QUIET; then
        local total=$#
        local completed=0
        while [ "$completed" != "$total" ]; do
            running=$(ps aux | grep $joblist | wc -l)

            completed=$(( $total - $running + 1))
            hbar -T "$text" $completed $total
        done
        hbar -t ${HBAR_COMPLETE} -T "$end" $completed $total
    fi

    wait
}

wait_for_download () {
    if ! $QUIET; then
        local total_download=$1
        shift

        local downloaded=0
        while [ "$downloaded" -lt "$total_download" ]; do
            downloaded=0
            for output in $@; do
                [ -f $output ] && {
                    size=$(stat -t $output | cut -d" " -f2)
                } || {
                    size=0
                }
                downloaded=$((downloaded+size))
            done

            hbar -h -T "  downloading packages" $downloaded $total_download
        done
        hbar -th ${HBAR_COMPLETE} -T "${CHECKMARK} downloaded packages" $downloaded $total_download
    fi
        
    wait
}

wait_for_extract () {
    if ! $QUIET; then
        local total_filecount=$1
        local extracted=0
        shift

        while [ "$extracted" -lt "$total_filecount" ]; do
            extracted=0
            for output in $@; do
                if [ -f $output ]; then
                    size=$(cat $output | wc -l)
                    extracted=$((extracted+size))
                fi
            done

            hbar -T "  extracting files" $extracted $total_filecount
        done
        hbar -t ${HBAR_COMPLETE} -T "${CHECKMARK} extracted packages" $extracted $total_filecount
    fi
        
    wait
}

prompt_question () {
    $NOCONFIRM && return 0
    printf "$1 [Y/n] "
    read response
    [ "${var%${var#?}}"x != 'nx' ]
}

# return if a package is present on the system or not
#
is_installed() {
    [ -f "${INSTALLED_DIR}/$1/checksum" ]
}

# get the installed checksum of a package ($1)
#
get_installed_version () {
    local name=$1
    local file="${INSTALLED_DIR}/$name/checksum"
    [ -f $file ] &&
        cat $file
}

# 
#
package_exists () {
    [ -f "${PACKAGES_DIR}/$1" ]
}
