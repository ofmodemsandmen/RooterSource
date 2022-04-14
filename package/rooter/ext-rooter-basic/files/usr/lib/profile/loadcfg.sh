#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Load" "$@"
}

profile=$1
valid=$(echo "$profile" | grep "**Profile**")
if [ ! -z "$valid" ]; then
	echo "$profile" > /tmp/profile
	sed -i '1d' /tmp/profile
	cp /tmp/profile /etc/config/profile
fi
