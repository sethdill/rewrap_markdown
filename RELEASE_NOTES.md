# Rewrap Markdown 0.4

Rewrap Markdown 0.4 adds formatting checks and line-range wrapping, improves
prose punctuation, and fixes cases where wrapping could change how Markdown
renders.

## Highlights

- **Check formatting.** Use `--check` in CI or scripts. It leaves stdout empty
  and exits with `0` if the input is already formatted, `1` if formatting
  would change it, or `2` on an argument or input error.
- **Rewrap specific lines.** Use repeatable `--lines START:END` arguments to
  rewrap prose touched by inclusive, 1-based input ranges. Protected blocks
  and bytes outside the selected prose are preserved. Combine it with
  `--check` to check just those ranges.
- **Preserve Markdown structure.** Wrapping keeps prose from accidentally
  becoming a list, heading, blockquote, or other Markdown block. It also
  keeps literal backslashes from turning into hard line breaks.
- **Improve punctuation handling.** Wrapping keeps punctuation next to the
  text or inline markup it belongs to, including matched quotes and a wider
  range of sentence marks. Opt-in `--repair` also fixes spacing around
  inline code in matched parentheses and braces.
- **Match BBEdit column counts.** BBEdit's Markdown-aware wrapping uses
  UTF-16 code units to match the editor's column counts for text such as
  emoji. Use `--width-unit=utf16` for the same behavior on the command line.

Both CLIs support the new flags.
