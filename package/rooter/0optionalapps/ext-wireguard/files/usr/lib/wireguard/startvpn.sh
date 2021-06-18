#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Wireguard Start" "$@"
}

WG=$1

do_port() {
	PORT=$1
	udp=$2
	# look for rule for this port
	INB="inbound"$PORT$udp
	RULE=$(uci get firewall.$INB)
	if [ -z $RULE ]; then
		uci set firewall.$INB=rule
		uci set firewall.$INB.name=$INB
		uci set firewall.$INB.target=ACCEPT
		uci set firewall.$INB.src=*
		uci set firewall.$INB.proto=$udp
		uci set firewall.$INB.dest_port=$PORT
		uci commit firewall
		/etc/init.d/firewall reload
	fi
}

do_delete() {
	local config=$1
	
	uci delete network.$1
}

create_speer() {
	local config=$1

	uci set network.$config="wireguard_wg1"

	config_get persistent_keepalive $config persistent_keepalive
	uci set network.$config.persistent_keepalive="$persistent_keepalive"
	config_get route_allowed_ips $config route_allowed_ips
	uci set network.$config.route_allowed_ips="$route_allowed_ips"
	config_get publickey $config publickey
	uci set network.$config.public_key="$publickey"
	usepre=$(uci -q get wireguard.$WG.usepre)
	log "$usepre"
	if [ $usepre = "1" ]; then
		presharedkey=$(uci get wireguard.$WG.presharedkey)
		log "$presharedkey"
		uci set network.$config.preshared_key="$presharedkey"
	fi
	config_get allowed_ips $config allowed_ips
	allowed_ips=$allowed_ips","
	ips=$(echo $allowed_ips | cut -d, -f1)
	i=1
	while [ ! -z $ips ]
	do
		uci add_list network.$config.allowed_ips="$ips"
		i=$((i+1))
		ips=$(echo $allowed_ips | cut -d, -f$i)
	done

}

create_cpeer() {
	local config=$1
	
	uci set network.$config="wireguard_wg0"

	publickey=$(uci get wireguard."$config".publickey)
	uci set network.$config.public_key="$publickey"
	presharedkey=$(uci get wireguard."$WG".presharedkey)
	if [ ! -z $presharedkey ]; then
		uci set network.$config.preshared_key="$presharedkey"
	fi
	persistent_keepalive=25
	uci set network.$config.persistent_keepalive="$persistent_keepalive"
	route_allowed_ips=1
	uci set network.$config.route_allowed_ips="$route_allowed_ips"
	
	if [ $UDP = 1 ]; then
		endpoint_host="127.0.0.1"
		uci set network.$config.endpoint_host="$endpoint_host"
		sport=$(uci get wireguard."$config".port)
		if [ -z $sport ]; then
			sport="54321"
		fi
		uci set network.$config.endpoint_port="$sport"
	else
		endpoint_host=$(uci get wireguard."$config".endpoint_host)
		uci set network.$config.endpoint_host="$endpoint_host"
		sport=$(uci get wireguard."$config".sport)
		if [ -z $sport ]; then
			sport="51280"
		fi
		uci set network.$config.endpoint_port="$sport"
	fi
	
	ips=$(uci get wireguard."$config".ips)","
	cips=$(echo $ips | cut -d, -f1)
	i=1
	while [ ! -z $cips ]
	do
		uci add_list network.$config.allowed_ips="$cips"
		i=$((i+1))
		cips=$(echo $ips | cut -d, -f$i)
	done
}

handle_server() {
	config_foreach do_delete wireguard_wg1
	
	uci delete network.wg1
	uci set network.wg1="interface"
	uci set network.wg1.proto="wireguard"
	
	auto=$(uci get wireguard."$WG".auto)
	if [ -z $auto ]; then
		auto="0"
	fi
	uci set network.wg1.auto="$auto"
	
	port=$(uci get wireguard."$WG".port)
	if [ -z $port ]; then
		port="51280"
	fi
	uci set network.wg1.listen_port="$port"
	do_port $port udp
	
	privatekey=$(uci get wireguard."$WG".privatekey)
	uci set network.wg1.private_key="$privatekey"

	ips=$(uci get wireguard."$WG".addresses)","
	cips=$(echo $ips | cut -d, -f1)
	i=1
	while [ ! -z $cips ]
	do
		uci add_list network.wg1.addresses="$cips"
		i=$((i+1))
		cips=$(echo $ips | cut -d, -f"$i")
		if [ -z $cips ]; then
			break
		fi
	done
	
	config_load wireguard
	config_foreach create_speer custom$WG
	
	uci commit network
}

