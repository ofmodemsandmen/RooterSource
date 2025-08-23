#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Enable" "$@"
}

enable=$2
enabled=$(uci -q get zerotier.global.enabled)
if [ "$enabled" != "$enable" ]; then
	uci set zerotier.global.enabled="$enable"
	uci commit zerotier
	/etc/init.d/zerotier restart
fi

