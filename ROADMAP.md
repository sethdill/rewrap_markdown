# Rewrap Markdown Roadmap

This is a working planning document, not a release commitment. Version 0.2 has
shipped; new work is collected below for 0.3 and later releases. GitHub issues
and milestones can be created from the chosen items when release work begins.

## 0.3 Candidates

### Unwrap mode

- [x] Accept `--unwrap` and width `0`.
- [x] Join each paragraph and list item onto one line while preserving Markdown
  structure, protected blocks, and intentional hard line breaks.
- [x] Support the mode in both the Swift and Python command-line tools.
- [x] Accept and remember width `0` in BBEdit's Markdown-aware Hard Wrap dialog.
- [x] Document pasting unwrapped Markdown into GitHub, Jira, Slack, and web forms.

### Commit message mode

- [x] Add `--commit`, with a default body width of 72 columns.
- [x] Preserve the subject line, `#` comment lines, and final Git trailer block.
- [x] Allow an explicit width and support `--commit --unwrap`.
- [x] Include and document a `commit-msg` hook that rewrites the message only
  after the filter succeeds.

### Linux command-line support

- [x] Verify the existing Swift package and Python compatibility suite on real
  native x86_64 and aarch64 Linux CI runners before assuming portability.
- [x] Add official Static Linux SDK builds for x86_64 and aarch64 with pinned
  Swift 6.2.1 SDK checksum and SHA-256 release artifact files.
- [x] Share Linux build/smoke jobs between PR CI and the release workflow.
- [x] Execute downloaded release binaries and Python without Swift installed on
  Ubuntu 22.04/24.04, Debian 12, and Alpine 3.22 userlands, including Git hooks.
- [x] Keep installer and BBEdit targets macOS-only; retain portable CLI targets.
- [x] Document Linux installation, source/static builds, and validation limits.
- [ ] Validate older kernels and any additional distro before claiming support.
- [x] Automate checksum verification, README installation, PATH invocation,
  CLI/hook tests, and removal on native x86_64 and aarch64 Linux VMs.
- [x] Add a manual workflow for installation from published GitHub Release assets.
- [ ] Run the published-asset workflow after v0.3 assets are available.

### Homebrew CLI installation

- [x] Prepare a CLI-only source formula with an immutable commit URL and SHA-256.
- [x] Add version, wrapping, unwrap, and commit-mode formula assertions.
- [x] Add native macOS and Linux Homebrew CI on both architectures.
- [x] Document source versus binary tradeoffs and repeatable release updates.
- [ ] Complete the Homebrew matrix and record results before merging.
- [ ] Obtain Seth's explicit approval before creating/publishing the separate tap.
- [ ] Pin the final v0.3 release commit and publish the approved tap PR.
- [ ] Verify `brew install sethdill/tap/rewrap-markdown` from the public tap.
- [ ] Consider an installer cask only after signing, notarization, and Gatekeeper acceptance.

See [the tap handoff](Packaging/homebrew/README.md). Homebrew installs the CLI
only and never changes BBEdit support folders.

## Future Plans

### Check mode and pre-commit integration

- [ ] Add `--check`, returning a nonzero status when input would change.
- [ ] Add `--diff` to display the required changes.
- [ ] Accept multiple file arguments and add `-i` for in-place edits.
- [ ] Add `.pre-commit-hooks.yaml` for teams using the pre-commit framework and
  CI checks.

### Markdown in code comments

- [ ] Rewrap Markdown inside doc comments by temporarily removing and restoring
  the comment prefix.
- [ ] Start with Rust, Swift, Kotlin KDoc, Dart, and TypeScript JSDoc conventions.
- [ ] Preserve hanging indents, Markdown code blocks, and comment formatting.

### One sentence per line

- [ ] Add `--sentences` for semantic line breaks in docs-as-code workflows.
- [ ] Define sentence-boundary behavior for abbreviations, inline Markdown, and
  intentional hard breaks.

### Partial-file wrapping

- [ ] Accept explicit line ranges.
- [ ] Optionally limit wrapping to paragraphs touched by a Git diff.
- [ ] Make unchanged regions byte-for-byte stable for agent and assistant
  workflows.

## 0.2 (Released)

### BBEdit Hard Wrap menu action

- [x] Add an optional BBEdit menu action for **Text > Hard Wrap...**.
- [x] Detect Markdown using BBEdit's source language and common Markdown filename
  extensions.
- [x] For Markdown documents, prompt for the wrap width and run `rewrap-markdown`.
- [x] Rewrap the selection when one exists; otherwise rewrap the entire document.
- [x] Replace the selected text or document contents with the command's output.
- [x] For non-Markdown documents, return control to BBEdit's built-in Hard Wrap
  command.
- [x] Decide how errors from the command should be presented without changing the
  document.
- [x] Compile and test the script on a Mac with BBEdit installed. The source cannot
  be fully compiled against BBEdit's AppleScript terminology on a machine where
  BBEdit is absent.
- [x] Include the script in 0.2 release artifacts and installation documentation.
- [x] Do not link to this new artifact under the existing 0.1 release.

