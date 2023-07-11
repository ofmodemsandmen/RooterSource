#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "PreConnect $CURRMODEM" "$@"
}

CURRMODEM=$1
idV=$(uci -q get modem.modem$CURRMODEM.idV)
idP=$(uci -q get modem.modem$CURRMODEM.idP)
CPORT=$(uci get modem.modem$CURRMODEM.commport)

log "Running PreConnect script"

if [ ! -e /tmp/rst520$CURRMODEM ]; then
	if [ "$idV" = "2c7c" -a "$idP" = "0801" ]; then
		#log "Restart RM520"
		#/usr/lib/rooter/luci/restart.sh $CURRMODEM 11
		echo "0" > /tmp/rst520$CURRMODEM
	fi
fi