# Releasing

Rewrap Markdown uses simple source tags plus GitHub Releases.

## Versioning

The public version is stored in `VERSION` and exposed by both command-line
implementations:

```sh
swift run rewrap-markdown --version
python3 Reference/rewrap_markdown.py --version
```

Before a release, update:

- `VERSION`
- `RewrapMarkdown.version` in `Sources/RewrapMarkdownCore/RewrapMarkdown.swift`
- `VERSION` in `Reference/rewrap_markdown.py`
- the current version note in `README.md`
- `RELEASE_NOTES.md`

The test suite checks that the implementations report the version from
`VERSION`.

## Build Artifacts

Create local release artifacts with:

```sh
make dist
```

On macOS this creates:

- `dist/rewrap-markdown-VERSION-macos-ARCH`
- `dist/rewrap-markdown-VERSION.py`
- `dist/Rewrap Markdown (Swift)`
- `dist/Markdown-Hard-Wrap-Menu-Action.applescript`
- `dist/rewrap-markdown-commit-msg`

On Linux, `make dist` stages a native `linux-ARCH` executable plus the Python
script and Git hook; it excludes BBEdit files. These native builds are not
necessarily portable to another distribution. `make dist-cli` stages only this
portable target set on either platform. Installer and BBEdit targets require
macOS.

Build and verify a local unsigned installer with:

```sh
make pkg-unsigned
Packaging/pkg/verify-installer.sh "dist/rewrap-markdown-$(cat VERSION)-unsigned.pkg"
```

This is useful for testing, but local builds only produce a binary for the
current machine architecture. The GitHub Actions release workflow builds both:

- `rewrap-markdown-VERSION-macos-x86_64`
- `rewrap-markdown-VERSION-macos-arm64`

