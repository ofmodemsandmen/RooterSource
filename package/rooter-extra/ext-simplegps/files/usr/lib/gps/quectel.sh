#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	logger -t "Quectel GPS" "$@"
}

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

CURRMODEM=$1

CPORT=$(uci get modem.modem$CURRMODEM.commport)
rm -f /tmp/gps
rm -f /tmp/lastgps
if [ -z "$CPORT" ]; then
	exit 0
fi

ATCMDD="AT+QGPS?"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
err=$(echo "$OX" | grep "+QGPS: 1")
if [ -z "$err" ]; then
	ATCMDD="AT+QGPS=1"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	log "$OX"
fi

log "GPS setup and waiting"

ATCMDD="AT+QCFG=\"gpsdrx\""
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
err=$(echo "$OX" | grep "0")
if [ -n "$err" ]; then
	ATCMDD="AT+QCFG=\"gpsdrx\",1"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
fi
ATCMDD="AT+QGPSCFG=\"outport\",\"none\""
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")

while true; do
	refresh=$(uci -q get gps.configuration.refresh)
	ATCMDD="AT+QGPSLOC=0"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	err=$(echo "$OX" | grep "ERROR")
	if [ -z "$err" ]; then
		EN2=$(uci -q get gps.configuration.type2)
		if [ $EN2 = "1" ]; then
			result=`ps | grep -i "movement.sh" | grep -v "grep" | wc -l`
			if [ $result -lt 1 ]; then
				/usr/lib/gps/movement.sh &
			fi
		else
			PID=$(ps |grep "movement.sh" | grep -v grep |head -n 1 | awk '{print $1}')
			if [ ! -z "$PID" ]; then
				kill -9 $PID
			fi
		fi
		echo "$OX" > /tmp/gpsox
		result=`ps | grep -i "processq.sh" | grep -v "grep" | wc -l`
		if [ $result -lt 1 ]; then
			/usr/lib/gps/processq.sh 1
		fi
		if [ ! -e /tmp/gpsboot ]; then
			if [ -e /tmp/gps ]; then
				CONN=$(uci get modem.modem$CURRMODEM.connected)
				if [ $CONN = "1" ]; then
					echo "0" > /tmp/gpsboot
					/usr/lib/gps/sendreport.sh
				fi
			fi
		fi
		sleep $refresh
	else
		sleep 5
	fi
done
