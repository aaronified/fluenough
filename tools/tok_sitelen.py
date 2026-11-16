#!/usr/bin/env python3
"""Writes Toki Pona in sitelen pona, deterministically (owner, 2026-11-16:
"Also add sitelen pona decks").

    python3 tools/tok_sitelen.py decks/tok          # add the spelling in place
    python3 tools/tok_sitelen.py --check decks/tok  # exit 1 if a file is not up to date
    python3 tools/tok_sitelen.py --words decks/tok  # list the words of the decks
    python3 tools/tok_sitelen.py --glyph-deck decks/tok  # write the glyph deck

The decks keep Toki Pona in Latin letters: a card's `target` is the Latin
spelling, so every card, layer and id is as it was (ADR-0058). This tool adds
the card's second spelling, `target_scripts: { sitelen_pona: ... }`, to the
card and to each of its examples, and `scripts: ["latin", "sitelen_pona"]`
to the deck's language block, as Hindustani has two scripts (Deck Format,
"A card's other scripts"). The sitelen pona is written in the Unicode
private-use block of the UCSUR, the Under-ConScript Unicode Registry
(https://www.kreativekorp.com/ucsur/charts/sitelen.html), U+F1900 to
U+F19FF, which the downloaded font draws (decks/fonts/sitelen_pona).

The rules, all of them:

- Each word is its UCSUR glyph, WORDS below: the 120 words of pu, the 17 more
  of ku suli, and the four others the registry holds. `ali` and `ale` are one
  glyph. A word that is not in WORDS stops the tool, which names it.
- A word that starts with a capital is a name (jan Ali) and is written in a
  cartouche: U+F1990, a glyph for each letter, U+F1991. A letter is the glyph of
  a word that starts with it, LETTERS below: the usual choice, the same every
  time. A letter Toki Pona does not have stops the tool.
- Words are written with a space between them, and . , : ; ! ? stay as they
  are, joined to the word before. The reading and the IPA stay as they are,
  in Latin.
- Deck text in a grammar table (`pattern`) or in a reading passage has no
  other-script field in the format and stays in Latin.

`--glyph-deck` writes the glyph guide, `tok-script-sitelen-pona`, a script
deck taught from the Latin side (ADR-0055): one card for each word the
course teaches, its target the word's glyph and `target_scripts.latin` the
word, in the order the path first meets the words. A card's reading, IPA and
English meaning are those of the word's own card. The new card ids follow the
largest `tok-NNNN` in `decks/`, and a card keeps its id when the tool is run
again.

The tool changes the text of the files and nothing else: it checks, by reading
each file before and after, that the only difference is the added fields.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

SCRIPT = "sitelen_pona"
CARTOUCHE_START = "\U000F1990"
CARTOUCHE_END = "\U000F1991"

# word -> UCSUR code point (the registry's chart, sitelen.html). One word
# each, in code point order.
WORDS: dict[str, int] = {
    "a": 0xF1900, "akesi": 0xF1901, "ala": 0xF1902, "alasa": 0xF1903, "ale": 0xF1904,
    "ali": 0xF1904, "anpa": 0xF1905, "ante": 0xF1906, "anu": 0xF1907, "awen": 0xF1908,
    "e": 0xF1909, "en": 0xF190A, "esun": 0xF190B, "ijo": 0xF190C, "ike": 0xF190D,
    "ilo": 0xF190E, "insa": 0xF190F, "jaki": 0xF1910, "jan": 0xF1911, "jelo": 0xF1912,
    "jo": 0xF1913, "kala": 0xF1914, "kalama": 0xF1915, "kama": 0xF1916, "kasi": 0xF1917,
    "ken": 0xF1918, "kepeken": 0xF1919, "kili": 0xF191A, "kiwen": 0xF191B,
    "ko": 0xF191C, "kon": 0xF191D, "kule": 0xF191E, "kulupu": 0xF191F, "kute": 0xF1920,
    "la": 0xF1921, "lape": 0xF1922, "laso": 0xF1923, "lawa": 0xF1924, "len": 0xF1925,
    "lete": 0xF1926, "li": 0xF1927, "lili": 0xF1928, "linja": 0xF1929, "lipu": 0xF192A,
    "loje": 0xF192B, "lon": 0xF192C, "luka": 0xF192D, "lukin": 0xF192E, "lupa": 0xF192F,
    "ma": 0xF1930, "mama": 0xF1931, "mani": 0xF1932, "meli": 0xF1933, "mi": 0xF1934,
    "mije": 0xF1935, "moku": 0xF1936, "moli": 0xF1937, "monsi": 0xF1938, "mu": 0xF1939,
    "mun": 0xF193A, "musi": 0xF193B, "mute": 0xF193C, "nanpa": 0xF193D, "nasa": 0xF193E,
    "nasin": 0xF193F, "nena": 0xF1940, "ni": 0xF1941, "nimi": 0xF1942, "noka": 0xF1943,
    "o": 0xF1944, "olin": 0xF1945, "ona": 0xF1946, "open": 0xF1947, "pakala": 0xF1948,
    "pali": 0xF1949, "palisa": 0xF194A, "pan": 0xF194B, "pana": 0xF194C, "pi": 0xF194D,
    "pilin": 0xF194E, "pimeja": 0xF194F, "pini": 0xF1950, "pipi": 0xF1951,
    "poka": 0xF1952, "poki": 0xF1953, "pona": 0xF1954, "pu": 0xF1955, "sama": 0xF1956,
    "seli": 0xF1957, "selo": 0xF1958, "seme": 0xF1959, "sewi": 0xF195A,
    "sijelo": 0xF195B, "sike": 0xF195C, "sin": 0xF195D, "sina": 0xF195E,
    "sinpin": 0xF195F, "sitelen": 0xF1960, "sona": 0xF1961, "soweli": 0xF1962,
    "suli": 0xF1963, "suno": 0xF1964, "supa": 0xF1965, "suwi": 0xF1966, "tan": 0xF1967,
    "taso": 0xF1968, "tawa": 0xF1969, "telo": 0xF196A, "tenpo": 0xF196B,
    "toki": 0xF196C, "tomo": 0xF196D, "tu": 0xF196E, "unpa": 0xF196F, "uta": 0xF1970,
    "utala": 0xF1971, "walo": 0xF1972, "wan": 0xF1973, "waso": 0xF1974, "wawa": 0xF1975,
    "weka": 0xF1976, "wile": 0xF1977, "namako": 0xF1978, "kin": 0xF1979, "oko": 0xF197A,
    "kipisi": 0xF197B, "leko": 0xF197C, "monsuta": 0xF197D, "tonsi": 0xF197E,
    "jasima": 0xF197F, "kijetesantakalu": 0xF1980, "soko": 0xF1981, "meso": 0xF1982,
    "epiku": 0xF1983, "kokosila": 0xF1984, "lanpan": 0xF1985, "n": 0xF1986,
    "misikeke": 0xF1987, "ku": 0xF1988, "pake": 0xF19A0, "apeja": 0xF19A1,
    "majuna": 0xF19A2, "powe": 0xF19A3,
}

# The glyph a cartouche writes a letter with: the word it starts, the usual
# choice. Toki Pona has fourteen letters.
LETTERS = {
    "a": "akesi", "e": "esun", "i": "ijo", "j": "jan", "k": "kala",
    "l": "lipu", "m": "meli", "n": "nasa", "o": "olin", "p": "pona",
    "s": "soweli", "t": "tomo", "u": "uta", "w": "waso",
}

_PUNCT = ".,:;!?"
_TOKEN = re.compile(r"^(?P<word>[^.,:;!?]+)(?P<end>[.,:;!?]*)$")


class UnknownWord(ValueError):
    """A word or a letter the table does not have."""


def glyph(word: str) -> str:
    """The UCSUR glyph of one Toki Pona word: a cartouche for a name."""
    if word[:1].isupper():
        out = []
        for letter in word.lower():
            if letter not in LETTERS:
                raise UnknownWord(f"letter {letter!r} of the name {word!r}")
            out.append(chr(WORDS[LETTERS[letter]]))
        return CARTOUCHE_START + "".join(out) + CARTOUCHE_END
    if word not in WORDS:
        raise UnknownWord(f"word {word!r}")
    return chr(WORDS[word])


def sitelen_pona(text: str) -> str:
    """[text], Toki Pona in Latin letters, in sitelen pona."""
    out = []
    for token in text.split():
        m = _TOKEN.match(token)
        if m is None:
            raise UnknownWord(f"token {token!r}")
        out.append(glyph(m.group("word")) + m.group("end"))
    return " ".join(out)


# --- Deck files ---------------------------------------------------------

# A target line of a block style file, with the key quoted or not.
_BLOCK = re.compile(r'^(?P<indent>\s*)(?P<dash>- )?(?P<q>"?)target(?P=q): "(?P<text>[^"\\]*)"\s*$')
# A target inside a flow mapping: { target: "...", ... }
_FLOW = re.compile(r'(?P<head>\{\s*(?P<q>"?)target(?P=q):\s*)"(?P<text>[^"\\]*)"')
# The language block's script line, block style or flow style.
_LANG_BLOCK = re.compile(r'^(?P<indent>\s+)(?P<q>"?)script(?P=q): "latin"\s*$')
_LANG_FLOW = re.compile(r'(?P<head>\bscript: "latin")(?P<tail>,)')


def convert_lines(lines: list[str]) -> tuple[list[str], int]:
    """[lines] of a core vocab deck with the sitelen pona spelling added, and
    how many were added. Lines that already have it are left alone."""
    out: list[str] = []
    added = 0
    i = 0
    in_language = False
    while i < len(lines):
        line = lines[i]
        if re.match(r'^"?language"?:\s*$', line):
            in_language = True
        elif in_language and not line.startswith(" "):
            in_language = False
        if in_language and (m := _LANG_BLOCK.match(line)):
            q = m.group("q")
            out.append(line)
            out.append(f'{m.group("indent")}{q}scripts{q}: ["latin", "{SCRIPT}"]')
            i += 1
            continue
        if (m := _LANG_FLOW.search(line)) and line.startswith("language:"):
            out.append(line.replace(m.group(0), m.group("head") + ', scripts: ["latin", "'
                                    + SCRIPT + '"],', 1))
            i += 1
            continue
        m = _BLOCK.match(line)
        if m:
            q = m.group("q")
            key_indent = len(m.group("indent")) + (2 if m.group("dash") else 0)
            nxt = lines[i + 1] if i + 1 < len(lines) else ""
            out.append(line)
            if "target_scripts" not in nxt:
                pad = " " * key_indent
                out.append(f'{pad}{q}target_scripts{q}:')
                out.append(f'{pad}  {q}{SCRIPT}{q}: "{sitelen_pona(m.group("text"))}"')
                added += 1
            i += 1
            continue
        if "target:" in line or '"target":' in line:
            def flow(match: re.Match) -> str:
                nonlocal added
                text = match.group("text")
                if "target_scripts" in line:
                    return match.group(0)
                added += 1
                q = match.group("q")
                return (f'{match.group(0)}, {q}target_scripts{q}: '
                        f'{{ {q}{SCRIPT}{q}: "{sitelen_pona(text)}" }}')
            line = _FLOW.sub(flow, line)
        out.append(line)
        i += 1
    return out, added


def _targets(card: dict) -> list[str]:
    found = [card["target"]] if isinstance(card.get("target"), str) else []
    for ex in card.get("examples") or []:
        if isinstance(ex, dict) and isinstance(ex.get("target"), str):
            found.append(ex["target"])
    return found


def is_vocab_core(raw: object) -> bool:
    return (isinstance(raw, dict) and raw.get("part") == "core"
            and raw.get("kind") == "vocab" and isinstance(raw.get("cards"), list)
            and isinstance(raw.get("language"), dict)
            and raw["language"].get("code") == "tok")


def convert_file(path: Path, write: bool = True) -> int:
    """Adds the spelling to [path]; returns how many spellings it added (0
    for a file that is not a Toki Pona vocab core, or is up to date)."""
    text = path.read_text(encoding="utf-8")
    before = yaml.safe_load(text)
    if not is_vocab_core(before):
        return 0
    lines, added = convert_lines(text.split("\n"))
    if not added and before["language"].get("scripts"):
        return 0
    new = "\n".join(lines)
    after = yaml.safe_load(new)
    # The only difference is the added fields.
    expect = yaml.safe_load(text)
    expect["language"]["scripts"] = ["latin", SCRIPT]
    for card in expect["cards"]:
        if isinstance(card, dict) and "target" in card:
            card.setdefault("target_scripts", {})[SCRIPT] = sitelen_pona(card["target"])
        for ex in (card.get("examples") or []) if isinstance(card, dict) else []:
            if isinstance(ex, dict) and "target" in ex:
                ex.setdefault("target_scripts", {})[SCRIPT] = sitelen_pona(ex["target"])
    if after != expect:
        raise SystemExit(f"{path}: the converted file is not the expected one")
    if write:
        path.write_text(new, encoding="utf-8")
    return added


def deck_files(root: Path) -> list[Path]:
    return sorted(p for p in root.glob("*.yaml") if p.is_file())


def words_of(root: Path) -> dict[str, int]:
    """Every word of every target of the vocab cores, counted."""
    counts: dict[str, int] = {}
    for p in deck_files(root):
        raw = yaml.safe_load(p.read_text(encoding="utf-8"))
        if not is_vocab_core(raw):
            continue
        for card in raw["cards"]:
            if isinstance(card, dict):
                for t in _targets(card):
                    for w in re.findall(r"[^\W\d_]+", t):
                        counts[w] = counts.get(w, 0) + 1
    return counts


# --- The glyph deck -----------------------------------------------------

GLYPH_DECK = "tok-script-sitelen-pona"
GLYPH_LAYER = "tok-en-script-sitelen-pona"
_ID = re.compile(r"tok-(\d{4})\b")


def _q(text: str) -> str:
    """[text] as a double-quoted YAML scalar."""
    import json
    return json.dumps(text, ensure_ascii=False)


def _unit_decks(path: Path) -> list[str]:
    """The core ids of the path's decks, in unit order."""
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    found: list[str] = []
    for unit in raw.get("units", []):
        ids = unit if isinstance(unit, list) else (unit or {}).get("decks", [])
        for deck in ids or []:
            if isinstance(deck, str) and deck != "*" and deck != GLYPH_DECK \
                    and deck not in found:
                found.append(deck)
    return found


