#!/usr/bin/env python3
"""
Intelligent Markdown rewrap filter, designed for use as a BBEdit "#!" text
filter (or any Unix filter: stdin in, stdout out).

Copyright 2026 Seth Dillingham.
Licensed under the Apache License, Version 2.0. See LICENSE and NOTICE in the
project root.

Select a range of Markdown text in BBEdit, run this as a Unix filter, and the
selection is replaced with the same Markdown reflowed to a maximum line
width.

Behavior:
  * Plain paragraphs are reflowed to the target width.
  * Bulleted / numbered list items (including nested lists) are reflowed with
    a hanging indent so wrapped continuation lines align under the item's
    text, not under the marker.
  * Blockquotes (including nested ">" levels, and blockquotes containing
    lists) are reflowed with the quote markers preserved and reapplied.
  * Fenced code blocks (``` or ~~~), tables, headings (ATX and setext),
    thematic breaks, footnote definitions, and HTML blocks are never
    rewrapped -- their content passes through unchanged.
  * Inline code spans, links, images, autolinks, and bare URLs are treated
    as atomic and are never split across a line break.
  * Manual hard line breaks (trailing backslash or 2+ trailing spaces) are
    preserved as forced breaks; text is not merged across them, but each
    side is still individually wrapped.
  * Original bullet characters and ordered-list numbers are preserved
    exactly; only the wrapping/indentation of continuation lines changes.

Wrap width resolution order (first one found wins):
  1. Numeric command-line argument, e.g. `rewrap_markdown.py 100`
  2. MD_REWRAP_WIDTH environment variable
  3. DEFAULT_WIDTH, or DEFAULT_COMMIT_MESSAGE_WIDTH with `--commit`

Use `--unwrap` or width 0 to join paragraphs and list items onto one line.
Use `--commit` to preserve a commit message's subject, comment lines, and
trailer block while rewrapping its body.

This is a pragmatic, hand-rolled parser (no third-party dependencies), not a
full CommonMark implementation. It's tuned for typical hand-written
Markdown, not for pathological edge cases.
"""

import os
import re
import sys
import unicodedata
from typing import Callable, Literal, NamedTuple, Optional

VERSION = "0.4"
DEFAULT_WIDTH = 70
DEFAULT_COMMIT_MESSAGE_WIDTH = 72
BreakStyle = Literal["\\", "  "]

# ---------------------------------------------------------------------------
# Regex patterns for block-level constructs
# ---------------------------------------------------------------------------

BLANK_RE = re.compile(r"^\s*$")
FENCE_RE = re.compile(r"^( {0,3})(`{3,}|~{3,})\s*(.*)$")
ATX_RE = re.compile(r"^ {0,3}#{1,6}(?:\s+.*|)$")
HR_RE = re.compile(r"^ {0,3}(?:-(?:[ \t]*-){2,}|\*(?:[ \t]*\*){2,}|_(?:[ \t]*_){2,})[ \t]*$")
SETEXT_H1_RE = re.compile(r"^ {0,3}=+ *$")
SETEXT_H2_RE = re.compile(r"^ {0,3}-+ *$")
BLOCKQUOTE_RE = re.compile(r"^ {0,3}>( ?)(.*)$")
LIST_MARKER_RE = re.compile(r"^([ \t]*)([-*+]|\d{1,9}[.)])([ \t]+)(.*)$")
FOOTNOTE_RE = re.compile(r"^\[\^([^\]]+)\]:( +)(.*)$")
REFERENCE_DEFINITION_RE = re.compile(r"^ {0,3}\[[^\]]+\]:\s+\S+.*$")
TABLE_DELIM_RE = re.compile(r"^ {0,3}\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$")
HTML_BLOCK_START_RE = re.compile(
    r"^ {0,3}</?[a-zA-Z][a-zA-Z0-9-]*(?:\s|/?>|$)"
)
HTML_COMMENT_START_RE = re.compile(r"^ {0,3}<!--")
HTML_COMMENT_END_RE = re.compile(r"-->\s*$")
HTML_DECLARATION_START_RE = re.compile(r"^ {0,3}<(?:\?|![A-Za-z]|!\[CDATA\[)")
FRONT_MATTER_DELIM_RE = re.compile(r"^-{3,}\s*$")
GFM_ALERT_MARKER_RE = re.compile(r"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$")
# Only an odd run of backslashes ends in an unescaped hard-break marker.
HARD_BREAK_RE = re.compile(r"(?<!\\)(?:\\\\)*(\\)$| {2,}$")
COMMIT_COMMENT_RE = re.compile(r"^[ \t]*#")
COMMIT_TRAILER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]*[ \t]*[:=][ \t]+.+$")

# Keep Markdown syntax opaque to punctuation rules, including bracketed text
# that may reference a definition outside the supplied text.
BRACKETED_TEXT = r"\[(?:\\.|[^\[\]\\]|\[[^\[\]]*\])*\]"
LINK_DESTINATION = r"\((?:\\.|[^()\\]|\([^()]*\))*\)"
INLINE_ATOMIC_RE = re.compile("|".join([
    r"\\[!-/:-@\[-`{-~]",  # Markdown escape
    r"(?<!`)(?P<backticks>`+)(?!`).*?(?<!`)(?P=backticks)(?!`)|`+",
    rf"!?{BRACKETED_TEXT}{LINK_DESTINATION}|{BRACKETED_TEXT}(?:{BRACKETED_TEXT})?",
    r"""<!--.*?-->|</?[a-zA-Z][a-zA-Z0-9-]*(?:[^<>"']|"[^"]*"|'[^']*')*>""",
    r"<[^ >]+>|(?P<url>https?://\S+)",
    r"\{\{.*?\}\}|\{%.*?%\}|\$\{[^}]*\}",  # Common template delimiters
]))
INLINE_WORD_RE = re.compile(r"(?:\S|[\u00A0\u202F])+")
PARAGRAPH_BOUNDARY_SPACES = "\u00A0\u2009\u202F"
PARAGRAPH_EDGE_WHITESPACE_RE = re.compile(r"^[^\S\u00A0\u2009\u202F]+|[^\S\u00A0\u2009\u202F]+$")


