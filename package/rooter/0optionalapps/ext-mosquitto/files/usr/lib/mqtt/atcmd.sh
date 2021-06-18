#!/bin/sh

log() {
	logger -t "Remote AT Command" "$@"
}


ROOTER=/usr/lib/rooter

runatcmd() {
	ATCMDD=$command
	CURRMODEM=1
	COMMPORT="/dev/ttyUSB"$(uci get modem.modem$CURRMODEM.commport)
	CONN=$(uci get modem.modem$CURRMODEM.connected)
	if [ $CONN = "1" ]; then
		M2=$(echo "$ATCMDD" | sed -e "s#~#\"#g")
		COPS="at+cops=?"
		M3=$(echo "$M2" | awk '{print tolower($0)}')
		if `echo ${M3} | grep "${COPS}" 1>/dev/null 2>&1`
		then
			export TIMEOUT="75"
		else
			export TIMEOUT="5"
		fi
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M2")
	else
		OX="Modem Not Present"
	fi
	echo "$OX" > /tmp/atresult
	sleep 1
}

while [ true ]; do
	if [ -e /tmp/mqtt_runcmd ]; then
		ln="0"
		while read -r line; do
			if [ $ln = "0" ]; then
				ln="1"
				comtype=$line
			else
				command=$line
			fi
		done < /tmp/mqtt_runcmd
		#
		# AT Command
		#
		if [ $comtype = "1" ]; then
			runatcmd 
		fi
		rm -f /tmp/mqtt_runcmd
	fi
	if [ -e /tmp/mqtt_runexit ]; then
		rm -f /tmp/mqtt_runexit
		exit 0
	fi
	sleep 1
done

exit 0

