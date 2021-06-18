#!/bin/sh
. /lib/functions.sh

SET=$1

uci set travelmate.global.trm_enabled=$SET
uci commit travelmate

if [ $SET = "1" ]; then
	AU=$(uci get travelmate.global.trm_auto)
	hkillall travelmate.sh
	if [ $AU = "1" ]; then
		uci -q set wireless.wwan.ssid="Checking for Connection"
		uci -q set wireless.wwan.encryption="none"
		uci -q set wireless.wwan.key=
       	uci -q commit wireless
		/usr/lib/hotspot/travelmate.sh &
	fi
else
	hkillall travelmate.sh
	/usr/lib/hotspot/dis_hot.sh
fi