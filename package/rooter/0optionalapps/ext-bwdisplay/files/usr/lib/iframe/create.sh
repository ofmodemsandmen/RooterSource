#!/bin/sh
. /lib/functions.sh

bwdata() {
	result=`ps | grep -i "create_data.lua" | grep -v "grep" | wc -l`
	if [ $result -lt 1 ]; then
		lua /usr/lib/bwmon/create_data.lua
	fi
	while [ true ]
	do
		if [ -e /tmp/bwdata ]; then
			break
		fi
		sleep 1
	done
}

bwdata
/usr/lib/iframe/update.sh