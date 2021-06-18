#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "Meig Data" "$@"
}

CURRMODEM=$1
COMMPORT=$2

OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "meiginfo.gcom" "$CURRMODEM" | tr 'a-z' 'A-Z')
O=$($ROOTER/common/processat.sh "$OX")
O=$(echo $O)

RSRP=""
RSRQ=""
CHANNEL="-"
ECIO="-"
RSCP="-"
ECIO1=" "
RSCP1=" "
MODE="-"
MODTYPE="-"
NETMODE="-"
LBAND="-"
TEMP="-"
PCI="-"
SINR="-"

Oup=$(echo $O | tr 'a-z' 'A-Z')

CSQ=$(echo $O | grep -o "CSQ: [0-9]\+" | grep -o "[0-9]\+")
[ "x$CSQ" = "x" ] && CSQ=-1

if [ $CSQ -ge 0 -a $CSQ -le 31 ]; then
    CSQ_PER=$(($CSQ * 100/31))
    CSQ_RSSI=$((2 * CSQ - 113))
    CSQX=$CSQ_RSSI
    [ $CSQ -eq 0 ] && CSQ_RSSI="<= "$CSQ_RSSI
    [ $CSQ -eq 31 ] && CSQ_RSSI=">= "$CSQ_RSSI
    CSQ_PER=$CSQ_PER"%"
    CSQ_RSSI=$CSQ_RSSI" dBm"
else
    CSQ="-"
    CSQ_PER="-"
    CSQ_RSSI="-"
fi

MODE="-"
PSRAT=$(echo $O" " | grep -o "+PSRAT: .\+ OK " | tr " " ",")
TECH=$(echo $PSRAT | cut -d, -f2)
if [ ! -z "$TECH" ]; then
	MODE=$TECH
fi

SGCELL=$(echo $O" " | grep -o "+SGCELLINFO: .\+ OK " | tr " " ",")

case $MODE in
	"TD-LTE"|"FDD-LTE"|"FDD")
		RSSI=$(echo $SGCELL | cut -d, -f5)
		CSQ_RSSI=$(echo $RSSI | grep -o "[0-9]\{1,3\}")" dBm"
		RSCP=$(echo $SGCELL | cut -d, -f6)
		RSCP="-"$(echo $RSCP | grep -o "[0-9]\{1,3\}")
		ECIO=$(echo $SGCELL| cut -d, -f7)
		ECIO="-"$(echo $ECIO | grep -o "[0-9]\{1,3\}")
		SSINR=$(echo $SGCELL | cut -d, -f8 | grep -o "[0-9]\{1,3\}")
		if [ -n "$SSINR" ] && [ "$SSINR" -le "250" ]; then
			SINR=$((($SSINR / 5) - 20))" dB"
		fi
		LBAND=$(echo $SGCELL | cut -d, -f9)
		LBAND=$(echo $LBAND | grep -o "[0-9]\{1,5\}")
		let LBAND=LBAND-119
		LBAND="B"$LBAND
		CHANNEL=$(echo $SGCELL | cut -d, -f10)
		CHANNEL=$(echo $CHANNEL | grep -o "[0-9]\{1,5\}")
		ICELL=$(echo $O" " | grep -o "+CELLINFO: .\+ OK " | tr " " ",")
		PCI=$(echo $ICELL | cut -d, -f18)
		PCI=$(echo $PCI | grep -o "[0-9]\{1,5\}")
		if [ $MODE = "FDD" ]; then
			MODE="FDD LTE"
		fi
		;;
	"HSPA+"|"HSUPA"|"HSDPA"|"WCDMA")
		RSCP=$(echo $SGCELL | cut -d, -f11)
		RSCP="-"$(echo $RSCP | grep -o "[0-9]\{1,3\}")
		ECIO=$(echo $SGCELL| cut -d, -f12)
		ECIO="-"$(echo $ECIO | grep -o "[0-9]\{1,3\}")
		CHANNEL=$(echo $SGCELL | cut -d, -f8)
		CHANNEL=$(echo $CHANNEL | grep -o "[0-9]\{1,4\}")
		RSSI=$(echo $SGCELL | cut -d, -f10)
		CSQ_RSSI=$(echo $RSSI | grep -o "[0-9]\{1,3\}")" dBm"
		;;
	*)
		RSCP=$(echo $SGCELL | cut -d, -f10)
		RSCP="-"$(echo $RSCP | grep -o "[0-9]\{1,3\}")
		CHANNEL=$(echo $SGCELL | cut -d, -f8)
		CHANNEL=$(echo $CHANNEL | grep -o "[0-9]\{1,4\}")
		RSSI=$(echo $SGCELL | cut -d, -f9)
		CSQ_RSSI=$(echo $RSSI | grep -o "[0-9]\{1,3\}")" dBm"
		;;
esac

NETMODE="-"
NMODE=$(echo $O" " | grep -o "+MODODR: .\+ OK " | tr " " ",")
TECH=$(echo $NMODE | cut -d, -f2)
if [ ! -z "$TECH" ]; then
	MODTYPE="7"
	case $TECH in
	"2" )
		NETMODE="1" # Auto
		;;
	"1" )
		NETMODE="5" # 3G only
		;;
	"4" )
		NETMODE="4" # 3G preferred
		;;
	"3" )
		NETMODE="3" # 2G only
		;;
	"5" )
		NETMODE="7" # LTE only
		;;
	* )
		NETMODE="1"
		;;
	esac
fi

echo 'CSQ="'"$CSQ"'"' > /tmp/signal$CURRMODEM.file
echo 'CSQ_PER="'"$CSQ_PER"'"' >> /tmp/signal$CURRMODEM.file
echo 'CSQ_RSSI="'"$CSQ_RSSI"'"' >> /tmp/signal$CURRMODEM.file
echo 'ECIO="'"$ECIO"'"' >> /tmp/signal$CURRMODEM.file
echo 'RSCP="'"$RSCP"'"' >> /tmp/signal$CURRMODEM.file
echo 'ECIO1="'"$ECIO1"'"' >> /tmp/signal$CURRMODEM.file
echo 'RSCP1="'"$RSCP1"'"' >> /tmp/signal$CURRMODEM.file
echo 'MODE="'"$MODE"'"' >> /tmp/signal$CURRMODEM.file
echo 'MODTYPE="'"$MODTYPE"'"' >> /tmp/signal$CURRMODEM.file
echo 'NETMODE="'"$NETMODE"'"' >> /tmp/signal$CURRMODEM.file
echo 'CHANNEL="'"$CHANNEL"'"' >> /tmp/signal$CURRMODEM.file
echo 'LBAND="'"$LBAND"'"' >> /tmp/signal$CURRMODEM.file
echo 'TEMP="'"$TEMP"'"' >> /tmp/signal$CURRMODEM.file
echo 'PCI="'"$PCI"'"' >> /tmp/signal$CURRMODEM.file
echo 'SINR="'"$SINR"'"' >> /tmp/signal$CURRMODEM.file

CONNECT=$(uci get modem.modem$CURRMODEM.connected)
if [ $CONNECT -eq 0 ]; then
    exit 0
fi

if [ "$CSQ" = "-" ]; then
	log "$OX"
fi

WWANX=$(uci get modem.modem$CURRMODEM.interface)
OPER=$(cat /sys/class/net/$WWANX/operstate 2>/dev/null)

if [ ! $OPER ]; then
	exit 0
fi
if echo $OPER | grep -q "unknown"; then
	exit 0
fi

if echo $OPER | grep -q "down"; then
	echo "1" > "/tmp/connstat"$CURRMODEM
fi
