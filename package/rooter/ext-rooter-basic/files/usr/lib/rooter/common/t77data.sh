#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "T77 Data" "$@"
}

CURRMODEM=$1
COMMPORT=$2

OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "t77info.gcom" "$CURRMODEM")
OX=$(echo $OX | tr 'a-z' 'A-Z')
OXC=$(echo $OX | tr -d " ")

PCELL_LTE="RAT:[LTE+NR]\{3,6\}MCC:.\+PCELL:LTE_BAND:[0-9]\+[^C]\+WIDTH:[.0-9]\{1,6\}MHZCHANNEL:[0-9]\+PCI:[0-9]\{1,3\}LTE_RSRP:.\{2,8\}DBM,RSRQ:.\{2,8\}DB.\{12,20\},LTE_SNR:.\{3,7\}DB"
SCELL_LTE="SCELL:LTE_BAND:[0-9]\+LTE_BAND_WIDTH:[.0-9]\{1,6\}MHZCHANNEL:[0-9]\+PCI:[0-9]\{1,3\}LTE_RSRP:.\{2,8\}DBM,RSRQ:.\{2,8\}DB.\{12,20\},LTE_SNR:[^S]\{2,7\}"
PCELL_NSA="NR_BAND:N[0-9]\{1,3\}NR_BAND_WIDTH:[.0-9]\{3,5\}MHZNR_CHANNEL:[0-9]\{6\}NR_PCI:[0-9]\{1,3\}NR_RSRP:.\{2,8\}DBM.\{15,60\}NR_RSRQ:.\{2,8\}NR_SNR:.\{3,7\}DB"

O=$($ROOTER/common/processat.sh "$OX")
O=$(echo $O)

REGXca="BAND:[0-9]\{1,3\} BW:[0-9.]\+MHZ EARFCN:[0-9]\+ PCI:[0-9]\+ RSRP:[^R]\+RSRQ:[^R]\+RSSI:[^S]\+SNR[^D]\+"
REGXrxd="RX_DIVERSITY:[^(]\+([^)]\+"

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

CSQ=$(echo $OX | grep -o "+CSQ: [0-9]\{1,2\}" | grep -o "[0-9]\{1,2\}")
if [ "$CSQ" = "99" ]; then
	CSQ=""
fi
if [ -n "$CSQ" ]; then
	CSQ_PER=$(($CSQ * 100/31))"%"
	CSQ_RSSI=$((2 * CSQ - 113))" dBm"
else
	CSQ="-"
	CSQ_PER="-"
	CSQ_RSSI="-"
fi

TEMP=$(echo $OX | grep -o "TSENS_TZ_SENSOR[0-9]:[0-9]\{1,3\}")
if [ -n "$TEMP" ]; then
	TEMP=${TEMP:17:3}
fi
if [ -z "$TEMP" ]; then
	TEMP=$(echo $OX | grep -o "XO_THERM_BUF:[0-9]\{1,3\}")
	if [ -n "$TEMP" ]; then
		TEMP=${TEMP:13:3}
	fi
fi
if [ -z "$TEMP" ]; then
	TEMP=$(echo $OX | grep -o "TSENS: [0-9]\{1,3\}C")
fi
if [ -n "$TEMP" ]; then
	TEMP=$(echo $TEMP | grep -o "[0-9]\{1,3\}")$(printf "\xc2\xb0")"C"
else
	TEMP="-"
fi
TECH=$(echo $O" " | grep -o "+COPS: .,.,[^,]\+,[027]")
TECH="${TECH: -1}"

