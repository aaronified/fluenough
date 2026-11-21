#!/usr/bin/env python3
"""Compare the decks' IPA with Wiktionary's and list the disagreements for a
human to review (#305, part of #217; wiki: Plan-Ipa-Revamp-And-Language-Phonology).

Usage:
    python3 tools/compare_wiktionary_ipa.py bn
    python3 tools/compare_wiktionary_ipa.py bn hi --markdown review.md --json review.json
    python3 tools/compare_wiktionary_ipa.py bn --dump Bengali.jsonl --limit 200
    python3 tools/compare_wiktionary_ipa.py bn --rules-only

It never writes into the decks. It reads them, and writes a review list.

Where the data comes from. The same place `tools/import_phonetic.py` reads:
Wiktionary's pronunciations as Wiktextract extracts them and kaikki.org
publishes them (English Wiktionary, CC BY-SA 4.0), one JSON-lines file per
language, downloaded once into `.cache/phonetic/` (git-ignored) and read from
there on every later run. `--dump FILE` uses a file you have, `--cache DIR`
moves the cache, `--refresh` downloads again. One download per language, never
a request per word, so nothing hammers Wiktionary; `--limit N` compares only
the first N core cards, for a quick look.

What it compares, per card of the language's core decks, at two levels:

- `broad`: the card's `ipa` against Wiktionary's `/ ... /` forms;
- `narrow`: the card's `phonetic` against Wiktionary's `[ ... ]` forms (only
  for cards that have a `phonetic`).

Wiktionary's entries are found, and its forms of the language's variety
chosen, with the importer's own code (`import_wiktionary.choose`,
`import_phonetic.Variety.rank`, `Variety.normalised`, `phonetic_patch.normalise`):
the same title, part of speech, meaning, variety and `normalise` / `align`
rules from `tools/phonetic_languages.yaml`. The importer's `agree` guard is
not applied, because the cards it drops are exactly the disagreements this
list is for.

How a difference is named (KINDS, likeliest real error first):

1. `consonant` or `vowel quality` or `vowel and consonant`: the base letters
   differ, once stress, length and diacritics are taken away.
2. `multiple Wiktionary variants`: Wiktionary gives several forms and the
   card's matches none (when it matches one, that is agreement).
3. `length mark`, `stress`, `diacritic only`: the base letters agree. If more
   than one of these differs, the first in this list names it. Stress is
   compared only when the card's form has a stress mark at all (the decks'
   broad `ipa` seldom does, and Wiktionary's nearly always does).
4. `missing in Wiktionary`: no entry, or no form of that level for the
   variety. Not a disagreement, so it is listed last and left out of the
   agreement rate.

Within a kind, the smaller difference comes first: one sound out is the
clearest slip, a wholesale mismatch is often another word's entry.

Credit: Wiktionary's pronunciations are CC BY-SA 4.0, as the decks are; the
output's header says so and every row links its Wiktionary page.

Stdlib and PyYAML only.
"""

from __future__ import annotations

import argparse
import difflib
import json
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import import_phonetic as ip  # noqa: E402
import import_wiktionary as iw  # noqa: E402
import phonetic_patch as pp  # noqa: E402

ROOT = ip.ROOT

LEVELS = ("broad", "narrow")

MISSING = "missing in Wiktionary"
MULTIPLE = "multiple Wiktionary variants"
KINDS = ["consonant", "vowel quality", "vowel and consonant", MULTIPLE,
         "length mark", "stress", "diacritic only", MISSING]
_KIND_RANK = {k: i for i, k in enumerate(KINDS)}

CREDIT = ("Pronunciations from [Wiktionary](https://en.wiktionary.org), "
          "licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), "
          "as Wiktextract extracts them and kaikki.org publishes them. "
          "This is a review aid: nothing here is written into the decks.")

STRESS = "\u02c8\u02cc"
LENGTH = "\u02d0\u02d1"
VOWELS = frozenset("aeiouyɪʏʊɛœɔæɐəɘɵɤɜɞɨʉɯɑɒɶɚɝɷ")
_DROPPED = frozenset(" .[]/")


