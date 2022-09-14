#!/bin/sh

#include colors.sh
#include glyphs.sh

export HBAR_COMPLETE="-c ${GREEN}${BG_DEFAULT}"
export HBAR_RED="-c ${BLACK}${BG_RED}"

export CONF_FILE="/etc/xipkg.conf"

[ ! -f "$CONF_FILE" ] && echo "No config found!" && exit 1

export CURL_OPTS="-sSL"

export DEFAULT_OPTION=$(parseconf -v default_cmd) 

export DEP_DIR=$(parseconf -v dir.deps)
export REPOS="$(parseconf -v repos)"
export SOURCES="$(parseconf sources.*)"

export PACKAGES_DIR=$(parseconf -v dir.packages)
export INSTALLED_DIR=$(parseconf -v dir.installed)
export KEYCHAIN_DIR=$(parseconf -v dir.keychain)

export CACHE_DIR=$(parseconf -v dir.cache)
export PACKAGE_CACHE="${CACHE_DIR}/packages"
export SYNC_CACHE="${CACHE_DIR}/sync"

export LOG_FILE="/var/log/xipkg.log"

export BUILDFILES_DIR=$(parseconf -v dir.buildfiles)
export BUILDFILES_GIT=$(parseconf -v buildfiles_git)

[ ! -f ${LOG_FILE} ] && mkdir -p /var/log && touch ${LOG_FILE}
