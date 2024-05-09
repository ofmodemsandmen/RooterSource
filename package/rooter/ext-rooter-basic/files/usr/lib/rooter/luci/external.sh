#!/bin/sh

	rm /tmp/ipip
	curl -k https://api.ipify.org?format=json > /tmp/xpip
	curl -k https://api.ipify.org?format=json > /tmp/xpip
	mv /tmp/xpip /tmp/ipip
