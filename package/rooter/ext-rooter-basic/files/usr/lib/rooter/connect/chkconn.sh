#!/bin/sh

ROOTER=/usr/lib/rooter

CURRMODEM=$1

timeout=4
while [ $timeout -ge 0 ]; do
	conn=$(uci -q get modem.modem$CURRMODEM.connected)
	if [ "$conn" = '1' ]; then
		exit 0
	fi
	timeout=$((timeout-1))
	sleep 30
done
$ROOTER/luci/restart $CURRMODEM 11