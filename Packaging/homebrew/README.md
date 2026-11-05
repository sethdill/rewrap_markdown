# Homebrew formula

The [public tap](https://github.com/sethdill/homebrew-tap) is the authoritative
source for installation. This directory retains a tested staging copy.
The [v0.3 publishing checklist](../../RELEASING.md#v03-publishing-checklist)
records the launch and validation.

Install with:

```sh
brew install sethdill/tap/rewrap-markdown
```

It installs only the CLI, license, and notice into Homebrew's Cellar. There are
no BBEdit files, hooks, services, post-install scripts, or changes to support
folders. Homebrew handles linking, upgrades, and `brew uninstall`.

## Source versus release binaries

The **source formula** pins the full v0.3 release commit
`edbe983f49e62535004e32bd2c1edefb0bd4dd7f` and verifies the SHA-256
of its archive before building.

The package has no external Swift package dependencies. macOS builds use Xcode
15 or later. Linux uses Homebrew's `swift` formula and retains it as a runtime
dependency: native Swift builds can link Swift/Foundation shared libraries.
A `:build`-only dependency on Linux would incorrectly assume the installed CLI
can run after Swift is removed. `brew linkage --test` checks the installed keg.
The formula calls SwiftPM directly, avoiding the Makefile's editor installation
targets. SwiftPM's nested sandbox is disabled inside Homebrew's build sandbox.

Release binaries would avoid a compiler download and Linux runtime dependency,
and the new static Linux assets already have broader distro smoke coverage.
Versioned GitHub release assets can be replaced by the current
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

For each upstream release, transfer the validated formula to the tap and open a
tap PR. The updater can target the tap checkout with
`--output /path/to/homebrew-tap/Formula/rewrap-markdown.rb`.
Review the PR and run the native style, audit, source install, formula tests,
linkage, and removal checks. After merging, verify the public installation
command on clean macOS and Linux runners. Keep the upstream staging copy
synchronized with the tap.

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
