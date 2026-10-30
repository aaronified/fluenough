#!/usr/bin/env python3
"""Write each card's narrow `[ ... ]` IPA from Wiktionary into the decks
(owner, 2026-10-26 and 2026-10-30; wiki: Plan-Ipa-Revamp-And-Language-Phonology).

Usage:
    python3 tools/import_phonetic.py bn                  # report only
    python3 tools/import_phonetic.py bn --write          # patch the decks
    python3 tools/import_phonetic.py bn --dump Bengali.jsonl --write
    python3 tools/import_phonetic.py bn --report bn-phonetic.md

Where the data comes from. Wiktionary's pronunciation data, as Wiktextract
extracts it and kaikki.org publishes it: one JSON-lines file per language,
`https://kaikki.org/dictionary/<Language>/kaikki.org-dictionary-<Language>.jsonl`,
taken from the English Wiktionary (CC BY-SA 4.0, as the decks are). The tool
downloads it once, with `urllib`, into `.cache/phonetic/` (git-ignored) and
reads it from there on every later run; `--refresh` downloads it again, and
`--dump FILE` uses a file you have instead. Nothing is fetched while a run
only reads the decks.

What it does, per card of the language's core decks:

1. Finds the Wiktionary entries whose title is exactly the card's `target`,
   of the card's part of speech, narrowed by meaning as
   `tools/import_wiktionary.py` does.
2. In each, takes the first pronunciation that is a hand- or
   template-written narrow form `[ ... ]` for the language's variety (below).
   Wiktionary gives one per variety, tagged in a `note` or `tags` key.
3. Keeps the form only if the entries that fit all agree on it (a word with
   two readings is left alone), and only if it is IPA letters and marks in
   square brackets, NFC (`phonetic_patch.normalise`, the validator's own
   test).
4. With `--write`, adds `phonetic: "[...]"` and `phonetic_source:
   "wiktionary"` after the card's `ipa:` line, as text. Nothing else in the
   file changes, and a card that already has a `phonetic` is skipped.

Only cards Wiktionary has a form for are written: words and a few set
phrases. Sentences are not on Wiktionary, so they get their form from
`tools/derive_phonetic.py`, which runs after this and skips what is filled.

The report counts, per deck and in all, what happened to each card, by
outcome (see OUTCOMES).

Stdlib and PyYAML only.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))

import import_wiktionary as iw  # noqa: E402
import phonetic_patch as pp  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache" / "phonetic"
USER_AGENT = iw.USER_AGENT
DUMP_URL = "https://kaikki.org/dictionary/{name}/kaikki.org-dictionary-{name}.jsonl"

# What the dump calls each language on kaikki.org.
DUMP_NAMES = {"bn": "Bengali", "hi": "Hindi", "es": "Spanish"}


@dataclass(frozen=True)
class Variety:
    """Which of Wiktionary's pronunciations of a word the course teaches.

    Wiktionary marks a form's variety in the sound's `note` (Bengali: Rarh,
    Dhaka) and/or `tags` (Hindi: Hindi, Standard). A form with neither is
    "untagged": Wiktionary's default for the language.
    """
    name: str
    notes: frozenset[str] = frozenset()
    tags: frozenset[str] = frozenset()
    untagged: bool = True

    def rank(self, sound: dict) -> int | None:
        """0 for a form marked as this variety, 1 for an untagged one, None
        for a form of another variety, or one carrying any other note."""
        note = sound.get("note")
        tags = set(sound.get("tags") or [])
        if note is not None and note not in self.notes:
            return None
        if tags - self.tags:
            return None
        if note is None and not tags:
            return 1 if self.untagged else None
        return 0


# The variety per language: the plan's "Which variety per language" (open
# question 4), decided here and recorded in the plan. Only these languages
# are configured; another needs its variety named here first.
VARIETIES = {
    # Standard Colloquial Bengali of Kolkata, which Wiktionary marks Rarh.
    # The decks' `ipa` is the Kolkata standard too. Dhaka (Bangladeshi
    # Standard), Vanga and the rest are not taken.
    "bn": Variety("Standard Colloquial Bengali (Kolkata), Wiktionary's Rarh",
                  notes=frozenset({"Rarh"})),
    # Standard Hindi: Wiktionary tags nearly all of its Hindi forms
    # "Hindi, Standard". Forms tagged dialectal, colloquial, Persianized,
    # formal or with a note are not taken.
    "hi": Variety("Standard Hindi (Hindustani), Wiktionary's Hindi Standard",
                  tags=frozenset({"Hindi", "Standard"})),
    # Spanish: Wiktionary's untagged form, which is the general standard.
    # Regional forms (Andalusia, Latin America, ...) carry a tag and are not
    # taken. The decks' `ipa` writes θ, so the course is Castilian: see the
    # plan's note on this.
    "es": Variety("Standard Spanish, Wiktionary's untagged form"),
}

OUTCOMES = ["filled", "has phonetic", "no ipa line", "no entry", "no narrow form",
            "other variety", "ambiguous", "invalid"]


# --- The data ---------------------------------------------------------------

def dump_path(lang: str, cache: Path = CACHE) -> Path:
    return cache / f"kaikki.org-dictionary-{DUMP_NAMES[lang]}.jsonl"


def download(url: str, dest: Path) -> None:
    """[url] saved at [dest] through a `.part` file, so an interrupted
    download never looks like a dump."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_suffix(dest.suffix + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as resp, part.open("wb") as out:
        shutil.copyfileobj(resp, out, 1 << 20)
    part.replace(dest)


