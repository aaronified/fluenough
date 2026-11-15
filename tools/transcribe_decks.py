#!/usr/bin/env python3
"""Check, and optionally fix, the stored `reading` and `ipa` of a language's
core decks against `tools/transcribe.py` (issue #1295).

Usage:
    python3 tools/transcribe_decks.py --check decks/te te
    python3 tools/transcribe_decks.py --fix decks/te te         # anusvara only
    python3 tools/transcribe_decks.py --fix --all decks/te te   # every difference
    python3 tools/transcribe_decks.py --check --propagate decks/te te
    python3 tools/transcribe_decks.py --fix --propagate decks/te te
    python3 tools/transcribe_decks.py --check --layer-anusvara decks/te te

For each core deck file directly in the directory (the English layers in
`en/` are not read), every card, every card example and every
`{ word: ..., reading: ... }` entry (a card's bases and its notes' words) is
re-transcribed from its target text with the same logic as the single-word
mode: the stored reading is the typed hint, exactly as
`python3 tools/transcribe.py te "<target>" "<reading>"` would take it. A
stored value that differs from the recomputed one is printed with its id, the
field, the stored value and the recomputed value.

A difference is listed under "anusvara differences" when the target holds an
anusvara and the two values are the same once every nasal is treated as one
sound (the written nasal before a stop, ISO `ṁ`, IPA `ŋ ɲ ɳ n m`): that is
the medial-anusvara rule ("Telugu medial anusvara" in
wiki/Plan-Ipa-Revamp-And-Language-Phonology.md). Every other difference (ph
for f, ṛ for ru, ...) is listed under "other differences".

Keys may be bare or double-quoted (`target:` or `"target":`), also mixed in
one file, and every value must be a plain double-quoted string. In a block
entry the order of keys is id, target, reading, ipa: a `reading` or `ipa`
before its `target`, a single-quoted or unquoted value, a repeated key, or a
card id repeated in the file are reported under "not checked or not
changeable" and never changed. A file whose `part` is not `core`, or that has
no `part` key, is not read and is listed as skipped.

`--fix` rewrites only the differing values, and only the anusvara ones unless
`--all` is given. It never re-dumps the YAML: it replaces the stored value at
its exact place on its line, so comments, quoting, line endings and ordering
stay byte for byte. After it, the scan runs once more and the differences
left are printed. `--all` leaves alone any entry whose text holds no letter
of the deck's script (an IPA letter card, say) and any word that starts with
a hyphen (a suffix); they are listed under "skipped (not the deck's script /
suffix)".

A value that differs in more than its nasals (roḍḍu for rōḍḍu next to a
wrong anusvara) is still fixed for its nasals under plain `--fix`: the stored
value is kept character for character except its nasals, which take the
recomputed ones (listed as "nasals only"). A stored ṇḍ whose target has ంద
(ఉందా) becomes the dental nd. The other differences stay untouched.

`--propagate` carries the corrections to the places `--fix` does not read:
paradigm `readings: { ... }` maps, prose in the English layer (`en/`), and
files with no `part` key (`te-en-reading-*.yaml`, ...). It builds old -> new
from the readings the run changes (word by word, a word being a run of
letters, so `-` and punctuation bound it) and replaces each old word, whole,
inside quoted values of every `.yaml` in the directory and in `en/`. Never
rewritten: keys, values under `ipa`, `ipas`, `phonetic`, `id`, `ref` and the
like, and anything inside a Telugu-script run. An old word that is also a
correct reading of some card, that becomes two different words, or that is an
ASCII word of three letters or fewer is ambiguous: reported, and left
unchanged. Words of three letters or fewer are never rewritten (c, th, ... are
English and IPA), nor strings holding IPA letters, nor anything after an
unquoted `#`. `--propagate` is refused with `--all` (exit 2): it is for plain
`--fix`, which writes anusvara corrections only. Its occurrence count includes
the core values `--fix` itself writes. The homograph test knows only the
readings of core files with a `part` key; a reading kept only in a paradigm map
or a file with no `part` key is not weighed. The paradigm maps are not
re-derived: a cell of a map is rewritten only when it equals an old word, so a
map can end half-fixed (`cempalu` next to `ceṁpalō`); #1295 stays open for a
pass over them. `--check --propagate` lists the ambiguous words and the
occurrences per file; words found only in prose, not in a core reading, are
not propagated.

`--citations` is a separate pass (#1295) for the one place the other modes do
not read: the `reading` of an inline base, `{ word, base, reading }`, which is
the reading of the base's dictionary form (the card's `base`, not its `word`).
Only a word-final anusvara is checked: a stored final `m` where the rules write
`ṁ` for the base (andam -> andaṁ, uṇḍaḍam -> uṇḍaḍaṁ) is rewritten in place;
no other part of such a reading, and no other entry, is read or changed. It
works in the block and the flow form, and not with `--all` or `--propagate`
(exit 2):
    python3 tools/transcribe_decks.py --check --citations decks/te te
    python3 tools/transcribe_decks.py --fix --citations decks/te te

`--layer-anusvara` is a pass of its own (#1295) over the English layers
(`en/*.yaml`) only: the Telugu words that prose repeats with their reading in
parentheses, `అందం (andam)`, `చేయడం (cēyaḍam, to do)`. A Telugu-script word
(or, when the reading holds several words, as many Telugu words as the reading
has, as in `ఒకే పుస్తకం (oke pustakam)`) directly followed by ` (reading)` or
` (reading, gloss)`, inside a quoted value, has its reading's final `m` rewritten
to `ṁ` when `transcribe(words, lang)` equals the stored reading with exactly
that change. Nothing else is read or changed: no other reading, no gloss, no
key, no `ipa`, no id; a word whose computed reading differs in any other way is
left alone. Not with `--all`, `--propagate` or `--citations` (exit 2):
    python3 tools/transcribe_decks.py --check --layer-anusvara decks/te te
    python3 tools/transcribe_decks.py --fix --layer-anusvara decks/te te

Exit codes: `--check` 0 when every entry matches, 1 when any value differs,
any entry could not be checked, or (with `--propagate`) any occurrence or
ambiguous word is left; `--fix` 0, or 1 when it refused to change a value; 2
for a bad directory or arguments. Card ids are never touched.

Standard library only, like the other deck tools.
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

from transcribe import transcribe

_Q = r'"?'
_ID = re.compile(r'^\s*- "?id"?: "([^"]+)"\s*(?:#.*)?$')
_HEAD = re.compile(r'^(\s*)(- )?"?(target|word)"?: "([^"\\]*)"\s*(?:#.*)?$')
_HEAD_LOOSE = re.compile(r'^(\s*)(?:- )?"?(target|word)"?:')
_FIELD = re.compile(r'^(\s*)(?:- )?"?(reading|ipa|base)"?: "([^"\\]*)"\s*'
                    r'(?:#.*)?$')
_FIELD_LOOSE = re.compile(r'^\s*(?:- )?"?(reading|ipa|base)"?:')
_PART = re.compile(r'^"?part"?:\s*"?([A-Za-z-]*)"?\s*$', re.M)
_SCRIPT = re.compile(r'^\s*"?script"?:\s*"([a-z]+)"', re.M)
_IN_FLOW_KEY = re.compile(r'"?(target|word|reading|ipa|base)"?: "([^"\\]*)"')

# A nasal as one token. In the stored value ṇḍ (IPA ɳɖ) is one token too, so
# that ఉందా (stored uṇḍā, right undā) is a nasal difference and not a
# difference in ḍ: see _nasal_only.
_NASAL_ISO = re.compile("[ṁṃṅñṇnm]")
_NASAL_IPA = re.compile("n̪|[ŋɲɳnm]")
_RETROFLEX = {"ISO": ("ṇḍ", "ṇ", "ḍ", "d"), "IPA": ("ɳɖ", "ɳ", "ɖ", "d̪")}


@dataclass
class Difference:
    file: Path
    entry: str          # the card id, its example, or its word entry
    field: str
    stored: str
    computed: str
    line: int           # 0-based line holding the stored value
    start: int          # column span of the stored value on that line
    end: int
    anusvara: bool
    unsafe: bool = False  # not the deck's script, or a suffix: not for --all
    partial: bool = False  # only the nasals of a value that differs more


@dataclass
class Report:
    differences: list[Difference] = field(default_factory=list)
    unreadable: list[str] = field(default_factory=list)
    files: int = 0
    entries: int = 0
    skipped: list[str] = field(default_factory=list)
    # every reading checked: (file, line, start, stored, computed)
    readings: list[tuple] = field(default_factory=list)


_NASAL_LETTERS = {"NA", "MA", "NNA", "NYA", "NGA"}


def _nasal_sources(target: str) -> list[bool]:
    """For each nasal of [target] in order, whether it is an anusvara (or
    candrabindu) and not a nasal consonant."""
    out = []
    for c in target:
        name = unicodedata.name(c, "")
        if "ANUSVARA" in name or "CANDRABINDU" in name:
            out.append(True)
        elif name.split(" ")[-1:] and name.split(" ")[-1] in _NASAL_LETTERS \
                and "LETTER" in name:
            out.append(False)
    return out


def _nasal_only(field_name: str, stored: str, computed: str,
                target: str) -> str | None:
    """[stored] with only its nasals replaced by [computed]'s, in order, or
    None unless the target's nasals line up one to one with the right
    reading's, every nasal that changes is an anusvara of the target, and the
    letter after it is the same in both (so no half-fixed cluster, ɳd). A
    stored retroflex pair (ṇḍ) is one nasal: it stays when the right reading
    has ṇḍ, and becomes nd when the right reading has the dental n and d and
    the target has ంద."""
    ipa = field_name == "ipa"
    rx = _NASAL_IPA if ipa else _NASAL_ISO
    pair, nas, stop, dental = _RETROFLEX["IPA" if ipa else "ISO"]
    sources = _nasal_sources(target)
    old = list(re.finditer(re.escape(pair) + "|" + rx.pattern, stored))
    new = list(rx.finditer(computed))
    if len(old) != len(new) or len(sources) != len(new):
        return None
    changed, out, last = 0, [], 0
    for m, n, is_anusvara in zip(old, new, sources):
        rest = computed[n.end():]
        if m.group() == pair:
            if n.group() == nas and rest.startswith(stop):
                repl = pair
            elif (n.group() == "n" and rest.startswith(dental)
                  and is_anusvara and "\u0c02\u0c26" in target):
                repl = "n" + dental
            else:
                return None
        else:
            repl = n.group()
        if repl != m.group():
            if not is_anusvara:
                return None
            if m.group() != pair and (stored[m.end():m.end() + 1]
                                      != computed[n.end():n.end() + 1]):
                return None  # the letter after it would change too
            changed += 1
        out += [stored[last:m.start()], repl]
        last = m.end()
    if changed == 0:
        return None
    out.append(stored[last:])
    return "".join(out)


def _unsafe(text: str, script: str | None) -> bool:
    """A suffix, or text without a letter of the deck's script."""
    if text.startswith("-"):
        return True
    if script is None:
        return False
    return not any(c.isalpha() and unicodedata.name(c, "").startswith(
        script.upper()) for c in text)


