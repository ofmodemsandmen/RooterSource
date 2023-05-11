#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	modlog "Reconnect Modem $CURRMODEM" "$@"
}

CURRMODEM=$1
log "Re-starting Connection for Modem $CURRMODEM"
modis=$(uci -q get basic.basic.modem)
if [ ! -z $modis ]; then
	uci set basic.basic.modem="1"
	uci commit basic
fi
$ROOTER/luci/restart.sh $CURRMODEM 11

