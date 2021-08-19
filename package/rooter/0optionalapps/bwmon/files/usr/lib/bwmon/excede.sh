#!/bin/sh

log() {
	logger -t "excede BW " "$@"
}

if [ -e /etc/bwlock ]; then
	allocate=$2
	total=$1
	/usr/lib/bwmon/block 0
	if [ $total -gt $allocate ]; then
		/usr/lib/bwmon/block 1
	else
		/usr/lib/bwmon/block 0
	fi
fi