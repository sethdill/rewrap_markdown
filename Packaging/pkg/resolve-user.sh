#!/bin/sh

# Installer scripts run as root. Resolve the interactive user and BBEdit's
# conventional support location. Overrides are for local testing only.

install_user=${REWRAP_MARKDOWN_INSTALL_USER:-$(stat -f '%Su' /dev/console)}
if [ -z "$install_user" ] || [ "$install_user" = "root" ] || [ "$install_user" = "loginwindow" ]; then
	echo "rewrap-markdown: could not determine the logged-in user" >&2
	exit 1
fi

install_home=${REWRAP_MARKDOWN_INSTALL_HOME:-$(dscl . -read "/Users/$install_user" NFSHomeDirectory | sed 's/^NFSHomeDirectory: //')}
install_group=$(id -gn "$install_user")

if [ -n "${REWRAP_MARKDOWN_BBEDIT_SUPPORT_DIR:-}" ]; then
	bbedit_support_dir=$REWRAP_MARKDOWN_BBEDIT_SUPPORT_DIR
elif [ -d "$install_home/Library/Containers/com.barebones.bbedit" ]; then
	bbedit_support_dir="$install_home/Library/Containers/com.barebones.bbedit/Data/Library/Application Support/BBEdit"
else
	bbedit_support_dir="$install_home/Library/Application Support/BBEdit"
fi
