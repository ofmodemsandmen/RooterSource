#!/bin/sh

log() {
	logger -t "allocate" "$@"
}

amount=$1
log "Allocate $amount"

echo $amount > /etc/bwallocate
result=`ps | grep -i "create_data.lua" | grep -v "grep" | wc -l`
if [ $result -lt 1 ]; then
	lua /usr/lib/bwmon/create_data.lua
fi
