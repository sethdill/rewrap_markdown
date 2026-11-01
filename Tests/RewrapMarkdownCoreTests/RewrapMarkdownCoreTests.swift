// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@testable import RewrapMarkdownCore

final class RewrapMarkdownCoreTests: XCTestCase {
    func testSwiftCoreVersionString() throws {
        let version = try projectVersion()

        XCTAssertEqual(RewrapMarkdown.version, version)
        XCTAssertEqual(RewrapMarkdown.versionString, "rewrap-markdown \(version)")
    }

    func testSwiftCoreMatchesSharedCases() {
        for testCase in compatibilityCases {
            XCTAssertEqual(
                RewrapMarkdown.rewrap(testCase.input, width: testCase.width),
                testCase.expected,
                testCase.name
            )
        }
    }

    func testUnwrapRoundTripsCanonicalWrappedMarkdown() {
        for testCase in compatibilityCases {
            let wrapped = RewrapMarkdown.rewrap(testCase.input, width: testCase.width)
            let unwrapped = RewrapMarkdown.rewrap(wrapped, width: 0)

            XCTAssertEqual(
                RewrapMarkdown.rewrap(unwrapped, width: testCase.width),
                wrapped,
                testCase.name
            )
        }
    }

    func testWidthZeroSelectsUnwrapMode() {
        XCTAssertEqual(
            RewrapMarkdown.width(arguments: ["0"], environment: [:]),
            0
        )
        XCTAssertEqual(
            RewrapMarkdown.width(arguments: [], environment: ["MD_REWRAP_WIDTH": "0"]),
            0
        )
    }

    func testUnwrapPreservesMarkdownStructure() {
        let input = """
        This paragraph has been
        wrapped across several
        source lines.

        - This list item has a
          continuation line.
          - This nested item also
            has a continuation.
        - This item stays separate.

        > This quoted paragraph
        > has two source lines.

        This line has a hard break\u{20}\u{20}
        and this line continues
        after that break.

        ```swift
        let value = "code remains exactly as written"
        ```

        """

        let expected = """
        This paragraph has been wrapped across several source lines.

        - This list item has a continuation line.
          - This nested item also has a continuation.
        - This item stays separate.

        > This quoted paragraph has two source lines.

        This line has a hard break\u{20}\u{20}
        and this line continues after that break.

        ```swift
        let value = "code remains exactly as written"
        ```

        """

        XCTAssertEqual(RewrapMarkdown.rewrap(input, width: 0), expected)
    }

    func testCommitMessageModePreservesSpecialRegions() {
        let input = """
        A subject line that is intentionally much longer than the body width

        This commit body was manually
        wrapped and should be reflowed to
        the requested width without changing the subject.

        # This comment line must remain exactly as written even when it is long.
        Another body paragraph follows the comment and should be wrapped independently.

        Signed-off-by: Seth Dillingham <seth@example.com>
        Co-authored-by: Example Person <example@example.com>
         continuation text that belongs to the trailer

        """

        let expected = """
        A subject line that is intentionally much longer than the body width

        This commit body was manually
        wrapped and should be reflowed to
        the requested width without
        changing the subject.

        # This comment line must remain exactly as written even when it is long.
        Another body paragraph follows the
        comment and should be wrapped
        independently.

        Signed-off-by: Seth Dillingham <seth@example.com>
        Co-authored-by: Example Person <example@example.com>
         continuation text that belongs to the trailer

        """

        XCTAssertEqual(
            RewrapMarkdown.rewrapCommitMessage(input, width: 34),
            expected
        )
    }

    func testCommitMessageDefaultWidth() {
        XCTAssertEqual(RewrapMarkdown.defaultCommitMessageWidth, 72)
    }

