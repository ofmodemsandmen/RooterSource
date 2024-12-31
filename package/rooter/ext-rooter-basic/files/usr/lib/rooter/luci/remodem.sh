#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	modlog "Modem Remodem.sh $CURRMODEM" "$@"
}

CURRMODEM=$1
empty=$(uci -q get modem.modem$CURRMODEM.empty)
if [ "$empty" != "0" ]; then
	log "No Modem"
	exit 0
fi
CPORT=$(uci -q get modem.modem$CURRMODEM.commport)
uVid=$(uci get modem.modem$CURRMODEM.uVid)
if [ ! -e /dev/ttyUSB$CPORT ]; then
	log "No Modem"
	exit 0
fi
if [ $uVid != "2c7c" ]; then
	if [ ! -z "$CPORT" ]; then
		ATCMDD="AT+CFUN=1,1"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
else
	if [ ! -z "$CPORT" ]; then
		ATCMDD="AT+QPOWD=0"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		log "$OX"
		ATCMDD="AT+CFUN=1,1"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		log "$OX"
	fi
fi
