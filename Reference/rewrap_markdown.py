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
  1. First command-line argument, e.g. `md_rewrap.py 100`
  2. MD_REWRAP_WIDTH environment variable
  3. DEFAULT_WIDTH constant below

This is a pragmatic, hand-rolled parser (no third-party dependencies), not a
full CommonMark implementation. It's tuned for typical hand-written
Markdown, not for pathological edge cases.
"""

import os
import re
import sys
from typing import Literal, Optional

VERSION = "0.1"
DEFAULT_WIDTH = 70
BreakStyle = Literal["\\", "  "]

# ---------------------------------------------------------------------------
# Regex patterns for block-level constructs
# ---------------------------------------------------------------------------

BLANK_RE = re.compile(r"^\s*$")
FENCE_RE = re.compile(r"^( {0,3})(`{3,}|~{3,})\s*(.*)$")
ATX_RE = re.compile(r"^ {0,3}#{1,6}(?:\s+.*|)$")
HR_RE = re.compile(r"^ {0,3}(?:-(?: *-){2,}|\*(?: *\*){2,}|_(?: *_){2,}) *$")
SETEXT_H1_RE = re.compile(r"^ {0,3}=+ *$")
SETEXT_H2_RE = re.compile(r"^ {0,3}-+ *$")
BLOCKQUOTE_RE = re.compile(r"^ {0,3}>( ?)(.*)$")
BULLET_RE = re.compile(r"^( {0,3})([-*+])( +)(.*)$")
ORDERED_RE = re.compile(r"^( {0,3})(\d{1,9})([.)])( +)(.*)$")
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

# Inline "atomic" spans that must never be split by the wrapper.
INLINE_ATOMIC_RE = re.compile(
    r"(?P<code>(`+).*?\2)"
    r"|(?P<img>!\[[^\]]*\]\([^)]*\))"
    r"|(?P<link>\[[^\]]*\]\([^)]*\))"
    r"|(?P<reflink>\[[^\]]*\](?:\[[^\]]*\])?)"
    r"|(?P<autolink><[^ >]+>)"
    r"|(?P<url>https?://\S+)"
)


def get_width() -> int:
    if len(sys.argv) > 1:
        try:
            return max(1, int(sys.argv[1]))
        except ValueError:
            pass

    env = os.environ.get("MD_REWRAP_WIDTH")
    if env:
        try:
            return max(1, int(env))
        except ValueError:
            pass

    return DEFAULT_WIDTH


def version_string() -> str:
    return f"rewrap-markdown {VERSION}"


# ---------------------------------------------------------------------------
# Inline tokenizing / wrapping
# ---------------------------------------------------------------------------


def tokenize_inline(text: str) -> list[str]:
    """
    Split text into wrap-atomic tokens: whitespace-delimited words, except
    that inline code spans, links/images, autolinks and bare URLs are kept
    whole even if they contain spaces.
    """
    tokens: list[str] = []
    pos: int = 0
    
    for m in INLINE_ATOMIC_RE.finditer(text):
        if m.start() < pos:
            continue
        if m.start() > pos:
            tokens.extend(text[pos : m.start()].split())
        token = m.group(0)
        pos = m.end()
        while pos < len(text) and text[pos] in ",.;:!?":
            token += text[pos]
            pos += 1
        tokens.append(token)
    
    if pos < len(text):
        tokens.extend(text[pos:].split())
    
    return tokens


def wrap_tokens(tokens: list[str], width: int) -> list[str]:
    """
    Greedy word-wrap a token stream to `width` columns. A single token longer
    than `width` is placed alone on its own (over-length) line rather than
    being split.
    """
    lines: list[str] = []
    current: list[str] = []
    current_len: int = 0
    tok: str
    
    for tok in tokens:
        add_len = len(tok) if not current else len(tok) + 1
        if current and current_len + add_len > width:
            lines.append(" ".join(current))
            current = [tok]
            current_len = len(tok)
        else:
            current.append(tok)
            current_len += add_len
    
    if current:
        lines.append(" ".join(current))
    
    return lines or [""]


def wrap_paragraph_text(raw_lines: list[str], width: int) -> list[str]:
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
        tokens = tokenize_inline(text)
        wrapped = wrap_tokens(tokens, width) if tokens else [""]
        if break_style is not None and wrapped:
            wrapped[-1] = wrapped[-1] + break_style
        out_lines.extend(wrapped)
    
    return out_lines


# ---------------------------------------------------------------------------
# Block-level parsing
# ---------------------------------------------------------------------------


def leading_spaces(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def is_blockquote(line: str) -> bool:
    return BLOCKQUOTE_RE.match(line) is not None


def is_fence_start(line: str) -> bool:
    return FENCE_RE.match(line) is not None


def is_table_row(line: str) -> bool:
    return "|" in line and not BLANK_RE.match(line)


def is_html_block_start(line: str) -> bool:
    return HTML_BLOCK_START_RE.match(line) is not None


def process_block(lines: list[str], width: int) -> list[str]:
    """
    Process a self-contained sequence of raw lines (already dedented to
    this nesting level) and return the rewrapped output lines.
    """
    out: list[str] = []
    i: int = 0
    n: int = len(lines)

    while i < n:
        line: str = lines[i]

        # Blank line: pass through as-is.
        if BLANK_RE.match(line):
            out.append("")
            i += 1
            continue

        # Fenced code block: copy verbatim, including the fences.
        fm = FENCE_RE.match(line)
        if fm:
            fence_char = fm.group(2)[0]
            fence_len = len(fm.group(2))
            block = [line]
            i += 1
            while i < n:
                block.append(lines[i])
                close_m = re.match(
                    r"^ {0,3}(" + re.escape(fence_char) + r"{" + str(fence_len) + r",})\s*$",
                    lines[i],
                )
                i += 1
                if close_m:
                    break
            out.extend(block)
            continue

        # Thematic break: verbatim.
        if HR_RE.match(line):
            out.append(line.rstrip())
            i += 1
            continue

        # ATX heading: verbatim, single line.
        if ATX_RE.match(line):
            out.append(line.rstrip())
            i += 1
            continue

        # GFM alert marker inside blockquotes: verbatim, single line.
        if GFM_ALERT_MARKER_RE.match(line):
            out.append(line.rstrip())
            i += 1
            continue

        # Link reference definition: verbatim, single line.
        if REFERENCE_DEFINITION_RE.match(line):
            out.append(line.rstrip())
            i += 1
            continue

        # Indented code block: copy verbatim.
        if leading_spaces(line) >= 4:
            while i < n and (BLANK_RE.match(lines[i]) or leading_spaces(lines[i]) >= 4):
                out.append(lines[i].rstrip())
                i += 1
            continue

        # Setext heading (title line immediately followed by === or --- ):
        # only recognized right at the start of what would otherwise be a
        # fresh paragraph, matching typical hand-written usage.
        if (
            not BLANK_RE.match(line)
            and not is_blockquote(line)
            and not BULLET_RE.match(line)
            and not ORDERED_RE.match(line)
            and i + 1 < n
            and (SETEXT_H1_RE.match(lines[i + 1]) or SETEXT_H2_RE.match(lines[i + 1]))
        ):
            out.append(line.rstrip())
            out.append(lines[i + 1].rstrip())
            i += 2
            continue

        # HTML block: copy verbatim until a blank line.
        if is_html_block_start(line):
            while i < n and not BLANK_RE.match(lines[i]):
                out.append(lines[i].rstrip())
                i += 1
            continue

        # HTML comment: copy verbatim until the closing marker.
        if HTML_COMMENT_START_RE.match(line):
            while i < n:
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
            and TABLE_DELIM_RE.match(lines[i + 1])
        ):
            out.append(line.rstrip())
            out.append(lines[i + 1].rstrip())
            i += 2
            while i < n and is_table_row(lines[i]) and not BLANK_RE.match(lines[i]):
                out.append(lines[i].rstrip())
                i += 1
            continue

        # Blockquote: gather contiguous quoted lines (including bare ">"
        # blank-quote separators), strip one level of prefix, recurse, then
        # reapply the prefix.
        bqm = BLOCKQUOTE_RE.match(line)
        if bqm:
            inner = []
            while i < n:
                m = BLOCKQUOTE_RE.match(lines[i])
                if not m:
                    break
                inner.append(m.group(2))
                i += 1
            prefix_width = 2  # "> "
            rendered = process_block(inner, max(1, width - prefix_width))
            for rline in rendered:
                out.append("> " + rline if rline else ">")
            continue

        # Footnote definition: behaves like a list item with marker "[^x]: ".
        fnm = FOOTNOTE_RE.match(line)
        if fnm:
            marker = "[^{}]: ".format(fnm.group(1))
            content_col = len(marker)
            first_text = line[fnm.end(2):]
            item_lines, i = gather_indented_block(lines, i, content_col, first_text)
            rendered = process_block(item_lines, max(1, width - content_col))
            out.extend(render_hanging(rendered, marker, " " * content_col))
            continue

        # Bulleted list item.
        blm = BULLET_RE.match(line)
        if blm:
            indent, bullet, _spacing, first_text = blm.groups()
            marker = indent + bullet + " "
            content_col = len(marker)
            item_lines, i = gather_indented_block(lines, i, content_col, first_text)
            rendered = process_block(item_lines, max(1, width - content_col))
            out.extend(render_hanging(rendered, marker, " " * content_col))
            continue

        # Ordered list item.
        olm = ORDERED_RE.match(line)
        if olm:
            indent, num, punct, _spacing, first_text = olm.groups()
            marker = indent + num + punct + " "
            content_col = len(marker)
            item_lines, i = gather_indented_block(lines, i, content_col, first_text)
            rendered = process_block(item_lines, max(1, width - content_col))
            out.extend(render_hanging(rendered, marker, " " * content_col))
            continue

        # Otherwise: plain paragraph. Gather contiguous non-blank lines that
        # don't start a new block construct.
        para: list[str] = [line]
        i += 1
        while i < n and not BLANK_RE.match(lines[i]) and not starts_new_block(lines[i]):
            para.append(lines[i])
            i += 1
        out.extend(wrap_paragraph_text(para, width))

    return out


def starts_new_block(line: str) -> bool:
    return (
        is_fence_start(line)
        or ATX_RE.match(line)
        or GFM_ALERT_MARKER_RE.match(line)
        or HR_RE.match(line)
        or is_blockquote(line)
        or BULLET_RE.match(line)
        or ORDERED_RE.match(line)
        or FOOTNOTE_RE.match(line)
        or REFERENCE_DEFINITION_RE.match(line)
        or is_html_block_start(line)
        or HTML_COMMENT_START_RE.match(line)
        or leading_spaces(line) >= 4
    )


def gather_indented_block(
    lines: list[str],
    i: int,
    content_col: int,
    first_text: str
) -> tuple[list[str], int]:
    """
    Collect the lines belonging to a list/footnote item starting at index
    i (whose marker occupies the first `content_col` columns), including
    any further-indented continuation lines and nested blocks, plus blank
    lines that separate paragraphs within the same item (a "loose" item).
    Returns (item_lines_dedented, next_index).
    """
    n = len(lines)
    item = [first_text]
    j = i + 1
    
    while j < n:
        if BLANK_RE.match(lines[j]):
            # Blank line continues the item only if further indented content
            # (or another blank line) follows; otherwise it ends the item.
            k = j
            while k < n and BLANK_RE.match(lines[k]):
                k += 1
            if k < n and leading_spaces(lines[k]) >= content_col:
                # keep the blank(s), then continue with next indented line
                while j < k:
                    item.append("")
                    j += 1
                continue
            else:
                break

        if leading_spaces(lines[j]) >= content_col:
            item.append(lines[j][content_col:])
            j += 1
            continue

        break

    return item, j


def render_hanging(
    content_lines: list[str], first_prefix: str, rest_prefix: str
) -> list[str]:
    out: list[str] = []
    for idx, line in enumerate(content_lines):
        prefix = first_prefix if idx == 0 else rest_prefix
        out.append("" if line == "" else prefix + line)
    return out


def rewrap(text: str, width: int) -> str:
    # Normalize line endings, preserve trailing newline presence.
    had_trailing_newline = text.endswith("\n")
    lines: list[str] = text.split("\n")
    
    if lines and lines[-1] == "" and had_trailing_newline:
        lines = lines[:-1]
    
    out = process_block(lines, width)
    result: str = "\n".join(out)
    if had_trailing_newline:
        result += "\n"
    
    return result


def main():
    if "--version" in sys.argv[1:] or "-v" in sys.argv[1:]:
        print(version_string())
        return

    width = get_width()
    data = sys.stdin.read()
    sys.stdout.write(rewrap(data, width))


if __name__ == "__main__":
    main()
