#!/usr/bin/env python3
"""Give every core card that has a `reading` but no `ipa` its broad `ipa`, from
`tools/transcribe.py` (wiki: Plan-Ipa-Revamp-And-Language-Phonology, "any card
still lacking a broad `ipa` is given one"; Deck-Work-Queue-ZH, section 4).

Usage:
    python3 tools/fill_ipa.py zh                    # report only
    python3 tools/fill_ipa.py zh --write            # patch the decks
    python3 tools/fill_ipa.py zh --decks decks-live-checkout/decks --write
    python3 tools/fill_ipa.py zh --report zh-ipa.md

For each card of the language's core vocab decks (`part: core`, kind `vocab`)
that has a `target` and a `reading` and no `ipa`, the card's IPA is
`transcribe(target, lang, reading)`: the stored reading is the typed hint,
exactly as `tools/transcribe.py` takes it on the command line and as
`tools/transcribe_decks.py` does. For Mandarin the reading is the pinyin and
the IPA is derived from it (`mandarin_ipa`).

The line `ipa: "..."` is PATCHED into the file's text after the card's
`reading:` line, in that line's style (plain or quoted key, indent, a trailing
comma in a JSON-style file); a card written on one line (`- {"id": ..., "reading":
..., ...}`, nine Chinese files) gets `, "ipa": "..."` spliced in after its
top-level `reading` value. Nothing else in the file changes: not the ids, the
quoting or the order, and the file is never read and written back through a
YAML library. A card that already has an `ipa` is never touched (use
`tools/transcribe_decks.py` to check or correct a stored one).

A card whose reading cannot be read, or whose layout cannot take a line, is
counted and named on stderr, never written, never silent; a `--write` run then
exits 1. Run `tools/derive_phonetic.py` after this one: it needs the `ipa`.

Standard library and PyYAML only, like the other deck tools.
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import phonetic_patch as pp  # noqa: E402
import validate_decks as vd  # noqa: E402
from transcribe import CannotRead, transcribe  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

OUTCOMES = ["filled", "has ipa", "no reading", "cannot read", "invalid",
            "no target", pp.UNWRITABLE]
# The IPA must pass the validator's own broad test (letters and marks, no
# slashes or brackets).


def valid_broad(ipa: str) -> bool:
    return (bool(ipa) and ipa == unicodedata.normalize("NFC", ipa)
            and ipa == ipa.strip() and bool(vd.IPA_RE.fullmatch(ipa)))


def patch(text: str, fills: dict[str, str]) -> tuple[str, dict[str, str]]:
    """[text] with an `ipa` line added after the `reading:` line of each card
    in [fills] (card id to its IPA). Returns the new text and, for each card
    left alone, why: `"has ipa"`, `"no reading line"`, `"not in file"`,
    `"unsupported layout"`."""
    eol = "\r\n" if "\r\n" in text else "\n"
    lines = text.split("\n")
    left: dict[str, str] = {}
    for cid, ipa in fills.items():
        block = pp._card_block(lines, cid)
        if block is None:
            at = pp._flow_line(lines, cid)
            if at is None:
                left[cid] = "not in file"
                continue
            raw = lines[at]
            cr = "\r" if raw.endswith("\r") else ""
            line = raw[:-1] if cr else raw
            try:
                keys = pp._flow_keys(line)
            except ValueError:
                left[cid] = "unsupported layout"
                continue
            if "ipa" in keys:
                left[cid] = "has ipa"
            elif "reading" not in keys:
                left[cid] = "no reading line"
            else:
                new = pp.flow_insert(line, "reading", [("ipa", ipa)])
                if new is None:
                    left[cid] = "unsupported layout"
                else:
                    lines[at] = new + cr
            continue
        start, end = block.start, block.end
        pad = " " * block.indent
        comma = "," if block.json else ""
        if any(re.match(rf'^{pad}"?ipa"?:', ln) for ln in lines[start:end]):
            left[cid] = "has ipa"
            continue
        rx = re.compile(rf'^{pad}("?)reading\1:')
        at = next((k for k in range(start, end) if rx.match(lines[k])), None)
        if at is None:
            left[cid] = "no reading line"
            continue
        if block.json and not lines[at].rstrip("\r").rstrip().endswith(","):
            left[cid] = "unsupported layout"
            continue
        q = rx.match(lines[at]).group(1)
        j = at + 1
        while j < end and pp._indent(lines[j]) > block.indent and lines[j].strip():
            j += 1
        cr = "\r" if eol == "\r\n" else ""
        lines[j:j] = [f"{pad}{q}ipa{q}: {pp.quote(ipa)}{comma}{cr}"]
    return "\n".join(lines), left


@dataclass
class Item:
    cid: str
    ipa: str | None
    outcome: str


def scan_file(path: Path, lang: str) -> tuple[list[Item], dict[str, str]]:
    """What to do for each card of [path]: its outcome, and the IPA of the
    cards to fill. Every card is guarded: a failure is an outcome, never an
    exception that stops the rest."""
    raw = vd._load_raw(path)
    if not isinstance(raw, dict) or raw.get("part") != "core" \
            or raw.get("kind") not in (None, "vocab"):
        return [], {}
    items: list[Item] = []
    fills: dict[str, str] = {}
    for card in raw.get("cards") or []:
        try:
            if not isinstance(card, dict) or not vd._is_str(card.get("id")):
                continue
            cid = card["id"]
            if vd._is_str(card.get("ipa")):
                items.append(Item(cid, None, "has ipa"))
            elif not vd._is_str(card.get("target")):
                items.append(Item(cid, None, "no target"))
            elif not vd._is_str(card.get("reading")) or not card["reading"].strip():
                items.append(Item(cid, None, "no reading"))
            else:
                try:
                    t = transcribe(unicodedata.normalize("NFC", card["target"]),
                                   lang, card["reading"])
                except CannotRead as e:
                    print(f"warning: {path}: {cid}: cannot read: {e}", file=sys.stderr)
                    items.append(Item(cid, None, "cannot read"))
                    continue
                if not t.ipa:
                    print(f"warning: {path}: {cid}: no ipa for {card['reading']!r} "
                          f"({'; '.join(t.notes) or 'empty'})", file=sys.stderr)
                    items.append(Item(cid, None, "cannot read"))
                elif not valid_broad(t.ipa):
                    print(f"warning: {path}: {cid}: {t.ipa!r} is not a broad IPA",
                          file=sys.stderr)
                    items.append(Item(cid, None, "invalid"))
                else:
                    items.append(Item(cid, t.ipa, "filled"))
                    fills[cid] = t.ipa
        except Exception as e:  # noqa: BLE001 - one card must not stop the rest
            print(f"warning: {path}: {card!r:.80}: {type(e).__name__}: {e}",
                  file=sys.stderr)
            items.append(Item(str(card.get("id")) if isinstance(card, dict) else "?",
                              None, "cannot read"))
    return items, fills


def run(lang: str, decks: Path, write: bool) -> pp.Coverage:
    coverage = pp.Coverage()
    for path in sorted((decks / lang).glob("*.yaml")):
        try:
            items, fills = scan_file(path, lang)
        except Exception as e:  # noqa: BLE001
            print(f"warning: {path}: not read: {type(e).__name__}: {e}",
                  file=sys.stderr)
            continue
        deck = path.stem
        for it in items:
            coverage.add(deck, it.outcome)
        if not fills:
            continue
        text = path.read_text(encoding="utf-8")
        new, left = patch(text, fills)
        for cid, why in left.items():
            print(f"warning: {path}: {cid} not written ({why})", file=sys.stderr)
            coverage.move(deck, "filled", pp.UNWRITABLE)
        if write and new != text:
            path.write_text(new, encoding="utf-8", newline="")
    return coverage


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Add the broad ipa to cards that have a reading and none.")
    parser.add_argument("lang", help="the language's code, such as zh")
    parser.add_argument("--decks", type=Path, default=ROOT / "decks",
                        help="the decks folder (default: the repository's)")
    parser.add_argument("--write", action="store_true",
                        help="patch the decks; without it, only report")
    parser.add_argument("--report", type=Path, help="write the report here")
    args = parser.parse_args(argv[1:])
    if not (args.decks / args.lang).is_dir():
        print(f"error: {args.decks / args.lang} is not a folder", file=sys.stderr)
        return 2
    coverage = run(args.lang, args.decks, args.write)
    report = (f"# Broad ipa from the reading: {args.lang}\n\n"
              f"{'Written.' if args.write else 'Report only; nothing was written.'}\n\n"
              + coverage.render(args.lang, OUTCOMES, title="Coverage"))
    if args.report:
        args.report.write_text(report, encoding="utf-8")
    print(report)
    return pp.unwritable_exit(coverage, args.write)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
