#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "Modem Restart/Disconnect $CURRMODEM" "$@"
}

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

CURRMODEM=$1
empty=$(uci -q get modem.modem$CURRMODEM.empty)
if [ "$empty" = "1" ]; then
	exit 0
fi
CPORT=$(uci -q get modem.modem$CURRMODEM.commport)
INTER=$(uci get modem.modeminfo$CURRMODEM.inter)

jkillall chkconn.sh
# restart
echo "0" > /tmp/usbwait
uVid=$(uci get modem.modem$CURRMODEM.uVid)
uPid=$(uci get modem.modem$CURRMODEM.uPid)
if [ $uVid != "2c7c" ]; then
	if [ ! -z "$CPORT" ]; then
		ATCMDD="AT+CFUN=1,1"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	log "Hard modem reset done $OX"
else
	if [ ! -z "$CPORT" ]; then
		ATCMDD="AT+QPOWD=0"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	log "Hard modem reset done $OX"
fi
bn=$(cat /tmp/sysinfo/board_name)
bn=$(echo "$bn" | grep "mk01k21")
if [ ! -z "$bn" ]; then
	i=496
	echo $i > /sys/class/gpio/export
	echo "out" > /sys/class/gpio/gpio$i/direction
	echo "1" > /sys/class/gpio/gpio$i/value
	sleep 5
	echo "0" > /sys/class/gpio/gpio$i/value
	log "Power Toggle"
fi
ifdown wan$INTER
uci delete network.wan$CURRMODEM
uci set network.wan$CURRMODEM=interface
uci set network.wan$CURRMODEM.proto=dhcp
uci set network.wan$CURRMODEM.${ifname1}="wan"$CURRMODEM
uci set network.wan$CURRMODEM.metric=$CURRMODEM"0"
uci commit network
/etc/init.d/network reload

if [ -e $ROOTER/modem-led.sh ]; then
	$ROOTER/modem-led.sh $CURRMODEM 0
fi
while [ -e /tmp/usbwait ]
	do
		sleep 5
	done
