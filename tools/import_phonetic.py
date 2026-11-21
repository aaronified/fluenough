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
import re
import shutil
import sys
import unicodedata
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import derive_phonetic as dp  # noqa: E402
import import_wiktionary as iw  # noqa: E402
import phonetic_patch as pp  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache" / "phonetic"
USER_AGENT = iw.USER_AGENT
DUMP_URL = "https://kaikki.org/dictionary/{name}/kaikki.org-dictionary-{name}.jsonl"

REGISTRY = ROOT / "tools" / "phonetic_languages.yaml"


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
    # (regex, replacement) pairs applied in order to every Wiktionary form,
    # so it reads in the conventions of the course's own rules file. Opt-in
    # per language in the registry's `normalise:` list; empty for the rest.
    normalise: tuple[tuple[str, str], ...] = ()
    # (units regex, {form unit: broad unit}) pairs, applied after `normalise`
    # and only when the card's broad `ipa` is known. Wiktionary and the deck
    # sometimes write one sound two ways where either is right elsewhere (s
    # for ʃ in Gujarati, but a genuine /s/ stays), so a context-free regex
    # cannot decide. The units regex is read over the form and over the broad
    # ipa; if both hold the same number of units, the n-th form unit becomes
    # the n-th broad unit when the map lists exactly that pair. Any other
    # count, or any other pair, leaves the form alone.
    align: tuple[tuple[str, tuple[tuple[str, str], ...]], ...] = ()
    # Opt-in guard (registry `agree:`): (characters to ignore, (char, char)
    # pairs to map). When set and the card's broad ipa is known, an imported
    # form is accepted only if its phoneme skeleton (see `skeleton`) equals
    # the broad ipa's, after normalisation; otherwise the card keeps its
    # rule-derived form and the report lists it.
    agree: tuple[str, tuple[tuple[str, str], ...]] | None = None
    # With `agree`, also whether the ignored characters are put back into the
    # form where the broad ipa has them (`agree.restore`), so a sound the
    # source writes another way (Wiktionary's murmur for ɦ, dropped by the
    # `normalise` list) is the deck's again.
    restore: bool = False

    def skeleton(self, ipa: str) -> str:
        """[ipa] reduced to the sounds both a broad and a narrow form write:
        no brackets, spaces, syllable dots, stress, length or combining marks
        (nasalisation, dental, tie bars, ...), without the `agree` ignored
        characters, and with its `agree` map applied."""
        ignore, mapping = self.agree or ("", ())
        table = dict(mapping)
        out = []
        for ch in unicodedata.normalize("NFD", ipa):
            if (unicodedata.category(ch) == "Mn" or ch in "[]/ .\u02c8\u02cc\u02d0"
                    or ch in ignore):
                continue
            out.append(table.get(ch, ch))
        return "".join(out)

    def agrees(self, form: str, broad: str | None) -> bool:
        """Whether [form] may stand for the card whose broad ipa is [broad]."""
        return (self.agree is None or broad is None
                or self.skeleton(form) == self.skeleton(broad))

    def normalised(self, form: str, broad: str | None = None) -> str:
        """[form] with this language's `normalise` pairs applied, then its
        `align` pairs against the card's [broad] ipa (skipped when None)."""
        for pattern, replace in self.normalise:
            form = re.sub(pattern, replace, form)
        if broad is not None:
            for units, mapping in self.align:
                form = self._aligned(form, broad, units, dict(mapping))
            if self.restore and self.agree and self.agrees(form, broad):
                form = self._restored(form, broad)
        return form

    def _restored(self, form: str, broad: str) -> str:
        """[form] with the `agree` ignored characters of [broad] put in at the
        same place in its sounds (the two already agree without them)."""
        ignore = self.agree[0] if self.agree else ""
        keep = Variety(self.name, agree=("", self.agree[1] if self.agree else ()))
        wanted = [c for c in keep.skeleton(broad)]
        out, bi = [], 0
        for ch in unicodedata.normalize("NFD", form):
            sk = keep.skeleton(ch)
            if sk:
                while bi < len(wanted) and wanted[bi] in ignore and sk != wanted[bi]:
                    out.append(wanted[bi])
                    bi += 1
                bi += 1
            out.append(ch)
        out.extend(c for c in wanted[bi:] if c in ignore)
        return unicodedata.normalize("NFC", "".join(out))

    @staticmethod
    def _aligned(form: str, broad: str, units: str, mapping: dict[str, str]) -> str:
        found = list(re.finditer(units, form))
        want = re.findall(units, broad)
        if len(found) != len(want):
            return form
        out, last = [], 0
        for m, b in zip(found, want):
            out.append(form[last:m.start()])
            out.append(b if mapping.get(m.group()) == b else m.group())
            last = m.end()
        out.append(form[last:])
        return "".join(out)

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


