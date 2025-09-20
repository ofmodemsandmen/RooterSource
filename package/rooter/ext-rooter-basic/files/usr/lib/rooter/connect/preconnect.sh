#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "PreConnect $CURRMODEM" "$@"
}

chkT77() {
	T77=0
	if [ $idV = 1e2d ]; then
		T77=1
	elif [ $idV = 413c -a $idP = 81d7 ]; then
		T77=1
	elif [ $idV = 413c -a $idP = 81d8 ]; then
		T77=1
	elif [ $idV = 0489 -a $idP = e0b4 ]; then
		T77=1
	elif [ $idV = 0489 -a $idP = e0b5 ]; then
		T77=1
	elif [ $idV = 1bc7 -a $idP = 1910 ]; then
		T77=1
	fi
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

chkT77
if [ $T77 -eq 1 ]; then
	ATCMDD="AT+GPS?"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	log "$OX"
	err=$(echo "$OX" | grep "Disable")
	if [ ! -z "$err" ]; then
		ATCMDD="AT+GPS=1"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		/usr/lib/rooter/luci/restart.sh $CURRMODEM 11
		exit 0
	fi
fi