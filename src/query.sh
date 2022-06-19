#!/bin/sh


# list all available packages
#
list () {
    find ${PACKAGES_DIR} -type f | sed "s,${PACKAGES_DIR}/,," 
}

# list installed packages
#
installed () {
    ls -1 ${INSTALLED_DIR}
}

# list all packages and lable installed ones
#
list_installed () {
    list | while read -r line; do 
        [ -d ${INSTALLED_DIR}/$line ] \
            && echo $line "[installed]" \
            || echo $line
    done
}

# search for a package based on a query
#
search () {
    if [ $# = 0 ]; then
        list_installed
    else
        list_installed | grep $(echo $@ | sed "s/ /\\|/g")
    fi
}

# list the files that belong to a package
#
files () {
    for package in $@; do
        local file="${INSTALLED_DIR}/$package/files"
        [ -f $file ] && cat $file || >&2 printf "${RED}Package ${LIGHT_RED}$package${RED} is not installed\n"
    done
}

# figure out which package a file belongs to
#
file_info () {
    for file in $@; do
        [ ! -f ${SYSROOT}$file ] && file=$(realpath $file 2>/dev/null)
        local found=false
        for pkg in $(installed); do
            for list in ${INSTALLED_DIR}/$pkg/files; do
                [ -f $list ] &&  {
                    grep -q "^/usr${file}$" $list || grep -q "^${file}$" $list && {
                        ${QUIET} && echo $pkg || printf "${LIGHT_BLUE}%s${BLUE} belongs to ${LIGHT_BLUE}%s${RESET}\n" $file $pkg
                    found=true
                    }
            }
            done
        done
        $found || {
            printf "${RED}$file does not belong to any package!\n" > /dev/stderr
            return 1
        }
        
    done
}

# extract a variable from a package info 
#
#   extract_info [file] [FIELD]
#
extract_info () {
    grep -i "^$2=" $1 | cut -d'=' -f2-
}

# pretty print a xipkg info file
#
print_info ()  {
    file=$1
    name=$(extract_info $file "NAME")
    line="${LIGHT_CYAN}%-15s ${LIGHT_BLUE}%s\n" 
    for field in Name Description Version; do 
        printf "$line" "$field" "$(extract_info $file $field)"
    done

    printf "$line" "Dependencies" "$(extract_info $file "DEPS")"
    printf "$line" "Build Date" "$(extract_info $file "DATE")"

    is_installed $name && {
        date=$(date -d @$(stat -t $file | cut -d' ' -f13))
        printf "$line" "Install Date" "$date"
        printf "$line" "Install Size" "$(QUIET=true size_of $name)"
    } || true
}
 
# print information about one or more packages
#
info () {
    for package in $@; do 
        infofile=${INSTALLED_DIR}/$package/info
        [ -f $infofile ] && {
            print_info $infofile
        } || {
            printf "Package info for $package could not be found!\n"
        }
    done
}

# get the size of a package
#
size_of () {
    local size=0 file=
    for file in $(files $@); do 
        $VERBOSE && printf "${BLACK}file $file "
        [ -f "$file" ] && {
            set -- $(stat -t $file)
            $VERBOSE && printf "has size $2"
            size=$((size+$2))
        }
        $VERBOSE && printf "\n"
    done
    echo $size
}

