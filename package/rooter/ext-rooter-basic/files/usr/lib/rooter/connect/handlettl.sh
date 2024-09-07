#!/bin/sh 

log() {
	modlog "TTL Settings $CURRMODEM" "$@"
}

delTTL() {
	cp /etc/firewall.user /etc/ttl.user.bk
	sed /"#startTTL$CURRMODEM"/,/"#endTTL$CURRMODEM"/d /etc/ttl.user.bk > /etc/firewall.user
}

delHL() {
	cp /etc/firewall.user /etc/ttl.user.bk
	sed /"#startHL$CURRMODEM"/,/"#endHL$CURRMODEM"/d /etc/ttl.user.bk > /etc/firewall.user
}

CURRMODEM=$1

source /etc/openwrt_release
DR=$DISTRIB_RELEASE
vs=$(echo "$DR" | grep "21")
if [ -z "$vs" ]; then
	vs=$(echo "$DR" | grep "19")
fi

ttl=$(uci -q get modem.modeminfo$CURRMODEM.ttl)
if [ -z "$ttl" ]; then
	ttl="0"
fi
cttl=$(uci -q get modem.modeminfo$CURRMODEM.cttl)
if [ -z "$cttl" ]; then
	cttl="65"
fi
hl=$(uci -q get modem.modeminfo$CURRMODEM.hl)
if [ -z "$hl" ]; then
	hl="0"
fi
chl=$(uci -q get modem.modeminfo$CURRMODEM.chl)
if [ -z "$chl" ]; then
	chl="65"
fi
ttloption=$(uci -q get modem.modeminfo$CURRMODEM.ttloption)
if [ -z "$ttloption" ]; then
	ttloption="0"
fi
	
TTL="$ttl"
CTTL="$cttl"
HL="$hl"
CHL="$chl"
TTLOPTION="$ttloption"

if [ $CURRMODEM = "0" ]; then
	IFACE="wan"
else
	IFACE=$(uci -q get modem.modem$CURRMODEM.interface)
fi

if [ "$TTL" = "0" ]; then
	ENB=$(uci -q get ttl.ttl.enabled)
	if [ $ENB = "1" ]; then
		ttl=$(uci -q get ttl.ttl.ttl)
		if [ -z "$ttl" ]; then
			ttl="0"
		fi
		cttl=$(uci -q get ttl.ttl.cttl)
		if [ -z "$cttl" ]; then
			cttl="65"
		fi
		hl=$(uci -q get ttl.ttl.hl)
		if [ -z "$hl" ]; then
			hl="0"
		fi
		chl=$(uci -q get ttl.ttl.chl)
		if [ -z "$chl" ]; then
			chl="65"
		fi
		ttloption=$(uci -q get ttl.ttl.ttloption)
		if [ -z "$ttloption" ]; then
			ttloption="0"
		fi
		TTL="$ttl"
		CTTL="$cttl"
		HL="$hl"
		CHL="$chl"
		TTLOPTION="$ttloption"
	else
		delTTL
		delHL
		log "Deleting TTL/HL on interface $IFACE"
		/etc/init.d/firewall restart
		exit 0
	fi
fi

if [ "$TTL" = "2" ]; then
	TTL=$CTTL
fi
if [ "$HL" = "0" ]; then
	HL=$TTL
fi
if [ "$HL" = "2" ]; then
	HL=$CHL
fi

log "Checking TTL"
if [ "$TTL" = "1" ]; then
	delTTL
	log "Deleting TTL on interface $IFACE"
else
	delTTL
	log "Setting TTL $TTL on interface $IFACE"
	echo "#startTTL$CURRMODEM" >> /etc/firewall.user
	if [ "$TTL" = "TTL-INC 1" ]; then
		TTLOPTION="0"
		TTL=64
	fi
	
	if [ ! -z "$vs" ]; then
		r1="iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $TTL"
		r2="iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-set $TTL"
		r3="iptables -t mangle -I POSTROUTING -p icmp -o $IFACE -j TTL --ttl-set $TTL"
		r4="ip6tables -t mangle -I POSTROUTING ! -p icmpv6 -o $IFACE -j HL --hl-set $TTL"
		r5="ip6tables -t mangle -I PREROUTING ! -p icmpv6 -i $IFACE -j HL --hl-set $TTL"
		r6="ip6tables -t mangle -I POSTROUTING ! -p icmpv6 -o $IFACE -j HL --hl-set $TTL"
	else
		r1="nft add rule inet fw4 mangle_postrouting oifname $IFACE ip ttl set $TTL"
		r2="nft add rule inet fw4 mangle_prerouting oifname $IFACE ip ttl set $TTL"
		r3="nft add rule inet fw4 mangle_postrouting protocol icmp oifname $IFACE ip ttl set $TTL"
		r4="nft add rule inet fw4 mangle_postrouting oifname $IFACE ip6 hoplimit set $HL"
		r5="nft add rule inet fw4 mangle_prerouting oifname $IFACE ip6 hoplimit set $HL"
		r6="nft add rule inet fw4 mangle_postrouting protocol icmp oifname $IFACE ip6 hoplimit set $HL"
	fi

	if [ "$TTLOPTION" = "0" ]; then
		echo "$r1" >> /etc/firewall.user
		echo "$r2" >> /etc/firewall.user
	else
		if [ "$TTLOPTION" = "1" ]; then
			echo "$r1" >> /etc/firewall.user
		else
			echo "$r3" >> /etc/firewall.user
		fi
	fi
	echo "#endTTL$CURRMODEM" >> /etc/firewall.user
fi

log "Checking HL"
if [ "$HL" = "1" ]; then
	delHL
	log "Deleting HL on interface $IFACE"
else
	delHL
	log "Setting HL $HL on interface $IFACE"
	echo "#startHL$CURRMODEM" >> /etc/firewall.user

	if [ "$TTLOPTION" = "0" ]; then
		echo "$r4" >> /etc/firewall.user
		echo "$r5" >> /etc/firewall.user
	else
		if [ "$TTLOPTION" = "1" ]; then
			echo "$r4" >> /etc/firewall.user
		else
			echo "$r6" >> /etc/firewall.user
		fi
	fi
	echo "#endHL$CURRMODEM" >> /etc/firewall.user
fi
/etc/init.d/firewall restart




