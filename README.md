# Rewrap Markdown

A Swift command-line Markdown rewrap filter, ported from the original BBEdit
Python text filter. Both implementations read UTF-8 text from standard input
and write the rewrapped Markdown to standard output.

Current version: `0.1`.

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

`make install` builds the release executable and installs a `Rewrap Markdown`
text filter into BBEdit's Text Filters folder. It asks BBEdit for that folder
with AppleScript. Override the install location with `BBEDIT_FILTERS_DIR`:

```sh
BBEDIT_FILTERS_DIR="$HOME/Library/Application Support/BBEdit/Text Filters" make install
```

### Wrap Width

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

Width resolution matches the Python filter:

1. First command-line argument
2. `MD_REWRAP_WIDTH`
3. Default width of `70`

### BBEdit text filter

For a BBEdit text filter, build the executable and point the filter script at
the compiled binary:

```sh
swift build -c release
.build/release/rewrap-markdown 80
```

The implementation lives in `RewrapMarkdownCore` so the wrapping behavior can
be tested separately from stdin/stdout plumbing.

```sh
swift test
```

The original Python implementation is included at:

```text
Reference/rewrap_markdown.py
```

If you have Python 3.10 or newer installed, that file can be copied into
BBEdit's Text Filters folder and used instead of the Swift version. It may also
work on Python 3.9, though 3.10 and newer are the intentional support target.
It's not as fast, but if you want to tinker with it you may find it more
approachable.

#### Swift Wrapper for BBEdit

The Swift BBEdit wrapper for people who download a prebuilt binary is
included at:

```text
Distribution/BBEdit/Rewrap Markdown (Swift)
```

This is a very simple shell script that just calls the Swift version.

Put the Swift binary somewhere the wrapper searches, such as
`~/bin/rewrap-markdown`, `~/.local/bin/rewrap-markdown`, or beside the wrapper
in BBEdit's Text Filters folder. Then put `Rewrap Markdown (Swift)` in BBEdit's
Text Filters folder.

To change the BBEdit wrapping width, edit `WRAP_WIDTH=70` near the top of
that wrapper. The Python implementation can be installed directly as a
BBEdit text filter; to change its default width, edit `DEFAULT_WIDTH = 70`
in the Python file.

## Demo Document

A deliberately unwrapped demo document is included at:

```text
Samples/gfm_supported_unwrapped.md
```

Run it through the filter and save the result with `rewrapped` in the name to
show the context-aware behavior on paragraphs, lists, quoted lists, links,
tables, code fences, HTML, alerts, footnotes, and hard breaks.

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
