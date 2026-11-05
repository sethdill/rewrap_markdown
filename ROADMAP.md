# Roadmap

This is a release planning checklist, not a release commitment. Version 0.2 is
published; 0.3 is in preparation on `release/0.3`.

## 0.3

### Linux CLI

- [x] Merge native x86_64 and ARM64 compatibility, static builds, distro smoke
  tests, and installation/removal validation.
- [ ] Verify installation from published v0.3 assets after release.

### Homebrew CLI installation

- [x] Prepare a CLI-only source formula with an immutable commit URL and SHA-256.
- [x] Add version, wrapping, unwrap, and commit-mode formula assertions.
- [x] Add native macOS and Linux Homebrew CI on both architectures.
- [x] Document source versus binary tradeoffs and repeatable release updates.
- [x] Complete the Homebrew matrix and record results before merging.
- [x] Obtain Seth's approval to create and publish the tap after v0.3 ships
  and the formula passes validation against the final release commit.
- [ ] Pin the final v0.3 release commit and create the public tap and publish the formula.
- [ ] Verify `brew install sethdill/tap/rewrap-markdown` from the public tap.

Follow the [v0.3 publishing checklist](RELEASING.md#v03-publishing-checklist)
when tagging the release. See [the tap handoff](Packaging/homebrew/README.md). Homebrew installs the CLI
only and never changes BBEdit support folders. The provisional formula is
staged upstream; the separate tap will own the user-facing installation path.

## Later releases

- [ ] Consider an installer cask only after Developer ID signing, notarization,
  and Gatekeeper acceptance of the normally quarantined package.
- [ ] Reconsider binary-backed tap distribution if compiler/runtime dependencies
  outweigh the simplicity of source builds, with immutable assets and native
  validation required before switching.
