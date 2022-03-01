#!/bin/sh

remove () {
    local packages=$@

    local to_remove="${CACHE_DIR}/toremove"
    [ -f $to_remove ] && rm $to_remove
    local real=""

    for package in $@; do
        local package_dir="${INSTALLED_DIR}/$package"
        local filesfile="${package_dir}/files"
        if [ -d $package_dir ]; then 
            [ -f $filesfile ] &&
                cat $filesfile >> $to_remove
            echo $package_dir >> $to_remove 
            real="$real $package"
        else
            >&2 printf "${RED}Package ${LIGHT_RED}$package${RED} is not installed"
        fi
    done

    local total=$(cat $to_remove | wc -l)

    ${QUIET} || printf "${LIGHT_RED}The following packages will be removed from the system:\n\t${RED}%s\n" $real
    ${QUIET} || printf "${LIGHT_RED}Files to remove: ${RED}%s\n" $total

    if prompt_question "Continue?"; then

        local removed=0
        ${QUIET} || hbar
        for file in $(cat $to_remove); do
            rm -rf ${SYSROOT}/$file
            
            removed=$((removed+1))
            ${QUIET} || hbar ${HBAR_RED} -T "removing files" $removed $total
        done
        ${QUIET} || hbar -t ${HBAR_COMPLETE} -T "removing files" $removed $total
    else
        ${QUIET} || printf "${LIGHT_BLACK}Action cancled by user\n"
    fi

}

