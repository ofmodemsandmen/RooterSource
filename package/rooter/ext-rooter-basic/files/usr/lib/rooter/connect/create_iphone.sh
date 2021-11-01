#!/bin/sh 

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	logger -t "Create iPhone Connection" "$@"
}

handle_timeout(){
	local wget_pid="$1"
	local count=0
	ps | grep -v grep | grep $wget_pid
	res="$?"
	while [ "$res" = 0 -a $count -lt "$((TIMEOUT))" ]; do
		sleep 1
		count=$((count+1))
		ps | grep -v grep | grep $wget_pid
		res="$?"
	done

	if [ "$res" = 0 ]; then
		log "Killing process on timeout"
		kill "$wget_pid" 2> /dev/null
		ps | grep -v grep | grep $wget_pid
		res="$?"
		if [ "$res" = 0 ]; then
			log "Killing process on timeout"
			kill -9 $wget_pid 2> /dev/null
		fi
	fi
}

set_dns() {
	local pDNS1=$(uci -q get modem.modeminfo$CURRMODEM.dns1)
	local pDNS2=$(uci -q get modem.modeminfo$CURRMODEM.dns2)
	local pDNS3=$(uci -q get modem.modeminfo$CURRMODEM.dns3)
	local pDNS4=$(uci -q get modem.modeminfo$CURRMODEM.dns4)

	local aDNS="$pDNS1 $pDNS2 $pDNS3 $pDNS4"
	local bDNS=""

	echo "$aDNS" | grep -o "[[:graph:]]" &>/dev/null
	if [ $? = 0 ]; then
		log "Using DNS settings from the Connection Profile"
		pdns=1
		for DNSV in $(echo "$aDNS"); do
			if [ "$DNSV" != "0.0.0.0" ] && [ -z "$(echo "$bDNS" | grep -o "$DNSV")" ]; then
				[ -n "$(echo "$DNSV" | grep -o ":")" ] && continue
				bDNS="$bDNS $DNSV"
			fi
		done

		bDNS=$(echo $bDNS)
		uci set network.wan$INTER.peerdns=0
		uci set network.wan$INTER.dns="$bDNS"
		echo "$bDNS" > /tmp/v4dns$INTER

		bDNS=""
		for DNSV in $(echo "$aDNS"); do
			if [ "$DNSV" != "0:0:0:0:0:0:0:0" ] && [ -z "$(echo "$bDNS" | grep -o "$DNSV")" ]; then
				[ -z "$(echo "$DNSV" | grep -o ":")" ] && continue
				bDNS="$bDNS $DNSV"
			fi
		done
		echo "$bDNS" > /tmp/v6dns$INTER
	else
		log "Using Hostless Modem as a DNS"
		pdns=0
		rm -f /tmp/v[46]dns$INTER
	fi
}

set_network() {
	uci delete network.wan$INTER
	uci set network.wan$INTER=interface
	uci set network.wan$INTER.proto=dhcp
	source /etc/openwrt_release
	tone=$(echo "$DISTRIB_RELEASE" | grep "21.02")
	ifname="ifname"
	if [ ! -z $tone ]; then
		ifname="device"
	fi
	uci set network.wan$INTER.$ifname=$1
	uci set network.wan$INTER.metric=$INTER"0"
	set_dns
	uci commit network
	sleep 5
}

save_variables() {
	echo 'MODSTART="'"$MODSTART"'"' > /tmp/variable.file
	echo 'WWAN="'"$WWAN"'"' >> /tmp/variable.file
	echo 'USBN="'"$USBN"'"' >> /tmp/variable.file
	echo 'ETHN="'"$ETHN"'"' >> /tmp/variable.file
	echo 'WDMN="'"$WDMN"'"' >> /tmp/variable.file
	echo 'BASEPORT="'"$BASEPORT"'"' >> /tmp/variable.file
}

chcklog() {
	OOX=$1
	CLOG=$(uci get modem.modeminfo$CURRMODEM.log)
	if [ $CLOG = "1" ]; then
		log "$OOX"
	fi
}


CURRMODEM=$1
source /tmp/variable.file

MAN=$(uci get modem.modem$CURRMODEM.manuf)
MOD=$(uci get modem.modem$CURRMODEM.model)
$ROOTER/signal/status.sh $CURRMODEM "$MAN $MOD" "Connecting"
$ROOTER/log/logger "Attempting to Connect Modem #$CURRMODEM ($MAN $MOD)"

BASEP=$(uci get modem.modem$CURRMODEM.baseport)
idV=$(uci get modem.modem$CURRMODEM.idV)
idP=$(uci get modem.modem$CURRMODEM.idP)

$ROOTER/connect/get_profile.sh $CURRMODEM

