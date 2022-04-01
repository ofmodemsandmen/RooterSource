#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "AutoAPN " "$@"
}

exit 0

# T-Mobile Info
TMOB="89012"
TMOBAPN="fast.t-mobile.com"
TMOBTTL="65"
TMOBPIN="1234"

# ATT
ATT="89014"
ATTAPN="broadband"
ATTTTL="65"
ATTPIN="1111"

# Verison
VER="89148"
VERAPN="vzwinternet"
VERTTL="64"
VERPIN="1111"

CURRMODEM=$1
CPORT=$(uci get modem.modem$CURRMODEM.commport)
IFACE="wwan0"

FLG=0
VALUE="0"

ICCID=$(uci -q get modem.modem$CURRMODEM.iccid)
if echo $TMOB | grep -q -i "$ICCID"; then
	APN=$TMOBAPN
	VALUE=$TMOBTTL
	PINC=$TMOBPIN
	FLG=1
else
	if echo $ATT | grep -q -i "$ICCID"; then
		APN=$ATTAPN
		VALUE=$ATTTTL
		PINC=$ATTPIN
		FLG=1
	else
		if echo $VER | grep -q -i "$ICCID"; then
			APN=$VERAPN
			VALUE=$VERTTL
			PINC=$VERPIN
			FLG=1
		fi
	fi
fi

if [ $FLG -eq 1 ]; then
	uci set modem.modeminfo$CURRMODEM.apn=$APN
	uci commit modem
fi

if [ $VALUE != "0" ]; then
	FLG=0
	exst=$(cat /etc/firewall.user | grep "#startTTL")
	if [ ! -z "$exst" ]; then
		cp -f /etc/firewall.user /etc/firewall.user.bk
		sed /"#startTTL"/,/"#endTTL"/d /etc/firewall.user.bk > /etc/firewall.user
		rm -f /etc/firewall.user.bk
	fi

	echo "#startTTL" > /etc/firewall.user
	echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE" >> /etc/firewall.user
	echo "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-set $VALUE" >> /etc/firewall.user
	echo "ip6tables -t mangle -I POSTROUTING ! -p icmpv6 -o $IFACE -j HL --hl-set $VALUE" >> /etc/firewall.user
	echo "ip6tables -t mangle -I PREROUTING ! -p icmpv6 -i $IFACE -j HL --hl-set $VALUE" >> /etc/firewall.user
	echo "#endTTL" >> /etc/firewall.user
	FLG=1

	/etc/init.d/firewall restart
fi

