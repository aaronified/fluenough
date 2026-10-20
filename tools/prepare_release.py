#!/usr/bin/env python3
"""Prepare a release: bump the version files and date the changelog.

Usage:
    python3 tools/prepare_release.py 0.5.2           # in the repository root
    python3 tools/prepare_release.py 0.5.2 --root path/to/copy

Exit status: 0 on success, 1 when the release cannot be prepared (nothing is
written then), 2 if the arguments are wrong.

What it changes, all or nothing:
  - pubspec.yaml: `version:` becomes X.Y.Z+<current build number + 1>.
  - lib/app/app_info.dart: AppInfo.version becomes 'X.Y.Z'.
  - CHANGELOG.md: the body of `## [Unreleased]` moves under a new
    `## [X.Y.Z] - <today, UTC>` heading, and `## [Unreleased]` is left empty
    above it.
It then runs the same check as tools/check_release_version.py. It refuses an
empty Unreleased section and a version that is not higher than the current
one. The release workflow runs it (.github/workflows/release.yml) and commits
the result, so no release pull request is opened by hand.

Requires only the Python standard library.
"""

from __future__ import annotations

import datetime
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_release_version  # noqa: E402

VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
PUBSPEC_LINE = re.compile(
    r"""^version:[ \t]*(?P<q>["']?)(?P<name>\d+\.\d+\.\d+)(?:\+(?P<build>\d+))?(?P=q)[ \t]*(?:#.*)?$""",
    re.MULTILINE,
)
APP_INFO_LINE = re.compile(r"(static const String version = ')[^']*(';)")
UNRELEASED = "## [Unreleased]"
HEADING = re.compile(r"^## \[", re.MULTILINE)


class ReleaseError(Exception):
    """A release that cannot be prepared; the message says why."""


def parse(version: str) -> tuple[int, int, int]:
    match = VERSION.match(version)
    if not match:
        raise ReleaseError(f"'{version}' is not a version like 0.5.2.")
    major, minor, patch = (int(part) for part in match.groups())
    return major, minor, patch


def bump_pubspec(text: str, version: str) -> str:
    match = PUBSPEC_LINE.search(text)
    if not match:
        raise ReleaseError("pubspec.yaml has no top-level 'version: X.Y.Z+N' line.")
    if parse(version) <= parse(match.group("name")):
        raise ReleaseError(
            f"The new version {version} is not higher than the current "
            f"version {match.group('name')}."
        )
    build = int(match.group("build") or 0) + 1
    return text[: match.start()] + f"version: {version}+{build}" + text[match.end():]


def bump_app_info(text: str, version: str) -> str:
    new, count = APP_INFO_LINE.subn(lambda m: f"{m.group(1)}{version}{m.group(2)}", text)
    if count != 1:
        raise ReleaseError(
            "lib/app/app_info.dart has no single "
            "'static const String version = ...;' line."
        )
    return new


def move_unreleased(text: str, version: str, today: str) -> str:
    start = text.find(UNRELEASED)
    if start < 0:
        raise ReleaseError(f"CHANGELOG.md has no '{UNRELEASED}' heading.")
    body_start = start + len(UNRELEASED)
    following = HEADING.search(text, body_start)
    body_end = following.start() if following else len(text)
    body = text[body_start:body_end].strip()
    if not body:
        raise ReleaseError(
            "CHANGELOG.md's '## [Unreleased]' section is empty. Each pull "
            "request adds its line there; there is nothing to release."
        )
    rest = text[body_end:]
    new = f"{text[:body_start]}\n\n## [{version}] - {today}\n\n{body}\n"
    if rest:
        new += "\n" + rest
    return new


def prepare(root: Path, version: str, today: str) -> None:
    parse(version)
    files = {
        "pubspec": root / "pubspec.yaml",
        "app_info": root / "lib" / "app" / "app_info.dart",
        "changelog": root / "CHANGELOG.md",
    }
    try:
        texts = {k: p.read_text(encoding="utf-8") for k, p in files.items()}
    except OSError as error:
        raise ReleaseError(f"Cannot read {error.filename}: {error.strerror}.")
    new = {
        "pubspec": bump_pubspec(texts["pubspec"], version),
        "app_info": bump_app_info(texts["app_info"], version),
        "changelog": move_unreleased(texts["changelog"], version, today),
    }
    error = check_release_version.check(f"v{version}", new["pubspec"])
    if error:
        raise ReleaseError(error)
    for key, path in files.items():
        path.write_text(new[key], encoding="utf-8", newline="")


def main(argv: list[str]) -> int:
    args = argv[1:]
    root = Path(".")
    if len(args) == 3 and args[1] == "--root":
        root = Path(args[2])
        args = args[:1]
    if len(args) != 1:
        print(__doc__.strip().split("\n\n")[1], file=sys.stderr)
        return 2
    today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    try:
        prepare(root, args[0], today)
    except ReleaseError as error:
        print(f"::error::{error}")
        return 1
    print(f"Prepared release {args[0]}.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
