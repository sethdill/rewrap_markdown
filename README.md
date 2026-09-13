# Rewrap Markdown

A Swift command-line Markdown rewrap filter, ported from the original BBEdit
Python text filter. Both implementations read UTF-8 text from standard input
and write the rewrapped Markdown to standard output.

Current version: `0.1`.

## Install for BBEdit

Download files from the latest GitHub Release:

```text
https://github.com/sethdill/rewrap_markdown/releases/latest
```

Do not use GitHub's green **Code** button unless you want the source code.
Regular BBEdit users probably want one of the release downloads instead.

### Option 1: Swift Version

This is the faster version. Download the binary for your Mac:

- Apple Silicon: `rewrap-markdown-0.1-macos-arm64`
- Intel: `rewrap-markdown-0.1-macos-x86_64`

Also download:

- `Rewrap-Markdown-Swift`

If the files are in your Downloads folder, install them with these commands.
For Apple Silicon:

```sh
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/Library/Application Support/BBEdit/Text Filters"
cp "$HOME/Downloads/rewrap-markdown-0.1-macos-arm64" "$HOME/.local/bin/rewrap-markdown"
cp "$HOME/Downloads/Rewrap-Markdown-Swift" "$HOME/Library/Application Support/BBEdit/Text Filters/Rewrap Markdown"
chmod +x "$HOME/.local/bin/rewrap-markdown"
chmod +x "$HOME/Library/Application Support/BBEdit/Text Filters/Rewrap Markdown"
xattr -d com.apple.quarantine "$HOME/.local/bin/rewrap-markdown" 2>/dev/null || true
xattr -d com.apple.quarantine "$HOME/Library/Application Support/BBEdit/Text Filters/Rewrap Markdown" 2>/dev/null || true
```

For Intel, use the same commands but change the binary filename:

```sh
cp "$HOME/Downloads/rewrap-markdown-0.1-macos-x86_64" "$HOME/.local/bin/rewrap-markdown"
```

The BBEdit menu item will appear as **Rewrap Markdown**. To use a different
wrap width, edit the installed filter and change:

```sh
WRAP_WIDTH=70
```

to `WRAP_WIDTH=80`, `WRAP_WIDTH=120`, or whatever width you prefer.

In BBEdit, use **Text > Apply Text Filter > Rewrap Markdown**.

### Option 2: Python Version

This version is easier to inspect and tinker with, and can be installed by
itself. It intentionally supports Python 3.10 and newer; it may also work on
Python 3.9.

Download:

- `rewrap-markdown-0.1.py`

If the file is in your Downloads folder:

```sh
mkdir -p "$HOME/Library/Application Support/BBEdit/Text Filters"
cp "$HOME/Downloads/rewrap-markdown-0.1.py" "$HOME/Library/Application Support/BBEdit/Text Filters/Rewrap Markdown.py"
chmod +x "$HOME/Library/Application Support/BBEdit/Text Filters/Rewrap Markdown.py"
xattr -d com.apple.quarantine "$HOME/Library/Application Support/BBEdit/Text Filters/Rewrap Markdown.py" 2>/dev/null || true
```

To use a different wrap width, edit the installed Python filter and change:

```python
DEFAULT_WIDTH = 70
```

In BBEdit, use **Text > Apply Text Filter > Rewrap Markdown.py**.

## Command Line

```sh
swift run rewrap-markdown 80 < input.md > output.md
```

Show the version:

```sh
swift run rewrap-markdown --version
swift run rewrap-markdown -v
python3 Reference/rewrap_markdown.py --version
python3 Reference/rewrap_markdown.py -v
```

Width resolution:

1. First command-line argument
2. `MD_REWRAP_WIDTH`
3. Default width of `70`

## Build From Source

Common project tasks are available through `make`:

```sh
make build
make test
make test-executable
make dist
make install
```

`make dist` creates release artifacts in `dist/`: a macOS binary, the standalone
Python filter, and a drop-in BBEdit wrapper for the Swift binary.

GitHub Releases build and attach separate macOS binaries for Intel and Apple
Silicon automatically when a `v*` tag is pushed.

`make install` builds the release executable and installs a `Rewrap Markdown`
text filter into BBEdit's Text Filters folder. It asks BBEdit for that folder
with AppleScript. Override the install location with `BBEDIT_FILTERS_DIR`:

```sh
BBEDIT_FILTERS_DIR="$HOME/Library/Application Support/BBEdit/Text Filters" make install
```

The generated BBEdit wrapper uses width `70` by default. Override that with
`FILTER_WIDTH`:

```sh
FILTER_WIDTH=80 make install
```

After installation, you can also edit the generated BBEdit filter directly and
change:

```sh
WRAP_WIDTH=70
```

to whatever width you want (like 80, 120, etc.)

The implementation lives in `RewrapMarkdownCore` so the wrapping behavior can
be tested separately from stdin/stdout plumbing.

```sh
swift test
```

The original Python implementation is included at:

```text
Reference/rewrap_markdown.py
```

The Swift BBEdit wrapper source is included at:

```text
Distribution/BBEdit/Rewrap Markdown (Swift)
```

This is a very simple shell script that just calls the Swift version.

## Demo Document

A deliberately unwrapped demo document and its wrapped counterpart are included
at:

```text
Samples/gfm_supported_unwrapped.md
Samples/gfm_supported_wrapped.md
```

Compare them to see the context-aware behavior on paragraphs, lists, quoted
lists, links, tables, code fences, HTML, alerts, footnotes, and hard breaks.

### Tests

The tests use one shared set of compatibility cases. They always exercise the
Swift core implementation and the in-repo Python implementation.

Override the Python path with `PYTHON_REWRAP_MARKDOWN_PATH` to compare against
another copy:

```sh
PYTHON_REWRAP_MARKDOWN_PATH=/path/to/Rewrap\ Markdown.py swift test
```

To run the same cases against the compiled Swift executable too:

```sh
swift build -c release
REWRAP_MARKDOWN_EXECUTABLE=.build/release/rewrap-markdown swift test
```

## License

Licensed under the Apache License, Version 2.0. See `LICENSE` and `NOTICE`.