handle_client() {
	config_foreach do_delete wireguard_wg0
	
	uci delete network.wg0
	uci set network.wg0="interface"
	uci set network.wg0.proto="wireguard"
	
	auto=$(uci get wireguard."$WG".auto)
	if [ -z $auto ]; then
		auto="0"
	fi
	uci set network.wg0.auto="$auto"
	mtu=$(uci get wireguard."$WG".mtu)
	if [ ! -z $mtu ]; then
		uci set network.wg0.mtu="$mtu"
	fi
	port=$(uci get wireguard."$WG".port)
	if [ -z $port ]; then
		port="51280"
	fi
	uci set network.wg0.listen_port="$port"
	do_port $port udp
	
	privatekey=$(uci get wireguard."$WG".privatekey)
	uci set network.wg0.private_key="$privatekey"

	ips=$(uci get wireguard."$WG".addresses)","
	cips=$(echo $ips | cut -d, -f1)
	i=1
	while [ ! -z "$cips" ]
	do
		uci add_list network.wg0.addresses="$cips"
		i=$((i+1))
		cips=$(echo "$ips" | cut -d, -f"$i")
		if [ -z "$cips" ]; then
			break
		fi
	done
	
	create_cpeer $WG
	
	uci commit network
}

udp_server() {
	local config=$1
	udpport=$(uci get wireguard."$WG".udpport)
	if [ -z $udpport ]; then
		udpport="54321"
	fi
	port=$(uci get wireguard."$WG".port)
	if [ -z $port ]; then
		port="54321"
	fi
	do_port $udpport tcp
	udptunnel -s -v "0.0.0.0:"$udpport "127.0.0.1:"$port &
	#log "udptunnel -s -v 0.0.0.0:$udpport 127.0.0.1:$port"
}

udp_client() {
	local config=$1
	port=$(uci get wireguard."$WG".port)
	if [ -z $port ]; then
		port="54321"
	fi
	endpoint_host=$(uci get wireguard.$WG.endpoint_host)
	sport=$(uci get wireguard.$WG.sport)
	if [ -z $sport ]; then
		sport="51280"
	fi
	
	udptunnel "127.0.0.1:"$port $endpoint_host":"$sport &
	#log "udptunnel 127.0.0.1:$port $endpoint_host:$sport"
}

running=$(uci get wireguard.settings.enabled)
if [ $running = 1 ]; then
	exit 0
fi

config_load network
SERVE=$(uci get wireguard."$WG".client)
if [ $SERVE = "0" ]; then
	UDP=$(uci get wireguard."$WG".udptunnel)
	if [ $UDP = 1 ]; then
		udp_server $WG
	fi
	handle_server
	uci commit network
	ifup wg1
	sleep 2
	STA=$(cat /sys/class/net/wg1/operstate)
	if [ $STA = "down" ]; then
		UDP=$(uci get wireguard."$WG".udptunnel)
		if [ $UDP = 1 ]; then
			PID=$(ps |grep "udptunnel" | grep -v grep |head -n 1 | awk '{print $1}')
			kill -9 $PID
		fi
		ifdown wg0
		exit 0
	fi
else
	UDP=$(uci get wireguard."$WG".udptunnel)
	if [ $UDP = 1 ]; then
		udp_client $WG
	fi
	handle_client
	uci commit network
	ifup wg0
	sleep 2
	STA=$(cat /sys/class/net/wg0/operstate)
	if [ $STA = "down" ]; then
		UDP=$(uci get wireguard."$WG".udptunnel)
		if [ $UDP = 1 ]; then
			PID=$(ps |grep "udptunnel" | grep -v grep |head -n 1 | awk '{print $1}')
			kill -9 $PID
		fi
		ifdown wg0
		exit 0
	fi
fi

uci set wireguard.settings.enabled="1"
uci set wireguard."$WG".active="1"
uci commit wireguard

