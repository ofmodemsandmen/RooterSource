#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	modlog "Modem Rebootmodem.sh $CURRMODEM" "$@"
}

/usr/lib/rooter/luci/remodem.sh 1 &
/usr/lib/rooter/luci/remodem.sh 2 &
sleep 5
reboot -f