def load_registry(path: Path = REGISTRY) -> tuple[dict[str, str], dict[str, Variety]]:
    """The languages the import knows, from the registry file: what the dump
    calls each (`DUMP_NAMES`) and the variety each course teaches
    (`VARIETIES`), both by language code. A new language is an entry in the
    file, never a change here. Raises ValueError naming the entry that is
    wrong."""
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        raise ValueError(f"{path}: not valid YAML ({e})") from e
    if not isinstance(raw, dict):
        raise ValueError(f"{path}: must map language codes to entries")
    dumps: dict[str, str] = {}
    varieties: dict[str, Variety] = {}
    for lang, entry in raw.items():
        try:
            v = entry["variety"]
            dumps[str(lang)] = str(entry["dump"])
            varieties[str(lang)] = Variety(
                str(v.get("name") or lang),
                notes=frozenset(map(str, v.get("notes") or [])),
                tags=frozenset(map(str, v.get("tags") or [])),
                untagged=bool(v.get("untagged", True)),
                normalise=tuple(
                    (str(n["pattern"]), str(n["replace"]))
                    for n in entry.get("normalise") or [] if "pattern" in n),
                align=tuple(
                    (str(n["align"]), tuple((str(k), str(w)) for k, w in n["map"].items()))
                    for n in entry.get("normalise") or [] if "align" in n),
                agree=((str(entry["agree"].get("ignore") or ""),
                        tuple((str(k), str(w)) for k, w in
                              (entry["agree"].get("map") or {}).items()))
                       if entry.get("agree") is not None else None),
                restore=bool((entry.get("agree") or {}).get("restore", False)))
            for pattern, _ in varieties[str(lang)].normalise:
                re.compile(pattern)
            for units, _ in varieties[str(lang)].align:
                re.compile(units)
        except (KeyError, TypeError, AttributeError, re.error) as e:
            raise ValueError(f"{path}: {lang}: needs `dump` and `variety`, and "
                             f"`normalise` pairs of `pattern` and `replace` ({e!r})") from e
    return dumps, varieties


# What the dump calls each language on kaikki.org, and the variety per
# language (the plan's "Which variety per language"): read from the registry
# file `tools/phonetic_languages.yaml`. Another language needs only an entry
# there.
DUMP_NAMES, VARIETIES = load_registry()

OUTCOMES = ["filled", "has phonetic", "no ipa line", "no entry", "no narrow form",
            "other variety", "ambiguous", "disagrees", "invalid", pp.UNWRITABLE]


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


def read_entries(lines: Iterable[str], wanted: set[str],
                 markers: tuple[str, ...] = ('"[',)) -> dict[str, list[dict]]:
    """The entries whose title is in [wanted], from a dump's lines. Lines
    with none of the [markers] (by default a string that starts with `[`,
    a narrow form) are passed by without being parsed: that is most of a
    big dump. `compare_wiktionary_ipa.py` adds `"/` for the broad forms."""
    entries: dict[str, list[dict]] = {}
    for line in lines:
        if not any(m in line for m in markers):
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

