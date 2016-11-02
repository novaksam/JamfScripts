#!/bin/bash
#
# Replace existing dock icons with the ones to the new office applications
#

if [ ! -f /usr/local/bin/dockutil ]; then
	exit 1
fi

UpdateDock() {
	# Only update items that already exist
	/usr/local/bin/dockutil --list "/System/Library/User Template/Non_localized" | grep "$2"
	if [ $? -eq 0 ]; then
		for USER_TEMPLATE in "/System/Library/User Template"/*
		do
			/usr/local/bin/dockutil --add "$1" --replacing "$2" --no-restart "$USER_TEMPLATE" > /dev/null
		done
	
		/usr/local/bin/dockutil --add "$1" --replacing "$2" --allhomes --no-restart
		if [ -d /localtemp/ ]; then
			 /usr/local/bin/dockutil --add "$1" --replacing "$2" --homeloc /localtemp/ --allhomes --no-restart
		fi
	fi
}

Main() {

UpdateDock "/Applications/Microsoft Excel.app" "Microsoft Excel"
UpdateDock "/Applications/Microsoft Outlook.app" "Microsoft Outlook"
UpdateDock "/Applications/Microsoft PowerPoint.app" "Microsoft PowerPoint"
UpdateDock "/Applications/Microsoft Word.app" "Microsoft Word"
}

Main "$@"

exit 0