def word_cards(root: Path) -> list[tuple[str, str, str | None, str]]:
    """(word, card id, ipa, English meaning) of each word with a card of
    its own, in the order the path first meets it."""
    order = _unit_decks(root / "tok-path.yaml")
    listed = {p.stem for p in deck_files(root)}
    ordered = [d for d in order if d in listed] + sorted(listed - set(order))
    found: dict[str, tuple[str, str | None, str]] = {}
    for deck in ordered:
        core = yaml.safe_load((root / f"{deck}.yaml").read_text(encoding="utf-8"))
        if not is_vocab_core(core) or deck == GLYPH_DECK:
            continue
        layer_path = root / "en" / f"tok-en-{deck[4:]}.yaml"
        layer = (yaml.safe_load(layer_path.read_text(encoding="utf-8"))
                 if layer_path.is_file() else {}) or {}
        meanings = layer.get("cards") or {}
        for card in core["cards"]:
            word = card.get("target") if isinstance(card, dict) else None
            if (isinstance(word, str) and word in WORDS and word not in found
                    and card.get("id") and card.get("pos") != "phrase"):
                native = (meanings.get(card["id"]) or {}).get("native")
                if isinstance(native, str) and native:
                    found[word] = (card["id"], card.get("ipa"), native)
    return [(w, *found[w]) for w in found]


