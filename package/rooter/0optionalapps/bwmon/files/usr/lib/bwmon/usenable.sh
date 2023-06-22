#!/bin/sh

flg=$1

us=$(uci -q get nlbwmon.nlbwmon.enabled)
if [ "$flg" = "$us" ]; then
	exit 0
fi
uci set nlbwmon.nlbwmon.enabled=$flg
uci commit nlbwmon

if [ "$flg" = "0" ]; then
	/etc/init.d/nlbwmon stop &
else
	/etc/init.d/nlbwmon start &
fi