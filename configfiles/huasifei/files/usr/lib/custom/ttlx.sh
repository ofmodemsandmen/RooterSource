#!/bin/sh 

log() {
	logger -t "TTL Hack" "$@"
}

sleep 5
ENB=$(uci get ttl.ttl.enabled)
CURRMODEM=1
IFACE=$(uci get modem.modem$CURRMODEM.interface)
FLG=0

exst=$(cat /etc/firewall.user | grep "#startTTL")
if [ ! -z "$exst" ]; then
	cp -f /etc/firewall.user /etc/firewall.user.bk
	sed /"#startTTL"/,/"#endTTL"/d /etc/firewall.user.bk > /etc/firewall.user
	rm -f /etc/firewall.user.bk
	FLG=1
fi
if [ $ENB -eq 1 ]; then
	VALUE=$(uci get ttl.ttl.value)
	if [ -z $VALUE ]; then
		VALUE=65
	fi
	echo "#startTTL" >> /etc/firewall.user
	log Setting TTL on interface $IFACE
	
	if [ $VALUE = 0 ]; then
		echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-inc 1" >> /etc/firewall.user
		echo "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-inc 1" >> /etc/firewall.user
		echo "ip6tables -t mangle -I POSTROUTING ! -p icmpv6 -o $IFACE -j HL --hl-inc 1" >> /etc/firewall.user
		echo "ip6tables -t mangle -I PREROUTING ! -p icmpv6 -i $IFACE -j HL --hl-inc 1" >> /etc/firewall.user
	else
		echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE" >> /etc/firewall.user
		echo "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-set $VALUE" >> /etc/firewall.user
		echo "ip6tables -t mangle -I POSTROUTING ! -p icmpv6 -o $IFACE -j HL --hl-set $VALUE" >> /etc/firewall.user
		echo "ip6tables -t mangle -I PREROUTING ! -p icmpv6 -i $IFACE -j HL --hl-set $VALUE" >> /etc/firewall.user
	fi
	echo "#endTTL" >> /etc/firewall.user
	FLG=1
fi
if [ $FLG -eq 1 ]; then
	/etc/init.d/firewall restart
fi