def normalize_width(width: int) -> int:
    return 0 if width == 0 else max(1, width)


def get_width(arguments: list[str], fallback: int = DEFAULT_WIDTH) -> int:
    for argument in arguments:
        try:
            return normalize_width(int(argument))
        except ValueError:
            continue

    env = os.environ.get("MD_REWRAP_WIDTH")
    if env:
        try:
            return normalize_width(int(env))
        except ValueError:
            pass

    return normalize_width(fallback)


def version_string() -> str:
    return f"rewrap-markdown {VERSION}"


def usage_string() -> str:
    return """Usage: rewrap-markdown [--check] [--lines START:END]... [--width-unit=utf16] [--unwrap] [--commit] [--repair] [--indent=preserve|tabs|spaces] [WIDTH]

Read Markdown from standard input and write the transformed text to standard output.

  --check   Compare UTF-8 bytes without writing formatted output.
            Exit 0 if unchanged, 1 if different, or 2 for argument or input errors.
  --lines   Rewrap blocks touching inclusive, 1-based input lines. Repeatable.
            Incompatible with --commit.
  --width-unit=utf16  Measure wrap width in UTF-16 code units.
  --unwrap  Join paragraphs and list items onto one line (equivalent to width 0).
  --commit  Preserve the subject, comments, and trailers of a Git commit message.
  --repair  Fix spacing around inline code enclosed in parentheses or braces.
  --indent  Set the list indentation style (default: preserve).
  --version Print the version."""


# ---------------------------------------------------------------------------
# Inline tokenizing / wrapping
# ---------------------------------------------------------------------------


class ProsePunctuation:
    # Values are the separator to use in place of ordinary spaces or tabs.
    # None means the wrapper may break between the tokens.
    CLOSING_MARKS = {
        ",": "", ".": "", "?": "", "!": "",
        ":": " ", ";": " ",
        "…": " ", "。": " ", "，": " ", "、": " ",
        "？": " ", "！": " ", "؟": " ", "،": " ",
        "；": " ", "：": " ", "؛": " ",
    }
    INVERTED_MARKS = {"¿", "¡"}
    DELIMITER_PAIRS = {
        "(": {")"}, "{": {"}"},
        '"': {'"'}, "'": {"'"},
        "“": {"”"}, "„": {"“", "”"}, "‘": {"’"}, "‚": {"‘", "’"},
        "«": {"»"}, "»": {"«"}, "‹": {"›"}, "›": {"‹"},
        "（": {"）"}, "「": {"」"}, "『": {"』"},
    }
    CODE_ENCLOSURES = {"(", "{"}
    TRAILING_CLOSERS = {")", "]", "}", "”", "’", "»", "›", '"', "'", "）", "」", "』"}
    EXPRESSIVE_MARKS = {"?", "!", "…", "？", "！", "؟"}

    OPENING_QUOTES = {"“", "„", "‘", "‚"}
    CLOSING_QUOTES = {"”", "’"}
    URL_QUOTE_SUFFIX = re.compile(r"""["'”’»›]+[.,!?;:]*$""")

    @staticmethod
    def bare_url_quote_start(text: str, start: int, end: int) -> int:
        # Expose trailing quotes while keeping the entire URL token intact.
        match = ProsePunctuation.URL_QUOTE_SUFFIX.search(text, start, end)
        return match.start() if match else end

    def __init__(self, text: str, opaque: list[bool], repair: bool):
        self.text = text
        self.opaque = opaque
        self.repair = repair
        self.openers: dict[int, int] = {}
        self.closers: dict[int, int] = {}
        self.match_delimiters()

    def spacing(
        self, previous: tuple[int, int], following: tuple[int, int], *,
        previous_ends_in_code: bool, previous_ends_in_bare_url: bool,
        next_code_end: Optional[int],
    ) -> Optional[str]:
        left = previous[1] - 1
        right = following[0]
        first = self.prose_character(right)
        last = self.prose_character(left)

        # Moving a literal backslash to the end of the line creates a hard break.
        if last == "\\":
            return " "

        spacing = self.sentence_mark_spacing(first, following)
        if spacing is not None:
            word = self.text[previous[0]:previous[1]]
            # Preserve ambiguous numeric spacing and keep punctuation outside bare URLs.
            if (previous_ends_in_bare_url or word[-1].isspace()
                    or (first == "." and following[1] < len(self.text) and word.isnumeric())):
                return " "
            return spacing
        if last in self.INVERTED_MARKS:
            return "" if first is not None or next_code_end is not None else " "

        opener = self.closers.get(right)
        if (self.repair and opener is not None and self.prose_character(opener) in self.CODE_ENCLOSURES
                and previous_ends_in_code):
            return ""
        closer = self.openers.get(left)
        if (self.repair and closer is not None and last in self.CODE_ENCLOSURES and next_code_end is not None
                and self.first_non_space(next_code_end) == closer):
            return ""

        if left in self.openers or right in self.closers or last == "(" or first == ")":
            return " "
        # Directional quotes still face their text when another delimiter is unmatched.
        if last in self.OPENING_QUOTES and left not in self.closers:
            return " "
        if first in self.CLOSING_QUOTES and not self.is_word_character(right + 1):
            return " "
        return None

    def prose_character(self, index: int) -> Optional[str]:
        if 0 <= index < len(self.text) and not self.opaque[index]:
            return self.text[index]
        return None

    def first_non_space(self, index: int) -> int:
        while self.prose_character(index) in {" ", "\t"}:
            index += 1
        return index

    def sentence_mark_spacing(self, mark: Optional[str], token: tuple[int, int]) -> Optional[str]:
        if mark is None or mark not in self.CLOSING_MARKS:
            return None
        spacing = self.CLOSING_MARKS[mark]
        end = token[0] + 1
        if mark == "." and self.prose_character(end) == self.prose_character(end + 1) == ".":
            spacing = " "
            while self.prose_character(end) == ".":
                end += 1
        if mark in self.EXPRESSIVE_MARKS:
            while self.prose_character(end) in self.EXPRESSIVE_MARKS:
                end += 1
        # Closing delimiters can follow a mark, as in ?!” or .).
        # A dot followed by a name or digit can be literal text.
        if all(self.prose_character(index) in self.TRAILING_CLOSERS
               for index in range(end, token[1])):
            return spacing
        return None

    def match_delimiters(self) -> None:
        stack: list[tuple[int, set[str]]] = []
        for index in range(len(self.text)):
            mark = self.prose_character(index)
            if mark is None:
                continue
            straight_quote = mark in {'"', "'"}
            if (mark in {"’", "'"} and self.is_word_character(index - 1)
                    and self.is_word_character(index + 1)):
                continue
            if (stack and mark in stack[-1][1]
                    and (not straight_quote or not self.is_word_character(index + 1))):
                opener, _ = stack.pop()
                self.openers[opener] = index
                self.closers[index] = opener
            elif mark in self.DELIMITER_PAIRS and (
                not straight_quote or not self.is_word_character(index - 1)
            ):
                stack.append((index, self.DELIMITER_PAIRS[mark]))

    def is_word_character(self, index: int) -> bool:
        if not 0 <= index < len(self.text):
            return False
        return self.text[index].isalnum() or unicodedata.category(self.text[index]).startswith("M")


