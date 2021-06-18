#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "Phone Change" "$@"
}

CURRMODEM=$1
PHONE=$2
NAME=$3

CPORT=$(uci get modem.modem$CURRMODEM.commport)
PHONE=$(echo "$PHONE" | sed -e 's/ //g')

log "Change Modem $CURRMODEM SIM phone number to $PHONE, name to $NAME"

INTER=${PHONE:0:1}
if [ $INTER = "+" ]; then
	TON="145"
else
	TON="129"
fi

ATCMDD="AT+CPBS=\"ON\";+CPBS?"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
OX=$($ROOTER/common/processat.sh "$OX")

ON=$(echo "$OX" | awk -F[,\ ] '/^\+CPBS:/ {print $2}')
if [ "$ON" = "\"ON\"" ]; then
	ATCMDD="AT+CPBW=1,\"$PHONE\",$TON,\"$NAME\""
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	ATCMDD="AT+CNUM"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	OX=$($ROOTER/common/processat.sh "$OX")
	M2=$(echo "$OX" | grep -o "+CNUM:[^,]\+,[^,]\+,")
	CNUM=$(echo "$M2" | cut -d\" -f4)
	CNUMx=$(echo "$M2" | cut -d\" -f2)
	if [ -z "$CNUM" ]; then
		CNUM="*"
	fi
	if [ -z "$CNUMx" ]; then
		CNUMx="*"
	fi
	echo "$CNUM" > /tmp/msimnumx$CURRMODEM
	echo "$CNUMx" >> /tmp/msimnumx$CURRMODEM
	mv -f /tmp/msimnumx$CURRMODEM /tmp/msimnum$CURRMODEM
fi
