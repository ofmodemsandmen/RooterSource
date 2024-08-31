#!/bin/sh

if [ ! -e /etc/adclr ]; then
	uci -q delete adblock.global.adb_sources
	uci commit adblock
	echo "0" > /etc/adclr
fi