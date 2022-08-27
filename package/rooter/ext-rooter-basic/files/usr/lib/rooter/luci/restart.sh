#!/bin/sh 

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

ifname1="ifname"
if [ -e /etc/newstyle ]; then
	ifname1="device"
fi

CURRMODEM=$1
CPORT=$(uci -q get modem.modem$CURRMODEM.commport)

if [ ! -z "$CPORT" ]; then
	ATCMDD="AT+CFUN=1,1"
	OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	ifdown wan$CURRMODEM
	uci delete network.wan$CURRMODEM
	uci set network.wan$CURRMODEM=interface
	uci set network.wan$CURRMODEM.proto=dhcp
	uci set network.wan$CURRMODEM.${ifname1}="wan"$CURRMODEM
	uci set network.wan$CURRMODEM.metric=$CURRMODEM"0"
	uci commit network
	/etc/init.d/network reload
	ifdown wan$CURRMODEM
	echo "1" > /tmp/modgone
fi

PORT="usb1"
echo $PORT > /sys/bus/usb/drivers/usb/unbind
sleep 15
echo $PORT > /sys/bus/usb/drivers/usb/bind
sleep 10
PORT="usb2"
log "Re-binding USB driver on $PORT to reset modem"
echo $PORT > /sys/bus/usb/drivers/usb/unbind
sleep 15
echo $PORT > /sys/bus/usb/drivers/usb/bind
sleep 10
ifdown wan$CURRMODEM
uci delete network.wan$CURRMODEM
uci set network.wan$CURRMODEM=interface
uci set network.wan$CURRMODEM.proto=dhcp
uci set network.wan$CURRMODEM.${ifname1}="wan"$CURRMODEM
uci set network.wan$CURRMODEM.metric=$CURRMODEM"0"
uci commit network
/etc/init.d/network reload
ifdown wan$CURRMODEM
echo "1" > /tmp/modgone