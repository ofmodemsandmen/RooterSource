#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
#  stop and then restart the main YAMon script
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)

delay=$1
[ -z "$delay" ] && delay=10

logger "YAMON:" "Restarting"
sleep $delay
${d_baseDir}/shutdown.sh

${d_baseDir}/startup.sh $delay &