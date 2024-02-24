#!/bin/sh

result=`ps | grep -i "chkconn1.sh" | grep -v "grep" | wc -l`
if [ $result -lt 1 ]; then
	/usr/lib/rooter/connect/chkconn1.sh $1
fi