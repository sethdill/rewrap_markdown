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
from typing import Literal, Optional

VERSION = "0.3"
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
FRONT_MATTER_DELIM_RE = re.compile(r"^-{3,}\s*$")
GFM_ALERT_MARKER_RE = re.compile(r"^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$")
HARD_BREAK_RE = re.compile(r"(\\|  +)$")
COMMIT_COMMENT_RE = re.compile(r"^[ \t]*#")
COMMIT_TRAILER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]*[ \t]*[:=][ \t]+.+$")

# Inline "atomic" spans that must never be split by the wrapper.
INLINE_ATOMIC_RE = re.compile(
    r"(?P<code>(`+).*?\2)"
    r"|(?P<img>!\[[^\]]*\]\([^)]*\))"
    r"|(?P<link>\[[^\]]*\]\([^)]*\))"
    r"|(?P<reflink>\[[^\]]*\](?:\[[^\]]*\])?)"
    r"|(?P<autolink><[^ >]+>)"
    r"|(?P<url>https?://\S+)"
)


def normalize_width(width: int) -> int:
    return 0 if width == 0 else max(1, width)


def get_width(fallback: int = DEFAULT_WIDTH) -> int:
    for argument in sys.argv[1:]:
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
    return """Usage: rewrap-markdown [--unwrap] [--commit] [--repair] [--indent=preserve|tabs|spaces] [WIDTH]

Read Markdown from standard input and write the transformed text to standard output.

  --unwrap  Join paragraphs and list items onto one line (equivalent to width 0).
  --commit  Preserve the subject, comments, and trailers of a Git commit message.
  --repair  Fix spacing around parenthesized code and keep parentheses with adjacent words.
  --indent  Set the list indentation style (default: preserve).
  --version Print the version."""


# ---------------------------------------------------------------------------
# Inline tokenizing / wrapping
# ---------------------------------------------------------------------------


def tokenize_inline(text: str) -> list[str]:
    """
    Keep atomic spans whole and preserve their adjacency to surrounding text.
    Only source whitespace outside an atomic span creates a wrap opportunity.
    """
    tokens: list[str] = []
    token_end = 0

    def append_token(start: int, end: int):
        nonlocal token_end
        token = text[start:end]
        if tokens and start == token_end:
            tokens[-1] += token
        else:
            tokens.append(token)
        token_end = end

    def append_words(start: int, end: int):
        for word in re.finditer(r"\S+", text[start:end]):
            append_token(start + word.start(), start + word.end())

    cursor = 0
    for match in INLINE_ATOMIC_RE.finditer(text):
        append_words(cursor, match.start())
        append_token(match.start(), match.end())
        cursor = match.end()
    append_words(cursor, len(text))
    return tokens


# Escapes and all inline atoms are opaque. Code delimiters must have equal
# run lengths; unmatched runs cannot be mistaken for shorter code spans.
REPAIR_ATOMIC_RE = re.compile(
    r"\\[\s\S]|(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)|`+"
    r"|!\[[^\]]*\]\([^)]*\)|\[[^\]]*\]\([^)]*\)"
    r"|\[[^\]]*\](?:\[[^\]]*\])?|<[^ >]+>|https?://\S+"
)


