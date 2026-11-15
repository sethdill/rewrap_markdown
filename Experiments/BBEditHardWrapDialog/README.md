# BBEdit Hard Wrap dialog experiment

BBEdit automatically loads a matching `.xib` for Unix scripts and executables
in Scripts or Text Filters. Text > Hard Wrap… uses a compiled AppleScript
attachment with a `MenuSelect` handler. This experiment has the attachment call
a small AppKit helper that loads a compiled nib and returns the chosen width.
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
"$build_dir/HardWrapDialog" 70 0 1000
```

Open `HardWrapDialog.xib` in Xcode to edit the layout. Keep File’s Owner set to
`HardWrapDialogController`, with the `window` and `widthField` outlets and the
`accept:` and `cancel:` button actions connected. Recompile the nib to preview
layout changes. The helper takes the initial, minimum, and maximum widths and
prints the accepted integer or `cancel` on standard output.

## Try it from the menu

The prototype is opt-in. In a temporary copy of
[`Markdown Hard Wrap Menu Action.applescript`](../../Distribution/BBEdit/Markdown%20Hard%20Wrap%20Menu%20Action.applescript),
set `wrapDialogPath` to the absolute path of the built `HardWrapDialog`
executable. Keep the nib beside it. Back up the existing `Text•Hard Wrap….scpt`
outside BBEdit’s Menu Scripts folder, then compile the test copy with
`osacompile -o` and use it in the original script’s place. Restore the backup
after testing. With `wrapDialogPath` empty, the attachment uses its existing
AppleScript prompt.

Use a disposable Markdown document to check that the dialog comes to the front,
the width field starts with the remembered width, Return accepts, Escape cancels,
and invalid input leaves the prompt open. Check that `0` unwraps, a selected
range stays scoped to the selection, and the command without the ellipsis uses
the remembered width. Also check focus when returning to BBEdit and try changing
tabs or selections while the helper is open. The helper is modal in its own
process, so the attachment checks that the target is still current before writing.

## Verification so far

The XIB compiles and loads with its outlets and actions connected. A local
probe ran the AppleScript width handler through the AppKit helper and checked
widths `0`, `72`, and `1000`, plus Cancel. A separate probe checked that invalid
input leaves the dialog open for correction. The live BBEdit menu path and
focus handoff still need a manual test. Installer packaging is deferred.
