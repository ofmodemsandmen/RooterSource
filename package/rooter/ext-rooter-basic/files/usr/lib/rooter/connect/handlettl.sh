#!/bin/sh 

log() {
	logger -t "TTL Settings" "$@"
}

delTTL() {
	FLG="0"
	exst=$(cat /etc/ttl.user | grep "#startTTL")
	if [ ! -z "$exst" ]; then
		sed -i -e "s!iptables -t mangle -I POSTROUTING!iptables -t mangle -D POSTROUTING!g" /etc/ttl.user
		sed -i -e "s!iptables -t mangle -I PREROUTING!iptables -t mangle -D PREROUTING!g" /etc/ttl.user
		sed -i -e "s!ip6tables -t mangle -I POSTROUTING!iptables -t mangle -D POSTROUTING!g" /etc/ttl.user
		sed -i -e "s!ip6tables -t mangle -I PREROUTING!iptables -t mangle -D PREROUTING!g" /etc/ttl.user
		
		chmod 777 /etc/ttl.user
		/etc/ttl.user
		
		
		sed /"#startTTL"/,/"#endTTL"/d /etc/ttl.user > /etc/ttl.user
		FLG="1"
	fi
}

CURRMODEM=$1
TTL="$2"
if [ $CURRMODEM = "0" ]; then
	IFACE="wan"
else
	IFACE=$(uci -q get modem.modem$CURRMODEM.interface)
fi

if [ "$TTL" = "0" ]; then
	ENB=$(uci -q get ttl.ttl.enabled)
	if [ $ENB = "1" ]; then
		TTL=$(uci -q get ttl.ttl.value)
		if [ -z $TTL ]; then
			TTL=65
		fi
	else
		delTTL
		log "Deleting TTL on interface $IFACE"
		exit 0
	fi
fi

if [ "$TTL" = "1" ]; then
	delTTL
	log "Deleting TTL on interface $IFACE"
	exit 0
fi

if [ "$TTL" = "TTL-INC 1" ]; then
	TTL="0"
fi

delTTL
VALUE="$TTL"
echo "#startTTL" >> /etc/ttl.user
log "Setting TTL $VALUE on interface $IFACE"

if [ $VALUE = "0" ]; then
	echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-inc 1" >> /etc/ttl.user
	echo "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-inc 1" >> /etc/ttl.user
	if [ -e /usr/sbin/ip6tables ]; then
		echo "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-inc 1" >> /etc/ttl.user
		echo "ip6tables -t mangle -I PREROUTING -i $IFACE -j HL --hl-inc 1" >> /etc/ttl.user
	fi
else
	echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE" >> /etc/ttl.user
	echo "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-set $VALUE" >> /etc/ttl.user
	if [ -e /usr/sbin/ip6tables ]; then
		echo "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-set $VALUE" >> /etc/ttl.user
		echo "ip6tables -t mangle -I PREROUTING -i $IFACE -j HL --hl-set $VALUE" >> /etc/ttl.user
	fi
fi
echo "#endTTL" >> /etc/ttl.user
chmod 777 /etc/ttl.user
/etc/ttl.user


