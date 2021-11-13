#!/bin/sh

log() {
	logger -t "excede BW " "$@"
}

lock=$(uci -q get custom.bwallocate.lock)
if [ $lock = "1" ]; then
	enb=$(uci -q get custom.bwallocate.enabled)
	if [ $enb = '1' ]; then
		allocate=$2
		total=$1
		/usr/lib/bwmon/block 0
		action=$(uci -q get custom.bwallocate.action)
		if [ ! -e /usr/lib/throttle/throttle.sh ]; then
			action=0
		fi
		if [ $total -gt $allocate ]; then
			if [ $action = "0" ]; then
				if [ -e /etc/nodogsplash/control ]; then
					/etc/nodogsplash/control block
				else
					/usr/lib/bwmon/block 1
				fi
			else
				down=$(uci -q get custom.bwallocate.down)
				if [ -z $down ]; then
					down=5
				fi
				up=$(uci -q get custom.bwallocate.up)
				if [ -z $up ]; then
					up=2
				fi
				/usr/lib/throttle/throttle.sh start $down $up
			fi
		else
			if [ -e /usr/lib/throttle/throttle.sh ]; then
				/usr/lib/throttle/throttle.sh stop
			fi
			if [ -e /etc/nodogsplash/control ]; then
				/etc/nodogsplash/control unblock
			fi
			/usr/lib/bwmon/block 0
		fi
	fi
fi