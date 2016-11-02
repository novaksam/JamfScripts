#!/bin/bash
#
# Set a reboot flag, to signal the calling process to reboot at the end..
#
# This is designed to go into the third party update workflow, where
# a master policy calls sub-policies. This script should be ran in one of the sub policies,
# and it will be checked by 099_Policy_CheckReboot.sh at the end of the master.
#
# If the reboot flag is not set, then the check script will do a recon instead.

SetFlag() {
	defaults write /Library/Preferences/com.org.systeminfo REBOOT "TRUE"
}

Main() {
	SetFlag
}

Main "$@"
exit 0
