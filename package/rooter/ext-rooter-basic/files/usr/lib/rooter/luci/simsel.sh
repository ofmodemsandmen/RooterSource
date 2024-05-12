#!/bin/sh

ROOTER=/usr/lib/rooter

if [ -e /etc/dualsim ]; then
	bn=$(cat /tmp/sysinfo/board_name)
	bn=$(echo "$bn" | grep "z2101")
	if [ ! -z "$bn" ]; then
		simn=$(cat /sys/class/gpio/sim/value)
		if [ "$simn" = "1" ]; then
			echo "1" > /tmp/simsel
			echo "1" >> /tmp/simsel
		else
			echo "1" > /tmp/simsel
			echo "2" >> /tmp/simsel
		fi
	else
		CURRMODEM=1
		CPORT=$(uci -q get modem.modem$CURRMODEM.commport)
		if [ ! -z "$CPORT" ]; then
			ATCMDD="AT+QUIMSLOT?"
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
			echo $OX > /tmp/smm
			OX=$(cat /tmp/smm)
			sn=$(echo "$OX" | tr " " "," | cut -d, -f3)
			if [ "$sn" != "1" -a "$sn" != "2" ]; then
				sn="0"
			fi
			echo "1" > /tmp/simsel
			echo "$sn" >> /tmp/simsel
		else
			echo "0" > /tmp/simsel
			echo "0" >> /tmp/simsel
		fi
	fi
else
	echo "0" > /tmp/simsel
	echo "0" >> /tmp/simsel
fi