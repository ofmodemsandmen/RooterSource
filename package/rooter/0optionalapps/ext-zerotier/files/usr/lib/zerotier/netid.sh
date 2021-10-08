#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "NetID" "$@"
}

ID=$2

log "$ID"

uci delete zerotier.zerotier1.join
uci add_list zerotier.zerotier1.join=$ID
uci commit zerotier
/etc/init.d/zerotier restart
