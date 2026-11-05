#!/bin/sh
# Copyright 2026 Seth Dillingham
# SPDX-License-Identifier: Apache-2.0
# Run on a fresh native Linux runner; install exactly as documented in README.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
artifact_dir=$(CDPATH= cd -- "$1" && pwd)
arch=$(uname -m)
[ "$(uname -s)" = Linux ] || { echo 'Requires a Linux runner' >&2; exit 1; }
version=$(cat "$project_root/VERSION")
binary="rewrap-markdown-${version}-linux-${arch}"
(cd "$artifact_dir" && sha256sum -c "$binary.sha256")
install_bin_dir="$HOME/.local/bin"
installed_binary="$install_bin_dir/rewrap-markdown"
# Never overwrite or remove a pre-existing installation.
[ ! -e "$installed_binary" ] && [ ! -L "$installed_binary" ] || {
    echo "An installation already exists: $installed_binary" >&2; exit 1;
}
test_directory=$(mktemp -d)
trap 'rm -f "$installed_binary"; rm -rf "$test_directory"' EXIT
trap 'exit 1' HUP INT TERM
mkdir -p "$install_bin_dir"
install -m 755 "$artifact_dir/$binary" "$installed_binary"
PATH="$install_bin_dir:/usr/bin:/bin"
export PATH
# All invocations and Git repositories live outside the source checkout.
cd "$test_directory"
[ "$(command -v rewrap-markdown)" = "$installed_binary" ]
[ "$(rewrap-markdown --version)" = "rewrap-markdown $version" ]
REWRAP_SMOKE_HOOK="$artifact_dir/rewrap-markdown-commit-msg" \
REWRAP_SMOKE_USE_PATH=1 \
    python3 "$project_root/scripts/smoke.py" rewrap-markdown
rm "$installed_binary"
[ ! -e "$installed_binary" ]
hash -r
if command -v rewrap-markdown >/dev/null; then
    echo 'rewrap-markdown is still available after removal' >&2
    exit 1
fi
printf 'Installation, PATH invocation, Git hook, and removal passed on %s\n' "$arch"