def _block_fields(lines: list[str], i: int, indent: int,
                  claimed: set[int]) -> dict:
    """The `reading`, `ipa` and `base` lines of the block entry whose head is
    on line [i] with its keys at [indent]: name -> (line, match) or
    (reason, None) when repeated or not a plain double-quoted string."""
    fields: dict[str, tuple] = {}
    count: dict[str, int] = {}
    for j in range(i + 1, len(lines)):
        nxt = lines[j]
        if nxt.strip() == "" or nxt.lstrip().startswith("#"):
            continue
        ind = len(nxt) - len(nxt.lstrip())
        if ind < indent:
            break
        if ind != indent:
            continue  # nested lines (a card's examples) are other entries
        if nxt.lstrip().startswith("- ") or _HEAD_LOOSE.match(nxt):
            break
        loose = _FIELD_LOOSE.match(nxt)
        if not loose:
            continue
        name = loose.group(1)
        count[name] = count.get(name, 0) + 1
        claimed.add(j)
        fm = _FIELD.match(nxt)
        fields[name] = ((j, fm) if fm else
                        ("not a plain double-quoted value", None))
    for name, n in count.items():
        if n > 1:
            fields[name] = (f"{name} given more than once", None)
    return fields


def _flow_spans(line: str):
    """Each `{ ... }` of [line] as (start, text) with its nested braces and
    brackets blanked, so a key found in it belongs to that mapping alone."""
    stack: list[int] = []
    out = []
    for k, c in enumerate(line):
        if c == "{":
            stack.append(k)
        elif c == "}" and stack:
            out.append((stack.pop(), k))
    for a, b in out:
        text = list(line[a:b + 1])
        for a2, b2 in out:
            if a < a2 and b2 < b:
                text[a2 - a:b2 - a + 1] = " " * (b2 - a2 + 1)
        yield a, "".join(text)