# --- Telling two forms apart ------------------------------------------------

def tidy(form: str) -> str:
    """[form] as NFC, with no spaces: phrases compare by their sounds."""
    return unicodedata.normalize("NFC", "".join(form.split()))


def _is_diacritic(ch: str) -> bool:
    return unicodedata.category(ch) == "Mn" or (
        unicodedata.category(ch) == "Lm" and ch not in STRESS + LENGTH)


def strip(form: str, *, stress: bool = False, length: bool = False,
          diacritics: bool = False) -> str:
    """[form] (NFD) without syllable dots, spaces, brackets and, as asked,
    stress marks, length marks and diacritics (combining marks and modifier
    letters such as the aspiration mark)."""
    out = []
    for ch in unicodedata.normalize("NFD", form):
        if ch in _DROPPED:
            continue
        if (stress and ch in STRESS) or (length and ch in LENGTH) \
                or (diacritics and (_is_diacritic(ch))):
            continue
        out.append(ch)
    return "".join(out)


def distance(a: str, b: str) -> int:
    """The edit distance between [a] and [b], by characters."""
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def _sound_kind(core_a: str, core_b: str) -> str:
    """Whether the base letters differ in a vowel, a consonant or both."""
    vowel = consonant = False
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
            None, core_a, core_b, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        for ch in core_a[i1:i2] + core_b[j1:j2]:
            if ch in VOWELS:
                vowel = True
            else:
                consonant = True
    if vowel and consonant:
        return "vowel and consonant"
    return "vowel quality" if vowel else "consonant"


def difference(ours: str, theirs: str) -> tuple[str | None, int]:
    """None when [ours] and [theirs] are the same form, else the kind of
    their difference (see KINDS) and the edit distance between them."""
    a, b = tidy(ours), tidy(theirs)
    if not any(c in STRESS for c in a):
        b = strip(b, stress=True)  # the card writes no stress: not a difference
        a = strip(a)
    else:
        a, b = strip(a), strip(b)
    if unicodedata.normalize("NFC", a) == unicodedata.normalize("NFC", b):
        return None, 0
    dist = distance(a, b)
    core_a = strip(a, stress=True, length=True, diacritics=True)
    core_b = strip(b, stress=True, length=True, diacritics=True)
    if core_a != core_b:
        return _sound_kind(core_a, core_b), dist
    if strip(a, diacritics=True, stress=True) != strip(b, diacritics=True, stress=True):
        return "length mark", dist
    if strip(a, diacritics=True, length=True) != strip(b, diacritics=True, length=True):
        return "stress", dist
    return "diacritic only", dist


def judge(ours: str, theirs: list[str]) -> tuple[str, str | None, int]:
    """How [ours] stands against Wiktionary's forms [theirs] (best first, not
    empty): `("agree", None, 0)` if it is any of them, else `("differ", kind,
    distance)`. With several forms that all differ the kind is
    MULTIPLE and the distance is the nearest one's."""
    found = [difference(ours, t) for t in theirs]
    if any(kind is None for kind, _ in found):
        return "agree", None, 0
    nearest = min(range(len(found)), key=lambda i: found[i][1])
    kind, dist = found[nearest]
    return "differ", (MULTIPLE if len(theirs) > 1 else kind), dist


def closest_kind(ours: str, theirs: list[str]) -> str | None:
    """With several Wiktionary forms, the kind of difference from the
    nearest one (the row's own kind is then MULTIPLE)."""
    if len(theirs) < 2:
        return None
    found = [difference(ours, t) for t in theirs]
    return min(found, key=lambda f: f[1])[0]


# --- Wiktionary's forms -----------------------------------------------------

