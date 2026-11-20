// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation
import RewrapMarkdownCore

let arguments = Array(CommandLine.arguments.dropFirst())
let usage = """
Usage: rewrap-markdown [--check] [--lines START:END]... [--width-unit=utf16] [--unwrap] [--commit] [--repair] [--indent=preserve|tabs|spaces] [WIDTH] [FILE]

Read Markdown from FILE or standard input. Write to standard output by default.

  --output PATH  Atomically write the result to PATH.
  --in-place     Atomically update FILE and preserve its permissions.
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

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(2)
}

var indent = RewrapMarkdown.IndentStyle.preserve
var utf16Width = false
var widthArguments: [String] = []
var ranges: [RewrapMarkdown.LineRange] = []
var argumentIterator = arguments.makeIterator()
var flags: Set<String> = []
var inputPath: String?
var outputPath: String?
var positionalOnly = false
while let argument = argumentIterator.next() {
    if positionalOnly {
        guard inputPath == nil, !argument.isEmpty else { fail("Expected one input file.") }
        inputPath = argument
    } else if argument == "--" {
        positionalOnly = true
    } else if ["--version", "-v", "--help", "-h"].contains(argument) {
        print(["--version", "-v"].contains(argument) ? RewrapMarkdown.versionString : usage)
        exit(0)
    } else if ["--check", "--unwrap", "--commit", "--repair", "--in-place"].contains(argument) {
        flags.insert(argument)
    } else if argument == "--output" {
        guard outputPath == nil, let path = argumentIterator.next(), !path.isEmpty,
              !path.hasPrefix("-") else {
            fail("Expected one --output PATH.")
        }
        outputPath = path
    } else if argument == "--lines" {
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
    } else if argument.hasPrefix("-") || argument.isEmpty {
        fail("Unexpected argument: \(argument)")
    } else {
        guard inputPath == nil else { fail("Expected at most one input file.") }
        inputPath = argument
    }
}
let unwrap = flags.contains("--unwrap")
let commitMessage = flags.contains("--commit")
let check = flags.contains("--check")
let repair = flags.contains("--repair")
let inPlace = flags.contains("--in-place")

if widthArguments.count > 1 {
    fail("Expected at most one width argument.")
}
if inPlace && (inputPath == nil || outputPath != nil) {
    fail("--in-place requires an input file and cannot be used with --output.")
}
if check && (inPlace || outputPath != nil) {
    fail("--check cannot be used with --output or --in-place.")
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

let destination = inPlace ? inputPath : outputPath
let inputLabel = inputPath.map { "'\($0)'" } ?? "standard input"
let input: Data
let destinationInfo: stat?
do {
    destinationInfo = try destination.flatMap { try fileInfo($0, followLinks: false) }
    if destinationInfo.map({ !isRegular($0) }) == true {
        fail("Output path must be a regular file or a new file.")
    }
    if let inputPath {
        guard let sourceInfo = try fileInfo(inputPath, followLinks: true), isRegular(sourceInfo) else {
            fail("Could not read \(inputLabel): expected a regular file.")
        }
        if let destinationInfo, !inPlace, sameFile(sourceInfo, destinationInfo) {
            fail("Use --in-place to update the input file.")
        }
        input = try Data(contentsOf: URL(fileURLWithPath: inputPath))
    } else {
        input = try FileHandle.standardInput.readToEnd() ?? Data()
    }
} catch {
    fail("Could not read \(inputLabel) or prepare output: \(error.localizedDescription)")
}
guard let text = String(data: input, encoding: .utf8) else {
    fail("\(inputPath == nil ? "Standard input" : inputLabel) is not valid UTF-8.")
}
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
do {
    if let destination {
        if !inPlace || outputBytes != input {
            try replaceFile(destination, with: outputBytes, original: destinationInfo)
        }
    } else {
        try FileHandle.standardOutput.write(contentsOf: outputBytes)
    }
} catch {
    fail("Could not write \(destination ?? "standard output"): \(error.localizedDescription)")
}
