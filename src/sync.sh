#!/bin/bash

download_file() {
    curl ${CURL_OPTS} -o $1 -w "%{http_code}" $2 2> /dev/null
}

wait_for_jobs () {
    local total=$(jobs -r | wc -l)
    local completed=0
    while [ "$completed" != "$total" ]; do
        completed=$(( $total - $(jobs -r | wc -l)))
        hbar -T "$1" $completed $total
    done
    hbar -t -T "$2" $completed $total
    wait
}

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
    local tmp_file="$TMP_DIR/$name.$repo"

    local status=$(download_file $tmp_file $full_url)
    
    if [ "$status" = "200" ]; then
        while IFS= read -r line; do
            parse_line $repo $repo_url $line
        done < "$tmp_file"
    fi
}

dep_graph () {
    local src=$1
    local url=$(echo $src | cut -d":" -f2-)
    local name=$(echo $src | cut -d":" -f1)
    local full_url="${url}deps.graph"
    local tmp_file="$TMP_DIR/$name.deps"
    [ -f $tmp_file ] && rm $tmp_file; touch $tmp_file

    if [ "$(download_file $tmp_file $full_url)" = "200" ]; then
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

    local info_file=$(sed "s/.versions//g" <<< "$package_dir")
    mv $popular $info_file
    rm -r $package_dir
}

popularity_contest () {
    local list=$(ls -1 -d $PACKAGES_DIR/*/*)
    local total=$(echo $list | wc -l)

    for package_dir in $list; do
        contest $package_dir &
    done

    wait_for_jobs "contesting packages..." "contested packages"
}

index_deps () {
    local l=$1
    local total=${#SOURCES[*]}
    local completed=0

    for src in ${SOURCES[*]}; do
        dep_graph $src
        completed=$((completed+1))
        hbar -l $l -T "indexing dependencies..." $completed $total
    done
    hbar -l $l -T "indexed dependencies" $completed $total
}

index_repo () {
    local repo=$1 l=$2
    local total=${#SOURCES[*]}
    local completed=0

    for src in ${SOURCES[*]}; do
        list_source $repo $src 
        completed=$((completed+1))
        hbar -l $l -T "syncing $repo..." $completed $total
    done
    hbar -l $l -T "synced $repo" $completed $total
}


sync () {
    # prepare the file structure for the sync
    mkdir -pv $TMP_DIR
    rm -r $PACKAGES_DIR/*
    rm -r $DEP_DIR
    mkdir $DEP_DIR

    # create padding spaces for each hbar 
    for repo in ${REPOS[*]}; do 
        hbar
    done

    # download package lists and dep graphs at the same time
    index_deps 0 &
    local i=1
    for repo in ${REPOS[*]}; do 
        index_repo $repo $i &
        i=$((i+1))
    done

    # wait for all jobs to complete
    wait

    # determine which version of which package should be regarded
    hbar
    popularity_contest
}
