# Provisional Homebrew tap

This directory is a reviewable tap layout, not a published tap. On November 4,
2026, both the GitHub connector and authenticated `gh api` returned 404 for
`sethdill/homebrew-tap`; no accessible repository was found. A private repository
outside the account's access cannot be ruled out. Do not create the repository
or publish its contents without Seth's explicit approval.

Once approved, released, and published, the intended command is:

```sh
brew install sethdill/tap/rewrap-markdown
```

It installs only the CLI, license, and notice into Homebrew's Cellar. There are
no BBEdit files, hooks, services, post-install scripts, or changes to support
folders. Homebrew handles linking, upgrades, and `brew uninstall`.

## Source versus release binaries

Use a **source formula**. The initial URL pins the full Linux-support merge
commit `97b8ff23352ce8b46fcdc372404d3d0300265edb`, with a SHA-256 calculated from
the downloaded archive. Its `VERSION` is 0.3, but it is a provisional snapshot:
v0.3 has not shipped. Replace it with the reviewed v0.3 release commit before
launch; never publish this snapshot as the stable release.

The package has no external Swift package dependencies. macOS builds use Xcode
15 or later. Linux uses Homebrew's `swift` formula and retains it as a runtime
dependency: native Swift builds can link Swift/Foundation shared libraries.
A `:build`-only dependency on Linux would incorrectly assume the installed CLI
can run after Swift is removed. `brew linkage --test` checks the installed keg.
The formula calls SwiftPM directly, avoiding the Makefile's editor installation
targets. SwiftPM's nested sandbox is disabled inside Homebrew's build sandbox.

Release binaries would avoid a compiler download and Linux runtime dependency,
and the new static Linux assets already have broader distro smoke coverage.
However, currently published v0.2 assets are macOS-only and lack `--unwrap` and
`--commit`. Versioned GitHub release assets can also be replaced by the current
release workflow; they are not immutable merely because their URL has a tag.
Source pinned to a commit offers one checksummed input across architectures,
transparent builds, and no per-platform asset synchronization. Checksums fail
closed if GitHub ever changes archive bytes. Do not switch to a moving branch,
`latest` download URL, or remove checksum verification to repair such a failure.

This is a custom tap, not a submission to homebrew/core. Core's source-build
policy and acceptance requirements are distinct from custom tap distribution.
If source builds become unreliable or too expensive, reconsider signed macOS
and static Linux release binaries with an explicit asset immutability policy,
four platform checksums, native formula tests, and runtime linkage verification.

## Local validation

In a clean Homebrew environment, prepare a **local-only** tap:

```sh
brew tap-new sethdill/tap
cp Packaging/homebrew/Formula/rewrap-markdown.rb "$(brew --repository sethdill/tap)/Formula/"
brew style sethdill/tap/rewrap-markdown
brew audit --strict --online sethdill/tap/rewrap-markdown
brew install --build-from-source --verbose sethdill/tap/rewrap-markdown
brew test sethdill/tap/rewrap-markdown
brew linkage --test sethdill/tap/rewrap-markdown
brew uninstall sethdill/tap/rewrap-markdown
```

On current Homebrew, run `brew trust --formula sethdill/tap/rewrap-markdown`
after copying the reviewed formula and before audit/install. Older Homebrew
versions may not have that command. The fully qualified public install command
trusts only the requested formula.

Do not overwrite an existing real tap; use an isolated CI runner instead.
The formula asserts version reporting, ordinary wrapping, unwrap, and commit
wrapping with subject and trailer preservation using standard input/output.
`.github/workflows/homebrew.yml` runs these checks on native Apple Silicon,
Intel macOS, x86_64 Linux, and ARM64 Linux. A plain Swift build in a Swift Docker
image is not sufficient evidence of a working Homebrew Linux formula.
Homebrew may support fewer OS versions than the CLI itself.

## Release updates and separate repository handoff

After the release tag is final, resolve it to its full commit and regenerate:

```sh
revision=$(gh api repos/sethdill/rewrap_markdown/commits/v0.3 --jq .sha)
python3 scripts/update-homebrew.py --version 0.3 --revision "$revision"
```

The updater downloads the commit archive, validates its embedded `VERSION`,
computes SHA-256, and replaces only version/URL/checksum. It neither tags nor
pushes anything. A rerun with the same archive must produce no diff. Review
the commit against the release tag and verify the digest independently with
`curl -fL URL -o source.tar.gz && shasum -a 256 source.tar.gz`.
Run the entire native matrix after each update; preserve evidence in the PR.

Work belonging in `sethdill/homebrew-tap`, **after approval**:

1. Copy `Formula/rewrap-markdown.rb` from this directory to the tap's `Formula/`.
2. Add a user-facing README with installation, upgrade, uninstall, supported
   platforms, and a link to the upstream issue tracker.
3. Port the Homebrew CI matrix; in the real tap, use its checked-out formula
   rather than running `tap-new` over the tap itself. Run style, audit, install,
   test, and linkage checks for every formula change.
4. Open and review a tap PR per upstream release. The updater can target that
   checkout with `--output /path/to/homebrew-tap/Formula/rewrap-markdown.rb`.
5. Merge the approved tap PR, verify the public installation command on clean
   macOS and Linux machines, then mark availability in upstream README/roadmap.

Keep this provisional formula synchronized until the handoff. Afterward the tap
is authoritative; remove the duplicate upstream copy or explicitly keep it as a
tested staging copy. Source formulae need no bottle publishing credentials.
The generated `tap-new` bottle publishing workflows are not required here.

## Installer cask gate

No cask is prepared. The current `.pkg` is unsigned and not notarized. Consider
one only after Developer ID signing, successful notarization/stapling, signature
verification, and Gatekeeper acceptance of the normally quarantined download.
Do not use `--no-quarantine`, remove quarantine, or instruct users to use Open
Anyway as a Homebrew installation path.

## Primary documentation

Reviewed November 4, 2026:

- [How to create and maintain a tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap): repository naming, `Formula/`, direct installation, maintenance.
- [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook): dependency declarations, checksums, functional tests, style and audit.
- [Acceptable Formulae](https://docs.brew.sh/Acceptable-Formulae): immutable sources and core's source-build policy (core-specific).
- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux): Linux prerequisites and supported prefix.
- [Swift formula](https://formulae.brew.sh/formula/swift) and [source](https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/s/swift.rb): platform dependencies and Linux bottles.
- [Cask acceptable casks](https://docs.brew.sh/Acceptable-Casks): signing, notarization, and Gatekeeper policy.
