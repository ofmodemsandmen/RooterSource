#!/bin/sh

ROOTER=/usr/lib/rooter

snn=$1

bn=$(cat /tmp/sysinfo/board_name)
bn=$(echo "$bn" | grep "z2101")
if [ ! -z "$bn" ]; then
	if [ "$snn" = "2" ]; then
		snn="0"
	fi
	simn=$(uci -q get modem.general.simnum)
	if [ "$snn" != "$simn" ]; then
		if [ "$snn" = "1" ]; then
			echo "1" > /sys/class/gpio/sim/value
			uci set modem.general.simnum="1"
			uci commit modem
		else
			echo "0" > /sys/class/gpio/sim/value
			uci set modem.general.simnum="0"
			uci commit modem
		fi
		$ROOTER/luci/restart.sh 1 11
	fi
else	
	CURRMODEM=1
	CPORT=$(uci -q get modem.modem$CURRMODEM.commport)

	ATCMDD="AT+QUIMSLOT?"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	echo $OX > /tmp/smm
	OX=$(cat /tmp/smm)
	sn=$(echo "$OX" | tr " " "," | cut -d, -f3)
	if [ "$snn" != "$sn" ]; then
		ATCMDD="AT+QUIMSLOT=$snn"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		$ROOTER/luci/restart.sh $CURRMODEM 11
	fi
fi