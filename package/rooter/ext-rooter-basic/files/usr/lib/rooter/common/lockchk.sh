#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	modlog "Lock Provider" "$@"
}

setautocops() {
	case $NETMODE in
		"3")
			ATCMDD="AT+COPS=0,,,0" ;;
		"5")
			ATCMDD="AT+COPS=0,,,2" ;;
		"7")
			ATCMDD="AT+COPS=0,,,7" ;;
		"8")
			ATCMDD="AT+COPS=0,,,13" ;;
		"9")
			ATCMDD="AT+COPS=0,,,12" ;;
		*)
			ATCMDD="AT+COPS=0" ;;
	esac
	OX=$($ROOTER/gcom/gcom-locked "$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	exit 0
}

getmcc() {
	imsi=$(uci -q get modem.modem$CURRMODEM.imsi)
	mcc6=${imsi:0:6}
	mcc5=${imsi:0:5}
	mcc=${mcc6:0:3}
	while IFS= read -r line; do
		ldata=$line
		ldata=$(echo "$ldata" | tr "|" "!")
		tmp=$(echo "$ldata" | cut -d! -f1 )
		cmcc=$(echo "$tmp" | cut -d, -f2 )
		if [ "$mcc" = "$cmcc" ]; then
			break
		fi
	done < /usr/lib/country/mccdata
	tmp=$(echo "$ldata" | cut -d! -f2 )
	cmnc=$(echo "$tmp" | cut -d, -f1 )
	size=${#cmnc}
	MCC=$mcc
	if [ "$size" = "3" ]; then
		MNC=${mcc6:3}
	else
		MNC=${mcc5:3}
	fi
}

locking() {
	case $NETMODE in
		"3")
			ATCMDD="AT+COPS=$LOCK,2,\"$MCC$MNC\",0" ;;
		"5")
			ATCMDD="AT+COPS=$LOCK,2,\"$MCC$MNC\",2" ;;
		"7")
			ATCMDD="AT+COPS=$LOCK,2,\"$MCC$MNC\",7" ;;
		"8")
			ATCMDD="AT+COPS=$LOCK,2,\"$MCC$MNC\",13" ;;
		"9")
			ATCMDD="AT+COPS=$LOCK,2,\"$MCC$MNC\",12" ;;
		*)
			ATCMDD="AT+COPS=$LOCK,2,\"$MCC$MNC\"" ;;
	esac

	OX=$($ROOTER/gcom/gcom-locked "$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	log "$OX"
}

CURRMODEM=$1
log "Check ISP Lock"
CPORT=/dev/ttyUSB$(uci get modem.modem$CURRMODEM.commport)
NETMODE=$(uci -q get modem.modem$CURRMODEM.netmode)
alr=$(uci -q get profile.roaming.roam)
flg=0
if [ -e /usr/lib/country/mccdata ]; then
	flg=1
fi
if [ "$alr" = "1" -a $flg = 1 ]; then
	LOCK="1"
	getmcc
else
	if [ -e /usr/lib/netroam/lock.sh ]; then
		if [ -e /tmp/rlock ]; then
			/usr/lib/netroam/lock.sh $CURRMODEM
			exit 0
		fi
	fi
	LOCK=$(uci -q get modem.modeminfo$CURRMODEM.lock)
	if [ "$LOCK" = "2" ]; then
		LOCK="1"
	fi
	MCC=$(uci -q get modem.modeminfo$CURRMODEM.mcc)
	MNC=$(uci -q get modem.modeminfo$CURRMODEM.mnc)
fi
	ATCMDD="AT+COPS=3,2;+COPS?"
	OX=$($ROOTER/gcom/gcom-locked "$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	COPSMODE=$(echo $OX | grep -o "+COPS:[ ]\?[014]" | grep -o "[014]")
	COPSPLMN=$(echo $OX | grep -o "[0-9]\{5,6\}")
	if [ -z "$LOCK" -o "$LOCK" = "0" ]; then
		if [ "$COPSMODE" = "0" ]; then
			exit 0
		fi
		setautocops
	fi

	LMCC=${#MCC}
	if [ $LMCC -ne 3 ]; then
		setautocops
	fi

	if [ -z "$MNC" ]; then
		setautocops
	fi
	LMNC=${#MNC}
	if [ $LMNC -eq 1 ]; then
		MNC=0$MNC
	fi
	log "$COPSMODE$COPSPLMN"
	if [ "$COPSMODE$COPSPLMN" = "$LOCK$MCC$MNC" ]; then
		exit 0
	fi

locking
ERROR="ERROR"
if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
then
	if [ "$LOCK" = "1" ]; then
		log "Try Soft Lock"
		LOCK=4
		locking
		ERROR="ERROR"
		if `echo ${OX} | grep "${ERROR}" 1>/dev/null 2>&1`
		then
			log "Error While Soft Locking to Provider"
		else
			log "Soft Locked to Provider $MCC $MNC"
		fi
	else
		log "Error While Soft Locking to Provider"
	fi
else
	log "Hard Locked to Provider $MCC $MNC"
fi