PLTE=$(echo $OXC | grep -o "$PCELL_LTE")
SLTE=$(echo $OXC | grep -o "$SCELL_LTE")
PNR=$(echo $OXC | grep -o "$PCELL_NSA")
if [ -n "$PLTE" ]; then
	MODE="LTE"
	LBAND="B"$(echo $PLTE | cut -d: -f11 | grep -o "[0-9]\{1,3\}")
	BW=$(echo $PLTE | cut -d: -f12 | grep -o "[.0-9]\{3,5\}")
	if [ ${BW: -2} == ".0" ]; then
		BW=$(printf "%.0f" $BW)
	fi
	LBAND=$LBAND" (Bandwidth $BW MHz)"
	CHANNEL=$(echo $PLTE | cut -d: -f13 | grep -o "[0-9]\{1,7\}")
	PCI=$(echo $PLTE | cut -d: -f14 | grep -o "[0-9]\{1,3\}")
	RSCP=$(printf "%.0f" $(echo $PLTE | cut -d: -f15 | grep -o "[-.0-9]\{2,7\}"))
	ECIO=$(printf "%.0f" $(echo $PLTE | cut -d: -f16 | grep -o "[-.0-9]\{2,6\}"))
	SINR=$(printf "%.0f" $(echo $PLTE | cut -d: -f18 | grep -o "[-.0-9]\{3,6\}"))
	if [ -n "$PNR" ]; then
		MODE="LTE+NR (NR5G-NSA)"
		BAND="n"$(echo $PNR | cut -d: -f2 | grep -o "[0-9]\{1,3\}")
		BW=$(printf "%.0f" $(echo $PNR | cut -d: -f3 | grep -o "[.0-9]\{3,5\}"))
		LBAND=$LBAND"<br />"$BAND" (Bandwidth $BW MHz)"
		CHANNEL=$CHANNEL","$(echo $PNR | cut -d: -f4 | grep -o "[0-9]\{1,7\}")
		PCI=$PCI","$(echo $PNR | cut -d: -f5 | grep -o "[0-9]\{1,3\}")
		RSCP=$RSCP","$(printf "%.0f" $(echo $PNR | cut -d: -f6 | grep -o "[-.0-9]\{2,7\}"))
		ECIO=$ECIO","$(printf "%.0f" $(echo $PNR | cut -d: -f8 | grep -o "[-.0-9]\{2,6\}"))
		SINR=$SINR","$(printf "%.0f" $(echo $PNR | cut -d: -f9 | grep -o "[-.0-9]\{3,6\}"))
	fi
	for SLTEV in $(echo "$SLTE"); do
		BAND="B"$(echo $SLTEV | cut -d: -f3 | grep -o "[0-9]\{1,3\}")
		BW=$(echo $SLTEV | cut -d: -f4 | grep -o "[.0-9]\{3,5\}")
		if [ ${BW: -2} == ".0" ]; then
			BW=$(printf "%.0f" $BW)
		fi
		LBAND=$LBAND"<br />CA "$BAND" (Bandwidth $BW MHz)"
		CHANNEL=$CHANNEL","$(echo $SLTEV | cut -d: -f5 | grep -o "[0-9]\{1,7\}")
		PCI=$PCI","$(echo $SLTEV | cut -d: -f6 | grep -o "[0-9]\{1,3\}")
		RSCP=$RSCP","$(printf "%.0f" $(echo $SLTEV | cut -d: -f7 | grep -o "[-.0-9]\{2,7\}"))
		ECIO=$ECIO","$(printf "%.0f" $(echo $SLTEV | cut -d: -f8 | grep -o "[-.0-9]\{2,6\}"))
		SNR=$(echo $SLTEV | cut -d: -f10 | grep -o "[-.0-9]\{3,6\}")
		if [ -n "$SNR" ]; then
			SINR=$SINR","$(printf "%.0f" $SNR)
		else
			SINR=$SINR",-"
		fi
	done
