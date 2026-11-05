// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation
import RewrapMarkdownCore

let arguments = Array(CommandLine.arguments.dropFirst())
let usage = """
Usage: rewrap-markdown [--unwrap] [--commit] [WIDTH]

Read Markdown from standard input and write the transformed text to standard output.

  --unwrap  Join paragraphs and list items onto one line (equivalent to width 0).
  --commit  Preserve the subject, comments, and trailers of a Git commit message.
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
    output = RewrapMarkdown.rewrapCommitMessage(text, width: unwrap ? 0 : width)
} else {
    output = RewrapMarkdown.rewrap(text, width: unwrap ? 0 : width)
}
FileHandle.standardOutput.write(Data(output.utf8))