Linux CI first runs `make test-executable` on native x86_64 and aarch64 runners,
covering the Swift core, CLI, Python compatibility cases, and hook safety. The
reusable `linux-release.yml` workflow builds with Swift 6.2.1 and the matching
[official Static Linux SDK](https://www.swift.org/documentation/articles/static-linux-getting-started.html).
Its SDK URL and SHA-256 are pinned in that workflow, using Swift.org's release
metadata. To reproduce, install that toolchain and SDK, then run:

```sh
make dist-linux LINUX_ARCH=x86_64
make dist-linux LINUX_ARCH=aarch64
```

This produces `rewrap-markdown-VERSION-linux-x86_64` and
`rewrap-markdown-VERSION-linux-aarch64`, each with a `.sha256` file. SHA files
contain the basename so `sha256sum -c BINARY.sha256` works after downloading.
The build requires Make and `shasum` (on Debian/Ubuntu: `libdigest-sha-perl`).
SDK and toolchain versions must match; use the open-source toolchain rather
than Xcode's compiler for static cross-compilation.

The workflow rejects ELF interpreters and shared-library dependencies, runs the
full compatibility suite against each produced binary, then downloads the
artifacts into separate runtime tests. Both architectures execute natively
inside Ubuntu 22.04/24.04, Debian 12, and Alpine 3.22 containers without Swift.
Smoke tests verify checksums, wrap/unwrap, Unicode, protected Markdown, commit
mode, and successful/failing hooks invoked by Git for both implementations.
This is userland coverage on GitHub-hosted kernels, not a test of every distro
kernel or every Linux distribution.

Separate native Ubuntu VM jobs on x86_64 and aarch64 follow the README's
installation steps: verify the downloaded checksum, install into
`~/.local/bin`, invoke the command through `PATH` from outside the checkout,
exercise wrapping/unwrapping/commit mode and the installed Git hook, then remove
the binary and confirm it is no longer available. They also reject a deliberately
corrupted download before installation. These jobs run without a job container
and are required by the reusable release workflow alongside the distro tests.

The `Linux` workflow runs on pull requests and builds these same artifacts. The
`Release` workflow reuses the build and smoke jobs and waits for them before
publishing, alongside the unchanged macOS installer pipeline.

The workflow also uploads:

- `rewrap-markdown-VERSION-unsigned.pkg`, universal for Intel and Apple Silicon
- `rewrap-markdown-VERSION-unsigned.pkg.sha256`
- `rewrap-markdown-VERSION-linux-x86_64` and its `.sha256`
- `rewrap-markdown-VERSION-linux-aarch64` and its `.sha256`
- `rewrap-markdown-VERSION.py`
- `Rewrap-Markdown-Swift`
- `Markdown-Hard-Wrap-Menu-Action.applescript`
- `rewrap-markdown-commit-msg`

Before opening the release pull request, run the `Release` workflow manually
from the release branch with **Publish** disabled and leave **Tag** empty. This
builds the release-candidate artifacts without creating a GitHub Release.

Before publishing Linux binaries, confirm the build and every runtime smoke job
and native installation jobs passed for the exact release commit. A separate
Linux host is not required for these checks. Older kernels and distributions
outside the CI matrix remain unvalidated; test them before extending the
compatibility claim.

After publishing v0.3 or later, run **Actions > Verify published Linux
installation > Run workflow**, selecting the release tag as the **tag** input.
This downloads the actual GitHub Release binary, checksum, and commit-msg hook
on both architectures, then runs the same installation/removal test. It only
reads release assets and does not publish or modify a release. The workflow
must be present on the default branch for manual dispatch, and the selected
release tag must include the installation test scripts. For example:

```sh
gh workflow run linux-install.yml --ref main -f tag=v0.3
```

This final download-to-install check can only run after the release assets
exist; the pre-publication jobs exercise the exact workflow artifacts instead.

The installer is currently unsigned and not notarized. Before publishing a
release, download the Actions-built package to a Mac and perform this manual
Gatekeeper test:

1. Verify the checksum with `shasum -a 256 -c PACKAGE.sha256`.
2. Double-click the downloaded package and confirm macOS initially blocks it.
3. Use **System Settings > Privacy & Security > Open Anyway** and confirm the
   installer opens after authentication.
4. Check the default component selections, install, and smoke-test both BBEdit
   Hard Wrap commands.
5. Run the installer again and confirm previously installed optional
   components are selected.
6. Run the installed uninstaller and confirm the BBEdit integrations and
   `/usr/local/bin/rewrap-markdown` link are removed.

The Python file can be installed directly as a BBEdit text filter. The Swift
BBEdit wrapper should be installed alongside a downloaded Swift binary or
configured to point at it.

## Tagging

For version `0.3`, tag the tested merge commit as:

```sh
git tag v0.3
git push origin main v0.3
```

Pushing the tag runs the release workflow. If the GitHub Release already exists,
the workflow uploads or replaces the assets. If the release does not exist, the
workflow creates it.

For a tag that already exists, run the `Release` workflow manually from GitHub
Actions, enable **Publish**, and enter the tag name, such as `v0.3`.

## Homebrew release handoff

Homebrew support is staged in `Packaging/homebrew`, with the decision and native
validation matrix documented in its [README](Packaging/homebrew/README.md).
After finalizing a release tag, run `scripts/update-homebrew.py` with the public
version and full release commit SHA. Review the URL, version, and SHA-256 diff;
run style, strict online audit, installation, functional tests, and linkage on
both macOS architectures and both Linux architectures. Open a separate tap PR
only after Seth approves creating/publishing `sethdill/homebrew-tap`. Do not
claim the public brew command works until the approved tap is published and
clean-machine installation is verified. There is no automatic tap publishing.

Never move a published source tag or overwrite an archive to fix a release.
The formula pins commit archives; a changed digest requires investigation.
The unsigned installer is ineligible for a cask: require signing, notarization,
and normal Gatekeeper acceptance before proposing one.

On Linux, this formula deliberately retains Homebrew Swift as a runtime
dependency. Recheck the formula after Swift upgrades; if runtime compatibility
changes, rebuild and increment the formula revision in the tap. A successful
upstream Swift-container test alone does not validate Homebrew's toolchain or
runtime linkage.