class _Scan:
    def __init__(self, path: Path, lang: str, report: Report, script,
                 citations: bool = False):
        self.path, self.lang, self.report, self.script = (
            path, lang, report, script)
        self.citations = citations

    def citation(self, name: str, text: str, fields: dict) -> None:
        """Citations mode: the `reading` of an inline base (a `word` entry
        whose `base` is another text) is the base's dictionary form. Only its
        word-final anusvara is checked: a stored final `m` where the rules
        write `ṁ` (andam for andaṁ). Nothing else of it is touched."""
        base, reading = fields.get("base"), fields.get("reading")
        if not base or base[1] is None or base[3] == text:
            return
        if not reading or reading[1] is None:
            return
        self.report.entries += 1
        line, start, end, stored = reading
        try:
            computed = transcribe(base[3], self.lang, stored).reading
        except Exception as e:
            self.report.unreadable.append(
                f"{self.path.name} {name}: base {base[3]}: {e!r}")
            return
        if (computed.endswith("ṁ") and stored.endswith("m")
                and stored[:-1] == computed[:-1]):
            self.report.differences.append(Difference(
                self.path, name, "reading", stored, computed, line, start,
                end, True, _unsafe(base[3], self.script)))

    def entry(self, name: str, head: str, text: str, fields: dict) -> None:
        """[fields] maps reading/ipa/base to (line, start, end, value) or
        (reason, None). A `word` entry is checked for its reading only."""
        report = self.report
        if self.citations:
            if head == "word":
                self.citation(name, text, fields)
            return
        report.entries += 1
        if head == "word":
            fields.pop("ipa", None)
            base = fields.get("base")
            if base and base[1] is not None and base[3] != text:
                return  # the reading may be the base's, not the word's
        reading = fields.get("reading", (None, None))
        hint = reading[3] if reading[1] is not None else None
        try:
            t = transcribe(text, self.lang, hint)
        except Exception as e:  # CannotRead, or a rule's own error
            report.unreadable.append(f"{self.path.name} {name}: {e!r}")
            return
        computed = {"reading": t.reading, "ipa": t.ipa}
        for key in ("reading", "ipa"):
            if key not in fields:
                continue
            f = fields[key]
            if f[1] is None:
                report.unreadable.append(
                    f"{self.path.name} {name}: {key}: {f[0]}")
                continue
            line, start, end, stored = f
            if key == "reading":
                report.readings.append(
                    (self.path, line, start, stored, computed[key]))
            if stored == computed[key]:
                continue
            unsafe = _unsafe(text, self.script)
            cand = _nasal_only(key, stored, computed[key], text)
            full = cand == computed[key]
            report.differences.append(Difference(
                self.path, name, key, stored, computed[key], line, start,
                end, full, unsafe))
            if cand is not None and not full:
                report.differences.append(Difference(
                    self.path, name, key, stored, cand, line, start, end,
                    True, unsafe, True))


