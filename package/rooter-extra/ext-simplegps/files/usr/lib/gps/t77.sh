#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "T77 GPS" "$@"
}

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

CURRMODEM=$1

CPORT=$(uci get modem.modem$CURRMODEM.commport)
NMEA=$(uci get modem.modem$CURRMODEM.nmeaport)
rm -f /tmp/gps$CURRMODEM
rm -f /tmp/lastgps
if [ -z "$CPORT" ]; then
	exit 0
fi
log "Run T77"
ATCMDD="AT^GPS_STOP"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
ATCMDD="AT^GPS_START=0"
OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
log "$OX"
err=$(echo "$OX" | grep "ERROR")
if [ ! -z "$err" ]; then
	log "GPS won't start" 
	exit 0
fi
/usr/lib/gps/t77cat.sh $NMEA &

while true; do
	refresh=$(uci -q get gps.configuration.refresh)
	ATCMDD="AT+GPS_INFO"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	err=$(echo "$OX" | grep "GPS_CN")
	if [ ! -z "$err" ]; then
		while IFS= read -r line; do
			gpa=$(echo "$line" | grep '$GPGGA')
			if [ ! -z "$gpa" ]; then
				OX="$line"
				break
			fi
		done < /tmp/t77gps
		
		#OX='$GPGGA,184806.00,3752.295133,N,12216.720941,W,1,03,1.4,52.4,M,-26.0,M,,*62'

		#OX='$GPGGA,123519,4807.038000,N,01131.324000,E,1,08,0.9,545.4,M,46.9,M, , *42'

		echo "$OX" > /tmp/gpsox
		result=`ps | grep -i "processdw.sh" | grep -v "grep" | wc -l`
		if [ $result -lt 1 ]; then
			/usr/lib/gps/processdw.sh 1 $CURRMODEM
		fi
		sleep $refresh
	else
		log "Waiting GPS_INFO"
		sleep 5
	fi
	
done