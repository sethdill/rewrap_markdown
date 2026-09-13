// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation
import RewrapMarkdownCore

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--version") || arguments.contains("-v") {
    print(RewrapMarkdown.versionString)
    exit(0)
}

let width = RewrapMarkdown.width(
    arguments: arguments,
    environment: ProcessInfo.processInfo.environment
)

let input = FileHandle.standardInput.readDataToEndOfFile()
let text = String(data: input, encoding: .utf8) ?? ""
FileHandle.standardOutput.write(Data(RewrapMarkdown.rewrap(text, width: width).utf8))