def scan(path: Path, lang: str, report: Report,
         citations: bool = False) -> None:
    """Walk one deck file's lines, filling [report]."""
    raw = path.read_bytes().decode("utf-8")
    lines = raw.split("\n")
    sm = _SCRIPT.search(raw)
    sc = _Scan(path, lang, report, sm.group(1) if sm else None, citations)
    ids: dict[str, int] = {}
    for ln in lines:
        m = _ID.match(ln)
        if m:
            ids[m.group(1)] = ids.get(m.group(1), 0) + 1
    card = "?"
    claimed: set[int] = set()
    flow_lines: set[int] = set()
    for i, ln in enumerate(lines):
        m = _ID.match(ln)
        if m and not re.fullmatch(r"n\d+", m.group(1)):
            card = m.group(1)
        m = _HEAD.match(ln)
        if m:
            head, text = m.group(3), m.group(4)
            claimed.add(i)
            is_item = m.group(2) is not None
            indent = len(m.group(1)) + (2 if is_item else 0)
            raw_f = _block_fields(lines, i, indent, claimed)
            fields = {}
            for k, v in raw_f.items():
                if v[1] is None:
                    fields[k] = v
                else:
                    g = v[1]
                    fields[k] = (v[0], g.start(3), g.end(3), g.group(3))
            if head == "target" and not is_item and ids.get(card, 0) > 1:
                fields = {k: (f"card id {card} repeated in the file", None)
                          for k in fields}
            name = (f"{card}/example@{i + 1}" if head == "target" and is_item
                    else card if head == "target" else
                    f"{card}/word:{text}")
            sc.entry(name, head, text, fields)
        elif _HEAD_LOOSE.match(ln) and not ln.lstrip().startswith("#"):
            km = _HEAD_LOOSE.match(ln)
            if km.group(2) == "target" and "{" not in ln:
                report.unreadable.append(
                    f"{path.name} {card}: target on line {i + 1} is not a "
                    "plain double-quoted value")
        for a, text in _flow_spans(ln):
            flow_lines.add(i)
            found: dict[str, list] = {}
            for fm in _IN_FLOW_KEY.finditer(text):
                found.setdefault(fm.group(1), []).append(fm)
            head = next((h for h in ("target", "word") if h in found), None)
            if head is None or len(found[head]) > 1:
                continue
            fields = {}
            for k in ("reading", "ipa", "base"):
                if k in found:
                    if len(found[k]) > 1:
                        fields[k] = (f"{k} given more than once", None)
                    else:
                        g = found[k][0]
                        fields[k] = (i, a + g.start(2), a + g.end(2),
                                     g.group(2))
            text_v = found[head][0].group(2)
            sc.entry(f"{card}/{head}:{text_v}", head, text_v, fields)
    for i, ln in enumerate(lines):
        loose = _FIELD_LOOSE.match(ln)
        if i in claimed or i in flow_lines or not loose:
            continue
        if loose.group(1) == "base" or not _target_follows(lines, i):
            continue  # other shapes (grammar tables) are not cards
        report.unreadable.append(
            f"{path.name}: line {i + 1} has a reading or ipa before its "
            "target (key order is id, target, reading, ipa)")


