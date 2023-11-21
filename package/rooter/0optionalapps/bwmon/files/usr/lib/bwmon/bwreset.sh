#!/bin/sh

log() {
	modlog "BandWidth Reset" "$@"
}

amt=$1"000000"
echo "$amt" > /tmp/bwreset