    func testCommitMessageCanUnwrapOnlyItsBody() {
        let input = """
        Subject remains exactly as written

        This body is split
        across source lines.

        Signed-off-by: Seth Dillingham <seth@example.com>

        """
        let expected = """
        Subject remains exactly as written

        This body is split across source lines.

        Signed-off-by: Seth Dillingham <seth@example.com>

        """

        XCTAssertEqual(
            RewrapMarkdown.rewrapCommitMessage(input, width: 0),
            expected
        )
    }

    func testPythonOriginalMatchesSharedCases() throws {
        let pythonFilter = try originalPythonFilterPath()

        for testCase in compatibilityCases {
            XCTAssertEqual(
                try runPythonFilter(at: pythonFilter, input: testCase.input, width: testCase.width),
                testCase.expected,
                testCase.name
            )
        }
    }

    func testPythonOriginalReportsVersion() throws {
        let pythonFilter = try originalPythonFilterPath()
        let expected = "rewrap-markdown \(try projectVersion())\n"

        for argument in ["--version", "-v"] {
            XCTAssertEqual(
                try runProcess("/usr/bin/env", arguments: ["python3", pythonFilter, argument], input: ""),
                expected
            )
        }
    }

    func testPythonReportsNewModesInHelp() throws {
        let pythonFilter = try originalPythonFilterPath()
        let output = try runProcess(
            "/usr/bin/env",
            arguments: ["python3", pythonFilter, "--help"],
            input: ""
        )

        XCTAssertTrue(output.contains("--unwrap"))
        XCTAssertTrue(output.contains("--commit"))
    }

    func testPythonUnwrapModes() throws {
        let pythonFilter = try originalPythonFilterPath()
        let input = "This paragraph is\nwrapped across lines.\n"
        let expected = "This paragraph is wrapped across lines.\n"

        for arguments in [["--unwrap"], ["0"]] {
            XCTAssertEqual(
                try runProcess(
                    "/usr/bin/env",
                    arguments: ["python3", pythonFilter] + arguments,
                    input: input
                ),
                expected
            )
        }
    }

    func testPythonCommitMessageMode() throws {
        let pythonFilter = try originalPythonFilterPath()
        let input = """
        This subject remains long and unchanged

        This body text should wrap at the explicitly requested width.

        # Keep this comment exactly as written.

        Signed-off-by: Seth Dillingham <seth@example.com>

        """
        let expected = """
        This subject remains long and unchanged

        This body text should
        wrap at the explicitly
        requested width.

        # Keep this comment exactly as written.

        Signed-off-by: Seth Dillingham <seth@example.com>

        """

        XCTAssertEqual(
            try runProcess(
                "/usr/bin/env",
                arguments: ["python3", pythonFilter, "--commit", "24"],
                input: input
            ),
            expected
        )
    }

    func testSwiftExecutableMatchesSharedCases() throws {
        let executable = try swiftExecutablePath()

        for testCase in compatibilityCases {
            XCTAssertEqual(
                try runProcess(executable, arguments: [String(testCase.width)], input: testCase.input),
                testCase.expected,
                testCase.name
            )
        }
    }

    func testSwiftExecutableReportsVersion() throws {
        let executable = try swiftExecutablePath()
        let expected = "rewrap-markdown \(try projectVersion())\n"

        for argument in ["--version", "-v"] {
            XCTAssertEqual(
                try runProcess(executable, arguments: [argument], input: ""),
                expected
            )
        }
    }

    func testSwiftExecutableReportsNewModesInHelp() throws {
        let executable = try swiftExecutablePath()
        let output = try runProcess(executable, arguments: ["--help"], input: "")

        XCTAssertTrue(output.contains("--unwrap"))
        XCTAssertTrue(output.contains("--commit"))
    }

    func testSwiftExecutableUnwrapModes() throws {
        let executable = try swiftExecutablePath()
        let input = "This paragraph is\nwrapped across lines.\n"
        let expected = "This paragraph is wrapped across lines.\n"

        for arguments in [["--unwrap"], ["0"]] {
            XCTAssertEqual(
                try runProcess(executable, arguments: arguments, input: input),
                expected
            )
        }
    }

