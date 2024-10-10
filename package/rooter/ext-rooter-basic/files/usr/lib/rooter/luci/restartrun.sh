#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	modlog "Modem Restart/Disconnect $CURRMODEM" "$@"
}

pwrtoggle() {
	toggle="0"
	bn=$(cat /tmp/sysinfo/board_name)
	bnx=$(echo "$bn" | grep "mk01k21")
	if [ ! -z "$bnx" ]; then
		i=496
		echo $i > /sys/class/gpio/export
		echo "out" > /sys/class/gpio/gpio$i/direction
		echo "1" > /sys/class/gpio/gpio$i/value
		sleep 5
		echo "0" > /sys/class/gpio/gpio$i/value
		log "Power Toggle"
		toggle="1"
		return
	fi
	bnx=$(echo "$bn" | grep "x3000")
	if [ ! -z "$bnx" ]; then
		echo "0" > /sys/class/gpio/cellular-control/value
		sleep 2
		echo "1" > /sys/class/gpio/cellular-control/value
		log "Power Toggle"
		toggle="1"
		return
	fi
	bnx=$(echo "$bn" | grep "z8102ax-128m")
	if [ ! -z "$bnx" ]; then
		DEV=$(uci get modem.modem$CURRMODEM.device)
		if [ $DEV = "2-1.2" ]; then
			echo "0" > /sys/class/gpio/modem2/value
			sleep 2
			echo "1" > /sys/class/gpio/modem2/value
		else
			echo "0" > /sys/class/gpio/modem1/value
			sleep 2
			echo "1" > /sys/class/gpio/modem1/value
		fi
		log "Power Toggle"
		toggle="1"
		return
	fi
	bnx=$(echo "$bn" | grep "ws1698")
	if [ ! -z "$bnx" ]; then
		i=460
		echo $i > /sys/class/gpio/export
		echo "out" > /sys/class/gpio/gpio$i/direction
		echo "0" > /sys/class/gpio/gpio$i/value
		sleep 3
		echo "1" > /sys/class/gpio/gpio$i/value
		log "Power Toggle"
		toggle="1"
		return
	fi
	bnx=$(echo "$bn" | grep "wg1602")
	if [ ! -z "$bnx" ]; then
		DEV=$(uci get modem.modem$CURRMODEM.device)
		if [ $DEV = "1-1" ]; then
			echo "0" > /sys/class/gpio/4g1-pwr/value
			sleep 2
			echo "1" > /sys/class/gpio/4g1-pwr/value
		else
			echo "0" > /sys/class/gpio/4g2-pwr/value
			sleep 2
			echo "1" > /sys/class/gpio/4g2-pwr/value
		fi
		log "Power Toggle"
		toggle="1"
		return
	fi
	bnx=$(echo "$bn" | grep "e2600ac-c1")
	if [ ! -z "$bnx" ]; then
		i=523
		echo "0" > /sys/class/gpio/gpio$i/value
		sleep 3
		echo "1" > /sys/class/gpio/gpio$i/value
		log "Power Toggle"
		toggle="1"
		return
	fi
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

proto=$(uci -q get modem.modem$CURRMODEM.proto)
if [ "$proto" = 91 ]; then
	lspci -k > /tmp/mhipci
	while IFS= read -r line; do
		dev=$(echo "$line" | grep "Device")
		if [ ! -z "$dev" ]; then
			read -r line
			kd=$(echo "$line" | grep "Kernel driver")
			if [ -z "$kd" ]; then
				read -r line
			fi
			mhi=$(echo "$line" | grep "mhi-pci-generic")
			if [ ! -z "$mhi" ]; then
				dev=$(echo "$dev" | tr " " "," | cut -d, -f1)
				pcinum="0000:$dev"
				break			
			fi
		fi
	done < /tmp/mhipci
	echo "1" > /sys/bus/pci/devices/$pcinum/remove
	sleep 2
fi

pwrtoggle

if [ $uVid != "2c7c" ]; then
	if [ $uVid = "0e8d" -o $uVid = "8087" -o $uVid = "2cb7" -o $uVid = "1508" ]; then
		if [ ! -z "$CPORT" ]; then
			ATCMDD="AT+CFUN=15"
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		fi
	else
		if [ ! -z "$CPORT" ]; then
			ATCMDD="AT+CFUN=1,1"
			OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		fi
	fi
	log "Hard modem reset done $OX"
else
	if [ ! -z "$CPORT" ]; then
		ATCMDD="AT+QPOWD=0"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
		ATCMDD="AT+CFUN=1,1"
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	fi
	log "Hard modem reset done $OX"
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
