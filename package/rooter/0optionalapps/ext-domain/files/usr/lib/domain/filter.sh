#!/bin/sh
. /lib/functions.sh

log() {
	logger -t "Domain Filter " "$@"
}

handle_ipset() {
	local ips=$1
	echo "$ips" >> /etc/adblock/adblock.blacklist
}

do_ipset() {
	local config=$1
	local ipset

	config_list_foreach "$config" ipset handle_ipset
}

sleep 3
echo "#" > /etc/adblock/adblock.blacklist
config_load filter
config_foreach do_ipset filter
/etc/init.d/adblock restart
