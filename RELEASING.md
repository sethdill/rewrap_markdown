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

Create release artifacts with:

```sh
make dist
```

This creates:

- `dist/rewrap-markdown-VERSION-macos-ARCH`
- `dist/rewrap-markdown-VERSION.py`
- `dist/Rewrap Markdown (Swift)`

Attach those files to the GitHub Release. The Python file can be installed
directly as a BBEdit text filter. The Swift BBEdit wrapper should be installed
alongside a downloaded Swift binary or configured to point at it.

## Tagging

For version `0.1`, tag the release as:

```sh
git tag v0.1
git push origin main v0.1
```

Then create a GitHub Release from the tag and upload the files from `dist/`.
