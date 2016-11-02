#!/bin/bash
# 
# Creates and loads a launchagent to renew the active users kerberos ticket
# every 60 minutes.


# Set variables and mount share
USER=`echo "$3" | cut -d "@" -f1`
#USER=$3
SHARE=$4
SHARELABEL=$5
# Regular Expression for +10.11
REG="^1[1-9]$"
echo "User = $USER"
echo "Share = $SHARE"
echo "ShareLabel = $SHARELABEL"

osvers=$(sw_vers -productVersion | awk -F. '{print $2}')
sw_vers=$(sw_vers -productVersion)
sw_build=$(sw_vers -buildVersion)


NEW=0
# Get user's id number
id=$(printf `id -u $USER`)

# If the user is local they won't have any network shares
if [ $id -lt 10000000 ]; then
  echo "User $id is a local user, exiting."
  exit 0
fi


########################################
## Mount the share with Kerberos auth ##
########################################
if [ ! -f /Users/$USER/Library/LaunchAgents/com.org.kerberosrenew.plist ]; then

	NEW=1
	
	echo "Writting out Kerberos renwal agent"
	
	# Create the launch agent to mount the share
	/usr/bin/su -l "$USER" -c "/usr/bin/defaults write /Users/$USER/Library/LaunchAgents/com.org.kerberosrenew Label -string com.org.kerberosrenew"

	# Write out a launch agent
	/usr/bin/su -l "$USER" -c "/usr/bin/defaults write /Users/$USER/Library/LaunchAgents/com.org.kerberosrenew ProgramArguments -array /bin/sh -c \"kinit -R \""

	# Run every hour
	usr/bin/su -l "$USER" -c "/usr/bin/defaults write  /Users/$USER/Library/LaunchAgents/com.org.kerberosrenew StartInterval -integer 3600"

	# Set it to run at load
	/usr/bin/su -l "$USER" -c "/usr/bin/defaults write /Users/$USER/Library/LaunchAgents/com.org.kerberosrenew RunAtLoad -bool true"
	echo "Launch agent written"
fi

# Can I get more efficent here? Only check for that process? Possibly not right it out if already running?
if [[ $osvers =~ $REG ]]; then
	RUN=$(/usr/bin/su -l "$USER" -c "/bin/launchctl print gui/$id" | grep com.org.kerberosrenew | wc -l)
else	
	RUN=$(/usr/bin/su -l "$USER" -c "/bin/launchctl list" | grep com.org.kerberosrenew | wc -l)
fi

# Load the agent
if [ "$NEW" == 1 ]; then
	echo "Loading com.org.kerberosrenew..."
	if [[ $osvers =~ $REG ]]; then
		/usr/bin/su -l "$USER" -c "/bin/launchctl bootstrap gui/$id /Users/$USER/Library/LaunchAgents/com.org.kerberosrenew.plist"
	else	
		/usr/bin/su -l "$USER" -c "/bin/launchctl load -S Aqua /Users/$USER/Library/LaunchAgents/com.org.kerberosrenew.plist"
	fi	
fi


exit 0
