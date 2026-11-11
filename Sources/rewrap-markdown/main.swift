// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation
import RewrapMarkdownCore

let arguments = Array(CommandLine.arguments.dropFirst())
let usage = """
Usage: rewrap-markdown [--unwrap] [--commit] [--repair] [--indent=preserve|tabs|spaces] [WIDTH]

Read Markdown from standard input and write the transformed text to standard output.

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
var indent = RewrapMarkdown.IndentStyle.preserve
for argument in arguments where argument == "--indent" || argument.hasPrefix("--indent=") {
    guard argument.hasPrefix("--indent="),
          let style = RewrapMarkdown.IndentStyle(rawValue: String(argument.dropFirst("--indent=".count))) else {
        FileHandle.standardError.write(Data("Expected --indent=preserve, --indent=tabs, or --indent=spaces.\n".utf8))
        exit(2)
    }
    indent = style
}
let widthArguments = arguments.compactMap { Int($0).map(String.init) }
let width = RewrapMarkdown.width(
    arguments: widthArguments,
    environment: ProcessInfo.processInfo.environment,
    fallback: commitMessage
        ? RewrapMarkdown.defaultCommitMessageWidth
        : RewrapMarkdown.defaultWidth
)

let input = FileHandle.standardInput.readDataToEndOfFile()
let text = String(data: input, encoding: .utf8) ?? ""
let output: String
if commitMessage {
    output = RewrapMarkdown.rewrapCommitMessage(text, width: unwrap ? 0 : width, indent: indent, repair: arguments.contains("--repair"))
} else {
    output = RewrapMarkdown.rewrap(text, width: unwrap ? 0 : width, indent: indent, repair: arguments.contains("--repair"))
}
FileHandle.standardOutput.write(Data(output.utf8))