Current implementation branch work includes:

- `Distribution/BBEdit/Markdown Hard Wrap Menu Action.applescript`
- release artifact generation in `Makefile`
- release workflow asset generation
- draft README installation instructions

Implemented and manually verified on the `release/0.2` branch. The menu action
now mirrors BBEdit's two Hard Wrap commands, supports Shift bypass, remembers
the width outside the compiled script so upgrades preserve it, and finds the
shared installer executable.

### Supported source installation

`make install` is a supported installation route for developer-users, not only
for project contributors. This audience is comfortable with Terminal and may
want both editor integration and direct command-line use.

- [x] Make `make install` copy the executable to a stable location instead of
  making the BBEdit wrapper depend on `.build/release/rewrap-markdown` inside
  the source checkout.
- [x] Install the ordinary BBEdit text filter by default.
- [x] Keep the Hard Wrap override opt-in because it changes a standard BBEdit menu
  command.
- [x] Add these targets:

  - `make install`: executable plus ordinary BBEdit text filter
  - `make install-hard-wrap`: optional Hard Wrap menu action
  - `make install-all`: both integrations
  - `make uninstall`
  - `make uninstall-hard-wrap`
  - `make uninstall-all`

- [x] After `make install`, mention the optional `make install-hard-wrap` target.
- [x] Support explicit destination overrides for users with nonstandard BBEdit
  support folders or executable locations.
- [x] Ensure installation and removal are idempotent.

Implemented for 0.2, including `install-all`, `uninstall-cli`, and
`uninstall-all`. Source installs remain useful for developer-users alongside
the package installer.

### Installation for non-developer users

Provide a no-Terminal installation path that does not require Git, Swift,
Xcode Command Line Tools, or `make`.

- [x] Confirm that a `.bbpackage` can install the Text Filter but cannot install
  the Menu Scripts integration by itself.
- [x] Use a macOS `.pkg` with a shared executable and component choices.
- [x] Select **Markdown-aware Hard Wrap** by default; leave **BBEdit Text Filter**
  and **Command-line link** off by default.
- [x] Install BBEdit integrations for the user logged in at `/dev/console`, with
  manual instructions for customized BBEdit support folders.
- [x] Preserve optional component selections and the remembered Hard Wrap width
  across upgrades.
- [x] Provide a conservative installed uninstaller and package receipts.
- [x] Build one universal Intel/Apple Silicon package in GitHub Actions and publish
  its SHA-256 checksum.
- [x] Prepare 0.2 for unsigned distribution with documented Gatekeeper approval.
- [ ] Add Developer ID signing and Apple notarization in a later release when
  program membership is practical.

Research references:

