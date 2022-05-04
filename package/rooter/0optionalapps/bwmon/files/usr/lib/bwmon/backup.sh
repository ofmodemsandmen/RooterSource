#!/bin/sh

log() {
	logger -t "wrtbwmon" "$@"
}

# parameters
#
btype=$1
cDay=$2
monthlyUsageDB=$3
dailyUsageDB=$4
monthlyUsageBack=$5
dailyUsageBack=$6

/usr/lib/bwmon/backup-daily.lua $dailyUsageDB
/usr/lib/bwmon/backup-mon.lua $monthlyUsageDB
cp -f $monthlyUsageDB".bk" $monthlyUsageDB
cp -f $dailyUsageDB".bk" $dailyUsageDB

echo "start day $cDay" >> $monthlyUsageDB".bk"
cat $dailyUsageDB".bk" >> $monthlyUsageDB".bk"
echo "end day $cDay" >> $monthlyUsageDB".bk"


if [ $btype = "backup" ]; then
	cp -f $monthlyUsageDB".bk" $monthlyUsageBack
	cp -f $dailyUsageDB".bk" $dailyUsageBack 
else
	if [ $btype = "daily" ]; then
		cp -f $monthlyUsageDB".bk" $monthlyUsageDB
		cp -f $monthlyUsageDB".bk" $monthlyUsageBack
	fi
fi

#rm -f $monthlyUsageDB".bk"
rm -f $dailyUsageDB".bk"

