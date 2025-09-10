#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	logger -t "GPS" "$@"
}

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

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

CURRMODEM=$1
idV=$(uci -q get modem.modem$CURRMODEM.idV)
idP=$(uci -q get modem.modem$CURRMODEM.idP)
CPORT=$(uci get modem.modem$CURRMODEM.commport)
MCC=$(uci get modem.modem$CURRMODEM.mcc)
if [ -z "$MCC" ]; then
	MCC='0'
fi
MNC=$(uci get modem.modem$CURRMODEM.mnc)
MNC=${MNC:1}
if [ -z "$MNC" ]; then
	MNC='0'
fi
connect=$(uci get modem.modem$CURRMODEM.connected)
if [ -z "$connect" ]; then
	connect='0'
fi
echo "$connect" > /tmp/gpscon
echo "$MCC" >> /tmp/gpscon
echo "$MNC" >> /tmp/gpscon

enable=$(uci -q get gps.configuration.enabled)
if [ $enable = "0" ]; then
	exit 0
fi

log "Running GPS script"

QUECTEL=false
if [ "$idV" = "2c7c" ]; then
	QUECTEL=true
elif [ "$idV" = "05c6" ]; then
	QUELST="9090,9003,9215"
	if [[ $(echo "$QUELST" | grep -o "$idP") ]]; then
		QUECTEL=true
	fi
fi
if $QUECTEL; then
	if [ -e /usr/lib/gps/quectel.sh ]; then
		result=`ps | grep -i "quectel.sh" | grep -v "grep" | wc -l`
		if [ $result -lt 1 ]; then
			/usr/lib/gps/quectel.sh $CURRMODEM &
		fi
	fi
	return
fi

chksierra
if [ $SIERRAID -eq 1 ]; then
	if [ -e /usr/lib/gps/sierra.sh ]; then
		result=`ps | grep -i "sierra.sh" | grep -v "grep" | wc -l`
		if [ $result -lt 1 ]; then
			/usr/lib/gps/sierra.sh $CURRMODEM &
		fi
	fi
	return
fi


