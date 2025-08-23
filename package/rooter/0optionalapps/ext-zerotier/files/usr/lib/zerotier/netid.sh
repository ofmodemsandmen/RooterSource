#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "NetID" "$@"
}

ID=$2

uci delete zerotier.zerotier.id
uci add_list zerotier.zerotier.id=$ID
uci commit zerotier
uci set custom.zerotier.networkid=$ID
uci commit custom
/etc/init.d/zerotier restart
