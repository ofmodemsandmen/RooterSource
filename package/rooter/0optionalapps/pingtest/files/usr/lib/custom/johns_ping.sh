#!/bin/sh

. /lib/functions.sh
 
ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
logger -t "Custom Ping Test " "$@"
}

tping() {
	hp=$(httping $2 -t $TIMEOUT -c 3 -s $1)
	pingg=$(echo $hp" " | grep -o "round-trip .\+ ms ")
	if [ -z "$pingg" ]; then
		tmp=0
	else
		tmp=200
	fi
}

doping() {
	TYPE=$(uci get ping.ping.type)
	if [ $TYPE = "1" ]; then
		if [ "$LOGGING" = "1" ]; then
			log "Curl"
		fi
		RETURN_CODE_1=$(curl -s --connect-timeout $TIMEOUT -m 10 -s -o /dev/null -w "%{http_code}" $ipv41)
		RETURN_CODE_2=$(curl -s --connect-timeout $TIMEOUT --ipv6 -m 10 -s -o /dev/null -w "%{http_code}" $ipv6)
		RETURN_CODE_3=$(curl -s --connect-timeout $TIMEOUT -m 10 -s -o /dev/null -w "%{http_code}" $ipv42)
	else
		if [ "$LOGGING" = "1" ]; then
			log "Ping"
		fi
		tping "$ipv41"; RETURN_CODE_1=$tmp
		tping "$ipv6" "-6"; RETURN_CODE_2=$tmp
		tping "$ipv42"; RETURN_CODE_3=$tmp
	fi
}

ptest() {
	tries=0
	status=0
	while [ $tries -lt $1 ]
	do
		CONN=$(uci -q get modem.modem$CURRMODEM.connected)
		if [ $CONN = "1" ]; then
			uci set ping.ping.conn="4"
			uci commit ping
			doping
			if [[ "$RETURN_CODE_1" != "200" &&  "$RETURN_CODE_2" != "200" &&  "$RETURN_CODE_3" != "200" ]]; then
				uci set ping.ping.conn="1"
				uci commit ping
				status=1
				return
			fi
			if [ "$LOGGING" = "1" ]; then
				log "Second Ping Test Good"
			fi
			uci set ping.ping.conn="2"
			uci commit ping
			status=0
			return
		else
			sleep 20
			tries=$((tries+1))
		fi
	done
	status=1
}

ipv41=$(uci -q get ping.ping.ipv41)
if [ -z "$ipv41" ]; then
	ipv41="http://www.google.com/"
fi
ipv42=$(uci -q get ping.ping.ipv42)
if [ -z "$ipv42" ]; then
	ipv42="https://github.com"
fi
ipv6=$(uci -q get ping.ping.ipv6)
if [ -z "$ipv6" ]; then
	ipv6="http://ipv6.google.com"
fi
uci set ping.ping.conn="4"
uci commit ping
	
CURRMODEM=1
CPORT=$(uci -q get modem.modem$CURRMODEM.commport)
DELAY=$(uci -q get ping.ping.delay)
TIMEOUT=$(uci -q get ping.ping.timeout)
LOGGING=$(uci -q get ping.ping.logging)
if [ -z "$TIMEOUT" ]; then
	TIMEOUT=5
fi
RE=$(uci -q get ping.ping.reboot)

doping

if [[ "$RETURN_CODE_1" != "200" &&  "$RETURN_CODE_2" != "200" &&  "$RETURN_CODE_3" != "200" ]]; then
	if [ "$LOGGING" = "1" ]; then
		log "Bad Ping Test"
	fi
	doping
	if [[ "$RETURN_CODE_1" != "200" &&  "$RETURN_CODE_2" != "200" &&  "$RETURN_CODE_3" != "200" ]]; then
		if [ "$LOGGING" = "1" ]; then
			log "Second Bad Ping Test"
		fi
		uci set ping.ping.conn="3"
		uci commit ping
		if [ "$RE" = "1" ]; then
			touch /etc/banner && reboot -f
			exit 0
		fi
		if [ "$LOGGING" = "1" ]; then
			log "Restart Network"
		fi
		/usr/lib/rooter/luci/restart.sh $CURRMODEM 10
		sleep $DELAY
		ptest 3
		if [ $status -eq 0 ]; then
			if [ "$LOGGING" = "1" ]; then
				log "Good Ping after Network Restart"
			fi
			uci set ping.ping.conn="2"
			uci commit ping
			exit 0
		else
			if [ "$LOGGING" = "1" ]; then
				log "Hard Restart"
			fi
			/usr/lib/rooter/luci/restart.sh $CURRMODEM 11
			ptest 9
			if [ $status -eq 0 ]; then
				if [ "$LOGGING" = "1" ]; then
					log "Good Ping after Hard Restart"
				fi
				uci set ping.ping.conn="2"
				uci commit ping
				exit 0
			else
				touch /etc/banner && reboot -f
			fi
		fi
	fi
else
	if [ "$LOGGING" = "1" ]; then
		log "Good Ping"
	fi
	uci set ping.ping.conn="2"
	uci commit ping
fi
exit 0