def _target_follows(lines: list[str], i: int) -> bool:
    """Whether a target or word key of the same mapping comes after line i."""
    ind = len(lines[i]) - len(lines[i].lstrip())
    for nxt in lines[i + 1:]:
        if nxt.strip() == "" or nxt.lstrip().startswith("#"):
            continue
        n = len(nxt) - len(nxt.lstrip())
        if n < ind or (n == ind and nxt.lstrip().startswith("- ")):
            return False
        if n == ind and _HEAD_LOOSE.match(nxt):
            return True
    return False


def deck_files(directory: Path, report: Report | None = None) -> list[Path]:
    """The core deck files directly in [directory] (not its `en/` layers).
    Every other `.yaml` there is listed in [report].skipped."""
    out = []
    for p in sorted(directory.glob("*.yaml")):
        m = _PART.search(p.read_bytes().decode("utf-8"))
        if m and m.group(1) == "core":
            out.append(p)
        elif report is not None:
            report.skipped.append(
                f"{p.name} (part {m.group(1)!r})" if m
                else f"{p.name} (no part key)")
    return out


def run(directory: Path, lang: str, citations: bool = False) -> Report:
    report = Report()
    for p in deck_files(directory, report):
        report.files += 1
        scan(p, lang, report, citations)
    return report


def selected(report: Report, include_other: bool) -> list[Difference]:
    """The differences a fix would write: the anusvara ones, and with
    [include_other] the others too except the unsafe ones. A partial
    difference gives way to the full one for the same value."""
    full = {(d.file, d.line, d.start) for d in report.differences
            if include_other and not d.anusvara and not d.unsafe}
    out = []
    for d in report.differences:
        if d.anusvara:
            if d.partial and (d.file, d.line, d.start) in full:
                continue
            out.append(d)
        elif include_other and not d.unsafe:
            out.append(d)
    return out


