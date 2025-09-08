#!/bin/sh

ROOTER=/usr/lib/rooter
ROOTER_LINK="/tmp/links"

log() {
	logger -t "Mail Setting" "$@"
}

sett=$1
smtp=$(echo $sett | cut -d, -f1)
euser=$(echo $sett | cut -d, -f2)
epass=$(echo $sett | cut -d, -f3)

uci set gps.configuration.smtp=$smtp
uci set gps.configuration.euser=$euser
uci set gps.configuration.epass=$epass
uci commit gps