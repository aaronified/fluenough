#!/usr/bin/env python3
"""Fail if a user-visible string is written as a literal in a widget.

Usage:
    python3 tools/check_ui_strings.py lib/       # 0 ok, 1 findings, 2 bad args

AGENTS.md rule 10 says every label, title, button, hint and piece of interface
prose is a token in `lib/l10n/app_en.arb`, reached through `AppLocalizations`.
Until this existed the rule was a checklist box: swapping a token back for a
literal passed `flutter analyze` and every test, which is exactly the change a
hurried agent makes and no reviewer reliably catches.

Requires only Python 3.11+, like the deck validator, so it needs no Flutter
toolchain.

## What it looks for

A string literal in an argument position that puts text on screen — the first
argument to `Text(...)`, or a named argument from `TEXT_PARAMS` below. That is
a deliberately narrow net: it catches the common mistake with almost no false
positives, rather than flagging every string in the file and being switched off
within a week.

It does not attempt to parse Dart. A regex over source cannot know types, so it
errs towards silence: an interpolated string, a constant, or text built in a
variable and passed in will not be caught. This is a gate against the careless
change, not a proof.

## When a literal is right

Rarely, but it happens — a non-linguistic glyph, or a debug-only screen. Mark
the line and say why:

    Text('—'),  // ui-literal-ok: an em dash is not language
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Named arguments whose value is shown to a user.
TEXT_PARAMS = (
    "hintText",
    "labelText",
    "helperText",
    "errorText",
    "counterText",
    "prefixText",
    "suffixText",
    "semanticsLabel",
    "semanticLabel",
    "tooltip",
    "message",
    "label",
    "title",
    "subtitle",
    "confirmationDialogTitle",
    "cancelButtonText",
)

ALLOW = "ui-literal-ok"

# A single- or double-quoted Dart string with no interpolation, so that
# `'$count due'` is left to a human. Raw and triple-quoted strings are out of
# scope for the same reason.
STRING = r"""(?:'(?:[^'\\$\n]|\\.)*'|"(?:[^"\\$\n]|\\.)*")"""

# `\s*` spans newlines on purpose: `dart format` puts `Text(` and its argument
# on separate lines as soon as the call exceeds 80 columns, which is the normal
# case. A line-oriented check would miss every formatted widget in the repo.
TEXT_CALL = re.compile(rf"\bText\(\s*({STRING})", re.DOTALL)
NAMED = re.compile(rf"\b({'|'.join(TEXT_PARAMS)})\s*:\s*({STRING})", re.DOTALL)

# Excluded outright: generated localisations, and the ARB files' own home.
SKIP_DIRS = ("l10n",)


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def is_exempt(lines: list[str], number: int) -> bool:
    """Whether the finding on this line is commented out or marked allowed.

    Checks the literal's own line and the one above it, because a formatted
    call puts the marker on whichever the author found natural.
    """
    for candidate in (number - 1, number - 2):
        if 0 <= candidate < len(lines):
            line = lines[candidate]
            if ALLOW in line:
                return True
    line = lines[number - 1] if 0 < number <= len(lines) else ""
    return line.lstrip().startswith("//")


def findings_in(path: Path) -> list[tuple[int, str]]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    found: dict[int, str] = {}

    for match in TEXT_CALL.finditer(text):
        number = line_of(text, match.start(1))
        if not is_exempt(lines, number):
            found[number] = f"Text({match.group(1)})"

    for match in NAMED.finditer(text):
        number = line_of(text, match.start(2))
        if not is_exempt(lines, number):
            found.setdefault(number, f"{match.group(1)}: {match.group(2)}")

    return sorted(found.items())


def collect(target: Path) -> list[Path]:
    if target.is_file():
        return [target]
    return sorted(
        p
        for p in target.rglob("*.dart")
        if not any(part in SKIP_DIRS for part in p.parts)
        and not p.name.endswith(".g.dart")
    )


def main(argv: list[str]) -> int:
    targets = [Path(a) for a in argv[1:]] or [Path("lib")]
    paths: list[Path] = []
    for target in targets:
        if not target.exists():
            print(f"error: {target} does not exist", file=sys.stderr)
            return 2
        paths.extend(collect(target))

    if not paths:
        print("error: no Dart files found", file=sys.stderr)
        return 2

    total = 0
    for path in paths:
        for number, snippet in findings_in(path):
            total += 1
            print(f"{path}:{number}: user-visible string is a literal — {snippet}")

    if total:
        print(
            f"\n{total} literal string{'s' if total > 1 else ''} in a widget.\n"
            "Every one is a token in lib/l10n/app_en.arb, reached through\n"
            "AppLocalizations.of(context)!. See AGENTS.md rule 10 and ADR-0006.\n"
            "If a literal is genuinely right, mark the line `// ui-literal-ok:`\n"
            "and say why."
        )
        return 1

    print(f"{len(paths)} Dart files, no user-visible literals.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