INTER=$(uci get modem.modeminfo$CURRMODEM.inter)
if [ -z $INTER ]; then
	INTER=$CURRMODEM
else
	if [ $INTER = 0 ]; then
		INTER=$CURRMODEM
	fi
fi
log "Profile for Modem $CURRMODEM sets interface to WAN$INTER"
OTHER=1
if [ $CURRMODEM = 1 ]; then
	OTHER=2
fi
EMPTY=$(uci get modem.modem$OTHER.empty)
if [ $EMPTY = 0 ]; then
	OINTER=$(uci get modem.modem$OTHER.inter)
	if [ ! -z $OINTER ]; then
		if [ $INTER = $OINTER ]; then
			INTER=1
			if [ $OINTER = 1 ]; then
				INTER=2
			fi
			log "Switched Modem$CURRMODEM to WAN$INTER as Modem$OTHER is using WAN$OINTER"
		fi
	fi
fi
uci set modem.modem$CURRMODEM.inter=$INTER
uci commit modem
log "Modem$CURRMODEM is using WAN$INTER"

log "Checking Network Interface"
match="$(uci get modem.modem$CURRMODEM.maxcontrol | cut -d/ -f3- | xargs dirname)"
interface="$(if [ "$match" ]; then for a in /sys/class/net/*; do readlink $a; done | grep "$match"; fi | xargs -r basename)"

if [ "$interface" ]; then
	log "ECM Data Port : $interface"
	set_network "$interface"
elif
	ifconfig usb$USBN
then
	log "Using usb$USBN as network interface"
	uci set modem.modem$CURRMODEM.interface=usb$USBN
	if [ -e $ROOTER/changedevice.sh ]; then
		$ROOTER/changedevice.sh usb$USBN
	fi
	USBN=`expr 1 + $USBN`
else
	set_network eth$ETHN
	if
		ifconfig eth$ETHN
	then
		log "Using eth$ETHN as network interface"
		uci set modem.modem$CURRMODEM.interface=eth$ETHN
		if [ -e $ROOTER/changedevice.sh ]; then
			$ROOTER/changedevice.sh eth$ETHN
		fi
		ETHN=`expr 1 + $ETHN`
	fi
fi
uci commit modem


save_variables
rm -f /tmp/usbwait

ifup wan$INTER
while `ifstatus wan$INTER | grep -q '"up": false\|"pending": true'`; do
	sleep 1
done
wan_ip=$(expr "`ifstatus wan$INTER | grep '"nexthop":'`" : '.*"nexthop": "\(.*\)"')
if [ $? -ne 0 ] ; then
	wan_ip=192.168.0.1
fi
uci set modem.modem$CURRMODEM.ip=$wan_ip
uci commit modem

log "saving Trusted locks"
for file in `ls /var/lib/lockdown | grep -v SystemConfiguration.plist`;
do
	if [ ! -f "/etc/lockdown/locks/$file" ];then
		cp /var/lib/lockdown/$file /etc/lockdown/locks/
	else
		new_md5=`md5sum /var/lib/lockdown/$file | awk -F" " '{print $1}'`
		old_md5=`md5sum /etc/lockdown/locks/$file | awk -F" " '{print $1}'`
		if [ "$new_md5" != "$old_md5" ];then
			cp /var/lib/lockdown/$file /etc/lockdown/locks/
		fi
	fi
done

$ROOTER/log/logger "iPhone #$CURRMODEM Connected with IP $wan_ip"

ln -s $ROOTER/signal/otherhostless.sh $ROOTER_LINK/getsignal$CURRMODEM
$ROOTER_LINK/getsignal$CURRMODEM $CURRMODEM $PROT &

ln -s $ROOTER/connect/conmon.sh $ROOTER_LINK/con_monitor$CURRMODEM
$ROOTER_LINK/con_monitor$CURRMODEM $CURRMODEM &
uci set modem.modem$CURRMODEM.connected=1
uci commit modem

if [ -e $ROOTER/timezone.sh ]; then
	TZ=$(uci -q get modem.modeminfo$CURRMODEM.tzone)
	if [ "$TZ" = "1" ]; then
		log "Set TimeZone"
		$ROOTER/timezone.sh &
	fi
fi

CLB=$(uci get modem.modeminfo$CURRMODEM.lb)
if [ -e /etc/config/mwan3 ]; then
	ENB=$(uci get mwan3.wan$INTER.enabled)
	if [ ! -z $ENB ]; then
		if [ $CLB = "1" ]; then
			uci set mwan3.wan$INTER.enabled=1
		else
			uci set mwan3.wan$INTER.enabled=0
		fi
		uci commit mwan3
		/usr/sbin/mwan3 restart
	fi
fi
