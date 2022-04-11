#!/bin/sh

. /usr/lib/colors.sh &&
    export HBAR_COMPLETE="-c ${GREEN}${BG_DEFAULT}" &&
    export HBAR_RED="-c ${BLACK}${BG_RED}"

. /usr/lib/glyphs.sh

export CONF_FILE="/etc/xipkg.conf"

export CURL_OPTS="-sSL"

export DEP_DIR=$(parseconf -v dir.deps)
export REPOS="$(parseconf -v repos)"
export SOURCES="$(parseconf sources.*)"

export PACKAGES_DIR=$(parseconf -v dir.packages)
export INSTALLED_DIR=${SYSROOT}$(parseconf -v dir.installed)
export KEYCHAIN_DIR=$(parseconf -v dir.keychain)

export CACHE_DIR=$(parseconf -v dir.cache)
export PACKAGE_CACHE="${CACHE_DIR}/packages"
export SYNC_CACHE="${CACHE_DIR}/sync"

export LOG_FILE="/var/log/xipkg.log"
[ ! -f ${LOG_FILE} ] && mkdir -p /var/log && touch ${LOG_FILE}