def tokenize_inline(text: str, repair: bool = False) -> list[str]:
    opaque = [False] * len(text)
    code_starts: dict[int, int] = {}
    code_ends: set[int] = set()
    bare_url_ends: set[int] = set()
    ranges: list[tuple[int, int]] = []

    def append_range(start: int, end: int) -> None:
        if ranges and ranges[-1][1] == start:
            ranges[-1] = (ranges[-1][0], end)
        else:
            ranges.append((start, end))

    def append_words(start: int, end: int) -> None:
        for word in INLINE_WORD_RE.finditer(text, start, end):
            append_range(*word.span())

    cursor = 0
    for atom in INLINE_ATOMIC_RE.finditer(text):
        start, end = atom.span()
        append_words(cursor, start)
        append_range(start, end)
        opaque_end = ProsePunctuation.bare_url_quote_start(text, start, end) if atom.group("url") else end
        opaque[start:opaque_end] = [True] * (opaque_end - start)
        if atom.group("backticks"):
            code_starts[start] = end
            code_ends.add(end)
        elif atom.group("url"):
            bare_url_ends.add(end)
        cursor = end
    append_words(cursor, len(text))

    punctuation = ProsePunctuation(text, opaque, repair)
    tokens: list[str] = []
    previous: Optional[tuple[int, int]] = None
    for start, end in ranges:
        word = text[start:end]
        spacing = None
        if previous is not None:
            spacing = punctuation.spacing(
                previous, (start, end),
                previous_ends_in_code=previous[1] in code_ends,
                previous_ends_in_bare_url=previous[1] in bare_url_ends,
                next_code_end=code_starts.get(start),
            )
        if previous is None or spacing is None:
            tokens.append(word)
        else:
            gap = text[previous[1]:start]
            separator = spacing if all(char in " \t" for char in gap) else gap
            tokens[-1] += separator + word
        previous = (start, end)
    return tokens


def starts_wrapped_block(line: str, column: int) -> bool:
    return bool(
        starts_new_block(line, column)
        or SETEXT_H1_RE.match(line)
        or SETEXT_H2_RE.match(line)
        or TABLE_DELIM_RE.match(line)
        or HTML_DECLARATION_START_RE.match(line)
    )


def could_start_wrapped_block(tokens: list[str], index: int, column: int) -> bool:
    token = tokens[index]
    initial = token[0]
    if not (initial.isnumeric() or initial in "-+*#>[`~<=_|:"):
        return False
    following = tokens[index + 1] if index + 1 < len(tokens) else ""
    pair = token + " " + following
    # Look ahead for list content and for spaced thematic breaks like "_ _ _".
    return (
        starts_wrapped_block(token, column)
        or starts_wrapped_block(pair, column)
        or (index + 2 < len(tokens) and HR_RE.match(pair + " " + tokens[index + 2]) is not None)
    )


