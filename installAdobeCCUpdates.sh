#!/bin/bash
#
# 090_Policy_installAdobeUpdates.sh - Runs Adobe Remote Update Manager while supressing client sleep
# Sam Novak - 2015

#############
# Variables #
#############

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

REMOTE1="$4"
REMOTE2="$5"
REMOTE3="$6"
REMOTE4="$7"
REMOTE5="$8"
REMOTE6="$9"
# Regular Expression for +10.11
REG="^1[0-9]$"

OSVERS=$(sw_vers -productVersion | awk -F. '{print $2}')

CAFFEINE=0
# Let's stay up, if we can
if [ -f /usr/bin/caffeinate ]; then
	if [[ $OSVERS =~ $REG ]]; then
	    CAFFEINE=1
	fi
fi

if [ -f /usr/local/bin/RemoteUpdateManager ]; then
	if [ $CAFFEINE = 1 ]; then
		/usr/bin/caffeinate -i RemoteUpdateManager 2> /dev/null
	else
		RemoteUpdateManager 2> /dev/null
	fi
fi

exit 0