fi
if [ -z "$PLTE" ] && [ -n "$TECH" ]; then
	RSSI=$(echo $O | grep -o " RSSI: [^D]\+D" | grep -o "[-0-9\.]\+")
	if [ -n "$RSSI" ]; then
		CSQ_RSSI=$(echo $RSSI)" dBm"
	fi
	case $TECH in
		"7")
			MODE="LTE"
			ECIO=$(echo $O | grep -o " RSRQ: [^D]\+D" | grep -o "[-0-9\.]\+")
			SINR=$(echo $OX | grep -o "RS-S[I]*NR: [^D]\+D")
			SINR=${SINR:8}
			SINR=$(echo "$SINR" | grep -o "[-0-9.]\{1,3\}")
			LBAND="B"$(echo $O | grep -o " BAND: [0-9]\+" | grep -o "[0-9]\+")
			DEBUGv1=$(echo $O | grep -o "EARFCN(DL/UL):")
			DEBUGv2=$(echo $O | grep -o "LTE ENGINEERING")
			if [ -n "$DEBUGv1" ]; then
				RSCP=$(echo $O | grep -o "[^G] RSRP: [^D]\+D" | grep -o "[-0-9\.]\+")
				RSRPlist=$(echo $OX | grep -o "$REGXrxd" | grep -o "\-[.0-9]\{4,5\}" | tr "\n" ",")
				if [ -n "$RSRPlist" ]; then
					RSCP=$(echo $RSRPlist | cut -d, -f1)
					MIMO=$(echo $OX | grep -o "$REGXrxd" | cut -d" " -f2)
					if [ "$MIMO" == "3" ]; then
						RSCP="(2xMIMO) $RSCP"
					fi
					for IDX in 2 3 4; do
						RSCPval=$(echo $RSRPlist | cut -d, -f$IDX)
						if [ -n "$RSCPval" -a "$RSCPval" != "-256.0" ]; then
							RSCP="$RSCP dBm, $RSCPval"
						fi
					done
				fi
				CHANNEL=$(echo $O | grep -o " EARFCN(DL/UL): [0-9]\+" | grep -o "[0-9]\+")
				BWD=$(echo $O | grep -o " BW: [0-9\.]\+ MHZ" | grep -o "[0-9\.]\+")
				if [ "$BWD" != "1.4" ]; then
					BWD=${BWD/.*}
				fi
				LBAND=$LBAND" (Bandwidth $BWD MHz)"
				PCI=$(echo $OX | grep -o " ENB ID(PCI): [^(]\+([0-9]\{1,3\})" | grep -o "([0-9]\+)" | grep -o "[0-9]\+")
			fi
			if [ -n "$DEBUGv2" ]; then
				RSCP=$(echo $O | grep -o "RSRP: [^D]\+D" | grep -o "[-0-9\.]\+")
				CHANNEL=$(echo $O | grep -o " DL CHANNEL: [0-9]\+" | grep -o "[0-9]\+")
				PCI=$(echo $OX | grep -o " PCI: [0-9]\{1,3\}" | grep -o "[0-9]\+")
			fi
			SCC=$(echo $OX | grep -o " SCELL[1-9]:")
			if [ -n "$SCC" ]; then
				SCCn=$(echo $SCC | grep -o [0-9])
				for SCCx in $(echo "$SCCn"); do
					SCCv=$(echo $OX | grep -o "SCELL$SCCx: $REGXca" | tr ' ' ',')
					if [ -n "$SCCv" ]; then
						SLBV=B$(echo $SCCv | cut -d, -f2 | grep -o "[0-9]\{1,3\}")
						SBWV=$(echo $SCCv | cut -d, -f3 | grep -o "[0-9][^M]\+")
						if [ "$SBWV" != "1.4" ]; then
							SBWV=${SBWV%.*}
						fi
						LBAND=$LBAND"<br />"$SLBV" (CA, Bandwidth "$SBWV" MHz)"
						CHANNEL=$CHANNEL", "$(echo $SCCv | cut -d, -f4 | grep -o "[0-9]\+")
						PCI=$PCI", "$(echo $SCCv | cut -d, -f5 | grep -o "[0-9]\+")
						RSCP=$RSCP" dBm, "$(echo $SCCv | cut -d, -f6 | grep -o "[-0-9.]\+")
						ECIO=$ECIO" dB, "$(echo $SCCv | cut -d, -f7 | grep -o "[-0-9.]\+")
						CSQ_RSSI=$CSQ_RSSI", "$(echo $SCCv | cut -d, -f8 | grep -o "[-0-9.]\+")" dBm"
					SINR=$SINR", "$(echo $SCCv | cut -d, -f9 | grep -o "[-0-9.]\+")
					fi
				done
			else
				SCC=$(echo $O | grep -o " SCC[1-9][^M]\+MHZ")
				if [ -n "$SCC" ]; then
					printf '%s\n' "$SCC" | while read SCCX; do
						SCCX=$(echo $SCCX | tr " " ",")
						SLBV=$(echo $SCCX | cut -d, -f5 | grep -o "B[0-9]\{1,3\}")
						SBWV=$(echo $SCCX | cut -d, -f9)
						if [ "$SBWV" != "1.4" ]; then
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
			fi
			;;
		"2")
			MODE="WCDMA"
			DEBUGv1=$(echo $O | grep -o "RAT:WCDMA")
			if [ -n "$DEBUGv1" ]; then
				RSCP=$(echo $O | grep -o "RSCP:[^)]\+" | grep -o "[-0-9\.]\+DBM," | grep -o "[^DBM,]\+")
				ECIO=$(echo $O | grep -o " ECIO:[^D]\+D" | grep -o "[-0-9\.]\+")
				ECIO=$(echo $ECIO)
				CHANNEL=$(echo $O | grep -o " CHANNEL (DL): [0-9]\+" | grep -o "[0-9]\+")
				LBAND="B"$(echo $O | grep -o " BAND: [0-9]\+" | grep -o "[0-9]\+")
				BW=$(echo $O | grep -o " BW: [0-9\.]\+ MHZ" | grep -o "[0-9\.]\+")
				BW=$(printf "%.0f" $BW )
				LBAND=$LBAND" (Bandwidth $BW MHz)"
				PCI=$(echo $OX | grep -o "PSC:.\?[0-9]\{1,3\}" | grep -o "[0-9]\+")
			else
				QCSQ=$(echo $O | grep -o "\$QCSQ: -[0-9]\{2,3\},[-0-9]\{1,3\},[-0-9]\{1,3\},")
				if [ -n "$QCSQ" ]; then
					RSCP=$(echo $QCSQ | cut -d, -f1 | grep -o "[-0-9]*")
					ECIO=$(echo $QCSQ | cut -d, -f2)
				fi
			fi
			;;
		*)
			MODE="GSM"
			;;
	esac
fi
SCFG=$(echo $OX | grep -o "\^SYSCONFIG: [0-9]\{1,2\}" | grep -o "[0-9]\{1,2\}")
if [ -n "$SCFG" ]; then
	case $SCFG in
	"13" )
		NETMODE="3" ;;
	"14" )
		NETMODE="5" ;;
	"17" )
		NETMODE="7" ;;
	* )
		NETMODE="1" ;;
	esac
fi
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
	echo 'SINR="'"$SINR dB"'"'
} > /tmp/signal$CURRMODEM.file
CONNECT=$(uci -q get modem.modem$CURRMODEM.connected)
if [ "$CONNECT" == 0 ]; then
    exit 0
fi

if [ "$CSQ" = "-" ]; then
	log "$OX"
fi

WWANX=$(uci -q get modem.modem$CURRMODEM.interface)
OPER=$(cat /sys/class/net/$WWANX/operstate 2>/dev/null)
rm -f "/tmp/connstat"$CURRMODEM

if [ ! $OPER ]; then
	exit 0
fi
if echo $OPER | grep -q "unknown"; then
	exit 0
fi

if echo $OPER | grep -q "down"; then
	echo "1" > "/tmp/connstat"$CURRMODEM
fi