    func testSwiftExecutableCommitMessageMode() throws {
        let executable = try swiftExecutablePath()
        let input = """
        This subject remains long and unchanged

        This body text should wrap at the explicitly requested width.

        # Keep this comment exactly as written.

        Signed-off-by: Seth Dillingham <seth@example.com>

        """
        let expected = """
        This subject remains long and unchanged

        This body text should
        wrap at the explicitly
        requested width.

        # Keep this comment exactly as written.

        Signed-off-by: Seth Dillingham <seth@example.com>

        """

        XCTAssertEqual(
            try runProcess(executable, arguments: ["--commit", "24"], input: input),
            expected
        )
    }

    func testCommitMessageHookRewritesOnlyAfterSuccess() throws {
        let executable = try swiftExecutablePath()
        let hook = projectRoot()
            .appendingPathComponent("Distribution/Git/commit-msg")
            .path
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let message = temporaryDirectory.appendingPathComponent("COMMIT_EDITMSG")
        let input = """
        Subject stays as written

        This body starts on
        more than one line.

        Signed-off-by: Seth Dillingham <seth@example.com>

        """
        let expected = """
        Subject stays as written

        This body starts on more than one line.

        Signed-off-by: Seth Dillingham <seth@example.com>

        """
        try input.write(to: message, atomically: true, encoding: .utf8)

        XCTAssertEqual(
            try runHook(hook, message: message.path, executable: executable),
            0
        )
        XCTAssertEqual(
            try String(contentsOf: message, encoding: .utf8),
            expected
        )

        try input.write(to: message, atomically: true, encoding: .utf8)
        XCTAssertNotEqual(
            try runHook(hook, message: message.path, executable: "/does/not/exist"),
            0
        )
        XCTAssertEqual(
            try String(contentsOf: message, encoding: .utf8),
            input
        )
    }
}

private struct CompatibilityCase {
    let name: String
    let width: Int
    let input: String
    let expected: String
}

private let compatibilityCases = [
    CompatibilityCase(
        name: "plain paragraph wraps and preserves trailing newline",
        width: 32,
        input: "This is a paragraph that should wrap cleanly around the configured width without losing the final newline.\n",
        expected: """
        This is a paragraph that should
        wrap cleanly around the
        configured width without losing
        the final newline.

        """
    ),
    CompatibilityCase(
        name: "lists use hanging indent",
        width: 34,
        input: "- This item has enough words to wrap onto multiple lines while keeping the continuation aligned.\n",
        expected: """
        - This item has enough words to
          wrap onto multiple lines while
          keeping the continuation
          aligned.

        """
    ),
    CompatibilityCase(
        name: "blockquotes can contain lists",
        width: 42,
        input: "> - This quoted item should wrap while retaining both the quote marker and list indentation.\n",
        expected: """
        > - This quoted item should wrap while
        >   retaining both the quote marker and
        >   list indentation.

        """
    ),
    CompatibilityCase(
        name: "protected blocks pass through",
        width: 20,
        input: """
        # Heading stays as-is even when very very very long

        | A | B |
        |---|---|
        | a long cell | another long cell |

        ```swift
        let value = "this line should not be wrapped even though it is quite long"
        ```

        """,
        expected: """
        # Heading stays as-is even when very very very long

        | A | B |
        |---|---|
        | a long cell | another long cell |

        ```swift
        let value = "this line should not be wrapped even though it is quite long"
        ```

        """
    ),
    CompatibilityCase(
        name: "inline atomic spans are not split",
        width: 28,
        input: "Before [a link with spaces](https://example.com/path), after `code span`; then https://example.com/this/is/a/long/url.\n",
        expected: """
        Before
        [a link with spaces](https://example.com/path),
        after `code span`; then
        https://example.com/this/is/a/long/url.

        """
    ),
    CompatibilityCase(
        name: "reference link definitions pass through",
        width: 30,
        input: "[label]: https://example.com/a/reference/link \"Reference title\"\n\nBefore [label] after.\n",
        expected: """
        [label]: https://example.com/a/reference/link "Reference title"

        Before [label] after.

        """
    ),
    CompatibilityCase(
        name: "hard breaks are preserved",
        width: 24,
        input: "This line ends with a hard break  \nand this continues after it.\n",
        expected: """
        This line ends with a
        hard break  
        and this continues after
        it.

        """
    ),
    CompatibilityCase(
        name: "gfm alert marker stays on its own quoted line",
        width: 42,
        input: "> [!NOTE]\n> This alert text should wrap while preserving the GitHub alert marker as a separate quoted line.\n",
        expected: """
        > [!NOTE]
        > This alert text should wrap while
        > preserving the GitHub alert marker as a
        > separate quoted line.

        """
    ),
    CompatibilityCase(
        name: "html comments pass through",
        width: 30,
        input: "<!-- This long hidden comment should pass through without being wrapped or split into invalid comment text. -->\n",
        expected: "<!-- This long hidden comment should pass through without being wrapped or split into invalid comment text. -->\n"
    ),
    CompatibilityCase(
        name: "indented code blocks pass through",
        width: 30,
        input: "    let code = \"this indented code block should not be wrapped even though it is very long\"\n\nParagraph text after the code block should wrap normally.\n",
        expected: """
            let code = "this indented code block should not be wrapped even though it is very long"

        Paragraph text after the code
        block should wrap normally.

        """
    ),
]