def narrow_forms(entry: dict, variety: Variety,
                 broad: str | None = None) -> tuple[list[str], bool, bool, bool]:
    """The entry's narrow forms for [variety], best first, whether any form
    was of another variety, whether any form of this one was not valid IPA,
    and whether any was dropped because it disagrees with [broad] (the
    variety's `agree` guard)."""
    found: list[tuple[int, str]] = []
    other = invalid = disagree = False
    for sound in entry.get("sounds") or []:
        ipa = sound.get("ipa")
        if not isinstance(ipa, str) or not (ipa.startswith("[") and ipa.endswith("]")):
            continue
        rank = variety.rank(sound)
        if rank is None:
            other = True
            continue
        form = pp.normalise(ipa)
        if form is not None:
            form = pp.normalise(variety.normalised(form, broad))
        if form is None:
            invalid = True
        elif not variety.agrees(form, broad):
            disagree = True
        else:
            found.append((rank, form))
    found.sort(key=lambda p: p[0])  # stable: Wiktionary's order within a rank
    return [f for _, f in found], other, invalid, disagree


def choose_form(target: iw.Target, entries: list[dict], variety: Variety,
                broad: str | None = None) -> tuple[str | None, str]:
    """The card's narrow form and the outcome: `filled`, or why not."""
    _, fits = iw.choose(target, entries)
    if not fits:
        return None, "no entry"
    forms: set[str] = set()
    other = invalid = disagree = False
    for entry in fits:
        found, o, i, d = narrow_forms(entry, variety, broad)
        other, invalid, disagree = other or o, invalid or i, disagree or d
        if found:
            forms.add(found[0])
    if len(forms) > 1:
        return None, "ambiguous"
    if forms:
        return forms.pop(), "filled"
    if disagree:
        return None, "disagrees"
    if invalid:
        return None, "invalid"
    return None, "other variety" if other else "no narrow form"


# --- A run ------------------------------------------------------------------

def run(lang: str, dump: Path, decks: Path, write: bool,
        skipped: list[str] | None = None) -> tuple[pp.Coverage, dict]:
    """Fill [lang]'s decks from [dump]; returns the coverage and, per file,
    the forms found (written only when [write]). A card whose imported form
    disagrees with its broad ipa is not filled; its id and the two forms are
    appended to [skipped] when given."""
    variety = VARIETIES[lang]
    language = iw.read_language(decks, lang)
    targets = {t.cid: t for t in language.targets}
    cards = pp.core_cards(decks, lang)
    with dump.open(encoding="utf-8") as f:
        entries = read_entries(f, {c.target for c in cards})
    coverage = pp.Coverage()
    fills: dict[Path, dict[str, tuple[str, str]]] = {}
    outcomes: dict[tuple[Path, str], tuple[str, str]] = {}
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
            form, outcome = choose_form(t, entries.get(card.target, []), variety, card.ipa)
            coverage.add(deck, outcome)
            if outcome == "disagrees" and skipped is not None:
                skipped.append(f"{card.cid} {card.target}: broad /{card.ipa}/, "
                               "Wiktionary's form disagrees")
            if form is not None:
                fills.setdefault(card.file, {})[card.cid] = (form, "wiktionary")
                outcomes[(card.file, card.cid)] = (deck, outcome)
    pp.apply_fills(fills, outcomes, coverage, write)
    return coverage, fills