- [Bare Bones guidance for distributing BBEdit packages](https://hosting.barebones.com/support/technotes/filter-dialogs.html)
- [BBEdit package overview](https://www.bbeditextras.org/packages/)

### Release planning

- [ ] Create a GitHub milestone for `v0.2` when the intended scope is selected.
- [ ] Create one issue per independently testable feature or packaging task.
- [ ] Use the milestone as the release checklist and move deferred issues to `v0.3`
  or a later milestone.
- [x] Prepare user-facing changelog entries when the release scope is stable.
- [x] Keep the README focused on currently available installation and usage rather
  than unreleased download links.

### Built-in editor workflows

For 0.2, document the filtering features already built into Vim, Neovim, and
Emacs. Evaluation, recommendation, or development of editor extensions is
deferred to later releases.

The common behavior should be:

- Operate on selected text when a nonempty selection exists.
- Otherwise operate on the whole document.
- Send UTF-8 text to `rewrap-markdown` on standard input.
- Replace the source range with standard output as one undoable edit.
- Allow a configured width, and consider an optional width prompt.
- Preserve the document if the command fails and show a useful error.
- Initially target Markdown documents, while allowing an explicit invocation in
  other text documents.

#### Vim and Neovim

No plugin is required for basic use. Vim has a built-in range filter that sends
lines to an external command and replaces them with its output.

- [x] Document visual selection: select lines, press `!`, then enter `rewrap-markdown 70`.
  Vim supplies the visual range, displayed as
  `:'<,'>!rewrap-markdown 70`.
- [x] Document the entire-buffer command: `:%!rewrap-markdown 70`.
- [ ] Later release: consider an optional Vim command or mapping that chooses the
  visual selection when present and otherwise uses the whole buffer.
- [ ] Confirm expected behavior for characterwise selections; Vim's external
  filters fundamentally operate on line ranges.

Reference: [Vim filter documentation](https://vimhelp.org/usr_10.txt.html)

#### Emacs

No package is required for basic use. Emacs can pipe a region through an
external command and replace it with the output.

- [x] Document the selected-region command: `C-u M-| rewrap-markdown 70 RET`.
- [x] Document the entire-buffer workflow: `C-x h`, then
  `C-u M-| rewrap-markdown 70 RET`.
- [ ] Later release: consider a small Emacs Lisp command that uses the active
  region or the whole buffer and prompts for, or configures, the width.

Reference: [GNU Emacs shell command documentation](https://www.gnu.org/software/emacs/manual/html_node/emacs/Shell.html)

### Product positioning and use cases

- [x] Keep BBEdit as a first-class integration while presenting the command-line utility as
  useful beyond BBEdit.
- [x] Target developer-users and technical writers moving Markdown among editors
  and services.
- [x] Document the practical need: GitHub, Jira, Confluence, and other Markdown
  consumers may not render manually hard-wrapped text as users expect.
- [x] Keep the standard-input/standard-output interface stable so editor plugins
  remain small adapters around the core tool.

## Deferred Editor Extensions

All extension evaluation, recommendations, and development for editors other
than BBEdit are deferred until after 0.2. The notes below are retained for those
later releases.

### Visual Studio Code

Retain these candidates for evaluation in a later release:

- [ ] Evaluate [Filter Text](https://marketplace.visualstudio.com/items?itemName=yhirose.FilterText).
  It sends selected text to a shell command and replaces it with standard output.
  It supports saved command definitions. Its current documentation says an
  empty selection inserts output at the cursor, so whole-document use may need
  **Select All** first; test this against its older document-filter option.
- [ ] Evaluate [VSCode Pipe](https://marketplace.visualstudio.com/items?itemName=mtfuji.vs-code-pipe).
  It passes the selection on standard input, replaces it with standard
  output, and supports registered commands.
- [ ] Test both with `rewrap-markdown 70` on macOS and choose one primary
  recommendation.
- [ ] Verify nonzero-exit behavior, standard-error handling, multiple selections,
  executable path configuration, and one-step reuse of the saved command.
- [ ] Document **Select All** followed by filtering as an acceptable whole-document
  workflow when an extension does not provide an automatic fallback.
- [ ] Revisit a dedicated extension only if neither existing option is safe and
  ergonomic enough.

### Sublime Text

Retain these candidates for evaluation in a later release.

- [ ] Evaluate [External_Programs](https://packagecontrol.io/packages/External_Programs)
  first. It documents the exact desired default: send the selection, or the
  whole unsaved buffer when there is no selection, to standard input; replace
  that range with standard output; and report standard error separately.
- [ ] Also evaluate [FilterPipes](https://packagecontrol.io/packages/FilterPipes).
  Its **Send Text to Command** action sends selections to an external process
  and replaces them with standard output on success. It supports configured
  process commands and a `use_selections: false` whole-file option, but it
  describes itself as targeting Sublime Text 2 and 3 and has not been updated
  recently.
- [ ] Verify failure behavior, multiple selections, executable path configuration,
  and a reusable `rewrap-markdown 70` command.
- [ ] Look for a better-maintained existing package if FilterPipes is not reliable
  on the current Sublime Text release.

### PyCharm and other JetBrains IDEs

Retain these candidates for evaluation in a later release.

- [ ] Evaluate [Shell Filter](https://plugins.jetbrains.com/plugin/9958-shellfilter).
  It is an actively maintained IntelliJ-platform plugin whose manifest
  depends only on `com.intellij.modules.platform`, making it applicable to
  PyCharm and other IntelliJ-based IDEs. It runs selected text through a saved
  or ad hoc shell command and replaces the selection after successful
  completion.
- [ ] Test Shell Filter's temporary-file input with a configuration such as
  `rewrap-markdown 70 < %s`, where `%s` is replaced by the plugin's temporary
  file path.
- [ ] Evaluate [Pipeprofen](https://plugins.jetbrains.com/plugin/11257-pipeprofen),
  which sends selected lines to a Bash command on standard input.
- [ ] If both work reliably, document and recommend both. Explain the differences
  in input handling, command reuse, multiple-caret behavior, error handling,
  and whole-document workflow so users can choose the better fit.
- [ ] Test selection and whole-document workflows on macOS. Selecting the whole
  document before invoking the plugin is an acceptable 0.2 workflow.
- [ ] Verify current PyCharm compatibility and behavior with unsaved documents.
- [ ] Confirm Shell Filter's documented success-only replacement behavior in
  practice. For Pipeprofen, pay particular attention to failure safety because
  it says it treats standard error and standard output alike.
- [ ] Verify executable path handling, multiple carets, and reuse of the last or a
  saved `rewrap-markdown 70` command.
- [ ] Revisit a dedicated cross-JetBrains plugin only if the existing option is not
  safe and ergonomic enough.

Reference: [PyCharm External Tools](https://www.jetbrains.com/help/pycharm/configuring-third-party-tools.html)

### Nova

Retain this candidate for evaluation in a later release.

- [ ] Evaluate [Shell Tools](https://extensions.panic.com/extensions/computer.gareth/computer.gareth.ShellTools/)
  from Nova's Extension Library.
- [ ] Confirm that **Filter Text...** sends the selection to a shell command and
  replaces it with the command output; with no selection, it filters the entire
  document. This directly matches the desired interaction.
- [ ] Test `rewrap-markdown 70`, executable discovery, nonzero-exit behavior, and
  standard-error handling before recommending it.
- [ ] Determine whether users can save or bind the command so they do not need to
  type it on every invocation.
