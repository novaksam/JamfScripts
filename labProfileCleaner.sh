#!/bin/bash
#
# Lab Profile Cleaner - Deletes profiles over 30 days old
# Sam Novak - Aug 2013

#############
# Variables #
#############
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

# The current time
# Format: 
# %b: abbreviated month name (e.g., Jan)
# %e: day of month, space padded; same as %_d
# %H: hour (00..23)
# %M: minute (00..59)
# %S: second (00..60)
NOW=$(date +"%b %e %H:%M:%S")

# The time in seconds for 30 days
SEC=2592000

# The location of the log we'll be comparing against
LOG=/var/log/jamf.log

# The hostname used to delimit the log
HOST=$(hostname | cut -d "." -f1)

# Get the currently logged in user
# This currently cannot accomadate multiple logged in users
USER=$(users | awk -F" " '{ for (i=1; i<=NF; i++) print $i }' | grep -v adm)

#############
# Functions #
#############

# DO NOT LOG USER NAMES
# THE GIVIN LOGGING MECHANISM RECORDS TO THE /var/log/com.log
# AND SCREWS UP OLD PROFILE DETECTION!
ComLog() {
	/usr/bin/syslog -s -k Facility local7 Level info Message "$1"
}




####################
# Actual scripting #
####################

# Adding logged in user to the log to prevent long-time logins
# from getting  removed
ComLog "$USER is logged in"

# Get the maximum age a profile can be
MAXTIME=$(expr `date -jf "%b %e %H:%M:%S" "$NOW" +%s` - $SEC)

# Get all users in /Users
for E in $( ls /Users )
	do
	# verify the ID is fetchable
	# Also, pipe all the output to null so it can work faster through remote
	# Redirecting error output reduces "User does not exist" for localized and Shared folders
	id "$E" > /dev/null 2> /dev/null
	if [ $? = 0 ]; then
		# Verify the ID is for a Company user
		ID=$(printf `id -u $E`)
		if [ $ID -gt 10000000 ]; then
			# Date of last login
			AGE=$(grep $E $LOG | tail -n 1 | awk -F"$HOST" {'print $1'});
			# Remove the extra space at the end
			# prevents date printing Warning: Ignoring 1 extraneous characters in date string ( )
			TEMP=$(echo "$AGE" | tail -c 2)
			if [ "$TEMP" == " " ]; then
				AGE=`echo "${AGE%?}"`
			fi
			# Unix epoch time format
			# Additional format factor from the log
			# %a: abbreviated weekday name (e.g., Sun)
			UAGE=$(date -jf "%a %b %e %H:%M:%S" "$AGE" +%s);
			# Compare dates. If less than 0 profile is over 30 days old
			# This works by subtracting the maximum possible age (30 days ago)
			# from the last time they logged in resulting in a negative number
			# if the last login was over 30 days ago
			OLD=$(expr $UAGE - $MAXTIME)
			if [ "$OLD" -le 0 ]; then
				/bin/echo "$E is pretty old!"
				rm -fr /Users/$E
				#ComLog "$E is pretty old!"
			fi
		fi
	fi
done

exit 0
