// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation

public enum RewrapMarkdown {
    public enum IndentStyle: String {
        case preserve, tabs, spaces
    }

    public static let version = "0.3"
    public static let defaultWidth = 70
    public static let defaultCommitMessageWidth = 72

    public static var versionString: String {
        "rewrap-markdown \(version)"
    }

    public static func width(
        arguments: [String] = Array(CommandLine.arguments.dropFirst()),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fallback: Int = defaultWidth
    ) -> Int {
        if let first = arguments.first, let value = Int(first) {
            return normalizedWidth(value)
        }
        if let env = environment["MD_REWRAP_WIDTH"], let value = Int(env) {
            return normalizedWidth(value)
        }
        return normalizedWidth(fallback)
    }

    public static func rewrap(_ text: String, width: Int) -> String {
        rewrap(text, width: width, indent: .preserve)
    }

    public static func rewrap(_ text: String, width: Int, indent: IndentStyle = .preserve, repair: Bool = false) -> String {
        rewrapDocument(text, width: normalizedWidth(width), indent: indent, repair: repair)
    }

    public static func rewrapCommitMessage(
        _ text: String,
        width: Int = defaultCommitMessageWidth
    ) -> String {
        rewrapCommitMessage(text, width: width, indent: .preserve)
    }

    public static func rewrapCommitMessage(
        _ text: String,
        width: Int = defaultCommitMessageWidth,
        indent: IndentStyle = .preserve,
        repair: Bool = false
    ) -> String {
        let hadTrailingNewline = text.hasSuffix("\n")
        var lines = text.components(separatedBy: "\n")
        if hadTrailingNewline, lines.last == "" {
            lines.removeLast()
        }

        guard let subject = lines.first else {
            return text
        }

        let body = processCommitMessageBody(
            Array(lines.dropFirst()),
            width: normalizedWidth(width),
            indent: indent, repair: repair
        )
        var result = ([subject] + body).joined(separator: "\n")
        if hadTrailingNewline {
            result += "\n"
        }
        return result
    }
}

private func normalizedWidth(_ width: Int) -> Int {
    width == 0 ? 0 : max(1, width)
}

private func rewrapDocument(_ text: String, width: Int, indent: RewrapMarkdown.IndentStyle, repair: Bool) -> String {
    let hadTrailingNewline = text.hasSuffix("\n")
    var lines = text.components(separatedBy: "\n")
    if hadTrailingNewline, lines.last == "" {
        lines.removeLast()
    }

    var result = processBlock(lines, width: width, indent: indent, repair: repair).joined(separator: "\n")
    if hadTrailingNewline {
        result += "\n"
    }
    return result
}