def keep_markdown_markers_with_prose(tokens: list[str], column: int) -> list[str]:
    groups: list[str] = []
    start = 0
    for index in range(1, len(tokens) + 1):
        if index < len(tokens) and could_start_wrapped_block(tokens, index, column):
            continue
        groups.append(" ".join(tokens[start:index]))
        start = index
    return groups


def wrap_tokens(tokens: list[str], width: int, column: int, utf16_width: bool) -> list[str]:
    """
    Greedy word-wrap a token stream to `width` columns. A single token longer
    than `width` is placed alone on its own (over-length) line rather than
    being split.
    """
    if width == 0:
        return [" ".join(tokens)]

    lines: list[str] = []
    current: list[str] = []
    current_len: int = 0
    tok: str
    
    for tok in keep_markdown_markers_with_prose(tokens, column):
        token_start = column + current_len + (1 if current else 0)
        next_len = end_column(tok, token_start, utf16_width) - column
        if current and next_len > width:
            line = " ".join(current)
            # Opening punctuation in prose can become a block if it stands alone.
            if lines or not starts_wrapped_block(line, column):
                lines.append(line)
                current = [tok]
                current_len = end_column(tok, column, utf16_width) - column
                continue
        current.append(tok)
        current_len = next_len
    
    if current:
        lines.append(" ".join(current))
    
    return lines or [""]


def join_paragraph_lines(lines: list[str]) -> str:
    parts: list[str] = []
    for line in lines:
        if not line:
            continue
        if (parts and parts[-1][-1] not in PARAGRAPH_BOUNDARY_SPACES
                and line[0] not in PARAGRAPH_BOUNDARY_SPACES):
            parts.append(" ")
        parts.append(line)
    return "".join(parts)


def wrap_paragraph_text(raw_lines: list[str], width: int, column: int, repair: bool, utf16_width: bool) -> list[str]:
    """
    Reflow a paragraph's raw source lines to `width` columns.

    Soft-wrapped source lines are merged and re-flowed freely. A manual hard
    break (trailing backslash, or 2+ trailing spaces) at the end of a source
    line is preserved as a forced break point; each side of it is still
    individually wrapped.
    """
    
    segments: list[tuple[str, Optional[BreakStyle]]] = []
    buf: list[str] = []
    
    for line in raw_lines:
        stripped = PARAGRAPH_EDGE_WHITESPACE_RE.sub("", line)
        m = HARD_BREAK_RE.search(line)
        
        if m and stripped:
            break_style = "\\" if m.group(1) == "\\" else "  "
            # strip the break marker itself from the text
            text_part = line[:-1] if break_style == "\\" else line[:m.start()]
            buf.append(PARAGRAPH_EDGE_WHITESPACE_RE.sub("", text_part))
            segments.append((join_paragraph_lines(buf), break_style))
            buf = []
        else:
            buf.append(stripped)
    
    if buf:
        segments.append((join_paragraph_lines(buf), None))

    out_lines: list[str] = []
    for text, break_style in segments:
        tokens = tokenize_inline(text, repair)
        wrapped = wrap_tokens(tokens, width, column, utf16_width) if tokens else [""]
        if break_style is not None and wrapped:
            wrapped[-1] = wrapped[-1] + break_style
        out_lines.extend(wrapped)
    
    return out_lines


# ---------------------------------------------------------------------------
# Block-level parsing
# ---------------------------------------------------------------------------


def end_column(text: str, column: int, utf16_width: bool = False) -> int:
    for character in text:
        if character == "\t":
            column += 4 - column % 4
        else:
            column += 2 if utf16_width and ord(character) > 0xFFFF else 1
    return column


def leading_indent(line: str, column: int) -> int:
    prefix = line[:len(line) - len(line.lstrip(" \t"))]
    return end_column(prefix, column) - column


def block_syntax(line: str, column: int) -> str:
    # Expand leading tabs for structural tests, keeping the source for rendering.
    text = line.lstrip(" \t")
    prefix = line[:len(line) - len(text)]
    if "\t" not in prefix:
        return line
    return " " * (end_column(prefix, column) - column) + text


def drop_indent(line: str, column: int, width: int) -> tuple[str, str]:
    target = column + width
    index = 0
    while column < target and index < len(line) and line[index] in " \t":
        column = end_column(line[index], column)
        index += 1
    return line[:index], " " * max(0, column - target) + line[index:]


def indentation(width: int, column: int, tabs: bool) -> str:
    target = column + width
    prefix = ""
    while tabs and column + 4 - column % 4 <= target:
        prefix += "\t"
        column += 4 - column % 4
    return prefix + " " * (target - column)


def rebase_code_indent(line: str, width: int, input_col: int) -> str:
    # Recreate only the portion the Markdown parser strips from a code line.
    removed = min(width, leading_indent(line, input_col))
    _, text = drop_indent(line, input_col, removed)
    return " " * removed + text


def render_list_marker(
    leading: str, marker: str, padding: str, tab_padding: bool,
    style: str, input_col: int, output_col: int
) -> str:
    width = end_column(leading, input_col) - input_col
    if style != "preserve" or end_column(leading, output_col) != output_col + width:
        leading = indentation(width, output_col, style == "tabs")
    input_end = input_col + width + len(marker)
    output_end = output_col + width + len(marker)
    padding_width = end_column(padding, input_end) - input_end
    if style == "tabs" and tab_padding:
        padding = "\t"
    elif style != "preserve" or end_column(padding, output_end) != output_end + padding_width:
        padding = " " * padding_width
    return leading + marker + padding


