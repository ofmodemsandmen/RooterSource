#!/bin/sh

ROOTER=/usr/lib/rooter

/usr/lib/rooter/luci/restartrun.sh 1 &
/usr/lib/rooter/luci/restartrun.sh 2 &
sleep 70 && touch /etc/banner
reboot -f