def wiktionary_forms(entries: list[dict], variety: ip.Variety, level: str,
                     broad: str | None) -> tuple[list[str], str]:
    """The forms of [level] the language's variety has in [entries], best
    rank first, no repeats, in Wiktionary's order; with them, why there are
    none (`""` when there are some). Wiktionary writes a broad form between
    slashes and a narrow one between square brackets; both come back
    normalised as the importer does (brackets for `narrow`, none for `broad`)."""
    shut = ("/", "/") if level == "broad" else ("[", "]")
    found: list[tuple[int, str]] = []
    other = invalid = False
    for entry in entries:
        for sound in entry.get("sounds") or []:
            raw = sound.get("ipa")
            if not isinstance(raw, str) or not (raw.startswith(shut[0])
                                               and raw.endswith(shut[1])) or len(raw) < 3:
                continue
            rank = variety.rank(sound)
            if rank is None:
                other = True
                continue
            form = pp.normalise("[" + raw[1:-1] + "]")
            if form is not None and level == "narrow":
                form = pp.normalise(variety.normalised(form, broad))
            if form is None:
                invalid = True
            else:
                found.append((rank, form if level == "narrow" else form[1:-1]))
    if not found:
        return [], ("invalid form" if invalid else
                    "another variety only" if other else f"no {level} form")
    best = min(r for r, _ in found)
    forms: list[str] = []
    for r, f in found:
        if r == best and f not in forms:
            forms.append(f)
    return forms, ""


# --- A comparison -----------------------------------------------------------

@dataclass
class Row:
    cid: str
    word: str
    deck: str
    level: str
    ours: str
    wiktionary: list[str]
    kind: str | None = None          # None: agrees
    closest: str | None = None
    distance: int = 0
    source: str | None = None        # the card's phonetic_source (narrow)
    reason: str = ""                 # why missing

    @property
    def agrees(self) -> bool:
        return self.kind is None

    def as_json(self) -> dict:
        return {"id": self.cid, "word": self.word, "deck": self.deck,
                "level": self.level, "ours": self.ours,
                "wiktionary": self.wiktionary, "kind": self.kind,
                "closest_kind": self.closest, "distance": self.distance,
                "source": self.source, "reason": self.reason,
                "url": iw.page(self.word)}


@dataclass
class Comparison:
    lang: str
    variety: str
    dump: str
    cards: int = 0
    no_narrow: int = 0
    rows: list[Row] = field(default_factory=list)

    def review(self) -> list[Row]:
        """The disagreements and the missing, the likeliest real errors first."""
        rest = [r for r in self.rows if not r.agrees]
        return sorted(rest, key=lambda r: (_KIND_RANK[r.kind or MISSING], r.distance,
                                           r.cid, r.level))

    def summary(self) -> dict:
        def tally(rows: list[Row]) -> dict:
            agree = sum(r.agrees for r in rows)
            missing = sum(r.kind == MISSING for r in rows)
            differ = len(rows) - agree - missing
            compared = agree + differ
            return {"compared": compared, "agree": agree, "disagree": differ,
                    "missing": missing,
                    "agreement_rate": round(agree / compared, 4) if compared else None}

        by_level = {lv: tally([r for r in self.rows if r.level == lv]) for lv in LEVELS}
        compared = sum(v["compared"] for v in by_level.values())
        out = {"cards": self.cards, "cards_without_narrow": self.no_narrow,
               "overall": tally(self.rows), "levels": by_level}
        out["by_kind"] = {
            k: {"count": n, "share_of_compared": round(n / compared, 4) if compared else None}
            for k in KINDS if k != MISSING
            for n in [sum(r.kind == k for r in self.rows)]}
        sources = sorted({r.source for r in self.rows if r.level == "narrow" and r.source}
                         | ({"none"} if any(r.level == "narrow" and not r.source
                                            for r in self.rows) else set()))
        out["narrow_by_source"] = {
            s: tally([r for r in self.rows if r.level == "narrow"
                      and (r.source or "none") == s]) for s in sources}
        return out