def tokenize_repair_inline(source: str) -> list[str]:
    def atoms_and_mask(text):
        atoms = list(REPAIR_ATOMIC_RE.finditer(text))
        opaque = [False] * len(text)
        for atom in atoms:
            opaque[atom.start():atom.end()] = [True] * (atom.end() - atom.start())
        return atoms, opaque

    atoms, opaque = atoms_and_mask(source)
    # Only tighten closing parentheses that have an opener in this segment.
    depth = 0
    matched_closers = set()
    for index, char in enumerate(source):
        if opaque[index]:
            continue
        if char == "(":
            depth += 1
        elif char == ")" and depth > 0:
            depth -= 1
            matched_closers.add(index)

    removals = []
    for atom in atoms:
        if atom.group(1) is None:
            continue
        left, right = atom.span()
        while right < len(source) and source[right] in " \t":
            right += 1
        if right not in matched_closers:
            continue
        if right > atom.end():
            removals.append((atom.end(), right))

        while left > 0 and source[left - 1] in " \t":
            left -= 1
        if (0 < left < atom.start()
                and source[left - 1] == "(" and not opaque[left - 1]):
            removals.append((left, atom.start()))
    text = source
    for start, end in sorted(removals, reverse=True):
        text = text[:start] + text[end:]
    atoms, opaque = atoms_and_mask(text)
    ranges = []

    def append(start, end):
        if ranges and ranges[-1][1] == start:
            ranges[-1] = (ranges[-1][0], end)
        else:
            ranges.append((start, end))

    def words(start, end):
        for word in re.finditer(r"\S+", text[start:end]):
            append(start + word.start(), start + word.end())

    cursor = 0
    for atom in atoms:
        words(cursor, atom.start())
        append(atom.start(), atom.end())
        cursor = atom.end()
    words(cursor, len(text))
    tokens = []
    previous_end = None
    for start, end in ranges:
        closes = text[start] == ")" and not opaque[start]
        opens = (previous_end is not None and text[previous_end - 1] == "("
                 and not opaque[previous_end - 1])
        if tokens and (opens or closes):
            tokens[-1] += " " + text[start:end]
        else:
            tokens.append(text[start:end])
        previous_end = end
    return tokens


def wrap_tokens(tokens: list[str], width: int, column: int) -> list[str]:
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
    
    for tok in tokens:
        token_start = column + current_len + (1 if current else 0)
        next_len = end_column(tok, token_start) - column
        if current and next_len > width:
            lines.append(" ".join(current))
            current = [tok]
            current_len = end_column(tok, column) - column
        else:
            current.append(tok)
            current_len = next_len
    
    if current:
        lines.append(" ".join(current))
    
    return lines or [""]


def wrap_paragraph_text(raw_lines: list[str], width: int, column: int, repair: bool) -> list[str]:
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
        stripped = line.strip()
        m = HARD_BREAK_RE.search(line.rstrip("\n"))
        
        if m and stripped:
            break_style = "\\" if m.group(1) == "\\" else "  "
            # strip the break marker itself from the text
            text_part = line.rstrip("\n")[: m.start()].rstrip()
            buf.append(text_part.strip())
            segments.append((" ".join(w for w in buf if w), break_style))
            buf = []
        else:
            buf.append(stripped)
    
    if buf:
        segments.append((" ".join(w for w in buf if w), None))

    out_lines: list[str] = []
    for i, (text, break_style) in enumerate(segments):
        tokens = tokenize_repair_inline(text) if repair else tokenize_inline(text)
        wrapped = wrap_tokens(tokens, width, column) if tokens else [""]
        if break_style is not None and wrapped:
            wrapped[-1] = wrapped[-1] + break_style
        out_lines.extend(wrapped)
    
    return out_lines


# ---------------------------------------------------------------------------
# Block-level parsing
# ---------------------------------------------------------------------------


def end_column(text: str, column: int) -> int:
    for character in text:
        column += 4 - column % 4 if character == "\t" else 1
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


def process_block(lines: list[str], width: int, style: str, repair: bool) -> list[str]:
    rendered, _ = process_blocks(lines, width, set(), style, 0, 0, repair)
    return rendered


