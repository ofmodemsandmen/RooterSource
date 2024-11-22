#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	modlog "Modem Rebootmodem.sh $CURRMODEM" "$@"
}

proto=$(uci -q get modem.modem1.proto)
if [ "$proto" = 91 ]; then
	lspci -k > /tmp/mhipci
	while IFS= read -r line; do
		dev=$(echo "$line" | grep "Device")
		if [ -z "$dev" ]; then
			dev=$(echo "$line" | grep "SDX55")
		fi
		if [ ! -z "$dev" ]; then
			read -r line
			kd=$(echo "$line" | grep "Kernel driver")
			if [ -z "$kd" ]; then
				read -r line
			fi
			mhi=$(echo "$line" | grep "mhi-pci-generic")
			if [ ! -z "$mhi" ]; then
				dev=$(echo "$dev" | tr " " "," | cut -d, -f1)
				size=${#dev}
				if [ "$size" -eq 7 ]; then
					pcinum="0000:$dev"
				else
					pcinum="$dev"
				fi
				break			
			fi
		fi
	done < /tmp/mhipci
	echo 1 > /tmp/gotpcie1
	echo "1" > /sys/bus/pci/devices/$pcinum/remove
	log "PCi Remove"
else
	/usr/lib/rooter/luci/remodem.sh 1 &
fi
/usr/lib/rooter/luci/remodem.sh 2 &
sleep 5
reboot -f
