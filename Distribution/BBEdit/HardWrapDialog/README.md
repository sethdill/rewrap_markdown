# BBEdit Hard Wrap dialog

The **Text → Hard Wrap…** menu attachment calls an AppKit helper that loads
`HardWrapDialog.nib`. The macOS installer and `make install-hard-wrap`
install the helper and nib together in BBEdit's support folder.

## Preview the dialog

From the repository root on macOS with Xcode selected, run:

```sh
make hard-wrap-dialog
.build/bbedit-hard-wrap/HardWrapDialog 70 0 1000 0 0 preserve 'rewrap-markdown 0.5'
```

The arguments after the initial, minimum, and maximum widths are the
Unwrap state, Repair state, indentation style, and formatter version. Pass
`0` or `1` for the two checkboxes. The indentation styles are `preserve`,
`spaces`, and `tabs`.

Open `HardWrapDialog.xib` in Xcode to edit the layout. Keep File’s Owner set
to `HardWrapDialogController` and preserve its outlet and action connections.
Rebuild with `make hard-wrap-dialog` to preview changes.
