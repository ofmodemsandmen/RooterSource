#!/bin/sh

ROOTER=/usr/lib/rooter

CURRMODEM=$1
COMMPORT=$2

if [ -e /etc/nocops ]; then
	echo "0" > /tmp/block
	OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "cellinfo0.gcom" "$CURRMODEM")
	rm -f /tmp/block
else
	OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "cellinfo0.gcom" "$CURRMODEM")
fi
OY=$($ROOTER/gcom/gcom-locked "$COMMPORT" "cellinfo.gcom" "$CURRMODEM")
OXx=$OX

OX=$(echo $OX | tr 'a-z' 'A-Z')
OY=$(echo $OY | tr 'a-z' 'A-Z')
OX=$OX" "$OY

COPS="-"
COPS_MCC="-"
COPS_MNC="-"
COPSX=$(echo $OXx | grep -o "+COPS: [01],0,.\+," | cut -d, -f3 | grep -o "[^\"]\+")

if [ "x$COPSX" != "x" ]; then
	COPS=$COPSX
fi

COPSX=$(echo $OX | grep -o "+COPS: [01],2,.\+," | cut -d, -f3 | grep -o "[^\"]\+")

if [ "x$COPSX" != "x" ]; then
	COPS_MCC=${COPSX:0:3}
	COPS_MNC=${COPSX:3:3}
	if [ "$COPS" = "-" ]; then
		COPS=$(awk -F[\;] '/'$COPS'/ {print $2}' $ROOTER/signal/mccmnc.data)
		[ "x$COPS" = "x" ] && COPS="-"
	fi
fi

if [ "$COPS" = "-" ]; then
	COPS=$(echo "$O" | awk -F[\"] '/^\+COPS: 0,0/ {print $2}')
	if [ "x$COPS" = "x" ]; then
		COPS="-"
		COPS_MCC="-"
		COPS_MNC="-"
	fi
fi
COPS_MNC=" "$COPS_MNC

OX=$(echo "${OX//[ \"]/}")

REGV=$(echo "$OX" | grep -o "+C5GREG:2,[0-9],[A-F0-9]\{2,6\},[A-F0-9]\{5,10\}")
if [ -n "$REGV" ]; then
	LAC=$(echo "$REGV" | cut -d, -f3)
	LAC=$(printf "%06X" 0x$LAC)
	CID=$(echo "$REGV" | cut -d, -f4)
	CID=$(printf "%010X" 0x$CID)
	RNC=${CID:1:6}
	CID=${CID:7:3}
	RNC="-"
else
	REGV=$(echo "$OX" | grep -o "+CEREG:2,[0-9],[A-F0-9]\{2,4\},[A-F0-9]\{5,8\}")
	REGFMT="3GPP"
	if [ -z "$REGV" ]; then
		REGV=$(echo "$OX" | grep -o "+CEREG:2,[0-9],[A-F0-9]\{2,4\},[A-F0-9]\{1,3\},[A-F0-9]\{5,8\}")
		REGFMT="SW"
	fi
	if [ -n "$REGV" ]; then
		LAC=$(echo "$REGV" | cut -d, -f3)
		LAC=$(printf "%04X" 0x$LAC)
		if [ $REGFMT = "3GPP" ]; then
			CID=$(echo "$REGV" | cut -d, -f4)
		else
			CID=$(echo "$REGV" | cut -d, -f5)
		fi
		CID=$(printf "%08X" 0x$CID)
		RNC=${CID:1:5}
		CID=${CID:6:2}
	else
		REGV=$(echo "$OX" | grep -o "+CREG:2,[0-9],[A-F0-9]\{2,4\},[A-F0-9]\{2,8\}")
		if [ -n "$REGV" ]; then
			LAC=$(echo "$REGV" | cut -d, -f3)
			CID=$(echo "$REGV" | cut -d, -f4)
			if [ ${#CID} -gt 4 ]; then
				LAC=$(printf "%04X" 0x$LAC)
				CID=$(printf "%08X" 0x$CID)
				RNC=${CID:1:3}
				CID=${CID:4:4}
			else
				RNC="-"
			fi
		else
			LAC=""
		fi
	fi
fi
REGSTAT=$(echo "$REGV" | cut -d, -f2)
if [ "$REGSTAT" == "5" -a "$COPS" != "-" ]; then
	COPS_MNC=$COPS_MNC" (Roaming)"
fi
if [ -n "$LAC" ]; then
	LAC_NUM=$(printf "%d" 0x$LAC)
	LAC_NUM="  ("$LAC_NUM")"
	CID_NUM=$(printf "%d" 0x$CID)
	CID_NUM="  ("$CID_NUM")"
else
	LAC="-"
	LAC_NUM=""
	CID="-"
	RNC="-"
fi
if [ "$RNC" = "-" ]; then
	RNC_NUM=""
else
	RNC_NUM=$(printf "%d" 0x$RNC)
	RNC_NUM=" ($RNC_NUM)"
fi

{
	echo 'COPS="'"$COPS"'"'
	echo 'COPS_MCC="'"$COPS_MCC"'"'
	echo 'COPS_MNC="'"$COPS_MNC"'"'
	echo 'LAC="'"$LAC"'"'
	echo 'LAC_NUM="'"$LAC_NUM"'"'
	echo 'CID="'"$CID"'"'
	echo 'CID_NUM="'"$CID_NUM"'"'
	echo 'RNC="'"$RNC"'"'
	echo 'RNC_NUM="'"$RNC_NUM"'"'
} > /tmp/cell$CURRMODEM.file