def process_blocks(
    lines: list[str], width: int, lazy_lines: set[int], style: str, input_col: int, output_col: int, repair: bool
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
            inner = []
            while i < n and i not in lazy_lines:
                m = BLOCKQUOTE_RE.match(block_syntax(lines[i], input_col))
                if not m:
                    break
                inner.append(m.group(2))
                i += 1
            prefix_width = 2  # "> "
            rendered, _ = process_blocks(
                inner, nested_width(width, prefix_width), set(), style,
                input_col + bqm.end(1), output_col + prefix_width, repair
            )
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
                repair=repair, allows_lazy_lines=False
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
            output_marker = render_list_marker(
                leading, marker, padding, tab_padding, style, input_col, output_col
            )
            rendered, i = process_list_item(
                lines, i, leading + marker + padding, first_text, width, lazy_lines,
                style, input_col, output_col, repair=repair, allows_lazy_lines=True, output_marker=output_marker
            )
            if not tab_padding and style == "preserve" and not tab_stops_shift:
                rendered[0] = line.rstrip()
            out.extend(rendered)
            continue

        # Otherwise: plain paragraph. Gather contiguous non-blank lines that
        # don't start a new block construct.
        para: list[str] = [line]
        i += 1
        while i < n and not BLANK_RE.match(lines[i]) and not starts_new_block(lines[i], input_col):
            para.append(lines[i])
            i += 1
        out.extend(wrap_paragraph_text(para, width, output_col, repair))

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
    allows_lazy_lines: bool,
    output_marker: Optional[str] = None,
) -> tuple[list[str], int]:
    content_col = end_column(marker, input_col) - input_col
    first_prefix = output_marker if output_marker is not None else marker
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

    rendered, consumed = process_blocks(
        item, nested_width(width, output_width), lazy_lines, style,
        input_col + content_col, output_col + output_width, repair
    )
    use_tabs = allows_lazy_lines and (style == "tabs" or "\t" in first_prefix)
    rest_prefix = indentation(output_width, output_col, use_tabs)
    if style == "preserve" and original_continuation is not None:
        index, prefix = original_continuation
        if index < consumed and end_column(prefix, output_col) == output_col + output_width:
            rest_prefix = prefix
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


def rewrap(text: str, width: int, indent: str = "preserve", repair: bool = False) -> str:
    # Normalize line endings, preserve trailing newline presence.
    had_trailing_newline = text.endswith("\n")
    lines: list[str] = text.split("\n")
    
    if lines and lines[-1] == "" and had_trailing_newline:
        lines = lines[:-1]
    
    out = process_block(lines, normalize_width(width), indent, repair)
    result: str = "\n".join(out)
    if had_trailing_newline:
        result += "\n"
    
    return result


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


def process_commit_message_body(lines: list[str], width: int, indent: str, repair: bool) -> list[str]:
    trailer_start = commit_trailer_block_start(lines)
    body_end = len(lines) if trailer_start is None else trailer_start
    output: list[str] = []
    pending: list[str] = []

    def flush_pending() -> None:
        if pending:
            output.extend(process_block(pending, width, indent, repair))
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
    text: str, width: int = DEFAULT_COMMIT_MESSAGE_WIDTH, indent: str = "preserve", repair: bool = False
) -> str:
    had_trailing_newline = text.endswith("\n")
    lines = text.split("\n")
    if lines and lines[-1] == "" and had_trailing_newline:
        lines = lines[:-1]
    if not lines:
        return text

    output = [lines[0]]
    output.extend(process_commit_message_body(lines[1:], normalize_width(width), indent, repair))
    result = "\n".join(output)
    return result + "\n" if had_trailing_newline else result


def main():
    if "--version" in sys.argv[1:] or "-v" in sys.argv[1:]:
        print(version_string())
        return
    if "--help" in sys.argv[1:] or "-h" in sys.argv[1:]:
        print(usage_string())
        return

    arguments = sys.argv[1:]
    indent = "preserve"
    for argument in arguments:
        if argument == "--indent" or argument.startswith("--indent="):
            indent = argument.removeprefix("--indent=")
            if indent not in ("preserve", "tabs", "spaces"):
                print("Expected --indent=preserve, --indent=tabs, or --indent=spaces.", file=sys.stderr)
                raise SystemExit(2)
    unwrap = "--unwrap" in arguments
    commit_message = "--commit" in arguments
    width = get_width(
        DEFAULT_COMMIT_MESSAGE_WIDTH if commit_message else DEFAULT_WIDTH
    )
    data = sys.stdin.read()
    if commit_message:
        sys.stdout.write(rewrap_commit_message(data, 0 if unwrap else width, indent=indent, repair="--repair" in arguments))
    else:
        sys.stdout.write(rewrap(data, 0 if unwrap else width, indent=indent, repair="--repair" in arguments))


if __name__ == "__main__":
    main()
