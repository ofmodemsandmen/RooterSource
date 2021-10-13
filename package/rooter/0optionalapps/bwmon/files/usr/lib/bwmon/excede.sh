#!/bin/sh

log() {
	logger -t "excede BW " "$@"
}

lock=$(uci -q get custom.bwallocate.enabled)
if [ $lock = "1" ]; then
	enb=$(uci -q get custom.bwallocate.enabled)
	if [ $enb = '1' ]; then
		allocate=$2
		total=$1
		/usr/lib/bwmon/block 0
		if [ $total -gt $allocate ]; then
			if [ -e /etc/nodogsplash/control ]; then
				/etc/nodogsplash/control block
			fi
			/usr/lib/bwmon/block 1
		else
			if [ -e /etc/nodogsplash/control ]; then
				/etc/nodogsplash/control unblock
			fi
			/usr/lib/bwmon/block 0
		fi
	fi
fi