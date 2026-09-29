# Rewrap Markdown 0.2

Rewrap Markdown 0.2 adds a Markdown-aware replacement for BBEdit's Hard Wrap
commands and a customizable macOS installer.

## Highlights

- **Markdown-aware Hard Wrap:** BBEdit's **Text > Hard Wrap…** prompts for a
  width and rewraps the selection or complete Markdown document while
  preserving Markdown structure.
- **Remembered width:** **Text > Hard Wrap** immediately uses the last width.
  Hold Shift to bypass Rewrap Markdown and use BBEdit's built-in command.
- **macOS installer:** One universal installer supports Intel and Apple Silicon.
  Markdown-aware Hard Wrap is selected by default; the BBEdit Text Filter and
  `/usr/local/bin/rewrap-markdown` link are optional components.
- **Straightforward removal:** The installer includes an uninstaller for its
  shared executable, BBEdit integrations, command-line link, and receipts.
- **Improved source installation:** `make install-cli`, `make install`,
  `make install-hard-wrap`, and their uninstall counterparts use stable
  installation locations.

The 0.2 installer is unsigned and not notarized. macOS will require approval
under **System Settings > Privacy & Security > Open Anyway**. Verify the
download against the accompanying SHA-256 file before approving it.
