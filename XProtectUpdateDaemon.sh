#!/bin/bash
# This script aims to write a daemon that will automatically install XProtect and Gatekeeper updates
# on Macs that have had automatic update checking disabled (because that's the only way to get rid of that stupid notification)
#
# I've written it to be ran as part of a policy in jamf Pro, but there's nothing stopping you from using it with other management frameworks.
#
# Helpful sites:
# https://macops.ca/os-x-admins-your-clients-are-not-getting-background-security-updates
# https://derflounder.wordpress.com/2016/03/28/checking-xprotect-and-gatekeeper-update-status-on-macs/
#
SCRIPT="/Library/Scripts/XProtectUpdate.sh"
LABEL="com.org.XProtectUpdater"
DAEMON=/Library/LaunchDaemons/com.org.XProtectUpdater.plist
# Gets the OS version
OSVERS=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $2}')
# Regex for 10.9+
OSREGEX="^[19]?[0-9]$"
RUNNING=0
NEW=0

WriteScript() {
    /bin/echo "#!/bin/bash" > "$SCRIPT"
    /bin/echo '/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true' >> "$SCRIPT"
    /bin/echo '/usr/sbin/softwareupdate --background-critical' >> "$SCRIPT"
    /bin/echo '/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false' >> "$SCRIPT"
    /bin/chmod +x "$SCRIPT"
}

WriteDaemon() {
    /usr/bin/defaults write $DAEMON Label -string $LABEL
    /usr/bin/defaults write $DAEMON ProcessType Background
    /usr/bin/defaults write $DAEMON RunAtLoad -bool true
    # Run every 12 hours
    /usr/bin/defaults write $DAEMON StartInterval -int 43200
    /usr/bin/defaults write $DAEMON ProgramArguments -array
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments: string /bin/sh" $DAEMON
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments: string $SCRIPT" $DAEMON
    /bin/chmod 644 $DAEMON
}

CheckDaemon() {
    if [ -f $DAEMON ]; then
        RUNNING=$(/bin/launchctl list | /usr/bin/grep $LABEL | /usr/bin/wc -l)
    else
        NEW=1
    fi
}

LoadDaemon() {
    /bin/launchctl load -w $DAEMON
    RUNNING=1
}

CheckOSRequirements() {
    if [[ ! $OSVERS =~ $OSREGEX ]]; then
        /bin/echo "OS Requirements not met"
        exit 0
    fi
}

Main() {
    CheckOSRequirements
    CheckDaemon
    # 1 for new daemon, 0 for old
    if [ $NEW -eq 1 ]; then
        WriteDaemon
        WriteScript
    fi
    # 1 for already running, 0 for not running
    if [ $RUNNING -eq 0 ]; then
        LoadDaemon
    fi  
}

Main "$@"
