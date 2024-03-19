#!/bin/sh

ROOTER=/usr/lib/rooter


CURRMODEM=$1
CPORT=$(uci -q get modem.modem$CURRMODEM.commport)
uVid=$(uci get modem.modem$CURRMODEM.uVid)
if [ $uVid != "2c7c" ]; then
	if [ ! -z "$CPORT" ]; then
		ATCMDD="AT+CFUN=1,1"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
else
	if [ ! -z "$CPORT" ]; then
		ATCMDD="AT+QPOWD=0"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
fi