def is_blockquote(line: str) -> bool:
    return BLOCKQUOTE_RE.match(line) is not None


def is_fence_start(line: str) -> bool:
    return FENCE_RE.match(line) is not None


def is_table_row(line: str) -> bool:
    return "|" in line and not BLANK_RE.match(line)


def is_html_block_start(line: str) -> bool:
    return HTML_BLOCK_START_RE.match(line) is not None


def nested_width(width: int, prefix_width: int) -> int:
    return 0 if width == 0 else max(1, width - prefix_width)


class ProseEdit(NamedTuple):
    # Spans are local to the current container.
    span: tuple[int, int]
    group: Optional[int]
    direct: bool
    render: Callable[[int, int], list[str]]

    def nested(self, offset: int, render: Callable[[int, int], list[str]]) -> "ProseEdit":
        start, end = self.span
        return ProseEdit(
            (start + offset, end + offset),
            self.group + offset if self.group is not None else None,
            False,
            render,
        )


def process_block(lines: list[str], width: int, style: str, repair: bool, utf16_width: bool) -> list[str]:
    rendered, _ = process_blocks(lines, width, set(), style, 0, 0, repair, utf16_width=utf16_width)
    return rendered


def process_blocks(
    lines: list[str], width: int, lazy_lines: set[int], style: str,
    input_col: int, output_col: int, repair: bool, edits: Optional[list[ProseEdit]] = None, *, utf16_width: bool,
) -> tuple[list[str], int]:
    # A line missing list indentation can extend a paragraph, but cannot
    # start a block or extend a protected block such as a code fence.
    out: list[str] = []
    i: int = 0
    n: int = len(lines)
    tab_stops_shift = input_col % 4 != output_col % 4

    while i < n and i not in lazy_lines:
        line: str = lines[i]
        syntax = block_syntax(line, input_col)

        # Blank line: pass through as-is.
        if BLANK_RE.match(line):
            out.append("")
            i += 1
            continue

        # Fenced code block: copy verbatim, including the fences.
        fm = FENCE_RE.match(syntax)
        if fm:
            fence_char = fm.group(2)[0]
            fence_len = len(fm.group(2))
            block = [syntax if tab_stops_shift else line]
            i += 1
            while i < n and i not in lazy_lines:
                code_line = lines[i]
                code_syntax = block_syntax(code_line, input_col)
                close_m = re.match(
                    r"^ {0,3}(" + re.escape(fence_char) + r"{" + str(fence_len) + r",})\s*$",
                    code_syntax,
                )
                if tab_stops_shift:
                    code_line = code_syntax if close_m else rebase_code_indent(
                        code_line, len(fm.group(1)), input_col
                    )
                block.append(code_line)
                i += 1
                if close_m:
                    break
            out.extend(block)
            continue

        # Thematic break: verbatim.
        if HR_RE.match(syntax):
            out.append((syntax if tab_stops_shift else line).rstrip())
            i += 1
            continue

        # ATX heading: verbatim, single line.
        if ATX_RE.match(syntax):
            out.append((syntax if tab_stops_shift else line).rstrip())
            i += 1
            continue

        # GFM alert marker inside blockquotes: verbatim, single line.
        if GFM_ALERT_MARKER_RE.match(line):
            out.append(line.rstrip())
            i += 1
            continue

        # Link reference definition: verbatim, single line.
        if REFERENCE_DEFINITION_RE.match(syntax):
            out.append((syntax if tab_stops_shift else line).rstrip())
            i += 1
            continue

        # Indented code block: copy verbatim.
        if leading_indent(line, input_col) >= 4:
            while i < n and i not in lazy_lines and (BLANK_RE.match(lines[i]) or leading_indent(lines[i], input_col) >= 4):
                code_line = rebase_code_indent(lines[i], 4, input_col) if tab_stops_shift else lines[i]
                out.append(code_line.rstrip())
                i += 1
            continue

        # Setext heading (title line immediately followed by === or --- ):
        # only recognized right at the start of what would otherwise be a
        # fresh paragraph, matching typical hand-written usage.
        if (
            not BLANK_RE.match(line)
            and not is_blockquote(syntax)
            and not LIST_MARKER_RE.match(line)
            and i + 1 < n
            and i + 1 not in lazy_lines
            and (SETEXT_H1_RE.match(block_syntax(lines[i + 1], input_col))
                 or SETEXT_H2_RE.match(block_syntax(lines[i + 1], input_col)))
        ):
            out.append(line.rstrip())
            out.append(lines[i + 1].rstrip())
            i += 2
            continue

        # HTML block: copy verbatim until a blank line.
        if is_html_block_start(syntax):
            while i < n and i not in lazy_lines and not BLANK_RE.match(lines[i]):
                out.append(lines[i].rstrip())
                i += 1
            continue

        # HTML comment: copy verbatim until the closing marker.
        if HTML_COMMENT_START_RE.match(syntax):
            while i < n and i not in lazy_lines:
                out.append(lines[i].rstrip())
                is_end = HTML_COMMENT_END_RE.search(lines[i]) is not None
                i += 1
                if is_end:
                    break
            continue

        # GFM table: header row + delimiter row + body rows, verbatim.
        if (
            is_table_row(line)
            and i + 1 < n
            and i + 1 not in lazy_lines
            and TABLE_DELIM_RE.match(lines[i + 1])
        ):
            out.append(line.rstrip())
            out.append(lines[i + 1].rstrip())
            i += 2
            while i < n and i not in lazy_lines and is_table_row(lines[i]) and not BLANK_RE.match(lines[i]):
                out.append(lines[i].rstrip())
                i += 1
            continue

        # Blockquote: gather contiguous quoted lines (including bare ">"
        # blank-quote separators), strip one level of prefix, recurse, then
        # reapply the prefix.
        bqm = BLOCKQUOTE_RE.match(syntax)
        if bqm:
            start = i
            inner = []
            while i < n and i not in lazy_lines:
                m = BLOCKQUOTE_RE.match(block_syntax(lines[i], input_col))
                if not m:
                    break
                inner.append(m.group(2))
                i += 1
            prefix_width = 2  # "> "
            quoted_edits = [] if edits is not None else None
            rendered, _ = process_blocks(
                inner, nested_width(width, prefix_width), set(), style,
                input_col + bqm.end(1), output_col + prefix_width, repair, quoted_edits, utf16_width=utf16_width
            )
            if edits is not None:
                prefix = syntax[:bqm.end(1)]
                for edit in quoted_edits:
                    def render_quote(width, column, edit=edit, prefix=prefix):
                        rendered = edit.render(nested_width(width, len(prefix)), column + len(prefix))
                        return [prefix + line if line else prefix.rstrip() for line in rendered]

                    edits.append(edit.nested(start, render_quote))
            for rline in rendered:
                out.append("> " + rline if rline else ">")
            continue

        # Footnote definition: behaves like a list item with marker "[^x]: ".
        fnm = FOOTNOTE_RE.match(line)
        if fnm:
            marker = "[^{}]: ".format(fnm.group(1))
            first_text = line[fnm.end(2):]
            rendered, i = process_list_item(
                lines, i, marker, first_text, width, lazy_lines, style, input_col, output_col,
                repair=repair, utf16_width=utf16_width, allows_lazy_lines=False, edits=edits
            )
            out.extend(rendered)
            continue

        # Bulleted or ordered list item.
        match = LIST_MARKER_RE.match(line)
        if match:
            leading, marker, padding, first_text = match.groups()
            marker_end = end_column(leading + marker, input_col)
            tab_padding = end_column(padding, marker_end) - marker_end <= 4
            if not tab_padding:
                _, excess = drop_indent(padding, marker_end, 1)
                first_text = excess + first_text
                padding = " "
            def output_marker(column, leading=leading, marker=marker, padding=padding, tab_padding=tab_padding):
                return render_list_marker(leading, marker, padding, tab_padding, style, input_col, column)
            rendered, i = process_list_item(
                lines, i, leading + marker + padding, first_text, width, lazy_lines,
                style, input_col, output_col, repair=repair, utf16_width=utf16_width, allows_lazy_lines=True, output_marker=output_marker, edits=edits
            )
            if rendered and not tab_padding and style == "preserve" and not tab_stops_shift:
                rendered[0] = line.rstrip()
            out.extend(rendered)
            continue

        # Otherwise: plain paragraph. Gather contiguous non-blank lines that
        # don't start a new block construct.
        start = i
        para: list[str] = [line]
        i += 1
        while i < n and not BLANK_RE.match(lines[i]) and not starts_new_block(lines[i], input_col):
            para.append(lines[i])
            i += 1
        if edits is None:
            out.extend(wrap_paragraph_text(para, width, output_col, repair, utf16_width))
        else:
            def render_paragraph(width, column, para=para):
                return wrap_paragraph_text(para, width, column, repair, utf16_width)

            span = (start, i)
            edits.append(ProseEdit(span, None, True, render_paragraph))

    return out, i


