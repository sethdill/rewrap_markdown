# Rewrap Markdown

## Contents

- [Rewrap Prose](#rewrap-prose)
- [Why Use It?](#why-use-it)
- [Markdown It Understands](#markdown-it-understands)
- [Install](#install)
- [Command Line](#command-line)
- [BBEdit](#bbedit)
- [Other Editors](#other-editors)
- [Development](#development)
- [License](#license)

## Rewrap Prose

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

For a deliberately excessive tour, compare the
[unwrapped demo document](Samples/gfm_supported_unwrapped.md) with the
[wrapped demo document](Samples/gfm_supported_wrapped.md).

## Install

Rewrap Markdown requires macOS 12 or later. The BBEdit integrations have been
tested with BBEdit 15.5.5.

### macOS Installer

The easiest installation is the universal macOS package from the
[latest release](https://github.com/sethdill/rewrap_markdown/releases/latest).
Its Customize screen offers:

- **Markdown-aware Hard Wrap for BBEdit**, selected by default;
- **BBEdit Text Filter**, optional;
- **Command-line link** at `/usr/local/bin/rewrap-markdown`, optional.

The installer is unsigned. After trying to open it, macOS may block it
because it cannot verify the developer. Open **System Settings > Privacy &
Security**, scroll to Security, click **Open Anyway** for the Rewrap Markdown
installer, authenticate, and confirm **Open**. Only bypass this warning for an
installer downloaded from this project's GitHub release.

Each release includes a `.sha256` file. To verify the download before opening
it, run this in the directory containing both files:

```sh
shasum -a 256 -c rewrap-markdown-0.2-unsigned.pkg.sha256
```

Upgrades retain the remembered Hard Wrap width and automatically update any
optional components that were installed previously. To remove all package
components and their receipts:

```sh
sudo "/Library/Application Support/Rewrap Markdown/uninstall-rewrap-markdown"
```

### Release Binary

Download the binary for your Mac from the
[latest release](https://github.com/sethdill/rewrap_markdown/releases/latest).
For the current 0.2 release:

```sh
VERSION=0.2
ARCH=$(uname -m)
mkdir -p "$HOME/.local/bin"
install -m 755 \
  "$HOME/Downloads/rewrap-markdown-${VERSION}-macos-${ARCH}" \
  "$HOME/.local/bin/rewrap-markdown"
```

`~/.local/bin` is the default installation directory because it is stable,
per-user, and does not require administrator access. If it is not already on
your shell path, add this to `~/.zprofile` when using Zsh or
`~/.bash_profile` when using Bash:

```sh
export PATH="$HOME/.local/bin:$PATH"
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

#### BBEdit Integrations

For BBEdit, use `make install` instead. It installs the executable and the
standard text filter. The filter points to the installed executable, so it
keeps working if the source checkout is moved or deleted.

The filter uses a width of 70 by default. Choose another width when installing
it with:

```sh
FILTER_WIDTH=80 make install
```

Install the Markdown-aware Hard Wrap integration with
`make install-hard-wrap`, or install both BBEdit integrations with
`make install-all`. Remove Hard Wrap with `make uninstall-hard-wrap`, or remove
both integrations and the executable with `make uninstall-all`.

Override the executable directory or BBEdit support folder when needed:

```sh
INSTALL_BIN_DIR=/usr/local/bin make install-cli
BBEDIT_FILTERS_DIR="/path/to/Text Filters" make install
```

Use a directory your account can write to. Running the entire target with
`sudo` is not recommended because the BBEdit integration is installed for the
current user.

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

The text filter adds **Text > Apply Text Filter > Rewrap Markdown**. It filters
the selection, or the entire document when nothing is selected, at a configured
width of 70 by default.

To change the preferred width after installing the filter, hold the option key
when you choose the filter, then edit the `WRAP_WIDTH` variable.

### Markdown-Aware Hard Wrap

The menu attachment takes over **Text > Hard Wrap…** only for Markdown
documents. It asks for a width, remembers your answer, and rewraps the selection
or document. For other document types, BBEdit behaves normally.

Its modifiers mirror BBEdit's own menu behavior:

- Use **Text > Hard Wrap** to rewrap immediately using the remembered width.
- Hold Shift to bypass Rewrap Markdown and run BBEdit's built-in command.

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

The Swift implementation was ported from a Python-based text filter by the same
author. The test suite runs shared compatibility cases against both versions.

The Python script remains available at `Reference/rewrap_markdown.py` for
comparison and experimentation; it is no longer the main installation path.

## License

Licensed under the Apache License, Version 2.0. See `LICENSE` and `NOTICE`.
