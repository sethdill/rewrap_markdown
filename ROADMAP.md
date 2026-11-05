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
- [ ] Obtain Seth's explicit approval before creating/publishing the separate tap.
- [ ] Pin the final v0.3 release commit and publish the approved tap PR.
- [ ] Verify `brew install sethdill/tap/rewrap-markdown` from the public tap.

See [the tap handoff](Packaging/homebrew/README.md). Homebrew installs the CLI
only and never changes BBEdit support folders. The provisional formula is
staged upstream; the separate tap will own the user-facing installation path.

## Later releases

- [ ] Consider an installer cask only after Developer ID signing, notarization,
  and Gatekeeper acceptance of the normally quarantined package.
- [ ] Reconsider binary-backed tap distribution if compiler/runtime dependencies
  outweigh the simplicity of source builds, with immutable assets and native
  validation required before switching.
