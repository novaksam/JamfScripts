#!/bin/bash
#
# 090_Policy_hideAdobeUninstallers.sh.sh - Hides the Adobe uninstallers, since any uninstallations should be done with the uninstallers in Casper.
# Sam Novak - 2015

cd /Applications

chflags hidden Adobe*/Uninstall*

cd Utilities

chflags hidden Adobe\ Installers


exit 0
