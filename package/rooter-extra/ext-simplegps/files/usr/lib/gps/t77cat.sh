#!/bin/sh

NMEA=$1
while true; do
	if [ -e /dev/ttyUSB$NMEA ]; then
		cat /dev/ttyUSB$NMEA > /tmp/t77gps
		sleep 2
	else
		break
	fi
done