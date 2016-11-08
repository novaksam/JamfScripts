#!/bin/bash
# Variables used by Casper
USERNAME="JSSapi" #Username of user with API Computer read GET and Computer Group PUT access
PASSWORD="" #Password of user with API Computer read GET and Computer Group PUT access
JSS_URL='https://jss.com:8443' # JSS URL of the server you want to run API calls against
Headers="Accept: application/xml"


# Variables used by this script
JSS_ID_PATH="/tmp/comp_id" # Text file with one JSS ID per Line
JSS_API_INFO_DIR="/tmp/jss_api_tmp" # Directory where working files for each JSS ID will be stored
JSS_XML_INPUT="/tmp/JSS_XML_INPUT.xml" # XML Output to be uploaed to the JSS Computer Groups API
JSS_ORIG_XML="/tmp/JSS_ORIG_XML.xml" # Original group XML
STATIC_GROUP_ID="" # Static Group ID: This can be found in the URL when you click edit on a Static Group
STATIC_GROUP_NAME="Machine Auth Repair Group" # This is the name of the Static Group you want to overwrite
PROFILE="Machine Wireless Authentication"
PROFILE_INSTALLED=0
WIFI_INTERFACE=""
WIFI_SSID=""
WIFI_CORP_CONNECTED=0
WIFI_NON_CORP_CONNECTED=0
ETHERNET_CONNECTED=0
NETWORK_OK=0
mkdir -p "$JSS_API_INFO_DIR"
IFS_OLD=$IFS
IFS_TEMP=$'\n'

IFS=$IFS_TEMP

## Functions
#################################################################################################### 
# Include DecryptString() with your script to decrypt the password sent by the JSS
# The 'Salt' and 'Passphrase' values would be present in the script
function DecryptString() {
    # Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
    PASSWORD=$(echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}")
}

function CheckWiFi() {
	TEST=$(networksetup -getinfo "Wi-Fi" | grep -v IPv6 | grep IP\ address | cut -d' ' -f3 | grep 172\.16)
	if [ $? -eq 0 ]; then
		# Mac connected to corpnet via WiFi, which makes a wifi profile removal + update impossible, unless Ethernet is also connected
		WIFI_CORP_CONNECTED=1 
	else
		TEST=$(networksetup -getinfo "Wi-Fi" | grep -v IPv6 | grep IP\ address | cut -d' ' -f3)
		if [ $? -eq 0 ]; then
			WIFI_NON_CORP_CONNECTED=1
		fi
	fi
}

function CheckEthernet() {
	for E in $(networksetup -listallnetworkservices | grep -i Ethernet); do
		TEST=$(networksetup -getinfo "$E" | grep -v IPv6 | grep IP\ address | cut -d' ' -f3 | grep 172\.16)
		if [ $? -eq 0 ]; then
			# Mac connected to corpnet via Ethernet, which is what we need!
			ETHERNET_CONNECTED=1
		fi 
	done
		
}

function CheckNetwork() {
	CheckWiFi
	CheckEthernet
	
	if [ $WIFI_CORP_CONNECTED -eq 1 ]; then
		NETWORK_OK=0
	fi
	# Non-corp wifi is bad, so no AD rebind
	if [ $WIFI_NON_CORP_CONNECTED -eq 1 ]; then
		NETWORK_OK=1
	fi
	# Since corpnet ethernet is good, then we can rebind AD
	if [ $ETHERNET_CONNECTED -eq 1 ]; then
		NETWORK_OK=1
		#jamf policy -event rejoin_ad
	fi
}

function GetWifiInterface() {
	WIFI_INTERFACE=$(networksetup -listallhardwareports | grep Wi\-Fi -A1 | grep Device | cut -d' ' -f2)
}

function RemovePrefferedNetwork() {
	SSID="$1"
	networksetup -removepreferredwirelessnetwork "$WIFI_INTERFACE" "$SSID"
}
	
function DisplayJamfHelper() {
	"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType utility -title "Repair Wireless" -description "Please connect your MacBook to the corporate network with an Ethernet cable before running the WiFi Repair policy, or run if from off campus." -button1 "Ok" -defaultButton 1 
	exit 0
}

function GetProfile() {
	TEST=$(profiles -Cv | grep "$PROFILE" )
	if [ $? -eq 0 ]; then
		PROFILE_INSTALLED=1
	else
		PROFILE_INSTALLED=0
	fi
}

function CheckForProfileDeletion() {
	WAITING=1
	launchctl unload /Library/LaunchDaemons/com.jamfsoftware.task.1.plist
	jamf policy
	launchctl load /Library/LaunchDaemons/com.jamfsoftware.task.1.plist
	while [ $WAITING -eq 1 ]; do
		sleep 1
		# Check if the profile exists via grep. Will return 1 if profile not installed
		TEST=$(profiles -Cv | grep "$PROFILE" )
		if [ $? -eq 1 ]; then
			# Profile no longer present, we can exit loop
			WAITING=0
		fi
	done
	# Sleep just a little bit longer
}

function CheckForProfileInstallation() {
	WAITING=1
	while [ $WAITING -eq 1 ]; do
		sleep 1
		# Check if the profile exists via grep. Will return 0 if profile is installed
		TEST=$(profiles -Cv | grep "$PROFILE" )
		if [ $? -eq 0 ]; then
			# Profile present, we can exit loop
			WAITING=0
		fi
	done
}

