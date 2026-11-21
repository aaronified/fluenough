"""What `tools/import_phonetic.py` and `tools/derive_phonetic.py` share: how a
narrow transcription is checked, how it is written into a deck file, and how
coverage is counted and reported.

A card's `phonetic` is written by PATCHING the file's text (AGENTS.md rule 8):
two lines go in after the card's `ipa:` line and nothing else is touched, not
the card ids, not the quoting, not the order. The file is never read and
written back through a YAML library.

Stdlib and PyYAML only, like the other tools.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks as vd  # noqa: E402

SOURCES = vd.PHONETIC_SOURCES  # ("wiktionary", "rules")


def normalise(form: str) -> str | None:
    """A narrow form as the decks write it, or None when it is not one.

    Wiktionary's `[ˈkʰæt]` and the rules' `[ˈkʰæt]` both come in with their
    square brackets. What is returned is NFC, in brackets, with Latin g
    written as the IPA's ɡ and syllable dots dropped (the decks' `ipa` has no
    dots, and the narrow form should read like it). Anything but IPA letters
    and marks between the brackets gives None: the same test the validator
    makes (`check_phonetic`).
    """
    form = unicodedata.normalize("NFC", form.strip())
    if len(form) < 3 or form[0] != "[" or form[-1] != "]":
        return None
    inner = form[1:-1].replace(".", "").replace("g", "ɡ").strip()
    if not inner or not vd.IPA_RE.fullmatch(inner):
        return None
    return f"[{inner}]"


def quote(text: str) -> str:
    """A YAML double-quoted scalar. A narrow form holds no quote or backslash
    (IPA_RE refuses both), so this is the text between two quotes."""
    return json.dumps(text, ensure_ascii=False)


# --- Patching a file --------------------------------------------------------

@dataclass(frozen=True)
class _Block:
    start: int
    end: int
    indent: int       # indent of the card's own keys
    quoted: bool      # keys are written `"ipa":` rather than `ipa:`
    json: bool        # JSON-style layout: every value line ends in a comma


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _opens_card_list(lines: list[str], brace: int) -> bool:
    """Whether the `{` at [brace] is an element of the card list: the nearest
    earlier line that is less indented opens `"cards": [` (or is a bare `[`)."""
    here = _indent(lines[brace])
    for k in range(brace - 1, -1, -1):
        ln = lines[k].rstrip("\r")
        if ln.strip() and _indent(ln) < here:
            return ln.strip() in ('"cards": [', "[")
    return False


def _card_block(lines: list[str], cid: str) -> _Block | None:
    """Where card [cid] sits in the file, in one of the layouts the decks use:

    - block YAML, `  - id: "x"` at two spaces (keys at four);
    - the same list at column 0, `- id: "x"` (keys at two);
    - machine-serialised quoted keys, `- "id": "x"` at column 0 (keys at
      two) or `  - "id": "x"` at two spaces (keys at four);
    - JSON-style, a `{` line and then `"id": "x",` (keys at the `{` plus two).
    """
    c = re.escape(cid)
    heads = [
        (re.compile(rf'^  - id: "?{c}"?\s*$'), 4, False),
        (re.compile(rf'^  - "id": "{c}"\s*$'), 4, True),
        (re.compile(rf'^- id: "?{c}"?\s*$'), 2, False),
        (re.compile(rf'^- "id": "{c}"\s*$'), 2, True),
    ]
    json_head = re.compile(rf'^( +)"id": "{c}",\s*$')
    for i, raw in enumerate(lines):
        line = raw.rstrip("\r")
        found: tuple[int, bool, bool] | None = None
        for rx, indent, quoted in heads:
            if rx.match(line):
                found = (indent, quoted, False)
                break
        if found is None:
            m = json_head.match(line)
            # A card's id is the first line after its own `{`, and that `{`
            # sits directly in the card list. A note's or an example's `{`
            # sits in another list (`"notes": [`), so its id is never a card's.
            if m and i > 0 and lines[i - 1].rstrip("\r").strip() in ("{", "- {") \
                    and _indent(lines[i - 1]) == len(m.group(1)) - 2 \
                    and _opens_card_list(lines, i - 1):
                found = (len(m.group(1)), True, True)
        if found is None:
            continue
        indent, quoted, is_json = found
        # The block runs to the first line shallower than the card's keys
        # (the card's `}` for JSON, the next `- ` or a top-level key for the
        # column-0 layouts), blank lines excepted.
        floor = indent if is_json else indent - 1
        j = i + 1
        while j < len(lines) and (not lines[j].strip() or _indent(lines[j]) >= floor):
            j += 1
        while j > i + 1 and not lines[j - 1].strip():
            j -= 1
        return _Block(i, j, indent, quoted, is_json)
    return None


# --- One-line flow cards ------------------------------------------------------
# Some decks (nine Chinese files) write each card on one line:
#   - {"id": "zh-0644", "target": "公司", "reading": "gōngsī", ..., "examples": [...]}
# A key is added to such a card by splicing text into its line, after the value
# of a named top-level key; the rest of the line is untouched. Nested lists and
# mappings (`words`, `notes`, `examples`) are skipped, so a nested `reading` or
# `ipa` is never mistaken for the card's own.

def _flow_string_end(line: str, i: int) -> int:
    """Index just past the double-quoted string that starts at [i]."""
    j = i + 1
    while j < len(line):
        if line[j] == "\\":
            j += 2
            continue
        if line[j] == '"':
            return j + 1
        j += 1
    raise ValueError("unterminated string")


def _flow_value_end(line: str, i: int) -> int:
    """Index just past the flow value that starts at [i]: a string, a nested
    `{...}` or `[...]`, or a bare scalar."""
    if line[i] == '"':
        return _flow_string_end(line, i)
    if line[i] in "{[":
        depth = 0
        while i < len(line):
            c = line[i]
            if c == '"':
                i = _flow_string_end(line, i)
                continue
            if c in "{[":
                depth += 1
            elif c in "}]":
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
        raise ValueError("unterminated value")
    while i < len(line) and line[i] not in ",}":
        i += 1
    return i


def _flow_keys(line: str) -> dict[str, tuple[int, int, int]]:
    """The top-level keys of the card on [line] (a `- {` line) to (start of
    the key, start of its value, end of its value) as string indexes."""
    i = line.index("{")
    n = len(line)
    keys: dict[str, tuple[int, int, int]] = {}
    i += 1
    while i < n:
        while i < n and line[i] in " \t,":
            i += 1
        if i >= n or line[i] == "}":
            break
        if line[i] != '"':
            raise ValueError("not a quoted key")
        kend = _flow_string_end(line, i)
        key = line[i + 1:kend - 1]
        j = kend
        while j < n and line[j] in " \t":
            j += 1
        if j >= n or line[j] != ":":
            raise ValueError("no colon")
        j += 1
        while j < n and line[j] in " \t":
            j += 1
        vend = _flow_value_end(line, j)
        keys[key] = (i, j, vend)
        i = vend
    return keys


def _flow_line(lines: list[str], cid: str) -> int | None:
    """The index of the one-line flow card [cid], or None."""
    c = re.escape(cid)
    rx = re.compile(rf'^\s*- \{{"id": "{c}"[,}}]')
    for i, raw in enumerate(lines):
        if rx.match(raw.rstrip("\r")):
            return i
    return None


def _flow_scalar(line: str, span: tuple[int, int, int]) -> str | None:
    """The text of a double-quoted value at [span], without its quotes."""
    _, vs, ve = span
    v = line[vs:ve]
    return v[1:-1] if len(v) >= 2 and v[0] == '"' and v[-1] == '"' else None


def flow_insert(line: str, after: str, pairs: list[tuple[str, str]]
                ) -> str | None:
    """[line] with `, "key": "value"` for each of [pairs] spliced in after the
    value of the top-level key [after]; None when the key is not there or the
    line is not a flow card that can be read."""
    try:
        keys = _flow_keys(line)
    except ValueError:
        return None
    if after not in keys:
        return None
    end = keys[after][2]
    add = "".join(f", {quote(k)}: {quote(v)}" for k, v in pairs)
    return line[:end] + add + line[end:]


def _patch_flow(lines: list[str], at: int, form: str, source: str,
                replace_rules: bool, replace_source: str) -> str | None:
    """Add (or, for a `rules` card under [replace_rules], replace) `phonetic`
    and `phonetic_source` on the one-line card at lines[at]. None when done,
    else why not: `"has phonetic"`, `"no ipa line"`, `"unsupported layout"`."""
    raw = lines[at]
    cr = "\r" if raw.endswith("\r") else ""
    line = raw[:-1] if cr else raw
    try:
        keys = _flow_keys(line)
    except ValueError:
        return "unsupported layout"
    if "phonetic" in keys or "phonetic_source" in keys:
        src = _flow_scalar(line, keys["phonetic_source"]) if "phonetic_source" in keys else None
        if replace_rules and "phonetic" in keys and src == replace_source:
            ks, vs, ve = keys["phonetic"]
            new = line[:vs] + quote(form) + line[ve:]
            if source != replace_source and "phonetic_source" in keys:
                # The fill also changes the source: rewrite its value, working
                # from the later one so the indexes stay valid.
                _, svs, sve = _flow_keys(line)["phonetic_source"]
                spans = sorted([(vs, ve, quote(form)), (svs, sve, quote(source))],
                               reverse=True)
                new = line
                for a, b, t in spans:
                    new = new[:a] + t + new[b:]
            lines[at] = new + cr
            return None
        return "has phonetic"
    if "ipa" not in keys:
        return "no ipa line"
    new = flow_insert(line, "ipa", [("phonetic", form), ("phonetic_source", source)])
    if new is None:
        return "unsupported layout"
    lines[at] = new + cr
    return None


def patch(text: str, fills: dict[str, tuple[str, str]],
          replace_rules: bool = False,
          replace_source: str = "rules") -> tuple[str, dict[str, str]]:
    """[text] with `phonetic` and `phonetic_source` added after the `ipa:`
    line of each card in [fills] (card id to the form and its source).

    Returns the new text and, for each card in [fills] left alone, why:
    `"has phonetic"`, `"no ipa line"`, `"not in file"`, `"unsupported
    layout"`. A card that was patched is not in the second result. Every
    other line of the file is exactly as it was.

    The two lines copy the style of the card's own `ipa` line: plain or
    quoted keys (whatever its id line uses), its indent, and a trailing comma
    in a JSON-style file. A JSON-style card whose `ipa` is its
    last key is `"unsupported layout"`: a line cannot go in after it without
    adding a comma to the `ipa` line, and the file is only ever inserted into.

    With [replace_rules], a card whose `phonetic_source` is [replace_source]
    (`rules` unless given) has its `phonetic` value replaced in place, and its
    `phonetic_source` too when the fill's source is another one; any other
    card that has a `phonetic` is still left alone.
    """
    eol = "\r\n" if "\r\n" in text else "\n"
    rs = re.escape(replace_source)
    lines = text.split("\n")
    left: dict[str, str] = {}
    for cid, (form, source) in fills.items():
        block = _card_block(lines, cid)
        if block is None:
            fl = _flow_line(lines, cid)
            if fl is None:
                left[cid] = "not in file"
                continue
            why = _patch_flow(lines, fl, form, source, replace_rules, replace_source)
            if why:
                left[cid] = why
            continue
        start, end = block.start, block.end
        pad = " " * block.indent
        comma = "," if block.json else ""
        # The card's own keys may be quoted or plain whatever its id line is
        # (a plain `- id:` over `"ipa":` lines exists on decks-live), so the
        # style is read from the `ipa` line itself, not from the id line.
        ipa_rx = re.compile(rf'^{pad}("?)ipa\1:')
        at = next((k for k in range(start, end) if ipa_rx.match(lines[k])), None)
        m_ipa = ipa_rx.match(lines[at]) if at is not None else None
        q = m_ipa.group(1) if m_ipa else ('"' if block.quoted else "")
        if any(re.match(rf'^{pad}"?phonetic(?:_source)?"?:', ln) for ln in lines[start:end]):
            at_p = next((k for k in range(start, end)
                         if re.match(rf'^{pad}"?phonetic"?:', lines[k])), None)
            by_rules = any(re.match(
                rf'^{pad}"?phonetic_source"?:\s*(?:"{rs}"|\'{rs}\'|{rs})'
                rf'{comma}\s*(?:#.*)?$', lines[k].rstrip("\r"))
                for k in range(start, end))
            if replace_rules and at_p is not None and by_rules:
                cr = "\r" if lines[at_p].endswith("\r") else ""
                qp = '"' if lines[at_p].lstrip().startswith('"') else ""
                lines[at_p] = f"{pad}{qp}phonetic{qp}: {quote(form)}{comma}{cr}"
                if source != replace_source:
                    at_s = next((k for k in range(start, end) if re.match(
                        rf'^{pad}"?phonetic_source"?:', lines[k])), None)
                    if at_s is not None:
                        crs = "\r" if lines[at_s].endswith("\r") else ""
                        qs = '"' if lines[at_s].lstrip().startswith('"') else ""
                        lines[at_s] = (f"{pad}{qs}phonetic_source{qs}: "
                                       f'"{source}"{comma}{crs}')
            else:
                left[cid] = "has phonetic"
            continue
        if at is None:
            left[cid] = "no ipa line"
            continue
        if block.json and not lines[at].rstrip("\r").rstrip().endswith(","):
            left[cid] = "unsupported layout"
            continue
        j = at + 1
        while j < end and _indent(lines[j]) > block.indent and lines[j].strip():
            j += 1
        cr = "\r" if eol == "\r\n" else ""
        lines[j:j] = [f"{pad}{q}phonetic{q}: {quote(form)}{comma}{cr}",
                      f'{pad}{q}phonetic_source{q}: "{source}"{comma}{cr}']
    return "\n".join(lines), left


UNWRITABLE = "could not write (layout)"


def apply_fills(fills: dict[Path, dict[str, tuple[str, str]]],
                outcomes: dict[tuple[Path, str], tuple[str, str]],
                coverage: "Coverage", write: bool, replace_rules: bool = False,
                replace_source: str = "rules") -> None:
    """Patch every file in [fills] (written only when [write]) and move each
    card the patcher could not write from its outcome in [coverage] to
    `UNWRITABLE`, so a miss is counted whether or not the run writes.
    [outcomes] maps (file, card id) to the card's deck and counted outcome.
    """
    for path, fill in fills.items():
        text = path.read_text(encoding="utf-8")
        new, left = patch(text, fill, replace_rules=replace_rules,
                          replace_source=replace_source)
        for cid, why in left.items():
            deck, outcome = outcomes[(path, cid)]
            print(f"warning: {path}: {cid} not written ({why})", file=sys.stderr)
            coverage.move(deck, outcome, UNWRITABLE)
        if write and new != text:
            path.write_text(new, encoding="utf-8", newline="")


def unwritable_exit(coverage: "Coverage", write: bool) -> int:
    """The exit code of a run: 1 under [write] when any card could not be
    written (stderr says how many), else 0."""
    n = coverage.total().get(UNWRITABLE, 0)
    if n and write:
        print(f"error: {n} card(s) could not be written ({UNWRITABLE}); "
              "see the warnings above", file=sys.stderr)
        return 1
    return 0


# --- Reading the cards ------------------------------------------------------

@dataclass
class Card:
    cid: str
    target: str
    ipa: str | None
    phonetic: str | None
    file: Path
    # Whether the card sits in a layout `patch` writes into (block YAML,
    # quoted-key YAML or JSON-style).
    block: bool = True
    phonetic_source: str | None = None


def core_cards(decks: Path, lang: str) -> list[Card]:
    """Every card of the language's core decks, in file order: a vocab deck
    marked `part: core`, or a single-file vocab deck with no `part` at all
    (such as `ja-en-hiragana`, whose cards carry their own English and a
    broad `ipa`; #1428). A layer has `kind: "layer"` and is never taken."""
    cards: list[Card] = []
    for path in sorted((decks / lang).glob("*.yaml")):
        raw = vd._load_raw(path)
        if not isinstance(raw, dict) or raw.get("part") not in ("core", None) \
                or raw.get("kind") not in (None, "vocab"):
            continue
        text = path.read_text(encoding="utf-8")
        for card in raw.get("cards") or []:
            if not isinstance(card, dict) or not vd._is_str(card.get("id")) \
                    or not vd._is_str(card.get("target")):
                continue
            found = _card_block(text.split("\n"), card["id"])
            block = found is not None or _flow_line(text.split("\n"), card["id"]) is not None
            if found is not None and found.json:
                # `ipa` as the last key of a JSON-style card cannot be patched.
                ln = text.split("\n")[found.start:found.end]
                at = next((x for x in ln if x.startswith(" " * found.indent + '"ipa":')), None)
                block = at is None or at.rstrip("\r").rstrip().endswith(",")
            ipa = card.get("ipa")
            phonetic = card.get("phonetic")
            cards.append(Card(card["id"], unicodedata.normalize("NFC", card["target"]),
                              ipa if vd._is_str(ipa) else None,
                              phonetic if vd._is_str(phonetic) else None,
                              path, block,
                              card.get("phonetic_source")
                              if vd._is_str(card.get("phonetic_source")) else None))
    return cards


# --- Coverage ---------------------------------------------------------------

@dataclass
class Coverage:
    """Counts per deck of what a run did, by outcome. Outcomes are the
    tool's own words (`filled`, `has phonetic`, ...)."""
    decks: dict[str, dict[str, int]] = field(default_factory=dict)

    def add(self, deck: str, outcome: str) -> None:
        row = self.decks.setdefault(deck, {})
        row[outcome] = row.get(outcome, 0) + 1

    def move(self, deck: str, old: str, new: str) -> None:
        """Count one card of [deck] as [new] instead of [old]."""
        row = self.decks.setdefault(deck, {})
        if row.get(old, 0) > 0:
            row[old] -= 1
            if not row[old]:
                del row[old]
        row[new] = row.get(new, 0) + 1

    def total(self) -> dict[str, int]:
        out: dict[str, int] = {}
        for row in self.decks.values():
            for k, v in row.items():
                out[k] = out.get(k, 0) + v
        return out

    def render(self, lang: str, outcomes: list[str], *, title: str) -> str:
        """A Markdown table: a row per deck, a column per outcome, and the
        language's total; `cards` is the sum of a row."""
        head = ["deck", "cards", *outcomes]
        rows = [head]
        for deck in sorted(self.decks):
            row = self.decks[deck]
            rows.append([deck, str(sum(row.values())),
                         *(str(row.get(o, 0)) for o in outcomes)])
        tot = self.total()
        rows.append([f"**{lang} total**", str(sum(tot.values())),
                     *(str(tot.get(o, 0)) for o in outcomes)])
        lines = [f"## {title}", "",
                 "| " + " | ".join(head) + " |",
                 "|" + "|".join(["---"] + ["---:"] * (len(head) - 1)) + "|"]
        lines += ["| " + " | ".join(r) + " |" for r in rows[1:]]
        return "\n".join(lines) + "\n"
