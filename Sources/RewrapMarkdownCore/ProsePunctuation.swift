// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct ProsePunctuation {
    enum Spacing {
        case remove
        case preserve

        func separator(for gap: String) -> String {
            guard gap.allSatisfy({ $0 == " " || $0 == "\t" }) else { return gap }
            return self == .remove ? "" : " "
        }
    }

    private static let closingMarks: [Unicode.Scalar: Spacing] = [
        ",": .remove, ".": .remove, "?": .remove, "!": .remove,
        ":": .preserve, ";": .preserve,
        "…": .preserve, "。": .preserve, "，": .preserve, "、": .preserve,
        "？": .preserve, "！": .preserve, "؟": .preserve, "،": .preserve,
        "；": .preserve, "：": .preserve, "؛": .preserve,
    ]
    private static let invertedMarks: Set<Unicode.Scalar> = ["¿", "¡"]
    private static let delimiterPairs: [Unicode.Scalar: Set<Unicode.Scalar>] = [
        "(": [")"], "{": ["}"],
        "\"": ["\""], "'": ["'"],
        "“": ["”"], "„": ["“", "”"], "‘": ["’"], "‚": ["‘", "’"],
        "«": ["»"], "»": ["«"], "‹": ["›"], "›": ["‹"],
        "（": ["）"], "「": ["」"], "『": ["』"],
    ]
    private static let codeEnclosures: Set<Unicode.Scalar> = ["(", "{"]
    private static let trailingClosers: Set<Unicode.Scalar> = [
        ")", "]", "}", "”", "’", "»", "›", "\"", "'", "）", "」", "』",
    ]
    private static let expressiveMarks: Set<Unicode.Scalar> = ["?", "!", "…", "？", "！", "؟"]
    private static let openingQuotes: Set<Unicode.Scalar> = ["“", "„", "‘", "‚"]
    private static let closingQuotes: Set<Unicode.Scalar> = ["”", "’"]
    private static let urlQuoteSuffix = try! NSRegularExpression(pattern: #"["'”’»›]+[.,!?;:]*$"#)

    // Expose trailing quotes for matching while keeping the entire URL token intact.
    static func bareURLQuoteStart(in text: String, range: NSRange) -> Int {
        urlQuoteSuffix.firstMatch(in: text, range: range)?.range.location ?? NSMaxRange(range)
    }

    private let text: NSString
    private let opaque: [Bool]
    private let repair: Bool
    private var openers: [Int: Int] = [:]
    private var closers: [Int: Int] = [:]

    init(text: NSString, opaque: [Bool], repair: Bool) {
        self.text = text
        self.opaque = opaque
        self.repair = repair
        matchDelimiters()
    }

    // A spacing rule joins the two tokens. Nil leaves a wrap opportunity.
    func spacing(
        after previous: NSRange, before next: NSRange,
        previousEndsInCode: Bool, previousEndsInBareURL: Bool, nextCodeEnd: Int?
    ) -> Spacing? {
        let left = NSMaxRange(previous) - 1
        let right = next.location
        let first = proseCharacter(at: right)
        let last = proseCharacter(at: left)

        // Moving a literal backslash to the end of the line creates a hard break.
        if last == "\\" { return .preserve }

        if let first, let spacing = sentenceMarkSpacing(first, at: right, in: next) {
            let word = text.substring(with: previous)
            // Preserve ambiguous numeric spacing and keep punctuation outside bare URLs.
            if previousEndsInBareURL || word.last?.isWhitespace == true
                || (first == "." && NSMaxRange(next) < text.length && word.allSatisfy(\.isNumber)) {
                return .preserve
            }
            return spacing
        }
        if let last, Self.invertedMarks.contains(last) {
            return first != nil || nextCodeEnd != nil ? .remove : .preserve
        }

        if repair, let opener = closers[right], let mark = proseCharacter(at: opener),
           Self.codeEnclosures.contains(mark), previousEndsInCode {
            return .remove
        }
        if repair, let closer = openers[left], let mark = last,
           Self.codeEnclosures.contains(mark), let nextCodeEnd,
           firstNonSpace(after: nextCodeEnd) == closer {
            return .remove
        }

        if openers[left] != nil || closers[right] != nil || last == "(" || first == ")" {
            return .preserve
        }
        // Directional quotes still face their text when another delimiter is unmatched.
        if let last, Self.openingQuotes.contains(last), closers[left] == nil { return .preserve }
        if let first, Self.closingQuotes.contains(first), !isWordCharacter(at: right + 1) {
            return .preserve
        }
        return nil
    }

    private func proseCharacter(at index: Int) -> Unicode.Scalar? {
        guard index < text.length, !opaque[index] else { return nil }
        return Unicode.Scalar(text.character(at: index))
    }

    private func firstNonSpace(after offset: Int) -> Int {
        var index = offset
        while let character = proseCharacter(at: index), character == " " || character == "\t" {
            index += 1
        }
        return index
    }

    private func sentenceMarkSpacing(_ mark: Unicode.Scalar, at index: Int, in token: NSRange) -> Spacing? {
        guard var spacing = Self.closingMarks[mark] else { return nil }
        var end = index + 1
        if mark == ".", proseCharacter(at: end) == ".", proseCharacter(at: end + 1) == "." {
            spacing = .preserve
            while proseCharacter(at: end) == "." { end += 1 }
        }
        if Self.expressiveMarks.contains(mark) {
            while let character = proseCharacter(at: end), Self.expressiveMarks.contains(character) {
                end += 1
            }
        }
        if end == NSMaxRange(token) { return spacing }

        // A mark may be followed by closing punctuation, as in ?!” or .).
        // A dot followed by a name or digit can be literal text.
        return (end..<NSMaxRange(token)).allSatisfy { offset in
            proseCharacter(at: offset).map { Self.trailingClosers.contains($0) } ?? false
        } ? spacing : nil
    }

    private mutating func matchDelimiters() {
        var stack: [(offset: Int, endings: Set<Unicode.Scalar>)] = []
        for index in 0..<text.length {
            guard let mark = proseCharacter(at: index) else { continue }
            let straightQuote = mark == "\"" || mark == "'"
            if (mark == "’" || mark == "'"), isWordCharacter(at: index - 1),
               isWordCharacter(at: index + 1) {
                continue
            }
            if let opener = stack.last, opener.endings.contains(mark),
               !straightQuote || !isWordCharacter(at: index + 1) {
                stack.removeLast()
                openers[opener.offset] = index
                closers[index] = opener.offset
            } else if let endings = Self.delimiterPairs[mark],
                      !straightQuote || !isWordCharacter(at: index - 1) {
                stack.append((index, endings))
            }
        }
    }

    private func isWordCharacter(at index: Int) -> Bool {
        guard index >= 0, index < text.length,
              let character = Unicode.Scalar(text.character(at: index)) else { return false }
        return CharacterSet.alphanumerics.contains(character) || CharacterSet.nonBaseCharacters.contains(character)
    }
}