def starts_new_block(line: str, column: int) -> bool:
    syntax = block_syntax(line, column)
    return (
        is_fence_start(syntax)
        or ATX_RE.match(syntax)
        or GFM_ALERT_MARKER_RE.match(syntax)
        or HR_RE.match(syntax)
        or is_blockquote(syntax)
        or LIST_MARKER_RE.match(line)
        or FOOTNOTE_RE.match(syntax)
        or REFERENCE_DEFINITION_RE.match(syntax)
        or is_html_block_start(syntax)
        or HTML_COMMENT_START_RE.match(syntax)
        or leading_indent(line, column) >= 4
    )


def process_list_item(
    lines: list[str],
    i: int,
    marker: str,
    first_text: str,
    width: int,
    parent_lazy_lines: set[int],
    style: str,
    input_col: int,
    output_col: int,
    *,
    repair: bool,
    utf16_width: bool,
    allows_lazy_lines: bool,
    output_marker: Optional[Callable[[int], str]] = None,
    edits: Optional[list[ProseEdit]] = None,
) -> tuple[list[str], int]:
    content_col = end_column(marker, input_col) - input_col
    first_prefix = output_marker(output_col) if output_marker is not None else marker
    output_width = end_column(first_prefix, output_col) - output_col
    original_continuation = None
    n = len(lines)
    item = [first_text]
    lazy_lines: set[int] = set()
    j = i + 1
    
    while j < n:
        if BLANK_RE.match(lines[j]):
            # Blank line continues the item only if further indented content
            # (or another blank line) follows; otherwise it ends the item.
            k = j
            while k < n and BLANK_RE.match(lines[k]):
                k += 1
            if k < n and k not in parent_lazy_lines and leading_indent(lines[k], input_col) >= content_col:
                # keep the blank(s), then continue with next indented line
                while j < k:
                    item.append("")
                    j += 1
                continue
            else:
                break

        indent = leading_indent(lines[j], input_col)
        if j not in parent_lazy_lines and indent >= content_col:
            prefix, text = drop_indent(lines[j], input_col, content_col)
            if original_continuation is None and end_column(prefix, input_col) == input_col + content_col:
                original_continuation = (len(item), prefix)
            item.append(text)
            j += 1
            continue

        if not allows_lazy_lines:
            break
        text = lines[j].lstrip(" \t")
        if starts_new_block(text, input_col) or (
            is_table_row(lines[j])
            and j + 1 < n
            and j + 1 not in parent_lazy_lines
            and TABLE_DELIM_RE.match(lines[j + 1])
        ):
            break
        lazy_lines.add(len(item))
        item.append(text)
        j += 1

    item_edits = [] if edits is not None else None
    rendered, consumed = process_blocks(
        item, nested_width(width, output_width), lazy_lines, style,
        input_col + content_col, output_col + output_width, repair, item_edits, utf16_width=utf16_width
    )
    def continuation_prefix(prefix, width, column):
        if style == "preserve" and original_continuation is not None:
            index, original = original_continuation
            if index < consumed and end_column(original, column) == column + width:
                return original
        use_tabs = allows_lazy_lines and (style == "tabs" or "\t" in prefix)
        return indentation(width, column, use_tabs)

    if edits is not None:
        # Direct prose shares an item selection. Descendant items have their own.
        group = next((edit.span[0] for edit in item_edits if edit.direct), None)
        for edit in item_edits:
            if edit.direct:
                edit = edit._replace(group=group)
            starts_item = edit.span[0] == 0
            covers_item = starts_item and edit.span[1] == consumed

            def render_item(width, column, edit=edit, starts_item=starts_item, covers_item=covers_item):
                # Keep the content column stable when other parts of the item
                # remain in the source, including nested items and code.
                preferred = output_marker(column) if output_marker is not None else marker
                preferred_width = end_column(preferred, column) - column
                prefix = preferred if covers_item or preferred_width == content_col else marker
                prefix_width = end_column(prefix, column) - column
                continuation = continuation_prefix(prefix, prefix_width, column)
                rendered = edit.render(nested_width(width, prefix_width), column + prefix_width)
                return render_hanging(
                    rendered, prefix if starts_item else continuation, continuation,
                    starts_item and allows_lazy_lines,
                )

            edits.append(edit.nested(i, render_item))
        return [], i + consumed

    rest_prefix = continuation_prefix(first_prefix, output_width, output_col)
    # Each gathered line corresponds to one source line, including the marker line.
    return render_hanging(rendered, first_prefix, rest_prefix, allows_lazy_lines), i + consumed


