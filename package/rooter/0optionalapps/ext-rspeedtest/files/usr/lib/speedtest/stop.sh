#!/bin/sh

PID=$(ps |grep "speedtest --test-server" | grep -v grep |head -n 1 | awk '{print $1}')
kill -9 $PID
PID=$(ps |grep "/speedtest/closest.lua" | grep -v grep |head -n 1 | awk '{print $1}')
kill -9 $PID
PID=$(ps |grep "/speedtest/getspeed.sh" | grep -v grep |head -n 1 | awk '{print $1}')
kill -9 $PID
PID=$(ps |grep "/speedtest/servers.lua" | grep -v grep |head -n 1 | awk '{print $1}')
kill -9 $PID
PID=$(ps |grep "/speedtest/info.sh" | grep -v grep |head -n 1 | awk '{print $1}')
kill -9 $PID
	
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

