#!/bin/sh

download_file() {
    curl ${CURL_OPTS} -o $1 -w "%{http_code}" $2 2> /dev/null
}

wait_for_jobs () {
    if ! $QUIET; then
        local total=$(jobs -r | wc -l)
        local completed=0
        while [ "$completed" != "$total" ]; do
            completed=$(( $total - $(jobs -r | wc -l)))
            hbar -T "$1" $completed $total
        done
        hbar -t ${HBAR_COMPLETE} -T "$2" $completed $total
    fi

    wait
}

wait_for_download () {
    if ! $QUIET && [ "$(jobs -r | wc -l)" != "0" ]; then
        local total_download=$1
        shift
        local files=($@)

        unset downloaded
        while [ "$(jobs -r | wc -l)" != "0" ]; do
            local downloaded=0

            for output in ${files[*]}; do
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
    if ! $QUIET && [ "$(jobs -r | wc -l)" != "0" ]; then
        local total_filecount=$1
        shift
        local files=($@)

        unset extracted
        while [ "$(jobs -r | wc -l)" != "0" ]; do
            local extracted=0

            for output in ${files[*]}; do
                size=$(cat $output | wc -l)
                extracted=$((extracted+size))
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
    [ "${response:0}" != "n" ]
}
