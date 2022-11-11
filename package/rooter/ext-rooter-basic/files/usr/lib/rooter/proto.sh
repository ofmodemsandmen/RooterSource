#!/bin/sh

log() {
	modlog "Protofind $CURRMODEM" "$@"
}

CURRMODEM=$1
DEVICENAME=$2
path="/sys/bus/usb/devices/$DEVICENAME/"
ipath="$DEVICENAME:1."

cntr=0
serialcnt=0
retval=0
while [ true ]; do
	if [ ! -e $path$ipath$cntr ]; then
		break
	else
		cat $path$ipath$cntr"/uevent" > /tmp/uevent
		source /tmp/uevent
		rm -f /tmp/uevent
		modlog "Driver Name : $DRIVER"
		if [ "$DRIVER" = "option" -o "$DRIVER" = "qcserial" -o "$DRIVER" = "usb_serial" -o drv[j] == "usb_serial" -o "$DRIVER" = "sierra" ]; then
			let serialcnt=$serialcnt+1
		fi
	fi
	let cntr=$cntr+1
done
cntr=0
while [ true ]; do
	if [ ! -e $path$ipath$cntr ]; then
		break
	else
		cat $path$ipath$cntr"/uevent" > /tmp/uevent
		source /tmp/uevent
		rm -f /tmp/uevent
		case $DRIVER in
			"sierra_net" )
				retval=1
				break
			;;
			"qmi_wwan" )
				retval=2
				break
			;;
			"cdc_mbim" )
				retval=3
				break
			;;
			"huawei_cdc_ncm" )
				retval=4
				break
			;;
			"cdc_ncm" )
				retval=24
				break
			;;
			"cdc_ether"|"rndis_host" )
				retval=5
				break
			;;
			"ipheth" )
				retval=9
				break
			;;
			"uvcvideo" )
				retval=99
				break
			;;
			"usblp" )
				retval=98
				break
			;;
			"usb-storage" )
				retval=97
				break
			;;
		esac
	fi
	let cntr=$cntr+1
done
if [ $serialcnt -gt 0 -a $retval -eq 0 ]; then
	retval=11
fi
echo 'retval="'"$retval"'"' > /tmp/proto

