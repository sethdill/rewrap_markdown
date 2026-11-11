// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation
import RewrapMarkdownCore

let arguments = Array(CommandLine.arguments.dropFirst())
let usage = """
Usage: rewrap-markdown [--check] [--unwrap] [--commit] [--repair] [--indent=preserve|tabs|spaces] [WIDTH]

Read Markdown from standard input and write the transformed text to standard output.

  --check   Compare UTF-8 bytes without writing formatted output.
            Exit 0 if unchanged, 1 if different, or 2 for argument or input errors.
  --unwrap  Join paragraphs and list items onto one line (equivalent to width 0).
  --commit  Preserve the subject, comments, and trailers of a Git commit message.
  --repair  Fix spacing around enclosed code and keep paired delimiters with adjacent words.
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
var widthArguments: [String] = []
for argument in arguments {
    if argument == "--indent" || argument.hasPrefix("--indent=") {
        guard argument.hasPrefix("--indent="),
              let style = RewrapMarkdown.IndentStyle(rawValue: String(argument.dropFirst("--indent=".count))) else {
            fail("Expected --indent=preserve, --indent=tabs, or --indent=spaces.")
        }
        indent = style
    } else if let value = Int(argument) {
        widthArguments.append(String(value))
    } else if check && !["--check", "--unwrap", "--commit", "--repair"].contains(argument) {
        fail("Unexpected argument: \(argument)")
    }
}
if check && widthArguments.count > 1 {
    fail("Expected at most one width argument.")
}
let width = RewrapMarkdown.width(
    arguments: widthArguments,
    environment: ProcessInfo.processInfo.environment,
    fallback: commitMessage
        ? RewrapMarkdown.defaultCommitMessageWidth
        : RewrapMarkdown.defaultWidth
)

let input: Data
if check {
    do {
        input = try FileHandle.standardInput.readToEnd() ?? Data()
    } catch {
        fail("Could not read standard input: \(error.localizedDescription)")
    }
} else {
    input = FileHandle.standardInput.readDataToEndOfFile()
}
let decodedInput = String(data: input, encoding: .utf8)
if check && decodedInput == nil {
    fail("Standard input is not valid UTF-8.")
}
let text = decodedInput ?? ""
let output: String
if commitMessage {
    output = RewrapMarkdown.rewrapCommitMessage(text, width: unwrap ? 0 : width, indent: indent, repair: repair)
} else {
    output = RewrapMarkdown.rewrap(text, width: unwrap ? 0 : width, indent: indent, repair: repair)
}
let outputBytes = Data(output.utf8)
if check {
    exit(outputBytes == input ? 0 : 1)
}
FileHandle.standardOutput.write(outputBytes)
