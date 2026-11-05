#!/usr/bin/env python3
"""Pin the provisional tap formula to a reviewed release commit; never publish."""
import argparse
import hashlib
import io
from pathlib import Path
import re
import tarfile
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True, help="Public VERSION, without v")
    parser.add_argument("--revision", required=True, help="Full commit SHA resolved from the release tag")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "Packaging/homebrew/Formula/rewrap-markdown.rb")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", args.version):
        parser.error("version must be a stable numeric release")
    if not re.fullmatch(r"[0-9a-f]{40}", args.revision):
        parser.error("revision must be a full lowercase commit SHA")
    url = f"https://github.com/sethdill/rewrap_markdown/archive/{args.revision}.tar.gz"
    with urllib.request.urlopen(url, timeout=120) as response:
        archive = response.read()
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as source:
        member = source.getmember(f"rewrap_markdown-{args.revision}/VERSION")
        actual = source.extractfile(member).read().decode().strip()
    if actual != args.version:
        parser.error(f"archive VERSION is {actual!r}, not {args.version!r}")
    formula = args.output.read_text()
    for key, value in (("url", url), ("version", args.version), ("sha256", hashlib.sha256(archive).hexdigest())):
        formula, count = re.subn(rf'^  {key} ".*"$', f'  {key} "{value}"', formula, flags=re.MULTILINE)
        if count != 1:
            parser.error(f"expected exactly one {key} in {args.output}")
    args.output.write_text(formula)
    print(f"Updated {args.output}; review the diff and run all Homebrew checks before publishing.")


if __name__ == "__main__":
    main()
