// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation
import RewrapMarkdownCore

let arguments = Array(CommandLine.arguments.dropFirst())
let usage = """
Usage: rewrap-markdown [--check] [--lines START:END]... [--width-unit=utf16] [--unwrap] [--commit] [--repair] [--indent=preserve|tabs|spaces] [WIDTH]

Read Markdown from standard input and write the transformed text to standard output.

  --check   Compare UTF-8 bytes without writing formatted output.
            Exit 0 if unchanged, 1 if different, or 2 for argument or input errors.
  --lines   Rewrap blocks touching inclusive, 1-based input lines. Repeatable.
            Incompatible with --commit.
  --width-unit=utf16  Measure wrap width in UTF-16 code units.
  --unwrap  Join paragraphs and list items onto one line (equivalent to width 0).
  --commit  Preserve the subject, comments, and trailers of a Git commit message.
  --repair  Fix spacing around inline code enclosed in parentheses or braces.
  --indent  Set the list indentation style (default: preserve).
  --version Print the version.
"""

if arguments.contains("--version") || arguments.contains("-v") {
    print(RewrapMarkdown.versionString)
    exit(0)
}

if arguments.contains("--help") || arguments.contains("-h") {
    print(usage)
    exit(0)
}

let unwrap = arguments.contains("--unwrap")
let commitMessage = arguments.contains("--commit")
let check = arguments.contains("--check")
let repair = arguments.contains("--repair")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(2)
}

var indent = RewrapMarkdown.IndentStyle.preserve
var utf16Width = false
var widthArguments: [String] = []
var ranges: [RewrapMarkdown.LineRange] = []
var argumentIterator = arguments.makeIterator()
let strict = check || arguments.contains("--lines")
while let argument = argumentIterator.next() {
    if argument == "--lines" {
        guard let value = argumentIterator.next(),
              let range = RewrapMarkdown.LineRange(value) else {
            fail("Expected --lines START:END with positive, ascending line numbers.")
        }
        ranges.append(range)
    } else if argument.hasPrefix("--lines=") {
        fail("Expected --lines START:END.")
    } else if argument == "--indent" || argument.hasPrefix("--indent=") {
        guard argument.hasPrefix("--indent="),
              let style = RewrapMarkdown.IndentStyle(rawValue: String(argument.dropFirst("--indent=".count))) else {
            fail("Expected --indent=preserve, --indent=tabs, or --indent=spaces.")
        }
        indent = style
    } else if argument == "--width-unit" || argument.hasPrefix("--width-unit=") {
        guard argument == "--width-unit=utf16" else { fail("Expected --width-unit=utf16.") }
        utf16Width = true
    } else if let value = Int(argument) {
        widthArguments.append(String(value))
    } else if strict && !["--check", "--unwrap", "--commit", "--repair"].contains(argument) {
        fail("Unexpected argument: \(argument)")
    }
}
if strict && widthArguments.count > 1 {
    fail("Expected at most one width argument.")
}
if commitMessage && !ranges.isEmpty {
    fail("--lines cannot be used with --commit.")
}
let width = RewrapMarkdown.width(
    arguments: widthArguments,
    environment: ProcessInfo.processInfo.environment,
    fallback: commitMessage
        ? RewrapMarkdown.defaultCommitMessageWidth
        : RewrapMarkdown.defaultWidth
)

let input: Data
if strict {
    do {
        input = try FileHandle.standardInput.readToEnd() ?? Data()
    } catch {
        fail("Could not read standard input: \(error.localizedDescription)")
    }
} else {
    input = FileHandle.standardInput.readDataToEndOfFile()
}
let decodedInput = String(data: input, encoding: .utf8)
if strict && decodedInput == nil {
    fail("Standard input is not valid UTF-8.")
}
let text = decodedInput ?? ""
let output: String
if !ranges.isEmpty {
    do {
        output = try RewrapMarkdown.rewrap(text, lines: ranges, width: unwrap ? 0 : width, indent: indent, repair: repair, utf16Width: utf16Width)
    } catch {
        fail(error.localizedDescription)
    }
} else if commitMessage {
    output = RewrapMarkdown.rewrapCommitMessage(text, width: unwrap ? 0 : width, indent: indent, repair: repair, utf16Width: utf16Width)
} else {
    output = RewrapMarkdown.rewrap(text, width: unwrap ? 0 : width, indent: indent, repair: repair, utf16Width: utf16Width)
}
let outputBytes = Data(output.utf8)
if check {
    exit(outputBytes == input ? 0 : 1)
}
FileHandle.standardOutput.write(outputBytes)
