#!/bin/sh

export CONF_FILE="/etc/xipkg.conf"

CURL_OPTS="-SsL"

DEP_GRAPH=$(parseconf -v dir.deps)

get_deps() {
    local name=$1
    [ -f $DEP_GRAPH ] && sed -rn "s/^$name: (.*)/\1/p" $DEP_GRAPH || echo 
}
