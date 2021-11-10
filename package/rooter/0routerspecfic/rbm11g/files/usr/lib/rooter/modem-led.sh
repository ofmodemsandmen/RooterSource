#!/bin/sh

log() {
	logger -t "modem-led " "$@"
}

CURRMODEM=$1
COMMD=$2

	case $COMMD in
		"0" )
			echo none > /sys/class/leds/rbm11g:green:rssi0/trigger
			echo 0  > /sys/class/leds/rbm11g:green:rssi0/brightness
			echo none > /sys/class/leds/rbm11g:green:rssi1/trigger
			echo 0  > /sys/class/leds/rbm11g:green:rssi1/brightness
			echo none > /sys/class/leds/rbm11g:green:rssi2/trigger
			echo 0  > /sys/class/leds/rbm11g:green:rssi2/brightness
			echo none > /sys/class/leds/rbm11g:green:rssi3/trigger
			echo 0  > /sys/class/leds/rbm11g:green:rssi3/brightness
			echo none > /sys/class/leds/rbm11g:green:rssi4/trigger
			echo 0  > /sys/class/leds/rbm11g:green:rssi4/brightness
			;;
		"1" )
			echo timer > /sys/class/leds/rbm11g:green:rssi0/trigger
			echo 500  > /sys/class/leds/rbm11g:green:rssi0/delay_on
			echo 500  > /sys/class/leds/rbm11g:green:rssi0/delay_off
			;;
		"2" )
			echo timer > /sys/class/leds/rbm11g:green:rssi0/trigger
			echo 200  > /sys/class/leds/rbm11g:green:rssi0/delay_on
			echo 200  > /sys/class/leds/rbm11g:green:rssi0/delay_off
			;;
		"3" )
			echo timer > /sys/class/leds/rbm11g:green:rssi0/trigger
			echo 1000  > /sys/class/leds/rbm11g:green:rssi0/delay_on
			echo 0  > /sys/class/leds/rbm11g:green:rssi0/delay_off
			;;
		"4" )
			echo none > /sys/class/leds/rbm11g:green:rssi0/trigger
			echo 1  > /sys/class/leds/rbm11g:green:rssi0/brightness
			sig2=$3
			if [ $sig2 -lt 18 -a $sig2 -gt 0 ] 2>/dev/null;then
				echo none > /sys/class/leds/rbm11g:green:rssi1/trigger
				echo 0  > /sys/class/leds/rbm11g:green:rssi1/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi2/trigger
				echo 0  > /sys/class/leds/rbm11g:green:rssi2/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi3/trigger
				echo 0  > /sys/class/leds/rbm11g:green:rssi3/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi4/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi4/brightness
			elif [ $sig2 -ge 18 -a $sig2 -lt 24 ] 2>/dev/null;then
				echo none > /sys/class/leds/rbm11g:green:rssi1/trigger
				echo 0  > /sys/class/leds/rbm11g:green:rssi1/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi2/trigger
				echo 0  > /sys/class/leds/rbm11g:green:rssi2/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi3/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi3/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi4/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi4/brightness
			elif [ $sig2 -ge 24 -a $sig2 -lt 30 ] 2>/dev/null;then
				echo none > /sys/class/leds/rbm11g:green:rssi1/trigger
				echo 0  > /sys/class/leds/rbm11g:green:rssi1/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi2/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi2/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi3/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi3/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi4/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi4/brightness
			else
				echo none > /sys/class/leds/rbm11g:green:rssi1/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi1/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi2/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi2/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi3/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi3/brightness
				echo none > /sys/class/leds/rbm11g:green:rssi4/trigger
				echo 1  > /sys/class/leds/rbm11g:green:rssi4/brightness
			fi
			;;
	esac