def apply_fixes(report: Report, include_other: bool) -> tuple[int, list[str]]:
    """Patch the differing values in place. Returns (changed, refusals)."""
    changed = 0
    refused: list[str] = []
    by_file: dict[Path, list[Difference]] = {}
    for d in selected(report, include_other):
        by_file.setdefault(d.file, []).append(d)
    for path, diffs in by_file.items():
        lines = path.read_bytes().decode("utf-8").split("\n")
        for d in sorted(diffs, key=lambda d: (d.line, -d.start)):
            if lines[d.line][d.start:d.end] != d.stored:
                refused.append(f"{path.name} {d.entry} {d.field}: stored "
                               "value not found where it was read")
                continue
            lines[d.line] = (lines[d.line][:d.start] + d.computed
                             + lines[d.line][d.end:])
            changed += 1
        path.write_bytes("\n".join(lines).encode("utf-8"))
    return changed, refused


# --- propagation: the old readings elsewhere in the decks -------------------

_TOKEN = re.compile(r"(?:[^\W\d_]|[\u0300-\u036f])+")
_STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"')
_KEY_BEFORE = re.compile(r'"?([A-Za-z_][A-Za-z0-9_]*)"?\s*:\s')
# Values under these keys are not readings: never rewritten.
_NOT_READING = {"ipa", "ipas", "phonetic", "phonetic_source", "id", "ref",
                "key", "code", "core", "iso639_3", "tts", "icon", "tags",
                "license", "schema", "kind", "part", "theme", "slug"}


def _nfc(t: str) -> str:
    return unicodedata.normalize("NFC", t)


def _is_latin(token: str) -> bool:
    return all(unicodedata.name(c, "").startswith(("LATIN", "COMBINING"))
               for c in token)


def _eligible(old: str, new: str) -> bool:
    """Whether the word [old] may be rewritten anywhere: not three letters or
    fewer (c, d, th, ...: English prose and IPA hold them), and neither word
    plain ASCII of fewer than four letters."""
    def plain(w: str) -> bool:
        return w.isascii() and w.isalpha()
    return (len(old) > 3 and not (plain(old) and len(old) < 4)
            and not (plain(new) and len(new) < 4))


def token_map(report: Report, include_other: bool):
    """(old -> new, ambiguous) from the readings a fix would change: every
    word of the stored reading that differs from the word at the same place
    in the new one. A word is ambiguous, and never replaced, when it is also
    a correct reading of some card, or becomes two different words, or is too
    short to replace safely (see _eligible)."""
    chosen = {(d.file, d.line, d.start): d.computed
              for d in selected(report, include_other)
              if d.field == "reading"}
    pairs: dict[str, set[str]] = {}
    correct: set[str] = set()
    for path, line, start, stored, computed in report.readings:
        new = chosen.get((path, line, start))
        correct.update(_nfc(t) for t in _TOKEN.findall(computed))
        if new is None:
            correct.update(_nfc(t) for t in _TOKEN.findall(stored))
            continue
        a, b = _TOKEN.findall(stored), _TOKEN.findall(new)
        if len(a) != len(b):
            continue
        for x, y in zip(a, b):
            if x != y and _is_latin(x):
                pairs.setdefault(_nfc(x), set()).add(_nfc(y))
    mapping: dict[str, str] = {}
    ambiguous: dict[str, str] = {}
    for old, news in sorted(pairs.items()):
        if not all(_eligible(old, n) for n in news):
            ambiguous[old] = "too short to replace safely"
        elif old in correct:
            ambiguous[old] = "also a correct reading of another card"
        elif len(news) > 1:
            ambiguous[old] = "becomes " + " or ".join(sorted(news))
        else:
            mapping[old] = next(iter(news))
    return mapping, ambiguous


def layer_files(directory: Path) -> list[Path]:
    """Every `.yaml` in [directory] and in its `en/` layer."""
    out = sorted(directory.glob("*.yaml"))
    en = directory / "en"
    if en.is_dir():
        out += sorted(en.glob("*.yaml"))
    return out


def _has_ipa(text: str) -> bool:
    return any(0x250 <= ord(c) <= 0x2FF or c == "ŋ" for c in text)


def _comment_start(line: str, spans: list[re.Match]) -> int:
    """Where an unquoted `#` starts a comment, or the line's length."""
    for i, c in enumerate(line):
        if c == "#" and not any(m.start() < i < m.end() for m in spans):
            return i
    return len(line)


