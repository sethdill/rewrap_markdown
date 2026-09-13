// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation

public enum RewrapMarkdown {
    public static let version = "0.1"
    public static let defaultWidth = 70

    public static var versionString: String {
        "rewrap-markdown \(version)"
    }

    public static func width(
        arguments: [String] = Array(CommandLine.arguments.dropFirst()),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Int {
        if let first = arguments.first, let value = Int(first) {
            return max(1, value)
        }
        if let env = environment["MD_REWRAP_WIDTH"], let value = Int(env) {
            return max(1, value)
        }
        return defaultWidth
    }

    public static func rewrap(_ text: String, width: Int) -> String {
        let hadTrailingNewline = text.hasSuffix("\n")
        var lines = text.components(separatedBy: "\n")
        if hadTrailingNewline, lines.last == "" {
            lines.removeLast()
        }

        var result = processBlock(lines, width: width).joined(separator: "\n")
        if hadTrailingNewline {
            result += "\n"
        }
        return result
    }
}

private let blank = RegexPattern(#"^\s*$"#)
private let fence = RegexPattern(#"^( {0,3})(`{3,}|~{3,})\s*(.*)$"#)
private let atx = RegexPattern(#"^ {0,3}#{1,6}(?:\s+.*|)$"#)
private let thematicBreak = RegexPattern(#"^ {0,3}(?:-(?: *-){2,}|\*(?: *\*){2,}|_(?: *_){2,}) *$"#)
private let setextH1 = RegexPattern(#"^ {0,3}=+ *$"#)
private let setextH2 = RegexPattern(#"^ {0,3}-+ *$"#)
private let blockquote = RegexPattern(#"^ {0,3}>( ?)(.*)$"#)
private let bullet = RegexPattern(#"^( {0,3})([-*+])( +)(.*)$"#)
private let ordered = RegexPattern(#"^( {0,3})(\d{1,9})([.)])( +)(.*)$"#)
private let footnote = RegexPattern(#"^\[\^([^\]]+)\]:( +)(.*)$"#)
private let referenceDefinition = RegexPattern(#"^ {0,3}\[[^\]]+\]:\s+\S+.*$"#)
private let tableDelimiter = RegexPattern(#"^ {0,3}\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$"#)
private let htmlBlockStart = RegexPattern(#"^ {0,3}</?[a-zA-Z][a-zA-Z0-9-]*(?:\s|/?>|$)"#)
private let htmlCommentStart = RegexPattern(#"^ {0,3}<!--"#)
private let htmlCommentEnd = RegexPattern(#"-->\s*$"#)
private let gfmAlertMarker = RegexPattern(#"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$"#)
private let hardBreak = RegexPattern(#"(\\|  +)$"#)
private let inlineAtomic = RegexPattern(
    #"(`+).*?\1|!\[[^\]]*\]\([^)]*\)|\[[^\]]*\]\([^)]*\)|\[[^\]]*\](?:\[[^\]]*\])?|<[^ >]+>|https?://\S+"#
)

private func processBlock(_ lines: [String], width: Int) -> [String] {
    var output: [String] = []
    var i = 0

    while i < lines.count {
        let line = lines[i]

        if blank.matches(line) {
            output.append("")
            i += 1
            continue
        }

        if let match = fence.firstMatch(in: line) {
            let fenceText = match[2]
            let fenceChar = String(fenceText.prefix(1))
            let fenceLength = fenceText.count
            let closingFence = RegexPattern(#"^ {0,3}("# + NSRegularExpression.escapedPattern(for: fenceChar) + #"{\#(fenceLength),})\s*$"#)
            var block = [line]
            i += 1
            while i < lines.count {
                block.append(lines[i])
                let isClose = closingFence.matches(lines[i])
                i += 1
                if isClose {
                    break
                }
            }
            output.append(contentsOf: block)
            continue
        }

        if thematicBreak.matches(line) {
            output.append(trimRight(line))
            i += 1
            continue
        }

        if atx.matches(line) {
            output.append(trimRight(line))
            i += 1
            continue
        }

        if gfmAlertMarker.matches(line) {
            output.append(trimRight(line))
            i += 1
            continue
        }

        if referenceDefinition.matches(line) {
            output.append(trimRight(line))
            i += 1
            continue
        }

        if leadingSpaces(line) >= 4 {
            while i < lines.count, blank.matches(lines[i]) || leadingSpaces(lines[i]) >= 4 {
                output.append(trimRight(lines[i]))
                i += 1
            }
            continue
        }

        if !blank.matches(line),
           !isBlockquote(line),
           bullet.firstMatch(in: line) == nil,
           ordered.firstMatch(in: line) == nil,
           i + 1 < lines.count,
           setextH1.matches(lines[i + 1]) || setextH2.matches(lines[i + 1]) {
            output.append(trimRight(line))
            output.append(trimRight(lines[i + 1]))
            i += 2
            continue
        }

        if isHTMLBlockStart(line) {
            while i < lines.count, !blank.matches(lines[i]) {
                output.append(trimRight(lines[i]))
                i += 1
            }
            continue
        }

        if htmlCommentStart.matches(line) {
            while i < lines.count {
                output.append(trimRight(lines[i]))
                let isEnd = htmlCommentEnd.matches(lines[i])
                i += 1
                if isEnd {
                    break
                }
            }
            continue
        }

        if isTableRow(line), i + 1 < lines.count, tableDelimiter.matches(lines[i + 1]) {
            output.append(trimRight(line))
            output.append(trimRight(lines[i + 1]))
            i += 2
            while i < lines.count, isTableRow(lines[i]), !blank.matches(lines[i]) {
                output.append(trimRight(lines[i]))
                i += 1
            }
            continue
        }

        if blockquote.firstMatch(in: line) != nil {
            var inner: [String] = []
            while i < lines.count, let match = blockquote.firstMatch(in: lines[i]) {
                inner.append(match[2])
                i += 1
            }
            let rendered = processBlock(inner, width: max(1, width - 2))
            output.append(contentsOf: rendered.map { $0.isEmpty ? ">" : "> " + $0 })
            continue
        }

        if let match = footnote.firstMatch(in: line) {
            let marker = "[^\(match[1])]: "
            let contentColumn = marker.count
            let firstText = substring(line, fromUTF16Offset: match.rangeEnd(2))
            let gathered = gatherIndentedBlock(lines, start: i, contentColumn: contentColumn, firstText: firstText)
            let rendered = processBlock(gathered.lines, width: max(1, width - contentColumn))
            output.append(contentsOf: renderHanging(rendered, firstPrefix: marker, restPrefix: String(repeating: " ", count: contentColumn)))
            i = gathered.nextIndex
            continue
        }

        if let match = bullet.firstMatch(in: line) {
            let marker = match[1] + match[2] + " "
            let contentColumn = marker.count
            let gathered = gatherIndentedBlock(lines, start: i, contentColumn: contentColumn, firstText: match[4])
            let rendered = processBlock(gathered.lines, width: max(1, width - contentColumn))
            output.append(contentsOf: renderHanging(rendered, firstPrefix: marker, restPrefix: String(repeating: " ", count: contentColumn)))
            i = gathered.nextIndex
            continue
        }

        if let match = ordered.firstMatch(in: line) {
            let marker = match[1] + match[2] + match[3] + " "
            let contentColumn = marker.count
            let gathered = gatherIndentedBlock(lines, start: i, contentColumn: contentColumn, firstText: match[5])
            let rendered = processBlock(gathered.lines, width: max(1, width - contentColumn))
            output.append(contentsOf: renderHanging(rendered, firstPrefix: marker, restPrefix: String(repeating: " ", count: contentColumn)))
            i = gathered.nextIndex
            continue
        }

        var paragraph = [line]
        i += 1
        while i < lines.count, !blank.matches(lines[i]), !startsNewBlock(lines[i]) {
            paragraph.append(lines[i])
            i += 1
        }
        output.append(contentsOf: wrapParagraphText(paragraph, width: width))
    }

    return output
}

private func tokenizeInline(_ text: String) -> [String] {
    var tokens: [String] = []
    var cursor = 0

    for match in inlineAtomic.matches(in: text) {
        if match.range.location < cursor {
            continue
        }
        if match.range.location > cursor {
            tokens.append(contentsOf: splitWhitespace(substring(text, utf16Range: NSRange(location: cursor, length: match.range.location - cursor))))
        }
        var token = substring(text, utf16Range: match.range)
        var tokenEnd = String.Index(utf16Offset: match.range.location + match.range.length, in: text)
        while tokenEnd < text.endIndex, isAttachedPunctuation(text[tokenEnd]) {
            token.append(text[tokenEnd])
            tokenEnd = text.index(after: tokenEnd)
        }
        tokens.append(token)
        cursor = tokenEnd.utf16Offset(in: text)
    }

    let totalLength = text.utf16.count
    if cursor < totalLength {
        tokens.append(contentsOf: splitWhitespace(substring(text, utf16Range: NSRange(location: cursor, length: totalLength - cursor))))
    }

    return tokens
}

private func wrapTokens(_ tokens: [String], width: Int) -> [String] {
    var lines: [String] = []
    var current: [String] = []
    var currentLength = 0

    for token in tokens {
        let addedLength = current.isEmpty ? token.count : token.count + 1
        if !current.isEmpty, currentLength + addedLength > width {
            lines.append(current.joined(separator: " "))
            current = [token]
            currentLength = token.count
        } else {
            current.append(token)
            currentLength += addedLength
        }
    }

    if !current.isEmpty {
        lines.append(current.joined(separator: " "))
    }
    return lines.isEmpty ? [""] : lines
}

private func wrapParagraphText(_ rawLines: [String], width: Int) -> [String] {
    var segments: [(text: String, breakStyle: String?)] = []
    var buffer: [String] = []

    for line in rawLines {
        let stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutNewline = line
        if let match = hardBreak.firstMatch(in: withoutNewline), !stripped.isEmpty {
            let breakStyle = match[1] == "\\" ? "\\" : "  "
            let textPart = trimRight(substring(withoutNewline, toUTF16Offset: match.range.location))
            buffer.append(textPart.trimmingCharacters(in: .whitespaces))
            segments.append((buffer.filter { !$0.isEmpty }.joined(separator: " "), breakStyle))
            buffer.removeAll()
        } else {
            buffer.append(stripped)
        }
    }

    if !buffer.isEmpty {
        segments.append((buffer.filter { !$0.isEmpty }.joined(separator: " "), nil))
    }

    var output: [String] = []
    for segment in segments {
        let tokens = tokenizeInline(segment.text)
        var wrapped = tokens.isEmpty ? [""] : wrapTokens(tokens, width: width)
        if let breakStyle = segment.breakStyle, !wrapped.isEmpty {
            wrapped[wrapped.count - 1] += breakStyle
        }
        output.append(contentsOf: wrapped)
    }
    return output
}

private func startsNewBlock(_ line: String) -> Bool {
    isFenceStart(line)
        || atx.matches(line)
        || gfmAlertMarker.matches(line)
        || thematicBreak.matches(line)
        || isBlockquote(line)
        || bullet.firstMatch(in: line) != nil
        || ordered.firstMatch(in: line) != nil
        || footnote.firstMatch(in: line) != nil
        || referenceDefinition.matches(line)
        || isHTMLBlockStart(line)
        || htmlCommentStart.matches(line)
        || leadingSpaces(line) >= 4
}

private func gatherIndentedBlock(
    _ lines: [String],
    start i: Int,
    contentColumn: Int,
    firstText: String
) -> (lines: [String], nextIndex: Int) {
    var item = [firstText]
    var j = i + 1

    while j < lines.count {
        if blank.matches(lines[j]) {
            var k = j
            while k < lines.count, blank.matches(lines[k]) {
                k += 1
            }
            if k < lines.count, leadingSpaces(lines[k]) >= contentColumn {
                while j < k {
                    item.append("")
                    j += 1
                }
                continue
            }
            break
        }

        if leadingSpaces(lines[j]) >= contentColumn {
            item.append(substring(lines[j], fromUTF16Offset: contentColumn))
            j += 1
            continue
        }

        break
    }

    return (item, j)
}

private func renderHanging(_ contentLines: [String], firstPrefix: String, restPrefix: String) -> [String] {
    contentLines.enumerated().map { index, line in
        if line.isEmpty {
            return ""
        }
        return (index == 0 ? firstPrefix : restPrefix) + line
    }
}

private func leadingSpaces(_ line: String) -> Int {
    line.prefix { $0 == " " }.count
}

private func isBlockquote(_ line: String) -> Bool {
    blockquote.firstMatch(in: line) != nil
}

private func isFenceStart(_ line: String) -> Bool {
    fence.firstMatch(in: line) != nil
}

private func isTableRow(_ line: String) -> Bool {
    line.contains("|") && !blank.matches(line)
}

private func isHTMLBlockStart(_ line: String) -> Bool {
    htmlBlockStart.firstMatch(in: line) != nil
}

private func splitWhitespace(_ text: String) -> [String] {
    text.split { $0.isWhitespace }.map(String.init)
}

private func isAttachedPunctuation(_ character: Character) -> Bool {
    ",.;:!?".contains(character)
}

private func trimRight(_ text: String) -> String {
    String(text.reversed().drop { $0 == " " || $0 == "\t" }.reversed())
}

private func substring(_ text: String, utf16Range range: NSRange) -> String {
    let start = String.Index(utf16Offset: range.location, in: text)
    let end = String.Index(utf16Offset: range.location + range.length, in: text)
    return String(text[start..<end])
}

private func substring(_ text: String, fromUTF16Offset offset: Int) -> String {
    let start = String.Index(utf16Offset: min(offset, text.utf16.count), in: text)
    return String(text[start...])
}

private func substring(_ text: String, toUTF16Offset offset: Int) -> String {
    let end = String.Index(utf16Offset: min(offset, text.utf16.count), in: text)
    return String(text[..<end])
}

private final class RegexPattern {
    private let expression: NSRegularExpression

    init(_ pattern: String) {
        do {
            expression = try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid regex pattern: \(pattern)")
        }
    }

    func matches(_ text: String) -> Bool {
        firstMatch(in: text) != nil
    }

    func firstMatch(in text: String) -> RegexMatch? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range) else {
            return nil
        }
        return RegexMatch(text: text, match: match)
    }

    func matches(in text: String) -> [RegexMatch] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).map { RegexMatch(text: text, match: $0) }
    }
}

private struct RegexMatch {
    let text: String
    let match: NSTextCheckingResult

    var range: NSRange {
        match.range
    }

    subscript(_ group: Int) -> String {
        let range = match.range(at: group)
        guard range.location != NSNotFound else {
            return ""
        }
        return substring(text, utf16Range: range)
    }

    func rangeEnd(_ group: Int) -> Int {
        let range = match.range(at: group)
        guard range.location != NSNotFound else {
            return 0
        }
        return range.location + range.length
    }
}
