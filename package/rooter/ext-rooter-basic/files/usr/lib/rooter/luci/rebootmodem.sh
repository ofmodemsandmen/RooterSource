#!/bin/sh

ROOTER=/usr/lib/rooter

/usr/lib/rooter/luci/remodem.sh 1 &
/usr/lib/rooter/luci/remodem.sh 2 &
sleep 3
reboot -f
