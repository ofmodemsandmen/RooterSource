#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "Modem Restart/Disconnect $CURRMODEM" "$@"
}

CURRMODEM=$1
ACTION=$2

result=`ps | grep -i "restartrun.sh" | grep -v "grep" | wc -l`
if [ $result -lt 1 ]; then
	$ROOTER/luci/restartrun.sh $CURRMODEM $ACTION 
else
	log "Waiting for Modem $CURRMODEM"
	sleep 25
	$ROOTER/luci/restartrun.sh $CURRMODEM $ACTION
fi