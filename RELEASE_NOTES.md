# Rewrap Markdown 0.3

Rewrap Markdown 0.3 can unwrap Markdown for web forms and rewrap Git commit
messages without disturbing their special structure.

## Highlights

- **Unwrap mode:** `--unwrap`, or width `0`, joins each paragraph and list item
  onto one line while preserving Markdown structure and intentional hard
  breaks. BBEdit's Markdown-aware Hard Wrap dialog also accepts `0`.
- **Commit message mode:** `--commit` leaves the subject, `#` comment lines, and
  final Git trailer block unchanged while rewrapping the body at 72 columns by
  default.
- **Commit hook:** The release includes a `commit-msg` hook that safely rewrites
  a message only after the filter succeeds.
- **Discoverable CLI:** `--help` describes the available modes.

Both new modes are available in the Swift executable and Python implementation.
