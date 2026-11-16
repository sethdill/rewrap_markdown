-- Copyright 2026 Seth Dillingham
-- SPDX-License-Identifier: Apache-2.0
--
-- BBEdit menu action script for Text > Hard Wrap...
--
-- Install as a compiled script in BBEdit's Menu Scripts folder, named
-- Text•Hard Wrap….scpt, with Text•Hard Wrap.scpt as a symlink to it.
--
-- The bullet is Option-8. The first filename ends with a single ellipsis.

property defaultWrapWidth : 70
property minWrapWidth : 0
property maxWrapWidth : 1000
property rewrapMarkdownPath : ""
-- Set an absolute path in a test copy to try Experiments/BBEditHardWrapDialog.
property wrapDialogPath : ""
property preferencesSuite : "com.sethdillingham.rewrap-markdown"
property wrapWidthKey : "wrapWidth"
property lastPositiveWidthKey : "lastPositiveWrapWidth"
property repairKey : "repair"
property indentationKey : "indentation"

use framework "AppKit"
use framework "Foundation"
use scripting additions

on MenuSelect(menuName, itemName)
	if my isShiftKeyPressed() then return false
	if menuName is not "Text" then return false
	if itemName is not "Hard Wrap…" and itemName is not "Hard Wrap" then return false
	set usesExperimentalDialog to itemName is "Hard Wrap…" and my wrapDialogPath is not ""

	tell application "BBEdit.app"
		if not (exists front window) then return false

		tell front window
			set documentName to ""
			set languageName to ""

			try
				set documentName to name of its document as text
			end try

			try
				set languageName to «class SoLn» of its document as text
			end try

			if not my isMarkdownDocument(documentName, languageName) then return false

			set selectedLength to length of selection
			if usesExperimentalDialog then
				set originalWindowID to its ID
				set originalDocumentID to ID of its document
				if selectedLength is not 0 then set originalSelectionOffset to characterOffset of selection
			end if

			if selectedLength is 0 then
				set shouldReplaceDocument to true
				set sourceText to contents as text
			else
				set shouldReplaceDocument to false
				set sourceText to selection as text
			end if
		end tell
	end tell

	try
		set executablePath to my findRewrapMarkdownExecutable()
		set userDefaults to current application's NSUserDefaults's alloc()'s initWithSuiteName:(my preferencesSuite)
		set wrapOptions to my rememberedWrapOptions(userDefaults)
		if itemName is "Hard Wrap…" then set wrapOptions to my askForWrapOptions(wrapOptions, executablePath)
		set wrappedText to my rewrapMarkdown(sourceText, wrapOptions, executablePath)
	on error errorMessage number errorNumber
		if errorNumber is -128 then return true
		display alert "Could not rewrap Markdown." message errorMessage as critical
		return true
	end try

	tell application "BBEdit.app"
		if usesExperimentalDialog and not (exists front window) then return true
		tell front window
			-- The helper is modal in its own process. Discard stale results if BBEdit's target changed.
			if usesExperimentalDialog then
				if its ID is not originalWindowID then return true
				if ID of its document is not originalDocumentID then return true
				if length of selection is not selectedLength then return true
				considering case, diacriticals, punctuation, hyphens and white space
					if shouldReplaceDocument then
						if (contents as text) is not sourceText then return true
					else
						if characterOffset of selection is not originalSelectionOffset then return true
						if (selection as text) is not sourceText then return true
					end if
				end considering
			end if

			if shouldReplaceDocument then
				set contents to wrappedText
			else
				set selection to wrappedText
			end if
		end tell
	end tell

	if itemName is "Hard Wrap…" then my saveWrapOptions(wrapOptions, userDefaults)
	return true
end MenuSelect

on isMarkdownDocument(documentName, languageName)
	ignoring case
		if languageName contains "markdown" then return true
		if documentName ends with ".md" then return true
		if documentName ends with ".markdown" then return true
		if documentName ends with ".mdown" then return true
		if documentName ends with ".mkd" then return true
		if documentName ends with ".mkdn" then return true
	end ignoring

	return false
