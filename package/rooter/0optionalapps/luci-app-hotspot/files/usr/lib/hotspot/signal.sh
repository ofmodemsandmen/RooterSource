#!/bin/sh
. /lib/functions.sh

reconn=$1
uci set travelmate.global.signal=$reconn
uci commit travelmate