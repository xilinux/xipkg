#!/bin/sh


# save each listed package in a relevant directory, based on checksum
#
parse_line() {
    local repo=$1
    local repo_url=$2
    local package=$3
    local checksum=$4
    local size=$5
    local files=$6

    local package_name=$(basename -s ".xipkg" $package)

    local package_dir="$PACKAGES_DIR/$repo/$package_name.versions"
    local checksum_file=$package_dir/$checksum

    [ -d $package_dir ] || mkdir -p $package_dir
    printf "$repo_url/$package $checksum $size $files\n" >> $checksum_file
}

list_source () {
    local repo=$1
    local src=$2

    local url=$(echo $src | cut -d":" -f2-)
    local name=$(echo $src | cut -d":" -f1)
    local repo_url="${url}${repo}"
    local full_url="${repo_url}/packages.list"
    local tmp_file="${SYNC_CACHE}/$name.$repo"

    ${VERBOSE} && printf "${LIGHT_BLACK}Indexing $repo from $full_url\n"
    local status=$(download_file $tmp_file $full_url)
    
    if [ "$status" = "200" ] ||  [ "$status" = "000" ]; then
        while IFS= read -r line; do
            parse_line $repo $repo_url $line
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
            local package=$(echo $line | cut -d: -f1)
            local new=$(echo $line | cut -d: -f2-)
            echo $new >> $DEP_DIR/$package
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

    local list=$(ls -1 -d $PACKAGES_DIR/*/*)
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
        dep_graph $src
        completed=$((completed+1))
        ${QUIET} || hbar -l $l -T "${LARGE_CIRCLE} indexing dependencies..." $completed $total
    done
    ${QUIET} || hbar -l $l ${HBAR_COMPLETE} -T "${CHECKMARK} indexed dependencies" $completed $total
}

index_repo () {
    local repo=$1 l=$2
    set -- ${SOURCES}
    local total=$#
    local completed=0


    for src in ${SOURCES}; do
        list_source $repo $src 
        completed=$((completed+1))
        ${QUIET} || hbar -l $l -T "${LARGE_CIRCLE} syncing $repo..." $completed $total
    done
    ${QUIET} || hbar -l $l ${HBAR_COMPLETE} -T "${CHECKMARK} synced $repo" $completed $total
}

sync () {
    # prepare the file structure for the sync
    mkdir -p ${SYNC_CACHE}

    [ "$(ls -A $PACKAGES_DIR)" ] && rm -r $PACKAGES_DIR/*
    rm -r $DEP_DIR
    mkdir $DEP_DIR

    ${VERBOSE} && printf "${LIGHT_BLACK}Syncing\n"
    # create padding spaces for each hbar 
    ${QUIET} || for repo in ${REPOS}; do 
        hbar
    done

    # download package lists and dep graphs at the same time
    index_deps 0 &
    local i=1
    for repo in ${REPOS}; do 
        mkdir -p ${PACKAGES_DIR}/$repo
        index_repo $repo $i &
        i=$((i+1))
    done

    # wait for all jobs to complete
    wait

    # determine which version of which package should be regarded
    hbar
    popularity_contest
}