end isMarkdownDocument

on isShiftKeyPressed()
	set shiftMask to current application's NSEventModifierFlagShift as integer
	set rawFlags to current application's NSEvent's |modifierFlags|() as integer

	return ((rawFlags div shiftMask) mod 2 is not 0)
end isShiftKeyPressed

on rememberedWrapOptions(userDefaults)
	set savedWidth to my defaultWrapWidth
	if (userDefaults's objectForKey:(my wrapWidthKey)) is not missing value then
		set savedWidth to (userDefaults's integerForKey:(my wrapWidthKey)) as integer
		if savedWidth is less than minWrapWidth or savedWidth is greater than maxWrapWidth then set savedWidth to my defaultWrapWidth
	end if
	set wantsUnwrap to savedWidth is 0
	if wantsUnwrap then
		set savedWidth to (userDefaults's integerForKey:(my lastPositiveWidthKey)) as integer
		if savedWidth is less than 1 or savedWidth is greater than maxWrapWidth then set savedWidth to my defaultWrapWidth
	end if
	set savedIndent to userDefaults's stringForKey:(my indentationKey)
	if savedIndent is not missing value then set savedIndent to savedIndent as text
	if savedIndent is not in {"preserve", "spaces", "tabs"} then set savedIndent to "preserve"
	set wantsRepair to (userDefaults's boolForKey:(my repairKey)) as boolean
	return {settingsWidth:savedWidth, settingsUnwrap:wantsUnwrap, settingsRepair:wantsRepair, settingsIndent:savedIndent}
end rememberedWrapOptions

on saveWrapOptions(wrapOptions, userDefaults)
	userDefaults's setInteger:(my effectiveWidth(wrapOptions)) forKey:(my wrapWidthKey)
	userDefaults's setInteger:(settingsWidth of wrapOptions) forKey:(my lastPositiveWidthKey)
	userDefaults's setBool:(settingsRepair of wrapOptions) forKey:(my repairKey)
	userDefaults's setObject:(settingsIndent of wrapOptions) forKey:(my indentationKey)
	userDefaults's synchronize()
end saveWrapOptions

on effectiveWidth(wrapOptions)
	if settingsUnwrap of wrapOptions then return 0
	return settingsWidth of wrapOptions
end effectiveWidth

on askForWrapOptions(wrapOptions, executablePath)
	if my wrapDialogPath is not "" then
		try
			set formatterVersion to do shell script (quoted form of executablePath & " --version")
			set dialogArguments to (settingsWidth of wrapOptions as text) & " " & (minWrapWidth as text) & " " & (maxWrapWidth as text)
			set unwrapFlag to "0"
			set repairFlag to "0"
			if settingsUnwrap of wrapOptions then set unwrapFlag to "1"
			if settingsRepair of wrapOptions then set repairFlag to "1"
			set dialogArguments to dialogArguments & " " & unwrapFlag & " " & repairFlag
			set replyText to do shell script (quoted form of (my wrapDialogPath) & " " & dialogArguments & " " & quoted form of (settingsIndent of wrapOptions) & " " & quoted form of formatterVersion)
			if replyText is "cancel" then error number -128
			return my parseWrapOptions(replyText)
		on error errorMessage number errorNumber
			if errorNumber is -128 then error number -128
			display alert "Could not use the experimental Hard Wrap dialog." message errorMessage
		end try
	end if

	set chosenWidth to my askForWrapWidth(my effectiveWidth(wrapOptions))
	set settingsUnwrap of wrapOptions to chosenWidth is 0
	if chosenWidth is greater than 0 then set settingsWidth of wrapOptions to chosenWidth
	return wrapOptions
end askForWrapOptions

on parseWrapOptions(replyText)
	set replyString to current application's NSString's stringWithString:replyText
	set fields to (replyString's componentsSeparatedByString:tab) as list
	if (count of fields) is not 4 then error "The Hard Wrap dialog returned invalid settings."
	set {widthText, unwrapFlag, repairFlag, indentStyle} to fields
	set candidateWidth to widthText as integer
	if candidateWidth is less than 1 or candidateWidth is greater than maxWrapWidth or (candidateWidth as text) is not widthText then error "The dialog returned an invalid width."
	if unwrapFlag is not in {"0", "1"} or repairFlag is not in {"0", "1"} or indentStyle is not in {"preserve", "spaces", "tabs"} then error "The Hard Wrap dialog returned invalid settings."
	return {settingsWidth:candidateWidth, settingsUnwrap:(unwrapFlag is "1"), settingsRepair:(repairFlag is "1"), settingsIndent:indentStyle}
end parseWrapOptions

on askForWrapWidth(currentWidth)
	repeat
		set dialogResult to display dialog "Rewrap Markdown width (0 unwraps):" default answer (currentWidth as text) buttons {"Cancel", "Rewrap"} default button "Rewrap" cancel button "Cancel"
		set widthText to text returned of dialogResult

		try
			set candidateWidth to widthText as integer
			if candidateWidth is less than minWrapWidth or candidateWidth is greater than maxWrapWidth then error
			return candidateWidth
		on error
			display alert "Width must be a whole number from " & (minWrapWidth as text) & " to " & (maxWrapWidth as text) & ". Use 0 to unwrap."
		end try
	end repeat
end askForWrapWidth

on rewrapMarkdown(sourceText, wrapOptions, executablePath)
	set tempDirectory to do shell script "mktemp -d"
	set inputPath to tempDirectory & "/input.md"
	set outputPath to tempDirectory & "/output.md"

	try
		my writeUTF8Text(sourceText, inputPath)
		set formatterArguments to " --width-unit=utf16 --indent=" & quoted form of (settingsIndent of wrapOptions)
		if settingsRepair of wrapOptions then set formatterArguments to formatterArguments & " --repair"
		set wrapWidth to my effectiveWidth(wrapOptions)
		do shell script quoted form of executablePath & formatterArguments & " " & (wrapWidth as text) & " < " & quoted form of inputPath & " > " & quoted form of outputPath
		set wrappedText to my readUTF8Text(outputPath)
		do shell script "rm -rf " & quoted form of tempDirectory
		return wrappedText
	on error errorMessage number errorNumber
		try
			do shell script "rm -rf " & quoted form of tempDirectory
		end try
		error errorMessage number errorNumber
	end try
end rewrapMarkdown

on findRewrapMarkdownExecutable()
	if rewrapMarkdownPath is not "" then
		if my isExecutable(rewrapMarkdownPath) then return rewrapMarkdownPath
		error "The configured rewrapMarkdownPath is not executable: " & rewrapMarkdownPath
	end if

	set homePath to POSIX path of (path to home folder)
	set candidatePaths to {"/Library/Application Support/Rewrap Markdown/rewrap-markdown"}
	set candidatePaths to candidatePaths & {homePath & ".local/bin/rewrap-markdown", homePath & "bin/rewrap-markdown", "/opt/homebrew/bin/rewrap-markdown", "/usr/local/bin/rewrap-markdown"}

	repeat with candidatePath in candidatePaths
		if my isExecutable(candidatePath as text) then return candidatePath as text
	end repeat

	error "Could not find rewrap-markdown. Install Rewrap Markdown, install the command at ~/.local/bin/rewrap-markdown, or edit rewrapMarkdownPath in this script."
end findRewrapMarkdownExecutable

on isExecutable(posixPath)
	return (do shell script "if [ -x " & quoted form of posixPath & " ]; then echo yes; else echo no; fi") is "yes"
end isExecutable

on writeUTF8Text(theText, posixPath)
	set outputFile to POSIX file posixPath
	set fileReference to open for access outputFile with write permission
	try
		set eof fileReference to 0
		write theText to fileReference as «class utf8»
		close access fileReference
	on error errorMessage number errorNumber
		try
			close access fileReference
		end try
		error errorMessage number errorNumber
	end try
end writeUTF8Text

on readUTF8Text(posixPath)
	set inputFile to POSIX file posixPath
	return read inputFile as «class utf8»
end readUTF8Text
