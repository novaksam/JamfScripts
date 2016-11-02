#!/bin/bash
# I encountered a handful of applications that my autopkg installers couldn't overwrite for whatever reason
# so I wrote this to identify them and delete them, but only if they aren't running

RemoveApplications() {
	cd /Applications
	SOFTWARE="$1"
	# Test to see if any localized versions exist
	if [ -d "$SOFTWARE".localized ]; then
		# We
		# Get the newest iMovie folder
		# ./iMovie-3.localized:
		LATEST=$(ls -1t ./"$SOFTWARE"*.localized | head -n1)
		# ./iMovie-3.localized
		LATEST=${LATEST%:}
	
		# don't want to grep grep ;)
		if [ "$SOFTWARE" == "Garageband" ]; then
			SOFTWARE="GarageBand"
		fi
		
		RUNNING=$(ps aux | grep -v grep | grep "$SOFTWARE" | wc -l )
		
		if [ $RUNNING -eq 0 ] && [ "$SOFTWARE" == "GarageBand" ]; then
			SOFTWARE="Garageband"
			RUNNING=$(ps aux | grep -v grep | grep "$SOFTWARE" | wc -l )
		fi
		
		if [ $RUNNING -ge 2 ]; then
			echo "$SOFTWARE RUNNING"
		elif [ $RUNNING -eq 0 ] && [ "$SOFTWARE" == "GarageBand" ]; then
			if [ -d GarageBand.app ]; then
				rm -fr GarageBand.app
				
				cd "$LATEST"
				echo "$PWD"
				mv *.app ../
				cd ../
				#echo "Removing $1-*.localized"
				rm -fr "$1"-*.localized
				#echo "Removing $1.localized"
				rm -fr "$1".localized
			fi
		else
			if [ -d "$SOFTWARE".app ]; then
				rm -fr "$SOFTWARE".app
				
				cd "$LATEST"
				echo "$PWD"
				mv *.app ../
				cd ../
				rm -fr "$SOFTWARE"-*.localized
				rm -fr "$SOFTWARE".localized
			fi
		fi
	fi
}

Main() {
	RemoveApplications "iMovie"
	RemoveApplications "Garageband"
}

Main "$@"

exit 0
