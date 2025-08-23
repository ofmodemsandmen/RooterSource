#!/bin/sh

log() {
	modlog "Process Keep Alive" "$@"
}

sleep 20
OFF="1"
while [ true ]
do
	enabled=$(uci -q get zerotier.global.enabled)
	if [ "$enabled" = "1" ]; then
		if [ "$OFF" = "1" ]; then
			ps | grep -v grep | grep "/usr/bin/zerotier-one"
			if [ $? = 0 ] ; then
				OFF="0"
				log "Zerotier Running"
			fi
		else
			ps | grep -v grep | grep "/usr/bin/zerotier-one"
			if [ $? != 0 ] ; then
				log "Zerotier is Down"
				/etc/init.d/zerotier restart
				log "Zerotier restart"
				OFF="1"
				sleep 5
			fi
		fi
	fi
	sleep 5
done