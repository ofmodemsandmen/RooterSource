#!/bin/sh

ROOTER=/usr/lib/rooter
CURRMODEM=$1
action=$(uci -q get profile.simmiss.action)
if [ -z "$action" ]; then
	exit 0
fi
if [ "$action" = "0" ]; then
	exit 0
fi
if [ "$action" = "1" ]; then
	/usr/lib/rooter/luci/restartrun.sh $CURRMODEM
	exit 0
fi
if [ "$action" = "2" ]; then
	sleep 10 && touch /etc/banner
	reboot -f
	exit 0
fi