def _rewrite_line(line: str, mapping: dict[str, str], ambiguous: dict,
                  found: list[tuple[str, str]], skipped: set[str]) -> str:
    spans = list(_STRING.finditer(line))
    cutoff = _comment_start(line, spans)
    out, last = [], 0
    for m in spans:
        if m.end() > cutoff:
            break
        if line[m.end():].lstrip().startswith(":"):
            continue  # a key
        if _has_ipa(m.group()):
            continue  # IPA data, or prose holding IPA: left alone
        keys = list(_KEY_BEFORE.finditer(line[:m.start()]))
        if keys and keys[-1].group(1) in _NOT_READING:
            continue

        def sub(t: re.Match) -> str:
            tok = _nfc(t.group())
            if tok in ambiguous:
                skipped.add(tok)
                return t.group()
            new = mapping.get(tok)
            if new is None or not _eligible(tok, new):
                return t.group()
            found.append((tok, new))
            return new

        out += [line[last:m.start()], _TOKEN.sub(sub, m.group())]
        last = m.end()
    out.append(line[last:])
    return "".join(out)


def propagate(directory: Path, mapping: dict[str, str], ambiguous: dict,
              write: bool) -> tuple[dict[Path, int], set[str]]:
    """Replace every old reading of [mapping], as a whole word inside a
    quoted value, in each deck file and English layer of [directory]. Returns
    the replacements per file and the ambiguous words met."""
    per_file: dict[Path, int] = {}
    skipped: set[str] = set()
    for path in layer_files(directory):
        lines = path.read_bytes().decode("utf-8").split("\n")
        found: list[tuple[str, str]] = []
        new_lines = [_rewrite_line(ln, mapping, ambiguous, found, skipped)
                     for ln in lines]
        if found:
            per_file[path] = len(found)
            if write:
                path.write_bytes("\n".join(new_lines).encode("utf-8"))
    return per_file, skipped


# --- layer prose: Telugu words repeated with a reading in parentheses ------

_LAYER_SPAN = re.compile(
    r"((?:[\u0c00-\u0c7f]+ )*[\u0c00-\u0c7f]+) \(([^()\n]*)\)")


def layer_anusvara(directory: Path, lang: str, write: bool
                   ) -> list[tuple[Path, int, str, str, str]]:
    """The `<word> (<reading>[, gloss])` readings of the English layers
    whose final `m` the rules write `ṁ`. Returns (file, line number, words,
    stored, new) for each; with [write] the files are patched in place, only
    at the reading's last letter."""
    out: list[tuple[Path, int, str, str, str]] = []
    en = directory / "en"
    for path in sorted(en.glob("*.yaml")) if en.is_dir() else []:
        lines = path.read_bytes().decode("utf-8").split("\n")
        changed = False
        for i, ln in enumerate(lines):
            spans = list(_STRING.finditer(ln))
            cutoff = _comment_start(ln, spans)
            hits: list[int] = []
            for sm in spans:
                if sm.end() > cutoff:
                    break
                if ln[sm.end():].lstrip().startswith(":"):
                    continue  # a key
                keys = list(_KEY_BEFORE.finditer(ln[:sm.start()]))
                if keys and keys[-1].group(1) in _NOT_READING:
                    continue
                for m in _LAYER_SPAN.finditer(sm.group()):
                    stored = m.group(2).split(",")[0]
                    if not stored.endswith("m") or "ṁ" in stored:
                        continue
                    n = len(stored.split())
                    words = m.group(1).split(" ")
                    if n < 1 or len(words) < n:
                        continue
                    text = " ".join(words[-n:])
                    try:
                        computed = transcribe(text, lang).reading
                    except Exception:
                        continue
                    if computed != stored[:-1] + "ṁ":
                        continue
                    pos = sm.start() + m.start(2) + len(stored) - 1
                    hits.append(pos)
                    out.append((path, i + 1, text, stored, computed))
            for pos in sorted(hits, reverse=True):
                ln = ln[:pos] + "ṁ" + ln[pos + 1:]
                changed = True
            lines[i] = ln
        if write and changed:
            path.write_bytes("\n".join(lines).encode("utf-8"))
    return out


def _print_layer(rows, verb: str) -> int:
    for path, n, text, stored, new in rows:
        print(f"  {path.name}:{n} {text} ({stored}) -> ({new})")
    print(f"layer prose: {verb} {len(rows)} readings in "
          f"{len({r[0] for r in rows})} files")
    return len(rows)


