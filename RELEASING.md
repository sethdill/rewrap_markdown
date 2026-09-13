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

The test suite checks that the implementations report the version from
`VERSION`.

## Build Artifacts

Create local release artifacts with:

```sh
make dist
```

This creates:

- `dist/rewrap-markdown-VERSION-macos-ARCH`
- `dist/rewrap-markdown-VERSION.py`
- `dist/Rewrap Markdown (Swift)`

This is useful for testing, but local builds only produce a binary for the
current machine architecture. The GitHub Actions release workflow builds both:

- `rewrap-markdown-VERSION-macos-x86_64`
- `rewrap-markdown-VERSION-macos-arm64`

The workflow also uploads:

- `rewrap-markdown-VERSION.py`
- `Rewrap-Markdown-Swift`

The Python file can be installed directly as a BBEdit text filter. The Swift
BBEdit wrapper should be installed alongside a downloaded Swift binary or
configured to point at it.

## Tagging

For version `0.1`, tag the release as:

```sh
git tag v0.1
git push origin main v0.1
```

Pushing the tag runs the release workflow. If the GitHub Release already exists,
the workflow uploads or replaces the assets. If the release does not exist, the
workflow creates it.

For a tag that already exists, run the `Release` workflow manually from GitHub
Actions and enter the tag name, such as `v0.1`.
