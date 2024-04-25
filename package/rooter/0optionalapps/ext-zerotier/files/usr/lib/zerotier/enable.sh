#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Enable" "$@"
}

enable=$2
enabled=$(uci -q get zerotier.zerotier.enabled)
if [ "$enabled" != "$enable" ]; then
	uci set zerotier.zerotier.enabled="$enable"
	uci commit zerotier
	/etc/init.d/zerotier restart
fi

