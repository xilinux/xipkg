#!/bin/sh


list () {
    find ${PACKAGES_DIR} -type f | sed "s,${PACKAGES_DIR}/,," 
}

installed () {
    ls -1 ${INSTALLED_DIR}
}

list_installed () {
    list | while read -r line; do 
        [ -d ${INSTALLED_DIR}/$line ] \
            && echo $line "[installed]" \
            || echo $line
    done
}

search () {
    if [ $# = 0 ]; then
        list
    else
        list | grep $(echo $@ | sed "s/ /\\|/g")
    fi
}

files () {
    for package in $@; do
        local file="${INSTALLED_DIR}/$package/files"
        [ -f $file ] && cat $file || >&2 printf "${RED}Package ${LIGHT_RED}$package${RED} is not installed\n"
    done
}

file_info () {
    for file in $@; do
        [ ! -f ${SYSROOT}$file ] && file=$(realpath $file)
        for pkg in $(list_installed); do
            for list in ${INSTALLED_DIR}/$pkg/files; do
                grep -q ^${file}$ $list &&
                    printf "${LIGHT_BLUE}%s${BLUE} belongs to ${LIGHT_BLUE}%s${RESET}\n" $file $pkg
            done
        done
    done
}

