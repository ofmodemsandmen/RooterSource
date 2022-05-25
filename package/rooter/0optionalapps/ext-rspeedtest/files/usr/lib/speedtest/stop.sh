#!/bin/sh

killprocess() {
	proc=$1
	PID=$(ps |grep "$proc" | grep -v grep |head -n 1 | awk '{print $1}')
	if [ ! -z $PID ]; then
		kill -9 $PID
	fi
}

killprocess "speedtest --test-server"
killprocess "/speedtest/closest.lua"
killprocess "/speedtest/getspeed.sh"
killprocess "/speedtest/servers.lua"
	
rm -f /tmp/speed	
rm -f /tmp/sinfo
rm -f /tmp/close
rm -f /tmp/getspeed
rm -f /tmp/jpg
rm -f /tmp/pinfo
rm -f /tmp/sinfo
rm -f /tmp/slist
echo "0" > /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" > /tmp/spworking

