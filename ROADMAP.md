# Roadmap

Version [0.3](https://github.com/sethdill/rewrap_markdown/releases/tag/v0.3)
was published on November 5, 2026. Later releases list planned work.

## 0.3

### Unwrap mode

- [x] Add `--unwrap` and width `0` to join paragraphs and list items while
  preserving Markdown structure and intentional hard line breaks.
- [x] Support unwrapping in both the Swift and Python command-line tools.
- [x] Let BBEdit's Markdown-aware Hard Wrap command accept and remember width
  `0`.

### Commit message mode

- [x] Add `--commit`, defaulting message bodies to 72 columns while preserving
  the subject line, `#` comments, and final Git trailer block.
- [x] Support explicit widths and `--commit --unwrap`.
- [x] Include and document a failure-safe `commit-msg` hook.

### Linux CLI

- [x] Merge native x86_64 and ARM64 compatibility, static builds, distro smoke
  tests, and installation/removal validation.
- [x] Verify installation from published v0.3 assets on x86_64 and ARM64.

### Homebrew CLI installation

- [x] Prepare a CLI-only source formula with an immutable commit URL and SHA-256.
- [x] Add version, wrapping, unwrap, and commit-mode formula assertions.
- [x] Add native macOS and Linux Homebrew CI on both architectures.
- [x] Document source versus binary tradeoffs and repeatable release updates.
- [x] Complete the Homebrew matrix and record results before merging.
- [x] Obtain Seth's approval to create and publish the tap after v0.3 ships
  and the formula passes validation against the final release commit.
- [x] Pin the final v0.3 release commit and publish the formula in the
  [public tap](https://github.com/sethdill/homebrew-tap).
- [x] Verify `brew install sethdill/tap/rewrap-markdown` on macOS and Linux.
  [CI passed on both architectures](https://github.com/sethdill/homebrew-tap/actions/runs/42054876568).

See the [completed publishing checklist](RELEASING.md#v03-publishing-checklist)
and the [tap maintenance notes](Packaging/homebrew/README.md).

## 0.4

### Punctuation repair

- [x] Keep prose punctuation with its neighboring word or inline span in basic
  wrapping and unwrapping, including repairs such as `` `code` , `` to
  `` `code`, ``.
- [x] Extend opt-in repair to matched prose braces and quote wrapping, with
  shared Swift and Python regression cases.

### Bugs

- [x] Prevent wrap boundaries from turning prose into Markdown lists,
  blockquotes, headings, thematic breaks, fences, tables, or HTML blocks.
- [x] Prevent a literal backslash in prose from becoming a Markdown hard break.
- [x] Keep spaced parentheses, braces, and matched quotes with adjacent text
  in default wrapping.
- [ ] Improve quote matching for straight single quotes, unbalanced nested
  delimiters, and quotes next to bare URLs.
- [x] Keep a separated sentence period with the preceding number while
  preserving ambiguous numeric spacing.
- [x] Keep punctuation with inline markup and emoji, including inverted marks
  before links and commas after autolinks or closing HTML tags.
- [x] Keep ellipses, fullwidth and Arabic sentence marks, and East Asian
  delimiters with adjacent text. Preserve thin spaces before punctuation
  across soft breaks.

## Later releases

### Check mode and pre-commit integration

- [ ] Add `--check` and `--diff` for CI and review workflows.
- [ ] Accept multiple file arguments and add safe in-place editing with `-i`.
- [ ] Add a hook definition for the pre-commit framework.

### Markdown in code comments

- [ ] Rewrap Markdown in Rust and Swift doc comments, Kotlin KDoc, Dart doc
  comments, and TypeScript JSDoc while preserving comment prefixes and code
  blocks.

### Semantic line breaks

- [ ] Add `--sentences` for one-sentence-per-line documentation workflows,
  with defined behavior for abbreviations, inline Markdown, and hard breaks.

### Partial-file wrapping

- [ ] Accept explicit line ranges and optionally limit changes to paragraphs
  touched by a Git diff.
- [ ] Keep unchanged regions byte-for-byte stable for agent and assistant
  workflows.

### Packaging

- [ ] Consider an installer cask only after Developer ID signing, notarization,
  and Gatekeeper acceptance of the normally quarantined package.
- [ ] Reconsider binary-backed tap distribution if compiler/runtime dependencies
  outweigh the simplicity of source builds, with immutable assets and native
  validation required before switching.