def renormalise(lang: str, decks: Path, write: bool,
                skipped: list[str] | None = None) -> tuple[pp.Coverage, dict]:
    """Apply [lang]'s `normalise` pairs to the `phonetic` of every card
    whose `phonetic_source` is `wiktionary`, in place. Needs no dump. A card
    already in the course's conventions is `unchanged`; the others are
    `renormalised`. A card whose form, after normalising, disagrees with its
    broad ipa (the variety's `agree` guard) is `disagrees`: it is given the
    form the language's rules file derives, with source `rules`, when there
    is one (else it is left as it is), and its id is appended to [skipped].
    Cards from the rules, or with no source, are never touched."""
    variety = VARIETIES[lang]
    rules_file = decks / lang / f"{lang}-phonetics.yaml"
    try:
        rules = dp.load_rules(rules_file).rules if rules_file.is_file() else None
    except dp.RulesError:
        rules = None
    coverage = pp.Coverage()
    fills: dict[Path, dict[str, tuple[str, str]]] = {}
    outcomes: dict[tuple[Path, str], tuple[str, str]] = {}
    for card in pp.core_cards(decks, lang):
        deck = card.file.stem
        if card.phonetic is None or card.phonetic_source != "wiktionary":
            coverage.add(deck, "not wiktionary")
            continue
        form = pp.normalise(variety.normalised(card.phonetic, card.ipa))
        if form is None:
            coverage.add(deck, "invalid")
        elif not variety.agrees(form, card.ipa):
            coverage.add(deck, "disagrees")
            if skipped is not None:
                skipped.append(f"{card.cid} {card.target}: broad /{card.ipa}/, "
                               f"Wiktionary {card.phonetic}")
            if rules is not None and card.ipa is not None:
                derived, _ = dp.derive(card.ipa, rules)
                if derived is not None:
                    fills.setdefault(card.file, {})[card.cid] = (derived, "rules")
                    outcomes[(card.file, card.cid)] = (deck, "disagrees")
        elif form == card.phonetic:
            coverage.add(deck, "unchanged")
        else:
            coverage.add(deck, "renormalised")
            fills.setdefault(card.file, {})[card.cid] = (form, "wiktionary")
            outcomes[(card.file, card.cid)] = (deck, "renormalised")
    pp.apply_fills(fills, outcomes, coverage, write,
                   replace_rules=True, replace_source="wiktionary")
    return coverage, fills


RENORMALISE_OUTCOMES = ["renormalised", "unchanged", "not wiktionary", "disagrees", "invalid",
                        pp.UNWRITABLE]


def _skipped_section(skipped: list[str], what: str) -> str:
    """The report's list of cards the `agree` guard stopped, or nothing."""
    if not skipped:
        return ""
    return (f"\n\n## Wiktionary forms that disagree with the broad ipa ({what})\n\n"
            + "\n".join(f"- {line}" for line in skipped) + "\n")


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
    parser.add_argument("--renormalise", action="store_true",
                        help="instead of importing, apply the language's `normalise` "
                             "pairs to the Wiktionary cards already in the decks "
                             "(no dump needed)")
    parser.add_argument("--write", action="store_true",
                        help="patch the decks; without it, only report")
    parser.add_argument("--report", type=Path, help="write the report here")
    args = parser.parse_args(argv[1:])
    if args.lang not in VARIETIES:
        print(f"error: no variety is named for {args.lang!r} yet; add it to "
              f"tools/phonetic_languages.yaml (configured: {', '.join(sorted(VARIETIES))})", file=sys.stderr)
        return 2
    if not (args.decks / args.lang).is_dir():
        print(f"error: no decks for {args.lang!r} in {args.decks}", file=sys.stderr)
        return 2
    if args.renormalise:
        skipped: list[str] = []
        coverage, _ = renormalise(args.lang, args.decks, args.write, skipped)
        report = (f"# Narrow IPA from Wiktionary, renormalised: {args.lang}\n\n"
                  f"{'Written.' if args.write else 'Report only; nothing was written.'}\n\n"
                  + coverage.render(args.lang, RENORMALISE_OUTCOMES, title="Coverage")
                  + _skipped_section(skipped, "given the rules' form instead"))
        if args.report:
            args.report.write_text(report, encoding="utf-8")
        print(report)
        return pp.unwritable_exit(coverage, args.write)
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
    skipped = []
    coverage, _ = run(args.lang, dump, args.decks, args.write, skipped)
    report = (f"# Narrow IPA from Wiktionary: {args.lang}\n\n"
              f"Variety: {VARIETIES[args.lang].name}. Dump: {dump.name}. "
              f"{'Written.' if args.write else 'Report only; nothing was written.'}\n\n"
              + coverage.render(args.lang, OUTCOMES, title="Coverage")
              + _skipped_section(skipped, "kept their rule-derived form"))
    if args.report:
        args.report.write_text(report, encoding="utf-8")
    print(report)
    return pp.unwritable_exit(coverage, args.write)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
