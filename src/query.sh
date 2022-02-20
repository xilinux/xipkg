#!/bin/sh


list () {
    find ${PACKAGES_DIR} -type f | sed "s,${PACKAGES_DIR}/,," 
}

list_installed () {
    ls -1 ${INSTALLED_DIR}
}

search () {
    list | grep $(echo $@ | sed "s/ /\\|/g")
}

files () {
    for package in $@; do
        local file="${INSTALLED_DIR}/$package/files"
        [ -f $file ] && cat $file || >&2 printf "${RED}Package ${LIGHT_RED}$package${RED} is not installed"
    done
}

file_info () {
    for file in $@; do
        [ ! -f ${SYSROOT}$file ] && file=$(realpath $file)
        for list in ${INSTALLED_DIR}/*/files; do
            package=$(dirname $list | xargs basename)
            grep -q $file $list &&
                printf "${LIGHT_BLUE}%s${BLUE} belongs to ${LIGHT_BLUE}%s${RESET}\n" $file $package
        done
    done
}