private func originalPythonFilterPath() throws -> String {
    let environment = ProcessInfo.processInfo.environment
    let configured = environment["PYTHON_REWRAP_MARKDOWN_PATH"]
    let defaultPath = projectRoot()
        .appendingPathComponent("Reference/rewrap_markdown.py")
        .path
    let path = configured?.isEmpty == false ? configured! : defaultPath

    guard FileManager.default.isReadableFile(atPath: path) else {
        throw XCTSkip("Set PYTHON_REWRAP_MARKDOWN_PATH to run the shared cases against a Python filter.")
    }
    return path
}

private func projectVersion() throws -> String {
    try String(contentsOfFile: projectRoot().appendingPathComponent("VERSION").path, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func projectRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func swiftExecutablePath() throws -> String {
    guard let path = ProcessInfo.processInfo.environment["REWRAP_MARKDOWN_EXECUTABLE"], !path.isEmpty else {
        throw XCTSkip("Set REWRAP_MARKDOWN_EXECUTABLE to run the shared cases against a compiled Swift executable.")
    }
    guard FileManager.default.isExecutableFile(atPath: path) else {
        XCTFail("REWRAP_MARKDOWN_EXECUTABLE is not executable: \(path)")
        return path
    }
    return path
}

private func runPythonFilter(at path: String, input: String, width: Int) throws -> String {
    try runProcess("/usr/bin/env", arguments: ["python3", path, String(width)], input: input)
}

private func runProcess(_ launchPath: String, arguments: [String], input: String) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let standardInput = Pipe()
    let standardOutput = Pipe()
    let standardError = Pipe()
    process.standardInput = standardInput
    process.standardOutput = standardOutput
    process.standardError = standardError

    try process.run()
    standardInput.fileHandleForWriting.write(Data(input.utf8))
    try standardInput.fileHandleForWriting.close()
    process.waitUntilExit()

    let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = standardError.fileHandleForReading.readDataToEndOfFile()
    let stderr = String(data: errorOutput, encoding: .utf8) ?? ""

    XCTAssertEqual(process.terminationStatus, 0, stderr)
    return String(data: output, encoding: .utf8) ?? ""
}

private func runHook(_ hook: String, message: String, executable: String) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [hook, message]
    var environment = ProcessInfo.processInfo.environment
    environment["REWRAP_MARKDOWN"] = executable
    process.environment = environment
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}