def render_hanging(
    content_lines: list[str], first_prefix: str, rest_prefix: str, keep_empty_marker: bool
) -> list[str]:
    out: list[str] = []
    for idx, line in enumerate(content_lines):
        prefix = first_prefix if idx == 0 else rest_prefix
        out.append(prefix + line if line or (idx == 0 and keep_empty_marker) else "")
    return out


def rewrap(text: str, width: int, indent: str = "preserve", repair: bool = False, *, utf16_width: bool = False) -> str:
    # Normalize line endings, preserve trailing newline presence.
    had_trailing_newline = text.endswith("\n")
    lines: list[str] = text.split("\n")
    
    if lines and lines[-1] == "" and had_trailing_newline:
        lines = lines[:-1]
    
    out = process_block(lines, normalize_width(width), indent, repair, utf16_width)
    result: str = "\n".join(out)
    if had_trailing_newline:
        result += "\n"
    
    return result


def rewrap_lines(
    text: str, ranges: list[tuple[int, int]], width: int, indent: str, repair: bool, *, utf16_width: bool = False,
) -> str:
    parts = re.split(r"(\r\n|[\r\n])", text)
    lines = parts[::2]
    endings = parts[1::2]
    if lines[-1]:
        endings.append("")
    else:
        lines.pop()
    for start, end in ranges:
        if end > len(lines):
            raise ValueError(f"--lines {start}:{end} is out of bounds for input with {len(lines)} lines.")

    edits = []
    width = normalize_width(width)
    process_blocks(lines, width, set(), indent, 0, 0, repair, edits, utf16_width=utf16_width)
    ranges = sorted(ranges)
    selected = set()
    range_index = 0
    for edit in edits:
        first, end = edit.span
        while range_index < len(ranges) and ranges[range_index][1] <= first:
            range_index += 1
        if range_index < len(ranges) and ranges[range_index][0] <= end:
            selected.add(edit.group if edit.group is not None else first)

    output = []
    cursor = 0
    for edit in edits:
        first, end = edit.span
        if (edit.group if edit.group is not None else first) not in selected:
            continue
        output.extend(line + ending for line, ending in zip(lines[cursor:first], endings[cursor:first]))
        rendered = edit.render(width, 0)
        for index, line in enumerate(rendered):
            if index == len(rendered) - 1:
                ending = endings[end - 1]
            else:
                ending = endings[min(first + index, max(first, end - 2))] or "\n"
            output.append(line + ending)
        cursor = end
    output.extend(line + ending for line, ending in zip(lines[cursor:], endings[cursor:]))
    return "".join(output)


