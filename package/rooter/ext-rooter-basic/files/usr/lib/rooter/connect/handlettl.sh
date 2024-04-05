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
		TTL=$(uci -q get ttl.ttl.value)
		if [ -z "$TTL" ]; then
			TTL=65
		fi
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

	if [ "$TTLOPTION" = "0" ]; then
		echo "nft add rule inet fw4 mangle_postrouting oifname $IFACE ip ttl set $TTL" >> /etc/firewall.user
		echo "nft add rule inet fw4 mangle_prerouting oifname $IFACE ip ttl set $TTL" >> /etc/firewall.user
	else
		if [ "$TTLOPTION" = "1" ]; then
			echo "nft add rule inet fw4 mangle_postrouting oifname $IFACE ip ttl set $TTL" >> /etc/firewall.user
		else
			echo "nft add rule inet fw4 mangle_postrouting protocol icmp oifname $IFACE ip ttl set $TTL" >> /etc/firewall.user
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
		echo "nft add rule inet fw4 mangle_postrouting oifname $IFACE ip6 hoplimit set $HL" >> /etc/firewall.user
		echo "nft add rule inet fw4 mangle_prerouting oifname $IFACE ip6 hoplimit set $HL" >> /etc/firewall.user
	else
		if [ "$TTLOPTION" = "1" ]; then
			echo "nft add rule inet fw4 mangle_postrouting oifname $IFACE ip6 hoplimit set $HL" >> /etc/firewall.user
		else
			echo "nft add rule inet fw4 mangle_postrouting protocol icmp oifname $IFACE ip6 hoplimit set $HL" >> /etc/firewall.user
		fi
	fi
	echo "#endHL$CURRMODEM" >> /etc/firewall.user
fi
/etc/init.d/firewall restart