def compare(lang: str, dump: Path, decks: Path, *, limit: int | None = None,
            rules_only: bool = False) -> Comparison:
    """Compare [lang]'s core cards with Wiktionary's forms in [dump]. Reads
    the decks, writes nothing."""
    variety = ip.VARIETIES[lang]
    language = iw.read_language(decks, lang)
    targets = {t.cid: t for t in language.targets}
    cards = pp.core_cards(decks, lang)
    if limit is not None:
        cards = cards[:limit]
    with dump.open(encoding="utf-8") as f:
        entries = ip.read_entries(f, {c.target for c in cards}, ('"[', '"/'))
    result = Comparison(lang, variety.name, dump.name, cards=len(cards))
    for card in cards:
        t = targets.get(card.cid)
        fits = iw.choose(t, entries.get(card.target, []))[1] if t else []
        ours = {}
        if card.ipa:
            ours["broad"] = card.ipa
        if card.phonetic:
            if not rules_only or card.phonetic_source != "wiktionary":
                ours["narrow"] = card.phonetic
        else:
            result.no_narrow += 1
        for level, form in ours.items():
            normal = pp.normalise("[" + form + "]") if level == "broad" else pp.normalise(form)
            mine = normal if normal is None or level == "narrow" else normal[1:-1]
            mine = mine or form
            theirs, reason = wiktionary_forms(fits, variety, level, card.ipa)
            if not fits:
                reason = "no entry"
            row = Row(card.cid, card.target, card.file.stem, level, mine, theirs,
                      source=(card.phonetic_source or None) if level == "narrow" else None)
            if not theirs:
                row.kind, row.reason = MISSING, reason
            else:
                state, row.kind, row.distance = judge(mine, theirs)
                if state == "agree":
                    row.kind = None
                else:
                    row.closest = closest_kind(mine, theirs)
            result.rows.append(row)
    return result


# --- The output -------------------------------------------------------------

def _pct(rate: float | None) -> str:
    return "n/a" if rate is None else f"{rate * 100:.1f}%"


def _cell(text: str) -> str:
    return text.replace("|", "\\|").replace("\n", " ")


def _wrap(form: str, level: str) -> str:
    return f"/{form}/" if level == "broad" and form else form


def markdown(results: list[Comparison]) -> str:
    """The review list as Markdown: credit, a summary per language, then
    each language's list, likeliest real errors first."""
    lines = ["# Wiktionary IPA compared with the decks'", "", CREDIT, ""]
    for res in results:
        s = res.summary()
        lines += [f"## {res.lang}: summary", "",
                  f"Variety: {res.variety}. Dump: {res.dump}. {s['cards']} core cards, "
                  f"{s['cards_without_narrow']} without a `phonetic`.", "",
                  "| level | compared | agree | disagree | missing in Wiktionary | agreement |",
                  "|---|---:|---:|---:|---:|---:|"]
        for name, t in [*s["levels"].items(), ("all", s["overall"])]:
            lines.append(f"| {name} | {t['compared']} | {t['agree']} | {t['disagree']} | "
                         f"{t['missing']} | {_pct(t['agreement_rate'])} |")
        lines += ["", "| kind of difference | count | share of compared |", "|---|---:|---:|"]
        lines += [f"| {k} | {v['count']} | {_pct(v['share_of_compared'])} |"
                  for k, v in s["by_kind"].items()]
        if s["narrow_by_source"]:
            lines += ["", "Narrow forms by `phonetic_source` (a `wiktionary` card was taken "
                      "from Wiktionary, so it agrees by construction; `rules` is the check):",
                      "", "| source | compared | agree | agreement |", "|---|---:|---:|---:|"]
            lines += [f"| {k} | {v['compared']} | {v['agree']} | {_pct(v['agreement_rate'])} |"
                      for k, v in s["narrow_by_source"].items()]
        review = res.review()
        lines += ["", f"## {res.lang}: review list ({len(review)})", ""]
        if not review:
            lines += ["Nothing to review.", ""]
            continue
        lines += ["| # | card | word | level | ours | Wiktionary | kind | page |",
                  "|---:|---|---|---|---|---|---|---|"]
        for n, r in enumerate(review, 1):
            theirs = " ; ".join(_wrap(w, r.level) for w in r.wiktionary) or f"({r.reason})"
            kind = r.kind if not r.closest else f"{r.kind} (nearest: {r.closest})"
            lines.append(f"| {n} | {r.cid} | {_cell(r.word)} | {r.level} | "
                         f"{_cell(_wrap(r.ours, r.level))} | {_cell(theirs)} | {kind} | "
                         f"[page]({iw.page(r.word)}) |")
        lines.append("")
    return "\n".join(lines)


