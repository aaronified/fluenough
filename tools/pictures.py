#!/usr/bin/env python3
"""Copy the pictures the decks use from a Noto Emoji checkout.

    python3 tools/pictures.py path/to/noto-emoji

A card's `picture` is one emoji (ADR-0034). Its image is Noto Emoji's
128-pixel PNG, Apache-2.0, bundled in assets/pictures/ under the name
`picturePath` gives it in lib/core/models/card.dart. This copies every
picture a deck names, and removes any no deck names, so that only what is
used ships. Noto names a few files with U+FE0F and most without; both are
looked for.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from validate_decks import PICTURES, picture_file  # noqa: E402


def pictures_used() -> set[str]:
    """Every picture a card of a deck names."""
    used = set()
    for path in sorted((ROOT / "decks").rglob("*.yaml")):
        deck = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(deck, dict):
            continue
        for card in deck.get("cards") or []:
            if isinstance(card, dict) and isinstance(card.get("picture"), str):
                used.add(card["picture"])
    return used


def noto_file(source: Path, emoji: str) -> Path | None:
    """Noto's PNG of [emoji], named with or without U+FE0F."""
    for points in (
        [f"{ord(c):04x}" for c in emoji if c != "️"],
        [f"{ord(c):04x}" for c in emoji],
    ):
        file = source / f"emoji_u{'_'.join(points)}.png"
        if file.is_file():
            return file
    return None


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    source = Path(argv[1]) / "2D" / "png" / "128"
    if not source.is_dir():
        print(f"error: no {source}", file=sys.stderr)
        return 2
    PICTURES.mkdir(parents=True, exist_ok=True)
    used = pictures_used()
    wanted = {picture_file(e): e for e in used}
    missing = []
    for name, emoji in sorted(wanted.items()):
        file = noto_file(source, emoji)
        if file is None:
            missing.append(emoji)
        else:
            shutil.copyfile(file, PICTURES / name)
    for old in PICTURES.glob("emoji_u*.png"):
        if old.name not in wanted:
            old.unlink()
    print(f"{len(wanted) - len(missing)} pictures in {PICTURES.relative_to(ROOT)}")
    for emoji in missing:
        print(f"error: Noto Emoji has no {emoji}", file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
