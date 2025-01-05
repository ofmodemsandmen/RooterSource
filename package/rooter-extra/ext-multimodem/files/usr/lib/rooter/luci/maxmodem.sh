#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	modlog "MultiModem" "$@"
}

max=$1
uci set maxmodem.maxmodem.maxmodem=$max
uci commit maxmodem
$ROOTER/luci/rebootmodem.sh
