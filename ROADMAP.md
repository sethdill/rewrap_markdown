# Roadmap

Version [0.3](https://github.com/sethdill/rewrap_markdown/releases/tag/v0.3)
is published. Later releases list planned work.

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

See the [completed publishing checklist](RELEASING.md#v03-publishing-checklist)
and the [tap maintenance notes](Packaging/homebrew/README.md).

## Later releases

### Punctuation repair

- [ ] Define when opt-in `--repair` should remove spaces before punctuation
  following inline spans, for example changing `` `code` , `` to
  `` `code`, ``. Decide which marks and contexts qualify, and cover the rules
  with shared Swift and Python cases. Basic rewrap preserves source adjacency.

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