function GetComputerID() {
	# Get the computer ID
	SERIAL=`system_profiler SPHardwareDataType | awk '/Serial/ {print $4}'`
	URL="$JSS_URL/JSSResource/computers/serialnumber/$SERIAL"
	RESPONSE=$(/usr/bin/curl -H "$Headers" -u "$USERNAME:$PASSWORD" --url $URL) > /dev/null
	GroupMembership=$(echo $RESPONSE | xpath '//computer//general/id' 2>&1 | awk -F'<id>|</id>' '{print $2}') > /dev/null
	echo "$GroupMembership" > /tmp/comp_id
}

function GetOriginalGroup() {
	curl -k -H "$Headers" -v -u "$USERNAME":"$PASSWORD" $JSS_URL/JSSResource/computergroups/id/$STATIC_GROUP_ID > "$JSS_ORIG_XML"
}

function PutOriginalGroup() {
	curl -k -v -H "$Headers"  -u "$USERNAME":"$PASSWORD" $JSS_URL/JSSResource/computergroups/id/$STATIC_GROUP_ID -T "$JSS_ORIG_XML" -X PUT
}

# This creates an xml dump from the JSS API in the $JSS_API_INFO_DIR
function CheckAPI () {
	for system in `cat $JSS_ID_PATH | awk '{print$1}'`; do
		curl -k -H "$Headers" -v -u "$USERNAME":"$PASSWORD" $JSS_URL/JSSResource/computers/id/$system/subset/General -X GET  > "$JSS_API_INFO_DIR/$system.xml"
	done
	CreateXML
}

# This creates the first part of the XML header 
function CreateXML () {
	number_of_systems=`ls $JSS_API_INFO_DIR | wc | awk '{print$1}'`
	echo '<?xml version="1.0" encoding="UTF-8" standalone="no"?><computer_group><id>' > "$JSS_XML_INPUT"
	echo "$STATIC_GROUP_ID" >> "$JSS_XML_INPUT"
	echo '</id><name>' >> "$JSS_XML_INPUT"
	echo "$STATIC_GROUP_NAME" >> "$JSS_XML_INPUT"
	echo '</name><is_smart>false</is_smart><criteria/><computers><size>' >> "$JSS_XML_INPUT" 
	echo "$number_of_systems" >> "$JSS_XML_INPUT" 
	echo '</size>' >> "$JSS_XML_INPUT" 
	ParseXML
}

# This goes through the xml dumps and writes out the jssid, mac_address and name for each system into the $JSS_XML_INPUT that will be uploaded to the jss
function ParseXML () {
	for system in `cat $JSS_ID_PATH | awk '{print$1}'`; do
		id=`Xpath "$JSS_API_INFO_DIR/$system.xml" //id`
		mac_address=`Xpath "$JSS_API_INFO_DIR/$system.xml" //mac_address`
		name=`Xpath "$JSS_API_INFO_DIR/$system.xml" //name`
		echo '<computer>' >> "$JSS_XML_INPUT"
		echo "$id" >> "$JSS_XML_INPUT"
		#echo '</id><name>' >> "$JSS_XML_INPUT"
		echo "$name" >> "$JSS_XML_INPUT"
		#echo '</name><mac_address>' >> "$JSS_XML_INPUT"
		echo "$mac_address" >> "$JSS_XML_INPUT"
		echo '<serial_number/></computer>' >> "$JSS_XML_INPUT"
	done
	FinalizeXML
}

# This writes the final closing xml to the $JSS_XML_INPUT file and removes all carriage returns so that it is all on one line
function FinalizeXML () {
	echo '</computers></computer_group>' >> "$JSS_XML_INPUT"
	perl -pi -e 'tr/[\012\015]//d' "$JSS_XML_INPUT"
	UpdateStaticGroup
}

# This uploads the $JSS_XML_INPUT file to the JSS
function UpdateStaticGroup () {
	curl -k -v -H "$Headers"  -u "$USERNAME":"$PASSWORD" $JSS_URL/JSSResource/computergroups/id/$STATIC_GROUP_ID -T "$JSS_XML_INPUT" -X PUT
	echo "$?"
	echo "Done"
}

function CleanUp() {
	rm $JSS_XML_INPUT
	rm $JSS_ID_PATH
	rm $JSS_ORIG_XML
	if [ -d $JSS_API_INFO_DIR ]; then
		cd $JSS_API_INFO_DIR
		for E in $(ls); do
			rm $E
		done
		cd /tmp
		rmdir jss_api_tmp
	fi
}
	
	
## Script
#################################################################################################### 
# Script Action 1
# https://github.com/jamfit/Encrypted-Script-Parameters
#ENCRYPTEDSTRING="$4"
SALT=""
PASSPHRASE=""
DecryptString "$ENCRYPTEDSTRING" "$SALT" "$PASSPHRASE"
GetProfile
if [ $PROFILE_INSTALLED -eq 1 ]; then
	CheckNetwork
	if [ $NETWORK_OK -eq 1 ]; then
		GetComputerID
		GetOriginalGroup
		CheckAPI
		GetWifiInterface
		CheckForProfileDeletion
		RemovePrefferedNetwork "$WIFI_SSID"
		PutOriginalGroup
		CheckForProfileInstallation
		CleanUp
	else
		DisplayJamfHelper
	fi
fi
