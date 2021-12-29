#!/bin/sh

log() {
	logger -t "Getspeed " "$@"
}

post() {
	sxtime=$(($(date +%s%3N)))
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	curl -s -X POST -d $data $ulURL
	fxtime=$(($(date +%s%3N)))
	let "sxtime=$LATN + $sxtime"
	let "elapse=$fxtime - $sxtime"
}

data=$(head -c 100000 < /dev/zero | tr '\0' '\141')


while IFS= read -r line
do
	latency=$line
	break
done < /tmp/pinfo

while IFS= read -r line
do
	read -r line
	read -r line
	read -r line
	read -r line
	read -r line
	break
done < /tmp/sinfo

echo "2" > /tmp/spworking
rm -f /tmp/getspeed
LATN=${latency%.*}

ulURL=$line
dlURL=${ulURL%upload.php}
# dlWarmUp
size=750
xdlURL=$dlURL"random"$size"x"$size".jpg"
stime=$(($(date +%s%3N)))
curl -Z -s -o /dev/null  $xdlURL --next -o /dev/null  $xdlURL
ftime=$(($(date +%s%3N)))
let "stime=$LATN + $stime"
let "elapse=$ftime - $stime"
let "wuSpeed=18000/$elapse"
echo "18" >> /tmp/getspeed
echo $elapse >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" >> /tmp/getspeed

if [ 10 -lt $wuSpeed ]; then
		workload=4
elif [ 4 -lt $wuSpeed ]; then
		workload=2
elif [ 2 -lt $wuSpeed ]; then
		workload=1
else
		workload=1
fi
fsize=144
weight=1500

stime=$(($(date +%s%3N)))
size=$weight
xdlURL=$dlURL"random"$size"x"$size".jpg"
number=0
while true; do
	sxtime=$(($(date +%s%3N)))
	curl -Z -s -o /dev/null  $xdlURL --next -o /dev/null  $xdlURL --next -o /dev/null  $xdlURL  --next -o /dev/null  $xdlURL
	fxtime=$(($(date +%s%3N)))
	let "sxtime=$LATN + $sxtime"
	let "elapse=$fxtime - $sxtime"
	echo "$fsize" > /tmp/getspeed
	echo $elapse >> /tmp/getspeed
	echo "0" >> /tmp/getspeed
	echo "0" >> /tmp/getspeed
	let "number=$number+1"
	if [ $number -gt $workload ]; then
		break
	fi
done
ftime=$(($(date +%s%3N)))

let "xtime=$LATN * $workload"
let "stime=$xtime + $stime"
let "dlelapse=$ftime - $stime"
let "dlsent=$number * $fsize"
echo "$dlsent" > /tmp/getspeed
echo "$dlelapse" >> /tmp/getspeed
echo "0" >> /tmp/getspeed
echo "0" >> /tmp/getspeed

echo "3" > /tmp/spworking
post
let "wuSpeed=16000/$elapse"
echo "$dlsent" > /tmp/getspeed
echo "$dlelapse" >> /tmp/getspeed
echo "16" >> /tmp/getspeed
echo "$elapse" >> /tmp/getspeed
if [ 10 -lt $wuSpeed ]; then
		workload=16
elif [ 4 -lt $wuSpeed ]; then
		workload=8
elif [ 2 -lt $wuSpeed ]; then
		workload=4
else
		workload=1
fi

stime=$(($(date +%s%3N)))
number=0
while true; do
	sxtime=$(($(date +%s%3N)))
	post
	fxtime=$(($(date +%s%3N)))
	let "sxtime=$LATN + $sxtime"
	let "elapse=$fxtime - $sxtime"
	echo "$dlsent" > /tmp/getspeed
	echo "$dlelapse" >> /tmp/getspeed
	echo "16" >> /tmp/getspeed
	echo "$elapse" >> /tmp/getspeed
	let "number=$number+1"
	if [ $number -gt $workload ]; then
		break
	fi
done
ftime=$(($(date +%s%3N)))
let "stime=$LATN + $stime"
let "ulelapse=$ftime - $stime"
let "ulsent=$number * 16"
echo "$dlsent" > /tmp/getspeed
echo "$dlelapse" >> /tmp/getspeed
echo "$ulsent" >> /tmp/getspeed
echo "$ulelapse" >> /tmp/getspeed

echo "0" > /tmp/spworking
