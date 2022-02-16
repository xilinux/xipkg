#!/bin/bash

. /usr/lib/colors.sh
export CONF_FILE="/etc/xipkg.conf"

export CURL_OPTS="-SsL"

export DEP_DIR=$(parseconf -v dir.deps)
export REPOS=($(parseconf -v repos))
export SOURCES=($(parseconf sources.*))
export PACKAGES_DIR=$(parseconf -v dir.packages)
export INSTALLED_DIR=$(parseconf -v dir.installed)

export TMP_DIR="/tmp/xi"
