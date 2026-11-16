# BBEdit Hard Wrap dialog experiment

BBEdit automatically loads a matching `.xib` for Unix scripts and executables
in Scripts or Text Filters. Text > Hard Wrap… uses a compiled AppleScript
attachment with a `MenuSelect` handler. This experiment has the attachment call
a small AppKit helper that loads a compiled nib and returns the selected options.
[Bare Bones technical note](https://www.barebones.com/support/technotes/filter-dialogs.html)

## Preview and edit the layout

From the repository root on macOS with Xcode selected:

```sh
build_dir="$PWD/.build/hard-wrap-dialog"
mkdir -p "$build_dir"
xcrun ibtool --compile "$build_dir/HardWrapDialog.nib" \
  Experiments/BBEditHardWrapDialog/HardWrapDialog.xib
xcrun swiftc Experiments/BBEditHardWrapDialog/main.swift \
  -o "$build_dir/HardWrapDialog"
"$build_dir/HardWrapDialog" 70 0 1000 0 0 preserve "$(rewrap-markdown --version)"
```

Open `HardWrapDialog.xib` in Xcode to edit the layout. Keep File’s Owner set to
`HardWrapDialogController` and preserve its outlet and action connections.
Recompile the nib to preview layout changes. The arguments after the width
range are the Unwrap and Repair states (`0` or `1`), the indentation style
(`preserve`, `spaces`, or `tabs`), and the formatter version. To preview with
default options and an empty version label, pass just `70 0 1000`.

## Try it from the menu

The prototype is opt-in. In a temporary copy of
[`Markdown Hard Wrap Menu Action.applescript`](../../Distribution/BBEdit/Markdown%20Hard%20Wrap%20Menu%20Action.applescript),
set `wrapDialogPath` to the absolute path of the built `HardWrapDialog`
executable. Keep the nib beside it. Back up the existing `Text•Hard Wrap….scpt`
outside BBEdit’s Menu Scripts folder, then compile the test copy with
`osacompile -o` and use it in the original script’s place. Restore the backup
after testing. With `wrapDialogPath` empty, the attachment uses its existing
AppleScript prompt.

**Unwrap** disables the width field and keeps its last nonzero value. Entering
`0` also unwraps. **Repair** passes `--repair`. **Indentation** controls Markdown
list indentation and defaults to **Preserve existing**. The footer shows the
version reported by the formatter the attachment is using. The immediate
**Hard Wrap** command reuses the last settings applied with **Hard Wrap…**.

## Verification so far

Local probes verified the nib controls, validation, Cancel, and the AppleScript
round trip with the installed formatter. They also checked that an older saved
width of `0` opens the dialog with Unwrap selected. To verify the live menu, use
a disposable Markdown document and try both commands with a selection and with
the full document. Check focus on opening and closing the dialog, plus Return
and Escape. The helper is modal in its own process, so the attachment checks
that the document and selection are still current before applying the result.
