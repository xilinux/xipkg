#!/bin/sh


# save each listed package in a relevant directory, based on checksum
#
parse_line() {
    [ "$#" = "5" ] && {
        local url=$1
        local package=$2
        local checksum=$3
        local size=$4
        local files=$5

        local package_name=$(basename $package ".xipkg")

        local package_dir="$PACKAGES_DIR/$package_name.versions"
        local checksum_file=$package_dir/$checksum

        [ -d $package_dir ] || mkdir -p $package_dir
        printf "$url/$package $checksum $size $files\n" >> $checksum_file
    }
}

list_source () {
    local src=$1
    local url=$(echo $src | cut -d":" -f2-)
    local name=$(echo $src | cut -d":" -f1)
    local full_url="${url}/packages.list"
    local tmp_file="${SYNC_CACHE}/$name"

    ${VERBOSE} && printf "${LIGHT_BLACK}Indexing packages from $full_url\n"
    local status=$(download_file $tmp_file $full_url)
    
    if [ "$status" = "200" ] || [ "$status" = "000" ] && [ -f $tmp_file ]; then
        while IFS= read -r line; do
            parse_line $url $line
        done < "$tmp_file"
    else
        return 1
    fi
}

dep_graph () {
    local src=$1
    local url=$(echo $src | cut -d":" -f2-)
    local name=$(echo $src | cut -d":" -f1)
    local full_url="${url}deps.graph"
    local tmp_file="${SYNC_CACHE}/$name.deps.graph"
    [ -f $tmp_file ] && rm $tmp_file; touch $tmp_file

    local status=$(download_file $tmp_file $full_url)
    if [ "$status" = "200" ] ||  [ "$status" = "000" ]; then
        while IFS= read -r line; do
            [ "${#line}" != "0" ] && {
                local package=$(echo $line | cut -d: -f1)
                local new=$(echo $line | cut -d: -f2-)
                echo $new >> $DEP_DIR/$package
            }
        done < "$tmp_file"
    fi
}


contest () {
    local package_dir=$1

    local popular=$(wc -l $package_dir/* | sort -n | head -1 | awk '{ print $2 }' )

    local info_file=${package_dir%.versions}
    mv $popular $info_file
    rm -r $package_dir
}

popularity_contest () {
    if [ "$(find $PACKAGES_DIR -type f | wc -l)" = "0" ]; then
        printf "${RED}No packages found!\n";
        return 1
    fi

    local list=$(ls -1 -d $PACKAGES_DIR/*)
    local total=$(echo $list | wc -l)

    local completed=0
    for package_dir in $list; do
        contest $package_dir &
        completed=$((completed+1))
        ${QUIET} || hbar -T "${LARGE_CIRCLE} contesting packages..." $completed $total
    done
    ${QUIET} || hbar -t ${HBAR_COMPLETE} -T "${CHECKMARK} contested packages" $completed $completed
}

index_deps () {
    local l=$1
    set -- ${SOURCES}
    local total=$#
    local completed=0

    for src in ${SOURCES}; do
        ${QUIET} || hbar -l $l -T "${LARGE_CIRCLE} indexing dependencies..." $completed $total
        dep_graph $src
        completed=$((completed+1))
    done
    ${QUIET} || hbar -l $l ${HBAR_COMPLETE} -T "${CHECKMARK} indexed dependencies" $completed $total
}

index_repo () {
    local l=$1
    set -- ${SOURCES}
    local total=$#
    local completed=0

    for src in ${SOURCES}; do
        ${QUIET} || hbar -l $l -T "${LARGE_CIRCLE} syncing sources..." $completed $total
        list_source $src 
        completed=$((completed+1))
    done
    ${QUIET} || hbar -l $1 ${HBAR_COMPLETE} -T "${CHECKMARK} synced sources" $completed $total
}

sync () {
    # prepare the file structure for the sync
    mkdir -p ${SYNC_CACHE}

    [ "$(ls -A $PACKAGES_DIR)" ] && rm -r $PACKAGES_DIR/*
    rm -r $DEP_DIR
    mkdir $DEP_DIR

    ${VERBOSE} && printf "${LIGHT_BLACK}Syncing\n"

    # download package lists and dep graphs at the same time
    mkdir -p ${PACKAGES_DIR}

    # index packages and dependencies
    ${QUIET} || hbar
    ${QUIET} || hbar
    index_repo 1 &
    index_deps 0 &

    # wait for all jobs to complete
    wait

    # determine which version of which package should be regarded
    hbar
    popularity_contest
}
