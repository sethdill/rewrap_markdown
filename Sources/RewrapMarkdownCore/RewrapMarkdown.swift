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

    public struct LineRange {
        public let start: Int
        public let end: Int

        public init?(_ argument: String) {
            let parts = argument.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
                  let start = Int(parts[0]), let end = Int(parts[1]),
                  start > 0, end >= start else { return nil }
            self.start = start
            self.end = end
        }
    }

    public struct LineRangeError: LocalizedError {
        public let range: LineRange
        public let lineCount: Int

        public var errorDescription: String? {
            "--lines \(range.start):\(range.end) is out of bounds for input with \(lineCount) lines."
        }
    }

    public static func rewrap(
        _ text: String, lines ranges: [LineRange], width: Int,
        indent: IndentStyle = .preserve, repair: Bool = false
    ) throws -> String {
        let source = sourceLines(text)
        for range in ranges where range.end > source.count {
            throw LineRangeError(range: range, lineCount: source.count)
        }

        var edits: [ProseEdit] = []
        let context = IndentContext(style: indent, repair: repair)
        _ = processBlock(source.map(\.text), width: normalizedWidth(width),
                         context: context, lazyLines: [], collect: { edits.append($0) })

        let sortedRanges = ranges.sorted { $0.start < $1.start }
        var selected: Set<Int> = []
        var rangeIndex = 0
        for edit in edits {
            while rangeIndex < sortedRanges.count, sortedRanges[rangeIndex].end <= edit.span.lowerBound {
                rangeIndex += 1
            }
            if rangeIndex < sortedRanges.count, sortedRanges[rangeIndex].start <= edit.span.upperBound {
                selected.insert(edit.group ?? edit.span.lowerBound)
            }
        }

        var output = ""
        var cursor = 0
        for edit in edits where selected.contains(edit.group ?? edit.span.lowerBound) {
            for line in source[cursor..<edit.span.lowerBound] {
                output += line.text + line.ending
            }
            let rendered = edit.render(normalizedWidth(width), 0)
            let last = edit.span.upperBound - 1
            for (index, line) in rendered.enumerated() {
                let ending = index == rendered.count - 1 ? source[last].ending
                    : source[min(edit.span.lowerBound + index, max(edit.span.lowerBound, last - 1))].ending
                output += line + (index < rendered.count - 1 && ending.isEmpty ? "\n" : ending)
            }
            cursor = edit.span.upperBound
        }
        for line in source[cursor...] {
            output += line.text + line.ending
        }
        return output
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
private let htmlDeclarationStart = RegexPattern(#"^ {0,3}<(?:\?|![A-Za-z]|!\[CDATA\[)"#)
private let gfmAlertMarker = RegexPattern(#"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$"#)
// Only an odd run of backslashes ends in an unescaped hard-break marker.
private let hardBreak = RegexPattern(#"(?<!\\)(?:\\\\)*(\\)$| {2,}$"#)
private let commitComment = RegexPattern(#"^[ \t]*#"#)
private let commitTrailer = RegexPattern(#"^[A-Za-z0-9][A-Za-z0-9-]*[ \t]*[:=][ \t]+.+$"#)
private func sourceLines(_ text: String) -> [(text: String, ending: String)] {
    var lines: [(String, String)] = []
    var start = text.startIndex
    for index in text.indices {
        let character = text[index]
        if character == "\n" || character == "\r" || character == "\r\n" {
            lines.append((String(text[start..<index]), String(character)))
            start = text.index(after: index)
        }
    }
    if start < text.endIndex {
        lines.append((String(text[start...]), ""))
    }
    return lines
}

// Spans are local to the current container. The renderer receives the width
// and output column after its enclosing prefixes have been accounted for.
private struct ProseEdit {
    var span: Range<Int>
    var group: Int?
    var direct = true
    var render: (Int, Int) -> [String]

    func nested(at offset: Int, render: @escaping (Int, Int) -> [String]) -> Self {
        Self(span: (span.lowerBound + offset)..<(span.upperBound + offset),
             group: group.map { $0 + offset },
             direct: false, render: render)
    }
}

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
    _ lines: [String], width: Int, context: IndentContext, lazyLines: Set<Int>,
    collect: ((ProseEdit) -> Void)? = nil
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
            let start = i
            var inner: [String] = []
            while i < lines.count, !lazyLines.contains(i), let match = blockquote.firstMatch(in: blockSyntax(lines[i], column: context.input)) {
                inner.append(match[2])
                i += 1
            }
            let prefixLength = openingQuote.rangeEnd(1)
            let prefix = substring(syntax, toUTF16Offset: prefixLength)
            let collectQuoted: ((ProseEdit) -> Void)? = collect.map { collect in
                { edit in
                    collect(edit.nested(at: start) { width, column in
                        edit.render(nestedWidth(width, removing: prefixLength), column + prefixLength)
                            .map { $0.isEmpty ? trimRight(prefix) : prefix + $0 }
                    })
                }
            }
            let rendered = processBlock(
                inner, width: nestedWidth(width, removing: 2),
                context: context.nested(input: openingQuote.rangeEnd(1), output: 2), lazyLines: [], collect: collectQuoted
            ).rendered
            output.append(contentsOf: rendered.map { $0.isEmpty ? ">" : "> " + $0 })
            continue
        }

        if let match = footnote.firstMatch(in: line) {
            let marker = "[^\(match[1])]: "
            let firstText = substring(line, fromUTF16Offset: match.rangeEnd(2))
            let item = processListItem(
                lines, start: i, marker: marker, firstText: firstText, width: width,
                context: context, parentLazyLines: lazyLines, allowsLazyLines: false, collect: collect
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
            let outputMarker: (Int) -> String = { column in
                renderListMarker(leading: match[1], marker: match[2], padding: inputPadding,
                                 tabPadding: paddingWidth <= 4,
                                 context: context.nested(input: 0, output: column - context.output))
            }
            let item = processListItem(
                lines, start: i, marker: marker + inputPadding, firstText: firstText, width: width,
                context: context, parentLazyLines: lazyLines, allowsLazyLines: true,
                outputMarker: outputMarker, collect: collect
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

        let start = i
        var paragraph = [line]
        i += 1
        while i < lines.count, !blank.matches(lines[i]), !startsNewBlock(lines[i], column: context.input) {
            paragraph.append(lines[i])
            i += 1
        }
        if let collect {
            let span = start..<i
            collect(ProseEdit(span: span) { width, column in
                wrapParagraphText(paragraph, width: width, column: column, repair: context.repair)
            })
        } else {
            output.append(contentsOf: wrapParagraphText(paragraph, width: width, column: context.output, repair: context.repair))
        }
    }

    return (output, i)
}

// Markdown syntax is opaque to punctuation rules. Treat bare square brackets
// as potentially referencing definitions outside the supplied text.
private let bracketedText = #"\[(?:\\.|[^\[\]\\]|\[[^\[\]]*\])*\]"#
private let linkDestination = #"\((?:\\.|[^()\\]|\([^()]*\))*\)"#
private let inlineAtomic = RegexPattern([
    #"\\[!-/:-@\[-`{-~]"#, // Markdown escape
    #"(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)|`+"#, // Code span or unmatched backtick run
    #"!?\#(bracketedText)\#(linkDestination)|\#(bracketedText)(?:\#(bracketedText))?"#,
    #"<!--.*?-->|</?[a-zA-Z][a-zA-Z0-9-]*(?:[^<>"']|"[^"]*"|'[^']*')*>"#,
    #"<[^ >]+>|(https?://\S+)"#, // Autolink or bare URL
    #"\{\{.*?\}\}|\{%.*?%\}|\$\{[^}]*\}"#, // Common template delimiters
].joined(separator: "|"))
// Nonbreaking spaces are part of a word rather than wrap opportunities.
private let inlineWords = RegexPattern(#"(?:\S|[\u00A0\u202F])+"#)

private func tokenizeInline(_ source: String, repair: Bool) -> [String] {
    let text = source as NSString
    var opaque = Array(repeating: false, count: text.length)
    var codeStarts: [Int: Int] = [:]
    var codeEnds: Set<Int> = []
    var bareURLEnds: Set<Int> = []
    var ranges: [NSRange] = []

    // Adjacent source ranges form a single token.
    func append(_ range: NSRange) {
        if let last = ranges.last, NSMaxRange(last) == range.location {
            ranges[ranges.count - 1].length += range.length
        } else {
            ranges.append(range)
        }
    }

    func appendWords(from start: Int, to end: Int) {
        let gap = text.substring(with: NSRange(location: start, length: end - start))
        for word in inlineWords.matches(in: gap) {
            append(NSRange(location: start + word.range.location, length: word.range.length))
        }
    }

    var cursor = 0
    for atom in inlineAtomic.matches(in: source) {
        let start = atom.range.location
        let end = NSMaxRange(atom.range)
        appendWords(from: cursor, to: start)
        append(atom.range)
        for index in start..<end { opaque[index] = true }
        if !atom[1].isEmpty {
            codeStarts[start] = end
            codeEnds.insert(end)
        } else if !atom[2].isEmpty {
            bareURLEnds.insert(end)
        }
        cursor = end
    }
    appendWords(from: cursor, to: text.length)

    let punctuation = ProsePunctuation(text: text, opaque: opaque, repair: repair)
    var tokens: [String] = []
    var previous: NSRange?
    for range in ranges {
        let word = text.substring(with: range)
        if let previous, let spacing = punctuation.spacing(
            after: previous, before: range,
            previousEndsInCode: codeEnds.contains(NSMaxRange(previous)),
            previousEndsInBareURL: bareURLEnds.contains(NSMaxRange(previous)),
            nextCodeEnd: codeStarts[range.location]
        ) {
            let end = NSMaxRange(previous)
            let gap = text.substring(with: NSRange(location: end, length: range.location - end))
            tokens[tokens.count - 1] += spacing.separator(for: gap) + word
        } else {
            tokens.append(word)
        }
        previous = range
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

    for token in keepMarkdownMarkersWithProse(tokens, column: column) {
        let tokenStart = column + currentLength + (current.isEmpty ? 0 : 1)
        let nextLength = endColumn(token, from: tokenStart) - column
        if !current.isEmpty, nextLength > width {
            let line = current.joined(separator: " ")
            // Opening punctuation in prose can become a block if it stands alone.
            if !lines.isEmpty || !startsWrappedBlock(line, column: column) {
                lines.append(line)
                current = [token]
                currentLength = endColumn(token, from: column) - column
                continue
            }
        }
        current.append(token)
        currentLength = nextLength
    }

    if !current.isEmpty {
        lines.append(current.joined(separator: " "))
    }
    return lines.isEmpty ? [""] : lines
}

private func keepMarkdownMarkersWithProse(_ tokens: [String], column: Int) -> [String] {
    guard !tokens.isEmpty else { return [] }
    var groups: [String] = []
    var start = 0

    for index in 1...tokens.count {
        if index < tokens.count, couldStartWrappedBlock(tokens, at: index, column: column) {
            continue
        }
        groups.append(tokens[start..<index].joined(separator: " "))
        start = index
    }
    return groups
}

private func couldStartWrappedBlock(_ tokens: [String], at index: Int, column: Int) -> Bool {
    let token = tokens[index]
    guard let initial = token.first,
          initial.isNumber || "-+*#>[`~<=_|:".contains(initial) else {
        return false
    }
    let next = index + 1 < tokens.count ? tokens[index + 1] : ""
    let pair = token + " " + next
    // Look ahead for list content and for spaced thematic breaks like "_ _ _".
    return startsWrappedBlock(token, column: column)
        || startsWrappedBlock(pair, column: column)
        || (index + 2 < tokens.count && thematicBreak.matches(pair + " " + tokens[index + 2]))
}

private func startsWrappedBlock(_ line: String, column: Int) -> Bool {
    startsNewBlock(line, column: column)
        || setextH1.matches(line)
        || setextH2.matches(line)
        || tableDelimiter.matches(line)
        || htmlDeclarationStart.matches(line)
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

private let paragraphBoundarySpaces: Set<Character> = ["\u{00A0}", "\u{2009}", "\u{202F}"]
private let paragraphWhitespace = CharacterSet.whitespacesAndNewlines.subtracting(
    CharacterSet(charactersIn: "\u{00A0}\u{2009}\u{202F}")
)

private func joinParagraphLines(_ lines: [String]) -> String {
    var joined = ""
    for line in lines where !line.isEmpty {
        if let last = joined.last, let first = line.first,
           !paragraphBoundarySpaces.contains(last), !paragraphBoundarySpaces.contains(first) {
            joined += " "
        }
        joined += line
    }
    return joined
}

private func wrapParagraphText(_ rawLines: [String], width: Int, column: Int, repair: Bool) -> [String] {
    var segments: [(text: String, breakStyle: String?)] = []
    var buffer: [String] = []

    for line in rawLines {
        let stripped = line.trimmingCharacters(in: paragraphWhitespace)
        if let match = hardBreak.firstMatch(in: line), !stripped.isEmpty {
            let breakStyle = match[1] == "\\" ? "\\" : "  "
            let textPart = breakStyle == "\\"
                ? String(line.dropLast())
                : substring(line, toUTF16Offset: match.range.location)
            buffer.append(textPart.trimmingCharacters(in: paragraphWhitespace))
            segments.append((joinParagraphLines(buffer), breakStyle))
            buffer.removeAll()
        } else {
            buffer.append(stripped)
        }
    }

    if !buffer.isEmpty {
        segments.append((joinParagraphLines(buffer), nil))
    }

    var output: [String] = []
    for segment in segments {
        let tokens = tokenizeInline(segment.text, repair: repair)
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
    outputMarker: ((Int) -> String)? = nil,
    collect: ((ProseEdit) -> Void)? = nil
) -> (rendered: [String], nextIndex: Int) {
    let contentColumn = endColumn(marker, from: context.input) - context.input
    let firstPrefix = outputMarker?(context.output) ?? marker
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

    var edits: [ProseEdit] = []
    let collectItem: ((ProseEdit) -> Void)? = collect.map { _ in { edits.append($0) } }
    let parsed = processBlock(
        item, width: nestedWidth(width, removing: outputWidth),
        context: context.nested(input: contentColumn, output: outputWidth), lazyLines: lazyLines, collect: collectItem
    )
    let consumed = parsed.consumed
    func continuationPrefix(_ prefix: String, width: Int, column: Int) -> String {
        if context.style == .preserve, let original = originalContinuation,
           original.index < consumed,
           endColumn(original.prefix, from: column) == column + width {
            return original.prefix
        }
        let useTabs = allowsLazyLines && (context.style == .tabs || prefix.contains("\t"))
        return indentation(width: width, from: column, tabs: useTabs)
    }

    if let collect {
        // Direct prose shares an item selection. Descendant items have their own.
        let group = edits.first(where: \.direct)?.span.lowerBound
        for var edit in edits {
            if edit.direct {
                edit.group = group
            }
            let startsItem = edit.span.lowerBound == 0
            let coversItem = startsItem && edit.span.upperBound == consumed
            collect(edit.nested(at: i) { width, column in
                // Keep the content column stable when other parts of the item
                // remain in the source, including nested items and code.
                let preferred = outputMarker?(column) ?? marker
                let preferredWidth = endColumn(preferred, from: column) - column
                let prefix = coversItem || preferredWidth == contentColumn ? preferred : marker
                let prefixWidth = endColumn(prefix, from: column) - column
                let continuation = continuationPrefix(prefix, width: prefixWidth, column: column)
                let rendered = edit.render(nestedWidth(width, removing: prefixWidth), column + prefixWidth)
                return renderHanging(rendered, firstPrefix: startsItem ? prefix : continuation,
                                     restPrefix: continuation, keepEmptyMarker: startsItem && allowsLazyLines)
            })
        }
        return ([], i + parsed.consumed)
    }
    let restPrefix = continuationPrefix(firstPrefix, width: outputWidth, column: context.output)
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
