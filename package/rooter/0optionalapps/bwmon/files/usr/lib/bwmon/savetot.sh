#!/bin/sh

log() {
	logger -t "save total" "$@"
}

total=$1
log "$total"

uci set custom.bwday.bwday="$total"
uci commit custom