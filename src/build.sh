#!/bin/sh

get_buildfiles () {
    ${QUIET} || printf "${BLUE}Syncing sources..."

    [ -d "$BUILDFILES_DIR" ] ||
        mkdir -p $BUILDFILES_DIR

    cd $BUILDFILES_DIR

    {
        git rev-parse --git-dir && 
            git pull ||
            git clone $BUILDFILES_GIT .
        } > $(${VERBOSE}&&echo "/dev/stdout" || echo "/dev/null") 2>&1  && {
        ${QUIET} || printf "${GREEN}${CHECKMARK}\n"
    }
}

get_deps () {
    for f in $BUILDFILES_DIR/repo/*/$1/*.xibuild; do 
        sed -rn "s/^.*DEPS=\"(.*)\"/\1/p" $f
    done
}

build_order () {
    while [ "$#" != "0" ]; do 
        name=$1
        shift
        for dep in $(get_deps $name); do
            set -- $@ $dep
            echo $name $dep
        done
    done | tsort | reverse_lines 
}

# get the revision hash of a given builddir
#
get_revision () {
    cat $1/*.xibuild | sha512sum | cut -d' ' -f1
}

# return the installed revision of the given package
#
get_installed_revision () {
    local infofile=${INSTALLED_DIR}/$1/info
    [ -f $infofile ] && {
        sed -rn "s/^REVISION=(.*)$/\1/p" $infofile
    }
}

# test if the given package by name needs to be rebuilt
#
needs_build () {
    name=$1
    builddir=$(get_package_build $name)

    [ "$(get_revision $builddir)" = "$(get_installed_revision $name)" ] 
}


get_package_build () {
    local buildfile=$(find $BUILDFILES_DIR/repo -name "$1.xibuild" | head -1)
    echo ${buildfile%/*}
}

build_package () {
    local name=$(basename $1)
    local builddir=$(get_package_build $1)

    [ -d "$builddir" ] && {
       xibuild -ci -r ${SYSROOT} $builddir 
    } || { 
        ${QUIET} || printf "${RED}Package $1 does not exist!\n"
    }
}

build () {
    $DO_SYNC && get_buildfiles
    set -- $(build_order $@)

    for p in $@; do 
        needs_build $p && set -- $@ $p
    done

    printf "${LIGHT_BLUE}The following packages will be built: \n"
    echo "\t${BLUE}$@\n"

    prompt_question "${WHITE} Continue?" &&
        for package in $@; do 
            build_package $package || return 1
        done
}
