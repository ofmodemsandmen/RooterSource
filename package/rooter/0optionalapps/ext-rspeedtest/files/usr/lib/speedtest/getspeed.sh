#!/bin/sh

log() {
	logger -t "Getspeed " "$@"
}

echo "0" > /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "1" > /tmp/spworking

JITTER=""
LATENCY=""
DOWNLOAD_SPEED=""
UPLOAD_SPEED=""

while IFS= read -r line
do
	read -r line
	read -r line
	read -r line
	read -r line
	read -r line
	break
done < /tmp/sinfo
url=${line:7:100}
url=$(echo $url" " | tr "/" ",")
url=$(echo $url | cut -d, -f1)
rm -f /tmp/speed
speedtest --test-server $url --output text > /tmp/speed &
while [ -z $JITTER ]
do
	if [ -e /tmp/speed ]; then
		source /tmp/speed
	fi
	sleep 1
done
echo "$LATENCY" > /tmp/getspeed
echo "$JITTER" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "2" > /tmp/spworking

while [ -z $DOWNLOAD_SPEED ]
do
	if [ -e /tmp/speed ]; then
		source /tmp/speed
	fi
	sleep 1
done
echo "$LATENCY" > /tmp/getspeed
echo "$JITTER" >> /tmp/getspeed
echo "$DOWNLOAD_SPEED" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "3" > /tmp/spworking

while [ -z $UPLOAD_SPEED ]
do
	if [ -e /tmp/speed ]; then
		source /tmp/speed
	fi
	sleep 1
done
echo "$LATENCY" > /tmp/getspeed
echo "$JITTER" >> /tmp/getspeed
echo "$DOWNLOAD_SPEED" >> /tmp/getspeed
echo "$UPLOAD_SPEED" >> /tmp/getspeed
echo "0" > /tmp/spworking

