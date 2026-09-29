#!/bin/sh

set -eu

package=${1:?usage: verify-installer.sh PACKAGE}
expected_archs=${EXPECTED_ARCHS:-$(uname -m)}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/rewrap-installer-verify.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

choices="$work_dir/choices.plist"
expanded="$work_dir/expanded"

installer -showChoicesXML -pkg "$package" -target / > "$choices"

choice_value() {
	choice_id=$1
	key=$2
	index=0
	while /usr/libexec/PlistBuddy -c "Print :0:childItems:$index:choiceIdentifier" "$choices" >/dev/null 2>&1; do
		if [ "$(/usr/libexec/PlistBuddy -c "Print :0:childItems:$index:choiceIdentifier" "$choices")" = "$choice_id" ]; then
			/usr/libexec/PlistBuddy -c "Print :0:childItems:$index:$key" "$choices"
			return
		fi
		index=$((index + 1))
	done
	echo "Missing installer choice: $choice_id" >&2
	exit 1
}

[ "$(choice_value core choiceIsSelected)" = 1 ]
[ "$(choice_value core choiceIsVisible)" = false ]
[ "$(choice_value hard-wrap choiceIsSelected)" = 1 ]

expected_text_filter=0
[ -e "/Library/Application Support/Rewrap Markdown/Components/Text Filter/Rewrap Markdown.bbpackage-template" ] && expected_text_filter=1
[ "$(choice_value text-filter choiceIsSelected)" = "$expected_text_filter" ]

expected_command_line=0
[ -e "/Library/Application Support/Rewrap Markdown/Components/Command Line/installed" ] && expected_command_line=1
[ "$(choice_value command-line choiceIsSelected)" = "$expected_command_line" ]

pkgutil --expand-full "$package" "$expanded"
binary="$expanded/core.pkg/Payload/Library/Application Support/Rewrap Markdown/rewrap-markdown"
uninstaller="$expanded/core.pkg/Payload/Library/Application Support/Rewrap Markdown/uninstall-rewrap-markdown"
license="$expanded/core.pkg/Payload/Library/Application Support/Rewrap Markdown/LICENSE"
notice="$expanded/core.pkg/Payload/Library/Application Support/Rewrap Markdown/NOTICE"
installer_license="$expanded/Resources/LICENSE.txt"

[ -x "$binary" ]
[ -x "$uninstaller" ]
[ -f "$license" ]
[ -f "$notice" ]
[ -f "$installer_license" ]
grep -q '"License" shall mean the terms and conditions for use, reproduction, and distribution as defined by Sections 1 through 9 of this document.' "$installer_license"
lipo "$binary" -verify_arch $expected_archs
"$binary" --version
printf '%s\n' 'A long Markdown paragraph that verifies the packaged executable can wrap its input.' | "$binary" 40 >/dev/null

find "$expanded" -type f \( -name postinstall -o -name '*.sh' -o -name uninstall-rewrap-markdown \) -exec sh -n {} \;

echo "Verified installer choices, payload, scripts, and architectures: $expected_archs"
