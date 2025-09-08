#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	logger -t "Change GPS" "$@"
}

chksierra() {
	SIERRAID=0
	if [ $idV = 1199 ]; then
		case $idP in
			"68aa"|"68a2"|"68a3"|"68a9"|"68b0"|"68b1" )
				SIERRAID=1
			;;
			"68c0"|"9040"|"9041"|"9051"|"9054"|"9056"|"90d3" )
				SIERRAID=1
			;;
			"9070"|"907b"|"9071"|"9079"|"901c"|"9091"|"901f"|"90b1" )
				SIERRAID=1
			;;
		esac
	elif [ $idV = 114f -a $idP = 68a2 ]; then
		SIERRAID=1
	elif [ $idV = 413c -a $idP = 81a8 ]; then
		SIERRAID=1
	elif [ $idV = 413c -a $idP = 81b6 ]; then
		SIERRAID=1
	fi
}

chkquectel() {
	QUECTEL=false
	if [ "$idV" = "2c7c" ]; then
		QUECTEL=true
	elif [ "$idV" = "05c6" ]; then
		QUELST="9090,9003,9215"
		if [[ $(echo "$QUELST" | grep -o "$idP") ]]; then
			QUECTEL=true
		fi
	fi
}

sleep 3
enable=$(uci -q get gps.configuration.enabled)
CURRMODEM=1
CPORT=$(uci get modem.modem$CURRMODEM.commport)
if [ $enable = "0" ]; then
	PID=$(ps | grep "[q]uectel.sh" | awk '{print $1}')
	if [ -n "$PID" ]; then
		kill -9 $PID
		ATCMDD="AT+QGPSEND"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	PID=$(ps | grep "[s]ierra.sh" | awk '{print $1}')
	if [ -n "$PID" ]; then
		kill -9 $PID
		ATCMDD="AT!GPSEND=0"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	rm -f /tmp/gps
else
	idV=$(uci -q get modem.modem$CURRMODEM.idV)
	idP=$(uci -q get modem.modem$CURRMODEM.idP)
	CPORT=$(uci get modem.modem$CURRMODEM.commport)
	if [ -z "$CPORT" ]; then
		exit 0
	fi
	chksierra
	chkquectel
	if $QUECTEL; then
		result=`ps | grep -i "quectel.sh" | grep -v "grep" | wc -l`
		if [ $result -lt 1 ]; then
			/usr/lib/gps/quectel.sh $CURRMODEM &
		fi
		result=`ps | grep -i "processq.sh" | grep -v "grep" | wc -l`
		if [ $result -lt 1 ]; then
			/usr/lib/gps/processq.sh
		fi
	fi
	if [ $SIERRAID -eq 1 ]; then
		result=`ps | grep -i "sierra.sh" | grep -v "grep" | wc -l`
		if [ $result -lt 1 ]; then
			/usr/lib/gps/sierra.sh $CURRMODEM &
		fi
		result=`ps | grep -i "processs.sh" | grep -v "grep" | wc -l`
		if [ $result -lt 1 ]; then
			/usr/lib/gps/processs.sh
		fi
	fi
fi
/usr/lib/gps/report.sh
