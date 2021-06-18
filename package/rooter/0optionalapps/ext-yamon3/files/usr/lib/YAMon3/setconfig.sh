#!/bin/sh

log() {
	logger -t "YAMon 3 Setconfig : " "$@"
}

source "/usr/lib/YAMon3/includes/versions.sh"
source "/usr/lib/YAMon3/includes/util$_version.sh"

_configFile="/usr/lib/YAMon3/config.file"
configStr=$(cat "$_configFile")
source "$_configFile"
source "/usr/lib/YAMon3/includes/defaults.sh"
source "/usr/lib/YAMon3/strings/en/strings.sh"

sleep 5 

ENB=$(uci get yamon3.yamon3.enabled)
CENB=$(uci get yamon3.curryamon3.enabled)

if [ $ENB != $CENB ]; then
	if [ $ENB = 0 ]; then
		/etc/init.d/yamon3 stop
	else
		/etc/init.d/yamon3 enable
		/etc/init.d/yamon3 start
	fi
	uci set yamon3.curryamon3.enabled=$ENB
fi

uci commit yamon3

CHGE=0

TMP=$(uci get yamon3.tmpyamon3.upfreq)
CURR=$(uci get yamon3.curryamon3.upfreq)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.upfreq=$TMP
	_updatefreq=$TMP
	updateConfig "_updatefreq" "$TMP"
	CHGE=1
fi
TMP=$(uci get yamon3.tmpyamon3.pubint)
CURR=$(uci get yamon3.curryamon3.pubint)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.pubint=$TMP
	_publishInterval=$TMP
	updateConfig "_publishInterval" "$TMP"
	CHGE=1
fi
TMP=$(uci get yamon3.tmpyamon3.isp)
CURR=$(uci get yamon3.curryamon3.isp)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.isp=$TMP
	_ispBillingDay=$TMP
	updateConfig "_ispBillingDay" "$TMP"
	CHGE=1
fi
TMP=$(uci get yamon3.tmpyamon3.unlimited_usage)
CURR=$(uci get yamon3.curryamon3.unlimited_usage)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.unlimited_usage=$TMP
	_unlimited_usage=$TMP
	updateConfig "_unlimited_usage" "$TMP"
	CHGE=1
fi
TMP=$(uci get yamon3.tmpyamon3.unlimited_start)
CURR=$(uci get yamon3.curryamon3.unlimited_start)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.unlimited_start=$TMP
	updateConfig "_unlimited_start" "$TMP"
	_unlimited_start=$TMP
	CHGE=1
fi
TMP=$(uci get yamon3.tmpyamon3.unlimited_end)
CURR=$(uci get yamon3.curryamon3.unlimited_end)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.unlimited_end=$TMP
	_unlimited_end=$TMP
	updateConfig "_unlimited_end" "$TMP"
	CHGE=1
fi
TMP=$(uci get yamon3.tmpyamon3.datacap)
CURR=$(uci get yamon3.curryamon3.datacap)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.datacap=$TMP
	CHGE=1
fi
if [ $TMP = 1 ]; then
	TMP=$(uci get yamon3.tmpyamon3.capval)
	CURR=$(uci get yamon3.curryamon3.capval)
	if [ $TMP != $CURR ]; then
		uci set yamon3.curryamon3.capval=$TMP
		_monthlyDataCap=$TMP
		updateConfig "_monthlyDataCap" "$TMP"
		CHGE=1
	fi
else
	_monthlyDataCap=$TMP
	updateConfig "_monthlyDataCap" "$TMP"
	CHGE=1
fi
TMP=$(uci get yamon3.tmpyamon3.bridge)
CURR=$(uci get yamon3.curryamon3.bridge)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.bridge=$TMP
	_includeBridge=$TMP
	updateConfig "_includeBridge" "$TMP"
	CHGE=1
fi

TMP=$(uci get yamon3.tmpyamon3.bmac)
CURR=$(uci get yamon3.curryamon3.bmac)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.bmac=$TMP
	_bridgeMAC=$TMP
	updateConfig "_bridgeMAC" "$TMP"
	CHGE=1
fi

TMP=$(uci get yamon3.tmpyamon3.ipv6)
CURR=$(uci get yamon3.curryamon3.ipv6)
if [ $TMP != $CURR ]; then
	uci set yamon3.curryamon3.ipv6=$TMP
	_includeIPv6=$TMP
	updateConfig "_includeIPv6" "$TMP"
	CHGE=1
fi

if [ $CHGE = 1 ]; then
	uci commit yamon3
	_configFile="/usr/lib/YAMon3/config.file"
	echo "$configStr" > "$_configFile"
fi
