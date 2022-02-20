#!/bin/sh

search () {
    find ${PACKAGES_DIR} -type f | sed "s,${PACKAGES_DIR}/,," | grep$(echo $@ | sed "s/ /\\|/g")
}