def as_json(results: list[Comparison]) -> dict:
    """The same review list for tools: the summary and the rows (sorted as
    the Markdown's) per language."""
    return {"source": {"name": "Wiktionary", "via": "Wiktextract, kaikki.org",
                       "licence": "CC BY-SA 4.0",
                       "licence_url": "https://creativecommons.org/licenses/by-sa/4.0/"},
            "kinds": KINDS,
            "languages": {r.lang: {"variety": r.variety, "dump": r.dump,
                                   "summary": r.summary(),
                                   "review": [row.as_json() for row in r.review()]}
                          for r in results}}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="List where the decks' IPA and Wiktionary's disagree.")
    parser.add_argument("langs", nargs="+", metavar="lang",
                        help="language codes: " + ", ".join(sorted(ip.VARIETIES)))
    parser.add_argument("--decks", type=Path, default=ROOT / "decks",
                        help="the decks folder (default: the repository's)")
    parser.add_argument("--dump", type=Path,
                        help="a kaikki.org JSONL you have (one language only; "
                             "default: the cached download)")
    parser.add_argument("--cache", type=Path, default=ip.CACHE,
                        help="where the download is kept (default: .cache/phonetic)")
    parser.add_argument("--refresh", action="store_true", help="download the dump again")
    parser.add_argument("--limit", type=int, metavar="N",
                        help="compare only each language's first N core cards")
    parser.add_argument("--rules-only", action="store_true",
                        help="leave out narrow forms taken from Wiktionary (they agree "
                             "by construction)")
    parser.add_argument("--markdown", type=Path, help="write the Markdown review list here")
    parser.add_argument("--json", type=Path, help="write the JSON review list here")
    args = parser.parse_args(argv[1:])
    if args.limit is not None and args.limit < 1:
        print("error: --limit must be at least 1", file=sys.stderr)
        return 2
    if args.dump is not None and len(args.langs) > 1:
        print("error: --dump names one language's file; give one language", file=sys.stderr)
        return 2
    results = []
    for lang in args.langs:
        if lang not in ip.VARIETIES:
            print(f"error: no variety is named for {lang!r} yet; add it to "
                  f"tools/phonetic_languages.yaml (configured: "
                  f"{', '.join(sorted(ip.VARIETIES))})", file=sys.stderr)
            return 2
        if not (args.decks / lang).is_dir():
            print(f"error: no decks for {lang!r} in {args.decks}", file=sys.stderr)
            return 2
        dump = args.dump
        if dump is None:
            try:
                dump = ip.ensure_dump(lang, cache=args.cache, refresh=args.refresh)
            except OSError as e:
                print(f"error: could not download the dump: {e}", file=sys.stderr)
                return 2
        elif not dump.is_file():
            print(f"error: {dump} does not exist", file=sys.stderr)
            return 2
        results.append(compare(lang, dump, args.decks, limit=args.limit,
                               rules_only=args.rules_only))
    text = markdown(results)
    if args.markdown:
        args.markdown.write_text(text, encoding="utf-8")
    if args.json:
        args.json.write_text(json.dumps(as_json(results), ensure_ascii=False, indent=2)
                             + "\n", encoding="utf-8")
    if not args.markdown and not args.json:
        print(text)
    else:
        print("wrote " + ", ".join(str(p) for p in (args.markdown, args.json) if p),
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