def commit_trailer_block_start(lines: list[str]) -> Optional[int]:
    if not lines:
        return None

    end = len(lines) - 1
    while end >= 0 and (BLANK_RE.match(lines[end]) or COMMIT_COMMENT_RE.match(lines[end])):
        end -= 1
    if end < 0:
        return None

    start = end
    while (
        start > 0
        and not BLANK_RE.match(lines[start - 1])
        and not COMMIT_COMMENT_RE.match(lines[start - 1])
    ):
        start -= 1

    found_trailer = False
    for line in lines[start : end + 1]:
        if COMMIT_TRAILER_RE.match(line):
            found_trailer = True
        elif line.startswith((" ", "\t")) and found_trailer:
            continue
        else:
            return None
    return start if found_trailer else None


def process_commit_message_body(lines: list[str], width: int, indent: str, repair: bool, utf16_width: bool) -> list[str]:
    trailer_start = commit_trailer_block_start(lines)
    body_end = len(lines) if trailer_start is None else trailer_start
    output: list[str] = []
    pending: list[str] = []

    def flush_pending() -> None:
        if pending:
            output.extend(process_block(pending, width, indent, repair, utf16_width))
            pending.clear()

    for line in lines[:body_end]:
        if COMMIT_COMMENT_RE.match(line):
            flush_pending()
            output.append(line)
        else:
            pending.append(line)
    flush_pending()

    if trailer_start is not None:
        output.extend(lines[trailer_start:])
    return output


def rewrap_commit_message(
    text: str, width: int = DEFAULT_COMMIT_MESSAGE_WIDTH, indent: str = "preserve", repair: bool = False, *, utf16_width: bool = False
) -> str:
    had_trailing_newline = text.endswith("\n")
    lines = text.split("\n")
    if lines and lines[-1] == "" and had_trailing_newline:
        lines = lines[:-1]
    if not lines:
        return text

    output = [lines[0]]
    output.extend(process_commit_message_body(lines[1:], normalize_width(width), indent, repair, utf16_width))
    result = "\n".join(output)
    return result + "\n" if had_trailing_newline else result


def fail(message: str):
    print(message, file=sys.stderr)
    raise SystemExit(2)


def main():
    if "--version" in sys.argv[1:] or "-v" in sys.argv[1:]:
        print(version_string())
        return
    if "--help" in sys.argv[1:] or "-h" in sys.argv[1:]:
        print(usage_string())
        return

    arguments = sys.argv[1:]
    check = "--check" in arguments
    indent = "preserve"
    utf16_width = False
    strict = check or "--lines" in arguments
    ranges = []
    width_arguments = []
    argument_iterator = iter(arguments)
    for argument in argument_iterator:
        if argument == "--lines":
            value = next(argument_iterator, "")
            if not re.fullmatch(r"[0-9]+:[0-9]+", value):
                fail("Expected --lines START:END with positive, ascending line numbers.")
            try:
                start, end = map(int, value.split(":"))
            except ValueError:
                fail("Expected --lines START:END with positive, ascending line numbers.")
            if start < 1 or end < start or end > sys.maxsize:
                fail("Expected --lines START:END with positive, ascending line numbers.")
            ranges.append((start, end))
        elif argument.startswith("--lines="):
            fail("Expected --lines START:END.")
        elif argument == "--indent" or argument.startswith("--indent="):
            indent = argument.removeprefix("--indent=")
            if indent not in ("preserve", "tabs", "spaces"):
                fail("Expected --indent=preserve, --indent=tabs, or --indent=spaces.")
        elif argument == "--width-unit" or argument.startswith("--width-unit="):
            if argument != "--width-unit=utf16":
                fail("Expected --width-unit=utf16.")
            utf16_width = True
        elif argument not in ("--check", "--unwrap", "--commit", "--repair"):
            try:
                int(argument)
            except ValueError:
                if strict:
                    fail(f"Unexpected argument: {argument}")
            else:
                width_arguments.append(argument)
    if strict and len(width_arguments) > 1:
        fail("Expected at most one width argument.")

    unwrap = "--unwrap" in arguments
    commit_message = "--commit" in arguments
    repair = "--repair" in arguments
    if commit_message and ranges:
        fail("--lines cannot be used with --commit.")
    width = get_width(width_arguments, DEFAULT_COMMIT_MESSAGE_WIDTH if commit_message else DEFAULT_WIDTH)
    if unwrap:
        width = 0
    if strict:
        try:
            input_bytes = sys.stdin.buffer.read()
            data = input_bytes.decode("utf-8")
        except UnicodeDecodeError:
            fail("Standard input is not valid UTF-8.")
        except (OSError, AttributeError) as error:
            fail(f"Could not read standard input: {error}")
        # Match the universal newline handling of sys.stdin.read().
        if not ranges:
            data = data.replace("\r\n", "\n").replace("\r", "\n")
    else:
        data = sys.stdin.read()

    if ranges:
        try:
            output = rewrap_lines(data, ranges, width, indent, repair, utf16_width=utf16_width)
        except ValueError as error:
            fail(str(error))
    elif commit_message:
        output = rewrap_commit_message(data, width, indent=indent, repair=repair, utf16_width=utf16_width)
    else:
        output = rewrap(data, width, indent=indent, repair=repair, utf16_width=utf16_width)
    if check:
        raise SystemExit(0 if output.encode("utf-8") == input_bytes else 1)
    if ranges:
        sys.stdout.buffer.write(output.encode("utf-8"))
    else:
        sys.stdout.write(output)


if __name__ == "__main__":
    main()
