#!/bin/sh
. /lib/functions.sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "Special" "$@"
}

VL=0
do_vlan() {
	local config=$1
	config_get ports $1 ports
	if [ "$ports" = "1 2 6t" ]; then
		uci set network."$config".ports="0 1 6t"
		VL=1
	fi
	if [ "$ports" = "0 6t" ]; then
		uci set network."$config".ports="2 6t"
		VL=1
	fi
}

if [ ! -f /etc/rbm33 ]; then
	config_load network
	config_foreach do_vlan switch_vlan

	if [ $VL -eq 1 ]; then
		uci commit network
		/etc/init.d/network restart
	fi
	echo "0" > /etc/rbm33
fi

if [ -e /etc/dual ]; then
	# 1st modem location in a dual modem setup: USB port or pcie1 (port 1-1)
	WAIT1=15	# wait time for a primary modem; set 0 for pcie1 and 10+ for USB
	WAIT2=45	# delay for the second modem (pcie0 port 1-2)

	CNTR=0
	while [ $CNTR -le ${WAIT1} ]; do
		if [ -e /sys/bus/usb/drivers/usb/1-1 ]; then
			M1=1
			break
		fi
		CNTR=`expr $CNTR + 1`
		sleep 1
	done

	if [ "$M1" = 1 ]; then
		log "Found a modem in \"1-1\", adding ${WAIT2} sec delay before powering pcie0"
	else
		WAIT2=""
		log "No other modem found, powering pcie0 immediately"
	fi
else
	WAIT2=""
fi

if [ -x $ROOTER/gpio-set.sh ]; then
	$ROOTER/gpio-set.sh pcie0_power 1 ${WAIT2} &
fi
