#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "NetID" "$@"
}

enb=$(uci -q get zerotier.global.enabled)
if [ "$enb" = "0" ]; then
	status="0"
	ip="---"
	mac="---"
else
	stat=$(zerotier-cli status)
	onl=$(echo "$stat" | grep "ONLINE")
	if [ -z "$onl" ]; then
		status="1"
		ip="---"
		mac="---"
	else
		status="2"
		net=$(zerotier-cli listnetworks)
		col=$(echo "$net" | grep ":")
		if [ ! -z "$col" ]; then
			pos=$(awk -v a="$net" -v b=":" 'BEGIN{print index(a,b)}' | xargs expr -1 +)
			let pos=$pos-2
			chr=${net:$pos}
			chr=$(echo "$chr" | tr " " ",")
			mac=$(echo $chr | cut -d, -f1)
			ip=$(echo $chr | cut -d, -f5)
			ip=${ip::-3}
		else
			ip="---"
			mac="---"
		fi
	fi
fi
echo "$status" > /tmp/zstatus
echo "$mac" >> /tmp/zstatus
echo "$ip" >> /tmp/zstatus