def glyph_deck(root: Path) -> tuple[str, str]:
    """The text of the glyph deck's core and of its English layer."""
    words = word_cards(root)
    ids: dict[str, str] = {}
    top = 0
    for p in root.parent.rglob("*.yaml"):
        for n in _ID.findall(p.read_text(encoding="utf-8")):
            top = max(top, int(n))
    existing = root / f"{GLYPH_DECK}.yaml"
    if existing.is_file():
        old = yaml.safe_load(existing.read_text(encoding="utf-8"))
        for card in old.get("cards", []):
            ids[card["target"]] = card["id"]
    core = [
        '"schema": 1',
        f'"id": "{GLYPH_DECK}"',
        '"part": "core"',
        '"kind": "vocab"',
        '"language":',
        '  "code": "tok"',
        '  "iso639_3": "tok"',
        '  "name": "Toki Pona"',
        f'  "script": "{SCRIPT}"',
        f'  "scripts": ["{SCRIPT}", "latin"]',
        '  "icon": "Tp"',
        '"license": "CC-BY-SA-4.0"',
        '"tags": ["beginner", "unreviewed", "script"]',
        '"cards":',
    ]
    layer = [
        '"schema": 1',
        f'"id": "{GLYPH_LAYER}"',
        '"kind": "layer"',
        f'"core": "{GLYPH_DECK}"',
        '"native":',
        '  "code": "en"',
        '  "iso639_3": "eng"',
        '  "name": "English"',
        '"name": "Sitelen pona: the glyphs"',
        '"description": ' + _q(
            "The glyph of each Toki Pona word the course teaches, in the order "
            "you meet them: see the glyph, say the word. Sitelen pona writes a "
            "word as one glyph; a name goes in a cartouche. Not yet checked by "
            "a Toki Pona speaker: please report any mistake."),
        '"license": "CC-BY-SA-4.0"',
        '"tags": ["unreviewed", "script"]',
        '"cards":',
    ]
    for word, _card, ipa, native in words:
        glyph = chr(WORDS[word])
        if glyph not in ids:
            top += 1
            ids[glyph] = f"tok-{top:04d}"
        cid = ids[glyph]
        core += [f'- "id": "{cid}"', f'  "target": {_q(glyph)}',
                 '  "target_scripts":', f'    "latin": {_q(word)}',
                 f'  "reading": {_q(word)}']
        if ipa:
            core.append(f'  "ipa": {_q(ipa)}')
        core += ['  "pos": "letter"', '  "modes": ["listening", "speaking"]']
        layer += [f'  "{cid}":', f'    "native": {_q(native)}']
    return "\n".join(core) + "\n", "\n".join(layer) + "\n"


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    flags = {a for a in argv[1:] if a.startswith("--")}
    if len(args) != 1 or not flags <= {"--check", "--words", "--glyph-deck"}:
        print(__doc__)
        return 2
    root = Path(args[0])
    if "--glyph-deck" in flags:
        core, layer = glyph_deck(root)
        (root / f"{GLYPH_DECK}.yaml").write_text(core, encoding="utf-8")
        (root / "en" / f"{GLYPH_LAYER}.yaml").write_text(layer, encoding="utf-8")
        print(f"{core.count(chr(10) + '- ')} cards")
        return 0
    if "--words" in flags:
        for w, n in sorted(words_of(root).items()):
            mark = "name" if w[:1].isupper() else ("" if w in WORDS else "MISSING")
            print(f"{w}\t{n}\t{mark}")
        return 0
    total = 0
    stale = []
    for p in deck_files(root):
        try:
            n = convert_file(p, write="--check" not in flags)
        except UnknownWord as e:
            print(f"{p}: {e}", file=sys.stderr)
            return 1
        total += n
        if n:
            stale.append(p)
    if "--check" in flags:
        for p in stale:
            print(f"{p}: not in sitelen pona yet", file=sys.stderr)
        return 1 if stale else 0
    print(f"{total} spellings added to {len(stale)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
