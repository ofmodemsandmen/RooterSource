#!/bin/sh

log() {
	logger -t "excede BW " "$@"
}

allocate=$2
total=$1
/usr/lib/bwmon/block 0
if [ -e /etc/bwlock ]; then
	if [ $total -gt $allocate ]; then
		/usr/lib/bwmon/block 1
	else
		/usr/lib/bwmon/block 0
	fi
fi