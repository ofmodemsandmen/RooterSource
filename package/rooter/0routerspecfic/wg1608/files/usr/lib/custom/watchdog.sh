#!/bin/sh

log() {
	logger -t "WATCHSYSTEM" "$@"
}

exit 0

model=`cat /proc/cpuinfo |sed -n 2p|cut -d ":" -f2|sed 's/ //g'`

date=`date`

wdgpio=3
low=1
hig=0
wd_mode=1

if [ "$wdgpio" != "" ] ;then
	echo $wdgpio > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio$wdgpio/direction
	echo $low >/sys/class/gpio/gpio$wdgpio/value
	sleep 1
	echo $hig >/sys/class/gpio/gpio$wdgpio/value

cat > /tmp/feed_dog.sh <<EOF
#!/bin/sh

echo $low >/sys/class/gpio/gpio$wdgpio/value
    sleep 1
echo $hig >/sys/class/gpio/gpio$wdgpio/value
    sleep 1
echo $low >/sys/class/gpio/gpio$wdgpio/value
    sleep 1
echo $hig >/sys/class/gpio/gpio$wdgpio/value
    sleep 1
echo $low >/sys/class/gpio/gpio$wdgpio/value
    sleep 1
echo $hig >/sys/class/gpio/gpio$wdgpio/value
    sleep 1
echo "feed_dog.sh:-------------Feed" >>/tmp/watchdog.log 
EOF

	chmod 777 /tmp/feed_dog.sh
fi
	
while true
do

	date=`date`
	uptime=$(awk '{print $1}' /proc/uptime |sed 's/\..*$//')

	sleep 30
	echo "$date uptime-$uptime Watchsys:Network IS Down--NO Feed" >>/tmp/watchdog.log 
	/tmp/feed_dog.sh &   #运行时间小于5分钟，持续喂狗
	echo "$date uptime-$uptime Watchsys:Network IS Down-uptime<300-Feed" >>/tmp/watchdog.log

	logl=`cat /tmp/watchdog.log  |wc -l`
	if  [ "$logl" -gt 200 ] ;then
		echo "new_log" >/tmp/watchdog.log
	fi

	sleep 2
done









