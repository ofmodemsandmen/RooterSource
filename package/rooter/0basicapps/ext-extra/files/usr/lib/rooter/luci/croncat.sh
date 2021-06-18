#!/bin/sh

if [ -f /etc/cronuser ]; then
	if [ -f /etc/cronbase ]; then
		cat /etc/cronbase /etc/cronuser > /etc/crontabs/root
	else
		cp /etc/cronuser /etc/crontabs/root
	fi
else
	if [ -f /etc/cronbase ]; then
		cp /etc/cronbase /etc/crontabs/root
	else
		rm -f /etc/crontabs/root
	fi
fi

/etc/init.d/cron restart