#!/bin/sh

log() {
	logger -t "excede BW " "$@"
}

allocate=$2
total=$1

if [ -e /etc/bwlock ]; then
	if [ $total -gt $allocate ]; then
		log "Allocation exceeded $total $allocate"
	fi
fi