private let blank = RegexPattern(#"^\s*$"#)
private let fence = RegexPattern(#"^( {0,3})(`{3,}|~{3,})\s*(.*)$"#)
private let atx = RegexPattern(#"^ {0,3}#{1,6}(?:\s+.*|)$"#)
private let thematicBreak = RegexPattern(#"^ {0,3}(?:-(?:[ \t]*-){2,}|\*(?:[ \t]*\*){2,}|_(?:[ \t]*_){2,})[ \t]*$"#)
private let setextH1 = RegexPattern(#"^ {0,3}=+ *$"#)
private let setextH2 = RegexPattern(#"^ {0,3}-+ *$"#)
private let blockquote = RegexPattern(#"^ {0,3}>( ?)(.*)$"#)
private let listMarker = RegexPattern(#"^([ \t]*)([-*+]|\d{1,9}[.)])([ \t]+)(.*)$"#)
private let footnote = RegexPattern(#"^\[\^([^\]]+)\]:( +)(.*)$"#)
private let referenceDefinition = RegexPattern(#"^ {0,3}\[[^\]]+\]:\s+\S+.*$"#)
private let tableDelimiter = RegexPattern(#"^ {0,3}\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$"#)
private let htmlBlockStart = RegexPattern(#"^ {0,3}</?[a-zA-Z][a-zA-Z0-9-]*(?:\s|/?>|$)"#)
private let htmlCommentStart = RegexPattern(#"^ {0,3}<!--"#)
private let htmlCommentEnd = RegexPattern(#"-->\s*$"#)
private let gfmAlertMarker = RegexPattern(#"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$"#)
private let hardBreak = RegexPattern(#"(\\|  +)$"#)
private let commitComment = RegexPattern(#"^[ \t]*#"#)
private let commitTrailer = RegexPattern(#"^[A-Za-z0-9][A-Za-z0-9-]*[ \t]*[:=][ \t]+.+$"#)
private let inlineAtomic = RegexPattern(
    #"(`+).*?\1|!\[[^\]]*\]\([^)]*\)|\[[^\]]*\]\([^)]*\)|\[[^\]]*\](?:\[[^\]]*\])?|<[^ >]+>|https?://\S+"#
)
private let inlineWords = RegexPattern(#"\S+"#)

private struct IndentContext {
    let style: RewrapMarkdown.IndentStyle
    var input = 0
    var output = 0
    var repair = false

    var tabStopsShift: Bool { input % 4 != output % 4 }

    func nested(input: Int, output: Int) -> Self {
        Self(style: style, input: self.input + input, output: self.output + output, repair: repair)
    }
}

private func processBlock(_ lines: [String], width: Int, indent: RewrapMarkdown.IndentStyle, repair: Bool) -> [String] {
    processBlock(lines, width: width, context: IndentContext(style: indent, repair: repair), lazyLines: []).rendered
}

// A line missing list indentation can extend a paragraph, but cannot start
// a block or extend a protected block such as a code fence.
private func processBlock(
    _ lines: [String], width: Int, context: IndentContext, lazyLines: Set<Int>
) -> (rendered: [String], consumed: Int) {
    var output: [String] = []
    var i = 0

    while i < lines.count, !lazyLines.contains(i) {
        let line = lines[i]
        let syntax = blockSyntax(line, column: context.input)

        if blank.matches(line) {
            output.append("")
            i += 1
            continue
        }

        if let match = fence.firstMatch(in: syntax) {
            let fenceText = match[2]
            let fenceChar = String(fenceText.prefix(1))
            let fenceLength = fenceText.count
            let closingFence = RegexPattern(#"^ {0,3}("# + NSRegularExpression.escapedPattern(for: fenceChar) + #"{\#(fenceLength),})\s*$"#)
            var block = [context.tabStopsShift ? syntax : line]
            i += 1
            while i < lines.count, !lazyLines.contains(i) {
                let codeLine = lines[i]
                let codeSyntax = blockSyntax(codeLine, column: context.input)
                let isClose = closingFence.matches(codeSyntax)
                if context.tabStopsShift, isClose {
                    block.append(codeSyntax)
                } else {
                    block.append(rebaseCodeIndent(codeLine, width: match[1].count, context: context))
                }
                i += 1
                if isClose {
                    break
                }
            }
            output.append(contentsOf: block)
            continue
        }

        if thematicBreak.matches(syntax) {
            output.append(trimRight(context.tabStopsShift ? syntax : line))
            i += 1
            continue
        }

        if atx.matches(syntax) {
            output.append(trimRight(context.tabStopsShift ? syntax : line))
            i += 1
            continue
        }

        if gfmAlertMarker.matches(line) {
            output.append(trimRight(line))
            i += 1
            continue
        }

        if referenceDefinition.matches(syntax) {
            output.append(trimRight(context.tabStopsShift ? syntax : line))
            i += 1
            continue
        }

        if leadingIndent(line, column: context.input) >= 4 {
            while i < lines.count, !lazyLines.contains(i), blank.matches(lines[i]) || leadingIndent(lines[i], column: context.input) >= 4 {
                output.append(trimRight(rebaseCodeIndent(lines[i], width: 4, context: context)))
                i += 1
            }
            continue
        }

        if !blank.matches(line),
           !isBlockquote(syntax),
           listMarker.firstMatch(in: line) == nil,
           i + 1 < lines.count, !lazyLines.contains(i + 1),
           setextH1.matches(blockSyntax(lines[i + 1], column: context.input))
            || setextH2.matches(blockSyntax(lines[i + 1], column: context.input)) {
            output.append(trimRight(line))
            output.append(trimRight(lines[i + 1]))
            i += 2
            continue
        }

        if isHTMLBlockStart(syntax) {
            while i < lines.count, !lazyLines.contains(i), !blank.matches(lines[i]) {
                output.append(trimRight(lines[i]))
                i += 1
            }
            continue
        }

        if htmlCommentStart.matches(syntax) {
            while i < lines.count, !lazyLines.contains(i) {
                output.append(trimRight(lines[i]))
                let isEnd = htmlCommentEnd.matches(lines[i])
                i += 1
                if isEnd {
                    break
                }
            }
            continue
        }

        if isTableRow(line), i + 1 < lines.count, !lazyLines.contains(i + 1), tableDelimiter.matches(lines[i + 1]) {
            output.append(trimRight(line))
            output.append(trimRight(lines[i + 1]))
            i += 2
            while i < lines.count, !lazyLines.contains(i), isTableRow(lines[i]), !blank.matches(lines[i]) {
                output.append(trimRight(lines[i]))
                i += 1
            }
            continue
        }

        if let openingQuote = blockquote.firstMatch(in: syntax) {
            var inner: [String] = []
            while i < lines.count, !lazyLines.contains(i), let match = blockquote.firstMatch(in: blockSyntax(lines[i], column: context.input)) {
                inner.append(match[2])
                i += 1
            }
            let rendered = processBlock(
                inner, width: nestedWidth(width, removing: 2),
                context: context.nested(input: openingQuote.rangeEnd(1), output: 2), lazyLines: []
            ).rendered
            output.append(contentsOf: rendered.map { $0.isEmpty ? ">" : "> " + $0 })
            continue
        }

        if let match = footnote.firstMatch(in: line) {
            let marker = "[^\(match[1])]: "
            let firstText = substring(line, fromUTF16Offset: match.rangeEnd(2))
            let item = processListItem(
                lines, start: i, marker: marker, firstText: firstText, width: width,
                context: context, parentLazyLines: lazyLines, allowsLazyLines: false
            )
            output.append(contentsOf: item.rendered)
            i = item.nextIndex
            continue
        }

        if let match = listMarker.firstMatch(in: line) {
            let marker = match[1] + match[2]
            let markerEnd = endColumn(marker, from: context.input)
            let padding = match[3]
            let paddingWidth = endColumn(padding, from: markerEnd) - markerEnd
            let inputPadding = paddingWidth <= 4 ? padding : " "
            let firstText = paddingWidth <= 4
                ? match[4]
                : dropIndent(padding, column: markerEnd, width: 1).text + match[4]
            let outputMarker = renderListMarker(
                leading: match[1], marker: match[2], padding: inputPadding,
                tabPadding: paddingWidth <= 4, context: context
            )
            let item = processListItem(
                lines, start: i, marker: marker + inputPadding, firstText: firstText, width: width,
                context: context, parentLazyLines: lazyLines, allowsLazyLines: true,
                outputMarker: outputMarker
            )
            if paddingWidth > 4, context.style == .preserve, !context.tabStopsShift {
                output.append(trimRight(line))
                output.append(contentsOf: item.rendered.dropFirst())
            } else {
                output.append(contentsOf: item.rendered)
            }
            i = item.nextIndex
            continue
        }

        var paragraph = [line]
        i += 1
        while i < lines.count, !blank.matches(lines[i]), !startsNewBlock(lines[i], column: context.input) {
            paragraph.append(lines[i])
            i += 1
        }
        output.append(contentsOf: wrapParagraphText(paragraph, width: width, column: context.output, repair: context.repair))
    }

    return (output, i)
}

private func tokenizeInline(_ text: String) -> [String] {
    var tokens: [String] = []
    var tokenEnd = 0

    // Adjacent source ranges form one token. Only source whitespace outside
    // an atomic span creates an opportunity to wrap.
    func appendToken(_ range: NSRange) {
        let token = substring(text, utf16Range: range)
        if !tokens.isEmpty, range.location == tokenEnd {
            tokens[tokens.count - 1] += token
        } else {
            tokens.append(token)
        }
        tokenEnd = range.location + range.length
    }

    func appendWords(from start: Int, to end: Int) {
        let gap = substring(text, utf16Range: NSRange(location: start, length: end - start))
        for word in inlineWords.matches(in: gap) {
            appendToken(NSRange(location: start + word.range.location, length: word.range.length))
        }
    }

    var cursor = 0
    for match in inlineAtomic.matches(in: text) {
        appendWords(from: cursor, to: match.range.location)
        appendToken(match.range)
        cursor = match.range.location + match.range.length
    }
    appendWords(from: cursor, to: text.utf16.count)
    return tokens
}

// Repair has its own lexer so the default tokenizer retains its behavior.
// Escapes, exact-length backtick delimiters, and other inline atoms are opaque.
private let repairAtomic = RegexPattern(
    #"\\[\s\S]|(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)|`+|!\[[^\]]*\]\([^)]*\)|\[[^\]]*\]\([^)]*\)|\[[^\]]*\](?:\[[^\]]*\])?|<[^ >]+>|https?://\S+"#
)

private func tokenizeRepairInline(_ source: String) -> [String] {
    func atomsAndMask(_ text: String) -> ([RegexMatch], [Bool]) {
        let atoms = repairAtomic.matches(in: text)
        var opaque = Array(repeating: false, count: text.utf16.count)
        for atom in atoms {
            for i in atom.range.location..<NSMaxRange(atom.range) { opaque[i] = true }
        }
        return (atoms, opaque)
    }

    let (sourceAtoms, sourceOpaque) = atomsAndMask(source)
    let original = source as NSString
    let edited = NSMutableString(string: source)
    // Only tighten closing parentheses that have an opener in this segment.
    var depth = 0
    var matchedClosers: Set<Int> = []
    for i in 0..<original.length where !sourceOpaque[i] {
        switch original.character(at: i) {
        case 40: depth += 1
        case 41 where depth > 0:
            depth -= 1
            matchedClosers.insert(i)
        default: break
        }
    }

    var removals: [NSRange] = []
    for atom in sourceAtoms where !atom[1].isEmpty {
        let end = NSMaxRange(atom.range)
        var right = end
        while right < original.length, original.character(at: right) == 32 || original.character(at: right) == 9 { right += 1 }
        guard matchedClosers.contains(right) else { continue }
        if right > end {
            removals.append(NSRange(location: end, length: right - end))
        }

        var left = atom.range.location
        while left > 0, original.character(at: left - 1) == 32 || original.character(at: left - 1) == 9 { left -= 1 }
        if left > 0, left < atom.range.location,
           original.character(at: left - 1) == 40, !sourceOpaque[left - 1] {
            removals.append(NSRange(location: left, length: atom.range.location - left))
        }
    }
    for range in removals.sorted(by: { $0.location > $1.location }) { edited.deleteCharacters(in: range) }
    let text = edited as String
    let (atoms, opaque) = atomsAndMask(text)
    let ns = text as NSString
    var ranges: [NSRange] = []
    func append(_ range: NSRange) {
        if let last = ranges.last, NSMaxRange(last) == range.location {
            ranges[ranges.count - 1].length += range.length
        } else { ranges.append(range) }
    }
    func words(_ start: Int, _ end: Int) {
        let gap = ns.substring(with: NSRange(location: start, length: end - start))
        for word in inlineWords.matches(in: gap) {
            append(NSRange(location: start + word.range.location, length: word.range.length))
        }
    }
    var cursor = 0
    for atom in atoms {
        words(cursor, atom.range.location)
        append(atom.range)
        cursor = NSMaxRange(atom.range)
    }
    words(cursor, ns.length)

    var tokens: [String] = []
    var previousEnd: Int? = nil
    for range in ranges {
        let end = NSMaxRange(range)
        let closes = ns.character(at: range.location) == 41 && !opaque[range.location]
        let opens = previousEnd.map { ns.character(at: $0 - 1) == 40 && !opaque[$0 - 1] } ?? false
        if !tokens.isEmpty, opens || closes {
            tokens[tokens.count - 1] += " " + ns.substring(with: range)
        } else { tokens.append(ns.substring(with: range)) }
        previousEnd = end
    }
    return tokens
}

private func wrapTokens(_ tokens: [String], width: Int, column: Int) -> [String] {
    if width == 0 {
        return [tokens.joined(separator: " ")]
    }

    var lines: [String] = []
    var current: [String] = []
    var currentLength = 0

    for token in tokens {
        let tokenStart = column + currentLength + (current.isEmpty ? 0 : 1)
        let nextLength = endColumn(token, from: tokenStart) - column
        if !current.isEmpty, nextLength > width {
            lines.append(current.joined(separator: " "))
            current = [token]
            currentLength = endColumn(token, from: column) - column
        } else {
            current.append(token)
            currentLength = nextLength
        }
    }

    if !current.isEmpty {
        lines.append(current.joined(separator: " "))
    }
    return lines.isEmpty ? [""] : lines
}

private func processCommitMessageBody(_ lines: [String], width: Int, indent: RewrapMarkdown.IndentStyle, repair: Bool) -> [String] {
    let trailerStart = commitTrailerBlockStart(in: lines)
    let bodyEnd = trailerStart ?? lines.count
    var output: [String] = []
    var pending: [String] = []

    func flushPending() {
        guard !pending.isEmpty else {
            return
        }
        output.append(contentsOf: processBlock(pending, width: width, indent: indent, repair: repair))
        pending.removeAll()
    }

    for line in lines[..<bodyEnd] {
        if commitComment.matches(line) {
            flushPending()
            output.append(line)
        } else {
            pending.append(line)
        }
    }
    flushPending()

    if let trailerStart {
        output.append(contentsOf: lines[trailerStart...])
    }
    return output
}

private func commitTrailerBlockStart(in lines: [String]) -> Int? {
    guard !lines.isEmpty else {
        return nil
    }

    var end = lines.count - 1
    while end >= 0, blank.matches(lines[end]) || commitComment.matches(lines[end]) {
        end -= 1
    }
    guard end >= 0 else {
        return nil
    }

    var start = end
    while start > 0,
          !blank.matches(lines[start - 1]),
          !commitComment.matches(lines[start - 1]) {
        start -= 1
    }

    var foundTrailer = false
    for line in lines[start...end] {
        if commitTrailer.matches(line) {
            foundTrailer = true
        } else if line.first == " " || line.first == "\t" {
            guard foundTrailer else {
                return nil
            }
        } else {
            return nil
        }
    }
    return foundTrailer ? start : nil
}

private func nestedWidth(_ width: Int, removing prefixLength: Int) -> Int {
    width == 0 ? 0 : max(1, width - prefixLength)
}

private func wrapParagraphText(_ rawLines: [String], width: Int, column: Int, repair: Bool) -> [String] {
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
        let tokens = repair ? tokenizeRepairInline(segment.text) : tokenizeInline(segment.text)
        var wrapped = tokens.isEmpty ? [""] : wrapTokens(tokens, width: width, column: column)
        if let breakStyle = segment.breakStyle, !wrapped.isEmpty {
            wrapped[wrapped.count - 1] += breakStyle
        }
        output.append(contentsOf: wrapped)
    }
    return output
}

private func startsNewBlock(_ line: String, column: Int) -> Bool {
    let syntax = blockSyntax(line, column: column)
    return isFenceStart(syntax)
        || atx.matches(syntax)
        || gfmAlertMarker.matches(syntax)
        || thematicBreak.matches(syntax)
        || isBlockquote(syntax)
        || listMarker.firstMatch(in: line) != nil
        || footnote.firstMatch(in: syntax) != nil
        || referenceDefinition.matches(syntax)
        || isHTMLBlockStart(syntax)
        || htmlCommentStart.matches(syntax)
        || leadingIndent(line, column: column) >= 4
}

private func processListItem(
    _ lines: [String],
    start i: Int,
    marker: String,
    firstText: String,
    width: Int,
    context: IndentContext,
    parentLazyLines: Set<Int>,
    allowsLazyLines: Bool,
    outputMarker: String? = nil
) -> (rendered: [String], nextIndex: Int) {
    let contentColumn = endColumn(marker, from: context.input) - context.input
    let firstPrefix = outputMarker ?? marker
    let outputWidth = endColumn(firstPrefix, from: context.output) - context.output
    var originalContinuation: (index: Int, prefix: String)?
    var item = [firstText]
    var lazyLines: Set<Int> = []
    var j = i + 1

    while j < lines.count {
        if blank.matches(lines[j]) {
            var k = j
            while k < lines.count, blank.matches(lines[k]) {
                k += 1
            }
            if k < lines.count, !parentLazyLines.contains(k), leadingIndent(lines[k], column: context.input) >= contentColumn {
                while j < k {
                    item.append("")
                    j += 1
                }
                continue
            }
            break
        }

        let indent = leadingIndent(lines[j], column: context.input)
        if !parentLazyLines.contains(j), indent >= contentColumn {
            let split = dropIndent(lines[j], column: context.input, width: contentColumn)
            if originalContinuation == nil,
               endColumn(split.prefix, from: context.input) == context.input + contentColumn {
                originalContinuation = (item.count, split.prefix)
            }
            item.append(split.text)
            j += 1
            continue
        }

        guard allowsLazyLines else { break }
        let text = String(lines[j].drop { $0 == " " || $0 == "\t" })
        if startsNewBlock(text, column: context.input)
            || (isTableRow(lines[j]) && j + 1 < lines.count
                && !parentLazyLines.contains(j + 1) && tableDelimiter.matches(lines[j + 1])) {
            break
        }
        lazyLines.insert(item.count)
        item.append(text)
        j += 1
    }

    let parsed = processBlock(
        item, width: nestedWidth(width, removing: outputWidth),
        context: context.nested(input: contentColumn, output: outputWidth), lazyLines: lazyLines
    )
    let useTabs = allowsLazyLines && (context.style == .tabs || firstPrefix.contains("\t"))
    var restPrefix = indentation(width: outputWidth, from: context.output, tabs: useTabs)
    if context.style == .preserve, let original = originalContinuation,
       original.index < parsed.consumed,
       endColumn(original.prefix, from: context.output) == context.output + outputWidth {
        restPrefix = original.prefix
    }
    let rendered = renderHanging(
        parsed.rendered, firstPrefix: firstPrefix, restPrefix: restPrefix, keepEmptyMarker: allowsLazyLines
    )
    // Each gathered line corresponds to one source line, including the marker line.
    return (rendered, i + parsed.consumed)
}

private func renderHanging(
    _ contentLines: [String], firstPrefix: String, restPrefix: String, keepEmptyMarker: Bool
) -> [String] {
    contentLines.enumerated().map { index, line in
        if line.isEmpty, index != 0 || !keepEmptyMarker {
            return ""
        }
        return (index == 0 ? firstPrefix : restPrefix) + line
    }
}

private func endColumn<S: StringProtocol>(_ text: S, from start: Int) -> Int {
    text.reduce(start) { column, character in
        column + (character == "\t" ? 4 - column % 4 : 1)
    }
}

private func leadingIndent(_ line: String, column: Int) -> Int {
    endColumn(line.prefix { $0 == " " || $0 == "\t" }, from: column) - column
}

// Expand leading tabs for structural tests, keeping the source for rendering.
private func blockSyntax(_ line: String, column: Int) -> String {
    let prefix = line.prefix { $0 == " " || $0 == "\t" }
    guard prefix.contains("\t") else { return line }
    return String(repeating: " ", count: endColumn(prefix, from: column) - column)
        + line.dropFirst(prefix.count)
}

private func dropIndent(_ line: String, column: Int, width: Int) -> (prefix: String, text: String) {
    let target = column + width
    var end = column
    var index = line.startIndex
    while end < target, index < line.endIndex {
        let character = line[index]
        guard character == " " || character == "\t" else { break }
        end += character == "\t" ? 4 - end % 4 : 1
        line.formIndex(after: &index)
    }
    let remainder = String(repeating: " ", count: max(0, end - target))
    return (String(line[..<index]), remainder + line[index...])
}

private func indentation(width: Int, from start: Int, tabs: Bool) -> String {
    let target = start + width
    var column = start
    var prefix = ""
    while tabs, column + 4 - column % 4 <= target {
        prefix += "\t"
        column += 4 - column % 4
    }
    return prefix + String(repeating: " ", count: target - column)
}

// Recreate only the portion the Markdown parser strips from a code line.
private func rebaseCodeIndent(_ line: String, width: Int, context: IndentContext) -> String {
    guard context.tabStopsShift, width > 0 else { return line }
    let removed = min(width, leadingIndent(line, column: context.input))
    return String(repeating: " ", count: removed)
        + dropIndent(line, column: context.input, width: removed).text
}

private func renderListMarker(
    leading: String, marker: String, padding: String, tabPadding: Bool, context: IndentContext
) -> String {
    let width = endColumn(leading, from: context.input) - context.input
    let leadingPrefix: String
    if context.style == .preserve, endColumn(leading, from: context.output) == context.output + width {
        leadingPrefix = leading
    } else {
        leadingPrefix = indentation(width: width, from: context.output, tabs: context.style == .tabs)
    }
    let inputEnd = context.input + width + marker.count
    let outputEnd = context.output + width + marker.count
    let paddingWidth = endColumn(padding, from: inputEnd) - inputEnd
    let outputPadding: String
    switch context.style {
    case .preserve where endColumn(padding, from: outputEnd) == outputEnd + paddingWidth:
        outputPadding = padding
    case .tabs where tabPadding:
        outputPadding = "\t"
    default:
        outputPadding = String(repeating: " ", count: paddingWidth)
    }
    return leadingPrefix + marker + outputPadding
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
