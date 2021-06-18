#!/bin/sh

exit 0

LED=0
SM=$(uci get system.greensignal)
if [ -z $SM ]; then
	uci set system.greensignal=led
	uci set system.greensignal.default="0"  
	uci set system.greensignal.name="WWANSignal"
	uci set system.greensignal.sysfs="green:signal"
	uci set system.greensignal.trigger="netdev"
	uci set system.greensignal.dev="wwan0"
	uci set system.greensignal.mode="link tx rx"
	LED=1
fi
SM=$(uci get system.greenglobe)
if [ -z $SM ]; then
	uci set system.greenglobe=led
	uci set system.greenglobe.default="0"  
	uci set system.greenglobe.name="USBSignal"
	uci set system.greenglobe.sysfs="green:globe"
	uci set system.greenglobe.trigger="netdev"
	uci set system.greenglobe.dev="usb0"
	uci set system.greenglobe.mode="link tx rx"
	LED=1
fi

if [ $LED -eq 1 ]; then
	uci commit system
	/etc/init.d/led restart
fi
