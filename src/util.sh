#!/bin/sh

download_file() {
    curl ${CURL_OPTS} -o $1 -w "%{http_code}" $2 2> /dev/null
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

            for output in $@; do
                size=$(stat -c %s $output)
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
            local extracted=0

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

format_bytes () {
    echo $@ | numfmt --to iec    

}

prompt_question () {
    $NOCONFIRM && return 0
    printf "$1 [Y/n] "
    read response
    [ "${var%${var#?}}"x != 'nx' ]
}
