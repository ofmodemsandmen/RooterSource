#!/bin/sh

ROOTER=/usr/lib/rooter

snn=$1
CURRMODEM=1
CPORT=$(uci -q get modem.modem$CURRMODEM.commport)

ATCMDD="AT+QUIMSLOT?"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
echo $OX > /tmp/smm
OX=$(cat /tmp/smm)
sn=$(echo "$OX" | tr " " "," | cut -d, -f3)
if [ "$snn" != "$sn" ]; then
	ATCMDD="AT+QUIMSLOT=$snn"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	$ROOTER/luci/restart.sh $CURRMODEM 11
fi