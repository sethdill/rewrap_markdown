# Rewrap Markdown

**Wrap prose without mangling Markdown.**

Rewrap Markdown is a command-line filter and BBEdit integration that makes
long Markdown readable in source form while preserving the structure that
makes it Markdown.

Give it this unwrapped task inside a blockquote:

```markdown
> - [ ] This release note has a [long link](https://example.com/releases/next) and an `inline command` that should stay intact while the surrounding prose wraps neatly.
```

At `54` columns, it produces:

```markdown
> - [ ] This release note has a
>   [long link](https://example.com/releases/next) and
>   an `inline command` that should stay intact while
>   the surrounding prose wraps neatly.
```

and at `80` columns it produces:

```markdown
> - [ ] This release note has a [long link](https://example.com/releases/next)
>   and an `inline command` that should stay intact while the surrounding prose
>   wraps neatly.
```

The prose is tidy. The quote, task marker, hanging indentation, link, and code
span still mean exactly what they meant before.

## Why Use It?

A generic line wrapper sees words and spaces. Rewrap Markdown also sees lists,
blockquotes, links, code, tables, alerts, comments, and hard line breaks.

That makes it useful when you:

- prefer readable, consistently wrapped Markdown source;
- move text among GitHub, Jira, Confluence, and text editors;
- need to reflow a list or quoted passage without repairing its indentation;
- want to wrap prose while leaving code blocks, tables, and HTML alone.

## Command Line

Wrap a document at 80 columns:

```sh
rewrap-markdown 80 < draft.md > draft-wrapped.md
```

Or rewrap text on the macOS clipboard:

```sh
pbpaste | rewrap-markdown 72 | pbcopy
```

The width is chosen in this order:

1. First command-line argument
2. `MD_REWRAP_WIDTH` (environment variable)
3. Default width of `70`

Use `rewrap-markdown --version` or `rewrap-markdown -v` to print the version.

## BBEdit

Rewrap Markdown offers two BBEdit workflows.

### Rewrap Markdown Text Filter

The standard integration adds **Text > Apply Text Filter > Rewrap Markdown**.
It filters the selection, or the entire document when nothing is selected, at
a configured width.

From a source checkout:

```sh
make install
```

The default width is 70. Choose another width during installation with:

```sh
FILTER_WIDTH=80 make install
```

To change the preferred width after installing the filter, hold the option key
when you choose the filter, then edit the `WRAP_WIDTH` variable.

### Markdown-Aware Hard Wrap

The optional menu attachment takes over **Text > Hard Wrap…** only for
Markdown documents. It asks for a width, remembers your answer, and rewraps the
selection or document. For other document types, BBEdit behaves normally.

```sh
make install-hard-wrap
```

Its modifiers mirror BBEdit's own menu behavior:

- Use **Text > Hard Wrap** to rewrap immediately using the remembered width.
- Hold Shift to bypass Rewrap Markdown and run BBEdit's built-in command.

Remove the optional attachment with `make uninstall-hard-wrap`.

The Hard Wrap integration is currently available from source and is planned
for the 0.2 release.

## Install

### Release Binary

Download the binary for your Mac from the
[latest release](https://github.com/sethdill/rewrap_markdown/releases/latest).
For the current 0.1 release:

```sh
VERSION=0.1
ARCH=$(uname -m)
mkdir -p "$HOME/.local/bin"
install -m 755 \
  "$HOME/Downloads/rewrap-markdown-${VERSION}-macos-${ARCH}" \
  "$HOME/.local/bin/rewrap-markdown"
```

`~/.local/bin` is the default installation directory because it is stable,
per-user, and does not require administrator access. If it is not already on
your shell path, add this to `~/.zprofile`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

For BBEdit 0.1 integration, also download `Rewrap-Markdown-Swift` from the
release and install it as a text filter:

```sh
mkdir -p "$HOME/Library/Application Support/BBEdit/Text Filters"
install -m 755 \
  "$HOME/Downloads/Rewrap-Markdown-Swift" \
  "$HOME/Library/Application Support/BBEdit/Text Filters/Rewrap Markdown"
```

### Build From Source

Building requires Swift 5.9 or newer:

```sh
git clone https://github.com/sethdill/rewrap_markdown.git
cd rewrap_markdown
make install-cli
```

`make install-cli` builds a release executable and copies it to
`~/.local/bin/rewrap-markdown`. It does not require BBEdit.

For BBEdit, use `make install` instead. It installs the executable and the
standard text filter. The filter points to the installed executable, so it
keeps working if the source checkout is moved or deleted.

Override the executable directory or BBEdit support folder when needed:

```sh
INSTALL_BIN_DIR=/usr/local/bin make install-cli
BBEDIT_FILTERS_DIR="/path/to/Text Filters" make install
```

Use a directory your account can write to. Running the entire target with
`sudo` is not recommended because the BBEdit integration is installed for the
current user.

## Markdown It Understands

Rewrap Markdown handles ordinary paragraphs plus the places where wrapping is
easy to get subtly wrong:

- ordered, unordered, nested, and task lists;
- blockquotes and quoted lists;
- GitHub alert blocks;
- footnote definitions;
- inline links, images, autolinks, bare URLs, and code spans;
- backslash and two-space hard line breaks.

It leaves structural content alone, including headings, reference definitions,
tables, fenced and indented code, HTML blocks, comments, and thematic breaks.

For a deliberately excessive tour, compare
[the unwrapped demo](Samples/gfm_supported_unwrapped.md) with
[the wrapped result](Samples/gfm_supported_wrapped.md).

## Other Editors

The executable reads UTF-8 from standard input and writes UTF-8 to standard
output, so it works with any editor that can filter selected text through a
command.

Vim and Neovim can filter a visual selection:

```vim
:'<,'>!rewrap-markdown 72
```

Or the entire buffer:

```vim
:%!rewrap-markdown 72
```

In Emacs, `C-u M-| rewrap-markdown 72 RET` replaces the active region with the
filtered output.

## Development

```sh
make build
make test
make test-executable
make dist
```

The wrapping engine lives in `RewrapMarkdownCore`, separate from the
stdin/stdout executable.

The test suite runs shared compatibility cases against the Swift implementation
and the original Python reference implementation.

My original Python script remains available at `Reference/rewrap_markdown.py`
for comparison and experimentation; it is no longer the main installation path.

## License

Licensed under the Apache License, Version 2.0. See `LICENSE` and `NOTICE`.