def ensure_dump(lang: str, *, cache: Path = CACHE, refresh: bool = False,
                fetch: Callable[[str, Path], None] = download) -> Path:
    """The language's dump in the cache, downloaded first if it is not
    there (or [refresh]). [fetch] is the download, replaceable in tests."""
    dest = dump_path(lang, cache)
    if refresh or not dest.is_file():
        print(f"downloading {DUMP_URL.format(name=DUMP_NAMES[lang])} "
              f"to {dest} (once)", file=sys.stderr)
        fetch(DUMP_URL.format(name=DUMP_NAMES[lang]), dest)
    return dest


def read_entries(lines: Iterable[str], wanted: set[str]) -> dict[str, list[dict]]:
    """The entries whose title is in [wanted], from a dump's lines. Lines
    with no string that starts with `[` hold no narrow form, and are passed
    by without being parsed: that is most of a big dump."""
    entries: dict[str, list[dict]] = {}
    for line in lines:
        if '"[' not in line:
            continue
        try:
            e = json.loads(line)
        except ValueError:
            continue
        title = e.get("word")
        if isinstance(title, str) and iw.nfc(title) in wanted:
            entries.setdefault(iw.nfc(title), []).append(e)
    return entries


# --- Choosing a form --------------------------------------------------------

def narrow_forms(entry: dict, variety: Variety) -> tuple[list[str], bool, bool]:
    """The entry's narrow forms for [variety], best first, whether any form
    was of another variety, and whether any form of this one was not valid
    IPA."""
    found: list[tuple[int, str]] = []
    other = invalid = False
    for sound in entry.get("sounds") or []:
        ipa = sound.get("ipa")
        if not isinstance(ipa, str) or not (ipa.startswith("[") and ipa.endswith("]")):
            continue
        rank = variety.rank(sound)
        if rank is None:
            other = True
            continue
        form = pp.normalise(ipa)
        if form is None:
            invalid = True
        else:
            found.append((rank, form))
    found.sort(key=lambda p: p[0])  # stable: Wiktionary's order within a rank
    return [f for _, f in found], other, invalid


