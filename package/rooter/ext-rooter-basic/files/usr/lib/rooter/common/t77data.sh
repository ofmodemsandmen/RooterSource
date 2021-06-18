#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "T77 Data" "$@"
}

CURRMODEM=$1
COMMPORT=$2

OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "t77info.gcom" "$CURRMODEM" | tr 'a-z' 'A-Z')
O=$($ROOTER/common/processat.sh "$OX")
OX=$(echo $OX)
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
PCI="-"
SINR="-"

CSQ=$(echo $O | grep -o "CSQ: [0-9]\+" | grep -o "[0-9]\+")
[ "x$CSQ" = "x" ] && CSQ=-1

if [ $CSQ -ge 0 -a $CSQ -le 31 ]; then
    CSQ_PER=$(($CSQ * 100/31))
    CSQ_RSSI=$((2 * CSQ - 113))
    [ $CSQ -eq 0 ] && CSQ_RSSI="<= "$CSQ_RSSI
    [ $CSQ -eq 31 ] && CSQ_RSSI=">= "$CSQ_RSSI
    CSQ_PER=$CSQ_PER"%"
    CSQ_RSSI=$CSQ_RSSI" dBm"
else
    CSQ="-"
    CSQ_PER="-"
    CSQ_RSSI="-"
fi
TEMP=$(echo $OX | grep -o "TSENS_TZ_SENSOR[0-9]:[0-9]\{1,3\}")
if [ -n "$TEMP" ]; then
	TEMP=${TEMP:17:3}
	TEMP=$(echo $TEMP | grep -o "[0-9]\{1,3\}")$(printf "\xc2\xb0")"C"
else
	TEMP=$(echo $OX | grep -o "XO_THERM_BUF:[0-9]\{1,3\}")
	if [ -n "$TEMP" ]; then
		TEMP=${TEMP:13:3}
		TEMP=$(echo $TEMP | grep -o "[0-9]\{1,3\}")$(printf "\xc2\xb0")"C"
	else
		TEMP="-"
	fi
fi
TECH=$(echo $O" " | grep -o "+COPS: .,.,[^,]\+,[027]")
TECH="${TECH: -1}"

if [ -n "$TECH" ]; then
	SGCELL=$(echo $O" " | grep -o "\$QCSQ .\+ OK " | tr " " "," | tr ",:" ",")

	case $TECH in
		"7")
			MODE="LTE"
			RSSI=$(echo $O | grep -o " RSSI: [^D]\+D" | grep -o "[-0-9\.]\+")
			CSQ_RSSI=$(echo $RSSI)" dBm"
			RSCP=$(echo $O | grep -o "[^G] RSRP: [^D]\+D" | grep -o "[-0-9\.]\+")
			RSCP=$(echo $RSCP)
			ECIO=$(echo $O | grep -o " RSRQ: [^D]\+D" | grep -o "[-0-9\.]\+")
			ECIO=$(echo $ECIO)
			SINR=$(echo $OX | grep -o "RS-SINR: [^D]\+D")
			SINR=${SINR:8}
			SINR=$(echo "$SINR" | grep -o "[-0-9]\{1,3\}")" dB"
			CHANNEL=$(echo $O | grep -o " EARFCN(DL/UL): [0-9]\+" | grep -o "[0-9]\+")
			LBAND="B"$(echo $O | grep -o " BAND: [0-9]\+" | grep -o "[0-9]\+")
			BWD=$(echo $O | grep -o " BW: [0-9\.]\+ MHZ" | grep -o "[0-9\.]\+")
			if [ "$BWD" != "1.4" ]; then
				BWD=${BWD/.*}
			fi
			LBAND=$LBAND" (Bandwidth $BWD MHz)"
			SCC=$(echo $O | grep -o " SCC[1-9][^M]\+MHZ")
			if [ -n "$SCC" ]; then
				printf '%s\n' "$SCC" | while read SCCX; do
					SCCX=$(echo $SCCX | tr " " ",")
					SLBV=$(echo $SCCX | cut -d, -f5 | grep -o "B[0-9]\{1,3\}")
					SBWV=$(echo $SCCX | cut -d, -f9)
					if [ $SBWV != "1.4" ]; then
						SBWV=${SBWV/.*}
					fi
					LBAND=$LBAND"<br />"$SLBV" (CA, Bandwidth "$SBWV" MHz)"
					echo "$LBAND" > /tmp/lbandvar$CURRMODEM
				done
				if [ -e /tmp/lbandvar$CURRMODEM ]; then
					read LBAND < /tmp/lbandvar$CURRMODEM
					rm /tmp/lbandvar$CURRMODEM
				fi
			fi
			PCI=$(echo $O | grep -o " ENB ID(PCI): [^(]\+([0-9]\{1,3\})" | grep -o "([0-9]\+)" | grep -o "[0-9]\+")
			;;
		*)
			if [ $TECH = "2" ]; then
				MODE="WCDMA"
			else
				MODE="GSM"
			fi
			RSCP=$(echo $SGCELL | cut -d, -f8)
			RSCP="-"$(echo $RSCP | grep -o "[0-9]\{1,3\}")
			ECIO=$(echo $SGCELL| cut -d, -f5)
			ECIO="-"$(echo $ECIO | grep -o "[0-9]\{1,3\}")
			RSSI=$(echo $SGCELL | cut -d, -f4)
			CSQ_RSSI="-"$(echo $RSSI | grep -o "[0-9]\{1,3\}")" dBm"
			;;
	esac
fi

NETMODE="1"
MODTYPE="8"

{
	echo 'CSQ="'"$CSQ"'"'
	echo 'CSQ_PER="'"$CSQ_PER"'"'
	echo 'CSQ_RSSI="'"$CSQ_RSSI"'"'
	echo 'ECIO="'"$ECIO"'"'
	echo 'RSCP="'"$RSCP"'"'
	echo 'ECIO1="'"$ECIO1"'"'
	echo 'RSCP1="'"$RSCP1"'"'
	echo 'MODE="'"$MODE"'"'
	echo 'MODTYPE="'"$MODTYPE"'"'
	echo 'NETMODE="'"$NETMODE"'"'
	echo 'CHANNEL="'"$CHANNEL"'"'
	echo 'LBAND="'"$LBAND"'"'
	echo 'PCI="'"$PCI"'"'
	echo 'TEMP="'"$TEMP"'"'
	echo 'SINR="'"$SINR"'"'
} > /tmp/signal$CURRMODEM.file

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
