-- Copyright 2026 Seth Dillingham
-- SPDX-License-Identifier: Apache-2.0
--
-- BBEdit menu action script for Text > Hard Wrap...
--
-- Install as a compiled script in BBEdit's Menu Scripts folder, named
-- Text•Hard Wrap….scpt, with Text•Hard Wrap.scpt as a symlink to it.
--
-- The bullet is Option-8. The first filename ends with a single ellipsis.

property wrapWidth : 70
property maxWrapWidth : 1000
property rewrapMarkdownPath : ""

use framework "AppKit"
use framework "Foundation"
use scripting additions

on MenuSelect(menuName, itemName)
	if my isShiftKeyPressed() then return false
	if menuName is not "Text" then return false
	if itemName is not "Hard Wrap…" and itemName is not "Hard Wrap" then return false

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
			if selectedLength is 0 then
				set shouldReplaceDocument to true
				set sourceText to contents as text
			else
				set shouldReplaceDocument to false
				set sourceText to selection as text
			end if
		end tell
	end tell

	if itemName is "Hard Wrap" then
		set requestedWidth to my wrapWidth
	else
		try
			set requestedWidth to my askForWrapWidth()
			set my wrapWidth to requestedWidth
		on error number -128
			return true
		end try
	end if

	try
		set wrappedText to my rewrapMarkdown(sourceText, requestedWidth)
	on error errorMessage number errorNumber
		display alert "Could not rewrap Markdown." message errorMessage as critical
		return true
	end try

	tell application "BBEdit.app"
		tell front window
			if shouldReplaceDocument then
				set contents to wrappedText
			else
				set selection to wrappedText
			end if
		end tell
	end tell

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

on askForWrapWidth()
	repeat
		set dialogResult to display dialog "Rewrap Markdown width:" default answer (my wrapWidth as text) buttons {"Cancel", "Rewrap"} default button "Rewrap" cancel button "Cancel"
		set widthText to text returned of dialogResult

		try
			set candidateWidth to widthText as integer
			if candidateWidth is less than 1 or candidateWidth is greater than maxWrapWidth then error
			return candidateWidth
		on error
			display alert "Width must be a whole number from 1 to " & (maxWrapWidth as text) & "."
		end try
	end repeat
end askForWrapWidth

on rewrapMarkdown(sourceText, wrapWidth)
	set executablePath to my findRewrapMarkdownExecutable()
	set tempDirectory to do shell script "mktemp -d"
	set inputPath to tempDirectory & "/input.md"
	set outputPath to tempDirectory & "/output.md"

	try
		my writeUTF8Text(sourceText, inputPath)
		do shell script quoted form of executablePath & space & (wrapWidth as text) & " < " & quoted form of inputPath & " > " & quoted form of outputPath
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
	set candidatePaths to {homePath & ".local/bin/rewrap-markdown", homePath & "bin/rewrap-markdown", "/opt/homebrew/bin/rewrap-markdown", "/usr/local/bin/rewrap-markdown"}

	repeat with candidatePath in candidatePaths
		if my isExecutable(candidatePath as text) then return candidatePath as text
	end repeat

	error "Could not find rewrap-markdown. Install it at ~/.local/bin/rewrap-markdown or edit rewrapMarkdownPath in this script."
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