def choose_form(target: iw.Target, entries: list[dict], variety: Variety) -> tuple[str | None, str]:
    """The card's narrow form and the outcome: `filled`, or why not."""
    _, fits = iw.choose(target, entries)
    if not fits:
        return None, "no entry"
    forms: set[str] = set()
    other = invalid = False
    for entry in fits:
        found, o, i = narrow_forms(entry, variety)
        other, invalid = other or o, invalid or i
        if found:
            forms.add(found[0])
    if len(forms) > 1:
        return None, "ambiguous"
    if forms:
        return forms.pop(), "filled"
    if invalid:
        return None, "invalid"
    return None, "other variety" if other else "no narrow form"


# --- A run ------------------------------------------------------------------

def run(lang: str, dump: Path, decks: Path, write: bool) -> tuple[pp.Coverage, dict]:
    """Fill [lang]'s decks from [dump]; returns the coverage and, per file,
    the forms found (written only when [write])."""
    variety = VARIETIES[lang]
    language = iw.read_language(decks, lang)
    targets = {t.cid: t for t in language.targets}
    cards = pp.core_cards(decks, lang)
    with dump.open(encoding="utf-8") as f:
        entries = read_entries(f, {c.target for c in cards})
    coverage = pp.Coverage()
    fills: dict[Path, dict[str, tuple[str, str]]] = {}
    for card in cards:
        deck = card.file.stem
        if card.phonetic is not None:
            coverage.add(deck, "has phonetic")
        elif card.ipa is None or not card.block:
            coverage.add(deck, "no ipa line")
        else:
            t = targets.get(card.cid)
            if t is None:
                coverage.add(deck, "no entry")
                continue
            form, outcome = choose_form(t, entries.get(card.target, []), variety)
            coverage.add(deck, outcome)
            if form is not None:
                fills.setdefault(card.file, {})[card.cid] = (form, "wiktionary")
    if write:
        for path, fill in fills.items():
            text = path.read_text(encoding="utf-8")
            new, _ = pp.patch(text, fill)
            if new != text:
                path.write_text(new, encoding="utf-8", newline="")
    return coverage, fills


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Write narrow IPA from Wiktionary into a language's decks.")
    parser.add_argument("lang", help="the language's code: " + ", ".join(sorted(VARIETIES)))
    parser.add_argument("--decks", type=Path, default=ROOT / "decks",
                        help="the decks folder (default: the repository's)")
    parser.add_argument("--dump", type=Path,
                        help="a kaikki.org JSONL you have (default: the cached download)")
    parser.add_argument("--cache", type=Path, default=CACHE,
                        help="where the download is kept (default: .cache/phonetic)")
    parser.add_argument("--refresh", action="store_true",
                        help="download the dump again")
    parser.add_argument("--write", action="store_true",
                        help="patch the decks; without it, only report")
    parser.add_argument("--report", type=Path, help="write the report here")
    args = parser.parse_args(argv[1:])
    if args.lang not in VARIETIES:
        print(f"error: no variety is named for {args.lang!r} yet; add it to "
              f"VARIETIES (configured: {', '.join(sorted(VARIETIES))})", file=sys.stderr)
        return 2
    if not (args.decks / args.lang).is_dir():
        print(f"error: no decks for {args.lang!r} in {args.decks}", file=sys.stderr)
        return 2
    dump = args.dump
    if dump is None:
        try:
            dump = ensure_dump(args.lang, cache=args.cache, refresh=args.refresh)
        except OSError as e:
            print(f"error: could not download the dump: {e}", file=sys.stderr)
            return 2
    elif not dump.is_file():
        print(f"error: {dump} does not exist", file=sys.stderr)
        return 2
    coverage, _ = run(args.lang, dump, args.decks, args.write)
    report = (f"# Narrow IPA from Wiktionary: {args.lang}\n\n"
              f"Variety: {VARIETIES[args.lang].name}. Dump: {dump.name}. "
              f"{'Written.' if args.write else 'Report only; nothing was written.'}\n\n"
              + coverage.render(args.lang, OUTCOMES, title="Coverage"))
    if args.report:
        args.report.write_text(report, encoding="utf-8")
    print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
