#!/bin/sh

remove () {
    local packages=$@

    local to_remove="${CACHE_DIR}/toremove"
    [ -d ${CACHE_DIR} ] || mkdir -p ${CACHE_DIR}
    [ -f $to_remove ] && rm $to_remove
    touch $to_remove
    local real=""

    for package in $@; do
        local package_dir="${INSTALLED_DIR}/$package"
        local filesfile="${package_dir}/files"
        if [ -d $package_dir ]; then 
            [ -f $filesfile ] &&
                while IFS= read -r file; do
                    echo ${SYSROOT}/$file >> $to_remove
                done < $filesfile
            echo $package_dir >> $to_remove 
            real="$real $package"
        else
            >&2 printf "${RED}Package ${LIGHT_RED}$package${RED} is not installed"
        fi
    done

    local total=$(cat $to_remove | wc -l)

    ${QUIET} || printf "${LIGHT_RED}The following packages will be removed from the system:\n\t${RED}%s\n" $real
    ${QUIET} || printf "${LIGHT_RED}Files to remove: ${RED}%s\n" $total
    ${VERBOSE} && cat $to_remove

    if prompt_question "Continue?"; then

        local removed=0
        ${QUIET} || hbar
        for file in $(cat $to_remove); do
            rm -rf $file
            
            removed=$((removed+1))
            ${QUIET} || hbar ${HBAR_RED} -T "removing files" $removed $total
        done
        ${QUIET} || hbar -t ${HBAR_COMPLETE} -T "removed files" $removed $total
    else
        ${QUIET} || printf "${LIGHT_BLACK}Action cancled by user\n"
    fi

}

clean () {
    set -- $(du -sh ${CACHE_DIR})
    
    if prompt_question "${LIGHT_RED}Remove ${RED}$1${LIGHT_RED} of cached files?"; then 
        rm -rf ${CACHE_DIR}/*
        ${QUIET} || printf "${GREEN}Cleared package cache!\n"
    else
        ${QUIET} || printf "${LIGHT_BLACK}Action cancled by user\n"
    fi
}
