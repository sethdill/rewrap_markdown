#!/bin/sh
# Copyright 2026 Seth Dillingham
# SPDX-License-Identifier: Apache-2.0
# Run inside the distribution container, from the checked-out project root.
set -eu
arch=$1
if command -v apk >/dev/null; then
    apk add --no-cache python3 git
else
    apt-get update
    apt-get install -y --no-install-recommends python3 git ca-certificates
fi
if command -v swift >/dev/null; then
    echo 'Runtime test must not have Swift installed' >&2
    exit 1
fi
(cd artifact && sha256sum -c ./*.sha256)
binary="$PWD/artifact/rewrap-markdown-$(cat VERSION)-linux-$arch"
chmod +x "$binary"
python3 scripts/smoke.py "$binary"
python3 scripts/smoke.py python3 Reference/rewrap_markdown.py
