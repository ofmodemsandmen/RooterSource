#!/bin/sh

log() {
	logger -t "Rollover" "$@"
}

amount=$1

uci set custom.bwallocate.rollover=$amount
uci commit custom
