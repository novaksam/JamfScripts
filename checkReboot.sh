#!/bin/bash
# 
# Check for the reboot flag, meaning the a subprocess requires a system reboot.
#
# This is designed to go into the third party update workflow, where
# a master policy calls sub-policies. This script is ran at the end of the master policy
# and check for a reboot flag set by 098_Policy_SetReboot.sh during a sub-policy
#
# If the reboot flag is not set, this script will do a recon instead.

# $4 is the amount of time in minutes to delay a reboot.
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

RESTART="0"
USERS="0"
TIME=0

getRestart() {
	REBOOT=$(defaults read /Library/Preferences/com.org.systeminfo REBOOT)
	if [ "$REBOOT" == "TRUE" ]; then
		RESTART="1"
		defaults delete /Library/Preferences/com.org.systeminfo REBOOT
	elif [ "$REBOOT" == "FALSE" ]; then
		# Honestly this shouldn't be set, but let's delete it anyway.
		defaults delete /Library/Preferences/com.org.systeminfo REBOOT
	fi
}

# If no time parameter is set, default to 20 minutes.
# the -z checks for zero length strings
getTime() {
	if [ -z "$1" ]; then
		TIME=1200
	else
		TIME=`expr $1 \* 60`
	fi
}

getUserCount() {
	COUNT=$(ls -l /dev/console | awk '/ / { print $3 }' | wc -l | tr -d ' ')
	if [ "$COUNT" -ne '0' ]; then
		USERS="1"
	fi
}

rebootPrompt() {
	if [ "$RESTART" == "1" ]; then
		getUserCount
		if [ "$USERS" == "1" ]; then
			/usr/local/bin/jamf displayMessage -message "This computer will restart automatically in $1 minutes. Please save anything you are working on and log out by choosing Log Out from the bottom of the Apple menu. You may also select restart from the Apple Menu to restart your computer sooner."
			# Ping for the desired delay minutes
			/sbin/ping -c $TIME 127.0.0.1 > /dev/null
			/usr/local/bin/jamf reboot -immediately -background
		else
			/usr/local/bin/jamf reboot -immediately -background
		fi
	fi
}

runRecon() {
	if [ "$RESTART" == "0" ]; then
		/usr/local/bin/jamf recon
	fi
}

Main() {
	getTime "$4"
	getRestart
	runRecon
	rebootPrompt "$4"
}

Main "$@"
exit 0
