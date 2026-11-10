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

    func testSwiftCoreFormattingOptions() {
        for testCase in formattingCases + repairCases {
            let result = testCase.commit
                ? RewrapMarkdown.rewrapCommitMessage(testCase.input, width: testCase.width, indent: testCase.indent, repair: testCase.repair)
                : RewrapMarkdown.rewrap(testCase.input, width: testCase.width, indent: testCase.indent, repair: testCase.repair)
            XCTAssertEqual(result, testCase.expected, testCase.name)
        }
    }

    func testRepairIsIdempotent() {
        for testCase in repairCases where testCase.repair {
            let result = testCase.commit
                ? RewrapMarkdown.rewrapCommitMessage(testCase.expected, width: testCase.width,
                                                     indent: testCase.indent, repair: true)
                : RewrapMarkdown.rewrap(testCase.expected, width: testCase.width,
                                       indent: testCase.indent, repair: true)
            XCTAssertEqual(result, testCase.expected, testCase.name)
        }
    }

    func testPythonFormattingOptions() throws {
        let pythonFilter = try originalPythonFilterPath()
        for testCase in formattingCases + repairCases {
            XCTAssertEqual(
                try runProcess(
                    "/usr/bin/env", arguments: ["python3", pythonFilter] + testCase.arguments,
                    input: testCase.input
                ),
                testCase.expected, testCase.name
            )
        }
    }

    func testSwiftExecutableFormattingOptions() throws {
        let executable = try swiftExecutablePath()
        for testCase in formattingCases + repairCases {
            XCTAssertEqual(
                try runProcess(executable, arguments: testCase.arguments, input: testCase.input),
                testCase.expected, testCase.name
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

private struct FormattingCase {
    let name: String
    let width: Int
    let indent: RewrapMarkdown.IndentStyle
    let commit: Bool
    let arguments: [String]
    let input: String
    let expected: String
    var repair: Bool = false
}

private let formattingCases: [FormattingCase] = {
    let tabbed = "*\tParent words go here.\n\t*\tChild words go here.\n"
    let spaced = "* Parent words go here.\n  * Child words go here.\n"
    let wrappedTabs = "*\tParent words go\n\there.\n\t*\tChild words\n\t\tgo here.\n"
    let wrappedSpaces = "*   Parent words go\n    here.\n    *   Child words\n        go here.\n"
    let unwrappedSpaces = "*   Parent words go here.\n    *   Child words go here.\n"
    let commitPrefix = "Subject stays unchanged (`subject code`)\n\n"
    let commitSuffix = "\n# Keep this comment.\n\nSigned-off-by: Tester <test@example.com>\n"
    let styles: [RewrapMarkdown.IndentStyle] = [.preserve, .tabs, .spaces]
    let modes: [[String]] = [
        [], ["--unwrap"], ["0"], ["--commit"],
        ["--commit", "--unwrap"], ["--commit", "0"]
    ]
    var cases: [FormattingCase] = []
    for style in styles {
        for mode in modes {
            let commit = mode.contains("--commit")
            let unwrap = mode.contains("--unwrap") || mode.contains("0")
            let input = style == .tabs ? spaced : tabbed
            let expected = style == .spaces
                ? (unwrap ? unwrappedSpaces : wrappedSpaces)
                : (unwrap ? tabbed : wrappedTabs)
            cases.append(FormattingCase(
                name: "\(style.rawValue) \(mode.joined(separator: " "))",
                width: unwrap ? 0 : 20, indent: style, commit: commit,
                arguments: ["--indent=\(style.rawValue)"] + mode + (unwrap ? [] : ["20"]),
                input: (commit ? commitPrefix : "") + input + (commit ? commitSuffix : ""),
                expected: (commit ? commitPrefix : "") + expected + (commit ? commitSuffix : "")
            ))
        }
    }
    for unwrap in [false, true] {
        cases.append(FormattingCase(
            name: "parenthesized code in commit body, unwrap=\(unwrap)",
            width: unwrap ? 0 : 25, indent: .preserve, commit: true,
            arguments: ["--commit"] + (unwrap ? ["--unwrap"] : ["25"]),
            input: commitPrefix + "Before (`code in parens`) after.\n" + commitSuffix,
            expected: commitPrefix + (unwrap
                ? "Before (`code in parens`) after.\n"
                : "Before (`code in parens`)\nafter.\n") + commitSuffix
        ))
    }
    return cases
}()

private let repairCases: [FormattingCase] = {
    func sample(_ name: String, _ input: String, _ expected: String, width: Int = 0,
                repair: Bool = true) -> FormattingCase {
        FormattingCase(name: name, width: width, indent: .preserve, commit: false,
                       arguments: (repair ? ["--repair"] : []) + [String(width)],
                       input: input, expected: expected, repair: repair)
    }
    var cases = [
        sample("repair code-only parentheses", "Before ( `code` ) after.\n", "Before (`code`) after.\n"),
        sample("one-sided and tab spacing", "(\t`x`) (`y`\t) (`z`)\n", "(`x`) (`y`) (`z`)\n"),
        sample("multiline code-only parentheses", "Before (\n`code`\n) after.\n", "Before (`code`) after.\n"),
        sample("multiline prose and code in tabbed lists",
               "*\tExample (such as `call(x)`\n\t) works.\n\t*\tNested (such as `call(y)`\n\t\t) works.\n",
               "*\tExample (such as\n\t`call(x)`) works.\n\t*\tNested (such as\n\t\t`call(y)`) works.\n",
               width: 30),
        sample("unmatched closing parenthesis after code", "Use `call(x)` ) after.\n",
               "Use `call(x)` ) after.\n"),
        sample("code stays with closing parenthesis", "Before ( `code` ) after.\n",
               "Before\n(`code`)\nafter.\n", width: 10),
        sample("long parenthetical wraps internally", "Before ( several\nordinary words\n) after.\n",
               "Before ( several\nordinary words )\nafter.\n", width: 18),
        sample("deliberate prose spacing", "( ordinary words ) and ( `x` plus prose )\n",
               "( ordinary words ) and ( `x` plus prose )\n"),
        sample("overlong parenthetical endpoints", "( longword )\n", "( longword )\n", width: 3),
        sample("disabled preserves code spacing", "Before ( `code` ) after.\n",
               "Before ( `code` ) after.\n", repair: false),
        sample("disabled allows parenthesis wrap", "Before ( `code` ) after.\n",
               "Before (\n`code` )\nafter.\n", width: 10, repair: false),
        sample("code contents and delimiter lengths", "( `` a ` b  `` ) ( ` ( x ) ` ) ( ```x`` )\n",
               "(`` a ` b  ``) (` ( x ) `) ( ```x`` )\n"),
        sample("escaped syntax", #"\( `x` ) ( `y` \) ( \`z\` )"# + "\n",
               #"\( `x` ) ( `y` \) ( \`z\` )"# + "\n"),
        sample("punctuation and brackets deferred", "`code` , `code` . [ `code` ]\n",
               "`code` , `code` . [ `code` ]\n"),
        sample("opaque inline content", "See [label ( `x` )](https://example.com) and <https://example.com/(x)> https://example.com/(`x`) ` ( x ) `.\n",
               "See [label ( `x` )](https://example.com) and <https://example.com/(x)> https://example.com/(`x`) ` ( x ) `.\n"),
        sample("hard break boundary", "Before (  \n`code` ) after.\n", "Before (  \n`code` ) after.\n"),
        sample("nested quote and protected definition", "> ( `x` )\n\n[^n]: ( `y` )\n", "> (`x`)\n\n[^n]: ( `y` )\n"),
    ]
    let protected = "# ( `x` )\n\nHeading ( `x` )\n===\n\n```\n( `x` )\n```\n\n    ( `x` )\n\n<div>\n( `x` )\n</div>\n\n<!-- ( `x` ) -->\n\n[a]: https://example.com/(x) \"( `x` )\"\n\n| ( `x` ) |\n| --- |\n| ( `y` ) |\n"
    cases.append(sample("protected blocks", protected, protected, width: 10))
    for style in [RewrapMarkdown.IndentStyle.preserve, .tabs, .spaces] {
        for mode in [[], ["--unwrap"], ["0"], ["--commit"], ["--commit", "--unwrap"], ["--commit", "0"]] {
            let commit = mode.contains("--commit")
            let unwrap = mode.contains("--unwrap") || mode.contains("0")
            let prefix = commit ? "Subject ( `subject` )\n\n" : ""
            let suffix = commit ? "\n# ( `comment` )\n\nSigned-off-by: ( `trailer` )\n" : ""
            let expected = style == .spaces ? "*   (`x`)\n    *   (`y`)\n" : "*\t(`x`)\n\t*\t(`y`)\n"
            cases.append(FormattingCase(
                name: "repair \(style.rawValue) \(mode.joined(separator: " "))",
                width: unwrap ? 0 : 12, indent: style, commit: commit,
                arguments: ["--repair", "--indent=\(style.rawValue)"] + mode + (unwrap ? [] : ["12"]),
                input: prefix + "*\t( `x` )\n\t*\t( `y` )\n" + suffix,
                expected: prefix + expected + suffix, repair: true
            ))
        }
    }
    return cases
}()

private let compatibilityCases = [
    CompatibilityCase(
        name: "code and enclosing parentheses stay attached at the wrap boundary",
        width: 25,
        input: "Before (`code in parens`) after.\n",
        expected: "Before (`code in parens`)\nafter.\n"
    ),
    CompatibilityCase(
        name: "enclosed code wider than the target stays whole",
        width: 10,
        input: "Before (`code in parens`) after.\n",
        expected: "Before\n(`code in parens`)\nafter.\n"
    ),
    CompatibilityCase(
        name: "double backticks and embedded backticks retain parentheses",
        width: 18,
        input: "Use (``a ` b``) here.\n",
        expected: "Use (``a ` b``)\nhere.\n"
    ),
    CompatibilityCase(
        name: "adjacent spans and surrounding text remain attached",
        width: 12,
        input: "A pré`two words`suffix`more words`終 Z\n",
        expected: "A\npré`two words`suffix`more words`終\nZ\n"
    ),
    CompatibilityCase(
        name: "separate code spans retain their wrap opportunity",
        width: 7,
        input: "`one a` `two b`\n",
        expected: "`one a`\n`two b`\n"
    ),
    CompatibilityCase(
        name: "explicit spaces around code remain in unwrap mode",
        width: 0,
        input: "Before ( `code` ) after.\n",
        expected: "Before ( `code` ) after.\n"
    ),
    CompatibilityCase(
        name: "links images autolinks and emphasis keep adjacent punctuation",
        width: 0,
        input: "([label text](https://example.com)), {![](/image.png)} [<user@example.com>] **`x y`**",
        expected: "([label text](https://example.com)), {![](/image.png)} [<user@example.com>] **`x y`**"
    ),
    CompatibilityCase(
        name: "code parentheses survive unwrap across input lines",
        width: 0,
        input: "Before (`code in parens`)\nafter.\n",
        expected: "Before (`code in parens`) after.\n"
    ),

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
