#!/bin/sh
log ()
{
	logger -t mofi_wd "$@"
}

WD_LED=/sys/class/leds/watchdog/brightness
wd_keep_alive()
{
	if [ ! -e "$WD_LED" ]	
	then
		log "$WD_LED does not exist"
		return	
	fi
	
	log "wd keep alive started"
	level=0
	while true
	do
		if [ "$level" = 0 ]
		then
			level=1
		else
			level=0
		fi
		echo "$level" > "$WD_LED"
		sleep 1
	done
}

wd_keep_alive
