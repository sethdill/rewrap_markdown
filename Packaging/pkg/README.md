# macOS Installer Package

Run `make pkg-unsigned` to build the local installer prototype in `dist/`.
The product package contains four components:

- **Core** is required and hidden. It installs the executable in
  `/Library/Application Support/Rewrap Markdown/`.
- **Markdown-aware Hard Wrap** is selected by default. It installs the
  compiled menu attachment in the current user's BBEdit support folder.
- **BBEdit Text Filter** is not selected by default. It installs
  `Rewrap Markdown.bbpackage` in the current user's BBEdit `Packages` folder.
- **Command-line link** is not selected by default. It links
  `/usr/local/bin/rewrap-markdown` to the core executable.

When the installer is run again, optional components already present in the
shared installation are selected automatically so upgrades update them. The
remembered Hard Wrap width is stored in the user's preferences rather than in
the compiled script, so replacing the script does not reset it.

The installer uses the account logged in at `/dev/console`. It prefers the
sandboxed BBEdit support folder when BBEdit's container exists and otherwise
uses `~/Library/Application Support/BBEdit`.

## Customized BBEdit Installations

For a BBEdit configuration that uses another support folder, install the
components manually:

1. Copy `Text•Hard Wrap….scpt` from
   `/Library/Application Support/Rewrap Markdown/Components/Hard Wrap/` to
   BBEdit's `Menu Scripts` folder.
2. In that folder, make a second copy or symbolic link named
   `Text•Hard Wrap.scpt`.
3. If desired, copy `Rewrap Markdown.bbpackage-template` from
   `/Library/Application Support/Rewrap Markdown/Components/Text Filter/` to
   BBEdit's `Packages` folder and rename it `Rewrap Markdown.bbpackage`.
4. Quit and reopen BBEdit after adding or removing the Text Filter package.

The Hard Wrap script finds the core executable in its standard installed
location. A user who moves the executable can instead edit the script's
`rewrapMarkdownPath` property.

## Migrating from `make install-cli`

An existing `~/.local/bin/rewrap-markdown` may appear earlier in `PATH` than
the optional installer link at `/usr/local/bin/rewrap-markdown`. After
installing the command-line component, remove the old copy and refresh the
shell's command cache:

```sh
rm ~/.local/bin/rewrap-markdown
rehash
which rewrap-markdown
```

The final command should report `/usr/local/bin/rewrap-markdown`.

## Uninstalling

The Core component installs an uninstaller. Run it with administrator
privileges to remove the shared executable, installed BBEdit integrations,
the command-line link when it still points to the shared executable, package
receipts, and package-owned files:

```sh
sudo "/Library/Application Support/Rewrap Markdown/uninstall-rewrap-markdown"
```

The uninstaller deliberately leaves customized files and unrelated commands
alone. It also leaves the remembered width preference in place for a future
reinstallation.

## Verification

Run the package verifier after building:

```sh
Packaging/pkg/verify-installer.sh dist/rewrap-markdown-0.2-unsigned.pkg
```

It checks the component choices, expanded payload, installer scripts,
executable smoke test, and expected architectures. Release CI creates a
universal Intel/Apple Silicon installer and a matching SHA-256 file.

## Unsigned Distribution

- The package is unsigned and not notarized.
- A local build contains only the architecture of the build Mac; release CI
  combines both supported architectures.
- On first launch, users must approve the package under **System Settings >
  Privacy & Security > Open Anyway**.
- Deselecting a component during an upgrade does not uninstall its previous
  copy. Use the uninstaller to remove installed components.
