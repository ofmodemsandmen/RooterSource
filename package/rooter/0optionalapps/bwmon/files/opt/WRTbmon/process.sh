#!/bin/sh

log() {
	logger -t "BWmon Process" "$@"
}

running=0
if [ -e "/tmp/WRTbmon" ]; then
	running=1
fi

sleep 5
ENB=$(uci get bwmon.bwmon.enabled)

if [ $running = 1 ]; then
	if [ $ENB = 0 ]; then
		log "Disable BWmon"
		rmdir /tmp/WRTbmon
		sleep 4
	fi
else
	if [ $ENB = 1 ]; then
		log "Enable BWmon"
		/opt/WRTbmon/wrtbwmon.sh &
	fi
fi



