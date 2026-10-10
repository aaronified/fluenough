#!/usr/bin/env python3
"""Fail if a release tag and pubspec.yaml's version differ (#141).

Usage:
    python3 tools/check_release_version.py v0.3.4             # reads pubspec.yaml
    python3 tools/check_release_version.py v0.3.4 path/to/pubspec.yaml

Exit status: 0 when they agree, 1 when they differ or the version cannot be
read, 2 if the arguments are wrong.

The release workflow builds with `--build-name` taken from the tag, so the
APK's versionName is the tag. The app itself reports `AppInfo.version`, which
is kept in step with `pubspec.yaml` by hand. Tagging a commit whose
`pubspec.yaml` was not bumped publishes an APK that calls itself the previous
version, and the update check (ADR-0017) then keeps offering the update the
phone already has. The release workflow runs this before it builds anything.

Only the version name is compared: `pubspec.yaml`'s `+build` part is ignored,
because the workflow sets the build number from its run number.

Requires only the Python standard library, so it runs before PyYAML is
installed. `version:` is a single top-level scalar, read with a regex rather
than a YAML parser.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

TAG = re.compile(r"^v(\d+\.\d+\.\d+)$")
# A top-level `version:` line, its value optionally quoted, then an optional
# trailing comment.
VERSION_LINE = re.compile(
    r"""^version:[ \t]*(?P<q>["']?)(?P<value>[^"'#\s]+)(?P=q)[ \t]*(?:#.*)?$"""
)


def pubspec_version(text: str) -> str | None:
    """The version name in a pubspec's text, without `+build`, or None."""
    for line in text.splitlines():
        match = VERSION_LINE.match(line.rstrip("\r"))
        if match:
            return match.group("value").split("+", 1)[0]
    return None


def check(tag: str, pubspec_text: str) -> str | None:
    """None when `tag` names the pubspec's version, else the error to show."""
    tag_match = TAG.match(tag)
    if not tag_match:
        return f"'{tag}' is not a version tag like v0.2.0."
    version = pubspec_version(pubspec_text)
    if version is None:
        return "pubspec.yaml has no top-level 'version:' line to compare the tag with."
    if tag_match.group(1) != version:
        return (
            f"The tag {tag} does not match pubspec.yaml's version {version}. "
            f"Bump 'version:' in pubspec.yaml and AppInfo.version in "
            f"lib/app/app_info.dart to {tag_match.group(1)}, commit, and tag "
            f"that commit instead (delete this tag first: "
            f"git push --delete origin {tag} && git tag -d {tag})."
        )
    return None


def main(argv: list[str]) -> int:
    if len(argv) not in (2, 3):
        print(__doc__.strip().split("\n\n")[1], file=sys.stderr)
        return 2
    tag = argv[1]
    path = Path(argv[2] if len(argv) == 3 else "pubspec.yaml")
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        print(f"Cannot read {path}: {error}", file=sys.stderr)
        return 2
    error = check(tag, text)
    if error:
        # A GitHub Actions annotation; plain text anywhere else.
        print(f"::error::{error}")
        return 1
    print(f"The tag {tag} matches pubspec.yaml's version.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
