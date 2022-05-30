#!/bin/sh
. /lib/functions.sh

SET=$1

uci set travelmate.global.trm_enabled=$SET
uci commit travelmate

if [ $SET = "1" ]; then
	AU=$(uci get travelmate.global.trm_auto)
	hkillall travelmate.sh
	if [ $AU = "1" ]; then
		uci set travelmate.global.ssid="8"
		uci commit travelmate
		uci -q set wireless.wwan.encryption="none"
		uci -q set wireless.wwan.key=
		uci set wireless.wwan.ssid="Hotspot Manager Interface"
       	uci -q commit wireless
		/usr/lib/hotspot/travelmate.sh &
	fi
else
	hkillall travelmate.sh
	/usr/lib/hotspot/dis_hot.sh
fi