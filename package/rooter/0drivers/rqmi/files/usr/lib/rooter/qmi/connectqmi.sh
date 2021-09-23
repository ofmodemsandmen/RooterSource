#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "QMI Connect" "$@"
}

	. /lib/functions.sh
	. /lib/netifd/netifd-proto.sh

CURRMODEM=$1
device=/dev/$2
auth=$3
NAPN=$4
username=$5
password=$6
RAW=$7
DHCP=$8
pincode=$9

INTER=$(uci -q get modem.modem$CURRMODEM.inter)
interface="wan"$INTER

case $auth in
	"0" )
		auth="none"
	;;
	"1" )
		auth="pap"
	;;
	"2" )
		auth="chap"
	;;
	*)
		auth="none"
	;;
esac
if [ $username = NIL ]; then
	username=
fi
if [ $password = NIL ]; then
	password=
fi

devname="$(basename "$device")"
devpath="$(readlink -f /sys/class/usbmisc/$devname/device/)"
ifname="$( ls "$devpath"/net )"

#while uqmi -s -d "$device" --get-pin-status | grep '"UIM uninitialized"' > /dev/null; do
#		sleep 1;
#done

[ -n "$pincode" ] && {
	uqmi -s -d "$device" --verify-pin1 "$pincode" || {
		log "Unable to verify PIN"
		ret=1
	}
}

uqmi -s -d "$device" --stop-network 0xffffffff --autoconnect > /dev/null & sleep 10 ; kill -9 $!

if [ $RAW -eq 1 ]; then
	DATAFORM='"raw-ip"'
elif [ $idV = 1199 -a $idP = 9055 ]; then
	$ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "reset.gcom" "$CURRMODEM"
	DATAFORM="802.3"
	uqmi -s -d "$device" --set-data-format 802.3
	uqmi -s -d "$device" --wda-set-data-format 802.3
else
	DATAFORM=$(uqmi -s -d "$device" --wda-get-data-format)
fi

log "WDA-GET-DATA-FORMAT is $DATAFORM"

if [ "$DATAFORM" = '"raw-ip"' ]; then
	[ -f /sys/class/net/$ifname/qmi/raw_ip ] || {
		log "Device only supports raw-ip mode but is missing this required driver attribute: /sys/class/net/$ifname/qmi/raw_ip"
		ret=1
	}
	ip link set dev $ifname down
	echo "Y" > /sys/class/net/$ifname/qmi/raw_ip
	ip link set dev $ifname up
fi

log "Setting FCC Auth: $(uqmi -s -d "$device" --fcc-auth)"
sleep 1
# uqmi -s -d "$device" --sync > /dev/null 2>&1

log "Waiting for network registration"
while uqmi -s -d "$device" --get-serving-system | grep '"searching"' > /dev/null; do
	sleep 5;
done

log "Starting network $NAPN"
cid=`uqmi -s -d "$device" --get-client-id wds`
[ $? -ne 0 ] && {
	log "Unable to obtain client ID"
	ret=1
}

uqmi -s -d "$device" --set-client-id wds,"$cid" --set-ip-family ipv4 > /dev/null

ST=$(uqmi -s -d "$device" --set-client-id wds,"$cid" --start-network ${NAPN:+--apn $NAPN} ${auth:+--auth-type $auth} \
	${username:+--username $username} ${password:+--password $password})
log "Connection returned : $ST"

CONN=$(uqmi -s -d "$device" --get-data-status)
log "Status is $CONN"

if [[ -z $(echo "$CONN" | grep -o "disconnected") ]]; then
	ret=0
	
	CONN4=$(uqmi -s -d "$device" --set-client-id wds,"$cid" --get-current-settings)
	log "GET-CURRENT-SETTINGS is $CONN4"

	cid6=`uqmi -s -d "$device" --get-client-id wds`
	[ $? -ne 0 ] && {
		log "Unable to obtain client ID"
		ret=1
	}
	uqmi -s -d "$device" --set-client-id wds,"$cid6" --set-ip-family ipv6 > /dev/null
	ST6=$(uqmi -s -d "$device" --set-client-id wds,"$cid6" --start-network ${NAPN:+--apn $NAPN} ${auth:+--auth-type $auth} \
	${username:+--username $username} ${password:+--password $password})
	log "IPv6 Connection returned : $ST6"
	CONN6=$(uqmi -s -d "$device" --set-client-id wds,"$cid6" --get-current-settings)
	CONF6=$(jsonfilter -s $CONN6 -e '@.ipv6')
	if [ -n "$CONF6" ];then
		log "IPv6 settings are $CONF6"
		touch /tmp/ipv6supp$INTER
	else
		rm -f /tmp/ipv6supp$INTER
	fi
	
	if [ $DATAFORM = '"raw-ip"' ]; then
		log "Handle raw-ip"
		json_load "$CONN4"
		json_select ipv4
		json_get_vars ip subnet gateway dns1 dns2
		if [ -n "$CONF6" ]; then
			json_load "$CONN6"
			json_select ipv6
			json_get_var ip_6 ip
			json_get_var gateway_6 gateway
			json_get_var dns1_6 dns1
			json_get_var dns2_6 dns2
			json_get_var ip_prefix_length ip-prefix-length
		fi

		if [ -s /tmp/v4dns$INTER -o -s /tmp/v6dns$INTER ]; then
			pdns=1
			if [ -s /tmp/v4dns$INTER ]; then
				v4dns=$(cat /tmp/v4dns$INTER 2>/dev/null)
			fi
			if [ -s /tmp/v6dns$INTER ]; then
				v6dns=$(cat /tmp/v6dns$INTER 2>/dev/null)
			fi
		else
			v4dns="$dns1 $dns2"
			v6dns="$dns1_6 $dns2_6"
			echo "$v6dns" > /tmp/v6dns$INTER
		fi

		if [ $DHCP -eq 0 ]; then
			log Applying IP settings to wan$INTER
			uci delete network.wan$INTER
			uci set network.wan$INTER=interface
			uci set network.wan$INTER.proto=static
			uci set network.wan$INTER.ifname=$ifname
			uci set network.wan$INTER.metric=$INTER"0"
			uci set network.wan$INTER.ipaddr=$ip/$subnet
			uci set network.wan$INTER.gateway='0.0.0.0'
			uci set network.wan$INTER.dns="$v4dns"
			uci commit network
			uci set modem.modem$CURRMODEM.interface=$ifname
			uci commit modem
		else
			proto_init_update "$ifname" 1
			proto_set_keep 1
			proto_add_ipv4_address "$ip" "$subnet"
			proto_add_ipv4_route "0.0.0.0" 0
			for DNSV in $(echo "$v4dns"); do
				proto_add_dns_server "$DNSV"
			done
			proto_send_update "$interface"
		fi
	fi
else
	uqmi -s -d "$device" --stop-network 0xffffffff --autoconnect > /dev/null & sleep 10 ; kill -9 $!
	ret=1
fi

exit $ret
