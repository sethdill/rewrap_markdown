# Rewrap Markdown 0.5

BBEdit's Markdown-aware **Text → Hard Wrap…** now has a dialog with controls
for wrap width, Unwrap, Repair, and list indentation. The footer displays the
version of Rewrap Markdown that BBEdit is running.

- **Unwrap** joins each paragraph and list item onto one line. Turning it off
  restores the previous width.
- **Repair** enables the existing opt-in inline-code spacing fixes.
- **Indentation** can preserve the current list indentation or convert it to
  spaces or tabs.

**Text → Hard Wrap** reuses the last applied settings. Hold Shift to use
BBEdit's built-in command. The macOS installer and `make install-hard-wrap`
both install the dialog with the menu attachment.
