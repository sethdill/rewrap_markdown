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
- [Roadmap](ROADMAP.md)
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

### Homebrew

```sh
brew install sethdill/tap/rewrap-markdown
```

The [public tap](https://github.com/sethdill/homebrew-tap) installs the CLI from
checksummed source on macOS and Linux. For BBEdit integration, use the macOS
installer below.

The command-line tool supports macOS 12 or later and Linux. BBEdit integration
and the `.pkg` installer require macOS; the integrations have been tested with
BBEdit 15.5.5. Linux release binaries are introduced in 0.3.

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

Each release includes a `.sha256` file. Set `VERSION` to the version you
downloaded and run this in the directory containing both files:

```sh
VERSION=0.3
shasum -a 256 -c "rewrap-markdown-${VERSION}-unsigned.pkg.sha256"
```

Upgrades retain the remembered Hard Wrap width and automatically update any
optional components that were installed previously. To remove all package
components and their receipts:

```sh
sudo "/Library/Application Support/Rewrap Markdown/uninstall-rewrap-markdown"
```

### macOS Release Binary

Download the binary for your Mac from the
[latest release](https://github.com/sethdill/rewrap_markdown/releases/latest).
Set `VERSION` to the version you downloaded:

```sh
VERSION=0.3
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

### Linux Release Binary (0.3)

From the [releases page](https://github.com/sethdill/rewrap_markdown/releases),
choose a release starting with 0.3 and download both
`rewrap-markdown-VERSION-linux-x86_64` (Intel/AMD) or
`rewrap-markdown-VERSION-linux-aarch64` (ARM64), and its `.sha256` file.

In the directory containing the downloaded files:

```sh
VERSION=0.3
ARCH=$(uname -m)  # x86_64 or aarch64
BINARY="rewrap-markdown-${VERSION}-linux-${ARCH}"
sha256sum -c "${BINARY}.sha256"
mkdir -p "$HOME/.local/bin"
install -m 755 "$BINARY" "$HOME/.local/bin/rewrap-markdown"
export PATH="$HOME/.local/bin:$PATH"
rewrap-markdown --version
```

Keep the PATH export in your shell's startup file (for example `~/.bashrc`).
The binaries use Swift's official Static Linux SDK and need no installed Swift
runtime. CI executes both architectures natively with Ubuntu 22.04 and 24.04,
Debian 12, and Alpine 3.22 userlands, checking wrapping, unwrapping, commit
messages, and the Git hook. Native Ubuntu VM jobs also verify the README
installation steps, invocation through `PATH`, and removal on both architectures.
Other distributions and older kernels have not been
validated; these tests do not establish compatibility with every Linux system.

### Python on Linux

With Python 3.10 or newer, the reference CLI also supports all three modes:

```sh
python3 Reference/rewrap_markdown.py 72 < draft.md > draft-wrapped.md
python3 Reference/rewrap_markdown.py --unwrap < draft.md > draft-unwrapped.md
python3 Reference/rewrap_markdown.py --commit < message.txt > message-wrapped.txt
```

The release's `rewrap-markdown-VERSION.py` can be installed as
`~/.local/bin/rewrap-markdown` with `install -m 755` to use the same command and
Git hook as the Swift binary. Python compatibility cases run on Linux CI too.

### Build From Source

Building on macOS requires Swift 5.9 or newer. Linux CI uses Swift 6.2.1;
install a matching Linux toolchain from [Swift.org](https://www.swift.org/install/)
and ensure Python 3.10+, Git, and Make are available for the test suite:

```sh
git clone https://github.com/sethdill/rewrap_markdown.git
cd rewrap_markdown
make install-cli
```

`make install-cli` builds a release executable and copies it to
`~/.local/bin/rewrap-markdown`. It does not require BBEdit.

#### BBEdit Integrations (macOS Only)

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

### Wrap Markdown

Wrap a document at 80 columns:

```sh
rewrap-markdown 80 < draft.md > draft-wrapped.md
```

Or rewrap text on the macOS clipboard:

```sh
pbpaste | rewrap-markdown 72 | pbcopy
```

### Check Formatting

Use `--check` to test whether formatting would change a document.

```sh
rewrap-markdown --check 80 < draft.md
python3 Reference/rewrap_markdown.py --check 80 < draft.md
```

Both CLIs compare the formatted UTF-8 bytes with the original stdin bytes
and leave stdout empty. Exit status `0` means the bytes match, `1` means
formatting would change them, and `2` indicates an argument or input error
reported on stderr. The check uses the requested width and supports
`--unwrap`, width `0`, `--repair`, `--commit`, and `--indent`.

### Rewrap Specific Lines

Use repeatable `--lines START:END` arguments to select lines from standard input.
Line numbers are 1-based and inclusive. Every range uses the original input's
line numbers, even if rewrapping an earlier block changes its length.

```sh
rewrap-markdown --lines 8:12 --lines 24:24 80 < draft.md > draft-wrapped.md
rewrap-markdown --check --lines 8:12 80 < draft.md
```

A range that touches prose selects the whole paragraph or the prose belonging to
the same list item, with its enclosing list and quote context. Nested list items
can be selected independently. A range can reach across fenced or indented code
and other protected blocks to select prose on either side. Protected blocks and
all bytes outside the selected prose are preserved, including line endings,
trailing spaces, and the presence or absence of a final newline.

Both CLIs support width, `--unwrap`, `--repair`, and `--indent` with ranges.
`--check` reports whether the selected formatting would change the input.
Malformed, reversed, or out-of-bounds ranges exit with status `2` and a
diagnostic on stderr. `--lines` is incompatible with `--commit`.

### Unwrap Markdown

Join each paragraph and list item onto one line before pasting Markdown into a
GitHub comment, Jira, Slack, or a web form:

```sh
rewrap-markdown --unwrap < draft.md > draft-unwrapped.md
```

Width `0` is equivalent to `--unwrap`. Markdown structure, protected blocks,
and intentional hard line breaks are preserved.

### Prose Punctuation

Both implementations join prose commas, periods, question marks, and
exclamation marks to the preceding word or inline span in every wrap mode.
Inverted question and exclamation marks join the following word. Colons and
semicolons stay with the preceding text when wrapping, with their space
preserved. Ellipses and supported non-ASCII sentence marks also stay with
the preceding text and retain their spacing. Spaced parentheses, braces,
and matched quotes stay with the adjacent text. Longer passages can wrap
inside those delimiters. An inseparable group may exceed the requested
width. Wrapping also keeps inline markers with preceding prose when starting
a new line with them could create a Markdown block. Nonbreaking spaces, thin
spaces before punctuation, and hard line breaks are preserved.

### Repair Spacing Around Inline Code (Opt-in)

Use `rewrap-markdown --repair 70` to remove spacing between an inline code span
and a matched closing parenthesis. For example, ``(such as `code` )`` becomes
``(such as `code`)``. When the span is the entire parenthetical, repair also
removes spacing after the opener, so ``( `code` )`` becomes ``(`code`)``.
These repairs apply to spaces, tabs, and spacing joined from soft line breaks.
`( ordinary words )` and ``( `code` plus prose )`` retain their spacing.

Code contents, escapes, links, URLs, and protected blocks are opaque to repair.
Intentional hard breaks remain boundaries.

`--repair` works with `--unwrap` and width `0` (repair before joining), all
`--indent=preserve|tabs|spaces` styles, and `--commit` (body only; subject,
comments, and trailers stay unchanged). `--repair` also applies the code
spacing rule to matched prose braces. Interior quote spacing is preserved.
Square brackets remain protected as potential Markdown references, and
recognized template delimiters are treated as syntax.

### List Indentation

Rewrapping preserves the indentation style of each list item by default.
Tabbed lists and sublists can coexist with space-indented lists. Tabs advance
to the next four-column stop for Markdown parsing and wrap measurement.

Use `--indent=tabs` or `--indent=spaces` to convert list indentation
explicitly. `--indent=preserve` selects the default behavior. These options
also work with `--unwrap` and `--commit`.

### Commit Messages

Rewrap a commit message while leaving its subject line, `#` comment lines, and
final Git trailer block unchanged:

```sh
rewrap-markdown --commit < message.txt > message-wrapped.txt
```

Commit message bodies default to 72 columns. Supply a different width as a
numeric argument, or use `--commit --unwrap` to join each body paragraph without
changing the protected parts of the message.

To rewrap every commit message in a repository, install the included hook:

```sh
install -m 755 Distribution/Git/commit-msg .git/hooks/commit-msg
```

For a downloaded release hook, use `rewrap-markdown-commit-msg` as the source
path in the command above. Do not overwrite an existing hook without combining
its behavior. The hook works on Linux and macOS.

The hook rewrites Git's message file only after `rewrap-markdown --commit`
succeeds. Set `REWRAP_MARKDOWN` in the hook environment if the executable is not
on Git's command path.

The width is chosen in this order:

1. Numeric command-line argument
2. `MD_REWRAP_WIDTH` (environment variable)
3. Default width of `70`, or `72` in commit message mode

Use `rewrap-markdown --help` to see the available modes, or
`rewrap-markdown --version` to print the version.

## BBEdit

Rewrap Markdown offers two BBEdit workflows.

### Rewrap Markdown Text Filter

The text filter adds **Text > Apply Text Filter > Rewrap Markdown**. It filters
the selection, or the entire document when nothing is selected, at a configured
width of 70 by default.

To change the preferred width after installing the filter, hold the option key
when you choose the filter, then edit the `WRAP_WIDTH` variable.

BBEdit's Markdown-aware Hard Wrap and text filters measure width in UTF-16
code units to match BBEdit's column readout. To use the same measurement from
the command line, pass `--width-unit=utf16`.

### Markdown-Aware Hard Wrap

The menu attachment takes over **Text > Hard Wrap…** only for Markdown
documents. It asks for a width, remembers your answer, and rewraps the selection
or document. For other document types, BBEdit behaves normally.

Enter `0` for the width to unwrap each paragraph and list item onto one line.
The remembered value also works with **Text > Hard Wrap** for immediate unwraps.

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
make test-smoke
make dist
```

`make dist` stages the native executable, Python script, and Git hook. On macOS
it also includes the BBEdit assets. `make dist-cli` is the portable subset;
`make install-cli` and `make uninstall-cli` work on both platforms. Installer
and BBEdit targets explicitly require macOS.

For fully static Linux release builds, install the matching Swift 6.2.1
open-source toolchain and official Static Linux SDK (Xcode's Swift toolchain
cannot use that SDK), then run:

```sh
make dist-linux LINUX_ARCH=x86_64
make dist-linux LINUX_ARCH=aarch64
```

See [RELEASING.md](RELEASING.md) and `.github/workflows/linux-release.yml` for
the pinned SDK URL/checksum and release validation. Native `make dist` builds
use the host toolchain and are not the portable static release artifacts.

The wrapping engine lives in `RewrapMarkdownCore`, separate from the
stdin/stdout executable.

The Swift implementation was ported from a Python-based text filter by the same
author. The test suite runs shared compatibility cases against both versions.

The Python script remains available at `Reference/rewrap_markdown.py` for
comparison and experimentation; it is no longer the main installation path.

On macOS, running `--check` with a directory redirected to stdin (for example,
using `< .`) exits with status `2` in the Swift CLI and status `1` in the
Python reference CLI. CPython rejects directory input during startup, before
the reference script can handle the error.

## License

Licensed under the Apache License, Version 2.0. See `LICENSE` and `NOTICE`.
