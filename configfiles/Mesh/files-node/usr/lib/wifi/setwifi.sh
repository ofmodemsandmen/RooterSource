#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Set Wifi" "$@"
}

wifidata=$1
wifidata=$(echo $wifidata | tr "|" ',')

log "$wifidata"

radio=$(echo $wifidata| cut -d, -f1)
disabled=$(echo $wifidata| cut -d, -f2)
noscan=$(echo $wifidata| cut -d, -f3)
mode=$(echo $wifidata| cut -d, -f4)
ssid=$(echo $wifidata| cut -d, -f5)
key=$(echo $wifidata| cut -d, -f6)
encrypt=$(echo $wifidata| cut -d, -f7)
channel=$(echo $wifidata| cut -d, -f8)
width=$(echo $wifidata| cut -d, -f9)
txpower=$(echo $wifidata| cut -d, -f10)
country=$(echo $wifidata| cut -d, -f11)

case $encrypt in
	"0" )
		encrypt="psk2"
	;;
	"1" )
		encrypt="pskmixed"
	;;
	"2" )
		encrypt="psk"
	;;
	"3" )
		encrypt="none"
	;;
esac

ht=""
case $mode in
	"1" )
		ht="HT"
	;;
	"2" )
		ht="VHT"
	;;
esac

if [ ! -z "$ht" ]; then
	case $width in
		"0" )
			ht=$ht"20"
		;;
		"1" )
			ht=$ht"40"
		;;
		"2" )
			if [ "$ht" = "HT" ]; then
				ht=$ht"40"
			else
				ht=$ht"80"
			fi
		;;
		"3" )
			if [ "$ht" = "HT" ]; then
				ht=$ht"40"
			else
				ht=$ht"160"
			fi
		;;
	esac
fi

uci set wireless.$radio.disabled=$disabled
uci set wireless.$radio.noscan=$noscan
uci set wireless.$radio.htmode=$ht
uci set wireless.$radio.channel=$channel
uci set wireless.$radio.txpower=$txpower
uci set wireless.$radio.country=$country

uci set wireless.default_$radio.ssid="$ssid"
uci set wireless.default_$radio.key="$key"
uci set wireless.default_$radio.encryption="$encrypt"
uci commit wireless
ubus call network reload