def _print_propagation(mapping, ambiguous, per_file, skipped, verb) -> None:
    print(f"propagation: {len(mapping)} old readings to replace "
          f"elsewhere, {len(ambiguous)} ambiguous")
    for tok, why in sorted(ambiguous.items()):
        met = " (met, left unchanged)" if tok in skipped else ""
        print(f"  ambiguous {tok!r}: {why}{met}")
    for path, n in sorted(per_file.items()):
        print(f"  {verb} {n} in {path.parent.name}/{path.name}")
    print(f"propagation {verb} {sum(per_file.values())} occurrences in "
          f"{len(per_file)} files")


def _print(report: Report) -> None:
    diffs = [d for d in report.differences]
    groups = (
        ("anusvara differences",
         [d for d in diffs if d.anusvara]),
        ("other differences",
         [d for d in diffs if not d.anusvara and not d.unsafe]),
        ("skipped (not the deck's script / suffix)",
         [d for d in diffs if not d.anusvara and d.unsafe]),
    )
    for title, rows in groups:
        print(f"{title}: {len(rows)}")
        for d in rows:
            note = " (nasals only)" if d.partial else ""
            print(f"  {d.file.name} {d.entry} {d.field}{note}: "
                  f"stored {d.stored!r} -> computed {d.computed!r}")
    if report.unreadable:
        print(f"not checked or not changeable: {len(report.unreadable)}")
        for u in report.unreadable:
            print(f"  {u}")
    for s in report.skipped:
        print(f"skipped file: {s}")
    print(f"total differences: {len([d for d in diffs if not d.partial])}")
    print(f"checked {report.files} files, {report.entries} entries, "
          f"skipped {len(report.skipped)} files")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--fix", action="store_true")
    ap.add_argument("--all", action="store_true",
                    help="with --fix, also fix the other differences")
    ap.add_argument("--propagate", action="store_true",
                    help="also replace the old readings elsewhere (other "
                    "value kinds, English layers, files without a part)")
    ap.add_argument("--citations", action="store_true",
                    help="check or fix only the word-final anusvara of the "
                    "reading of inline bases (the base's citation form)")
    ap.add_argument("--layer-anusvara", action="store_true",
                    help="check or fix only the word-final anusvara of the "
                    "readings in parentheses after a Telugu word in the "
                    "English layers")
    ap.add_argument("directory", type=Path)
    ap.add_argument("lang")
    args = ap.parse_args(argv[1:])
    if not args.directory.is_dir():
        print(f"not a directory: {args.directory}", file=sys.stderr)
        return 2
    if args.propagate and args.all:
        print("--propagate is for plain --fix only: with --all the map "
              "holds short words that English prose and IPA data share",
              file=sys.stderr)
        return 2
    if args.citations and (args.all or args.propagate):
        print("--citations is a pass of its own: not with --all or "
              "--propagate", file=sys.stderr)
        return 2
    if args.layer_anusvara:
        if args.all or args.propagate or args.citations:
            print("--layer-anusvara is a pass of its own: not with --all, "
                  "--propagate or --citations", file=sys.stderr)
            return 2
        rows = layer_anusvara(args.directory, args.lang, args.fix)
        _print_layer(rows, "replaced" if args.fix else "would replace")
        return 1 if (args.check and rows) else 0
    report = run(args.directory, args.lang, args.citations)
    _print(report)
    mapping, ambiguous = token_map(report, args.all)
    if args.check:
        pending = ambiguous_n = 0
        if args.propagate:
            per_file, skipped = propagate(args.directory, mapping,
                                          ambiguous, False)
            _print_propagation(mapping, ambiguous, per_file, skipped,
                               "would replace")
            pending, ambiguous_n = sum(per_file.values()), len(ambiguous)
        return 1 if (report.differences or report.unreadable or pending
                     or ambiguous_n) else 0
    changed, refused = apply_fixes(report, args.all)
    print(f"changed {changed} value(s)")
    for r in refused:
        print(f"  refused: {r}")
    if args.propagate:
        per_file, skipped = propagate(args.directory, mapping, ambiguous,
                                      True)
        _print_propagation(mapping, ambiguous, per_file, skipped,
                           "replaced")
    after = run(args.directory, args.lang, args.citations)
    print(f"differences left after the fix: "
          f"{len([d for d in after.differences if not d.partial])}")
    return 1 if refused else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
