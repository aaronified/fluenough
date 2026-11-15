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

def _card_block(lines: list[str], cid: str) -> tuple[int, int] | None:
    head = re.compile(rf'^  - id: "?{re.escape(cid)}"?\s*$')
    for i, line in enumerate(lines):
        if head.match(line.rstrip("\r")):
            j = i + 1
            while j < len(lines) and (
                    not lines[j].strip()
                    or len(lines[j]) - len(lines[j].lstrip(" ")) > 2):
                j += 1
            while j > i + 1 and not lines[j - 1].strip():
                j -= 1
            return i, j
    return None


def patch(text: str, fills: dict[str, tuple[str, str]],
          replace_rules: bool = False) -> tuple[str, dict[str, str]]:
    """[text] with `phonetic` and `phonetic_source` added after the `ipa:`
    line of each card in [fills] (card id to the form and its source).

    Returns the new text and, for each card in [fills] left alone, why:
    `"has phonetic"`, `"no ipa line"`, `"not in file"`. A card that was
    patched is not in the second result. Every other line of the file is
    exactly as it was.

    With [replace_rules], a card whose `phonetic_source` is `rules` has its
    `phonetic` value replaced in place; any other card that has a `phonetic`
    is still left alone.
    """
    eol = "\r\n" if "\r\n" in text else "\n"
    lines = text.split("\n")
    left: dict[str, str] = {}
    for cid, (form, source) in fills.items():
        block = _card_block(lines, cid)
        if block is None:
            left[cid] = "not in file"
            continue
        start, end = block
        if any(re.match(r"^    phonetic(?:_source)?:", ln) for ln in lines[start:end]):
            at_p = next((k for k in range(start, end)
                         if re.match(r"^    phonetic:", lines[k])), None)
            by_rules = any(re.match(r'^    phonetic_source:\s*"?rules"?\s*$',
                                    lines[k].rstrip("\r")) for k in range(start, end))
            if replace_rules and at_p is not None and by_rules:
                cr = "\r" if lines[at_p].endswith("\r") else ""
                lines[at_p] = f"    phonetic: {quote(form)}{cr}"
            else:
                left[cid] = "has phonetic"
            continue
        at = next((k for k in range(start, end) if re.match(r"^    ipa:", lines[k])), None)
        if at is None:
            left[cid] = "no ipa line"
            continue
        j = at + 1
        while j < end and len(lines[j]) - len(lines[j].lstrip(" ")) > 4 \
                and lines[j].strip():
            j += 1
        cr = "\r" if eol == "\r\n" else ""
        lines[j:j] = [f"    phonetic: {quote(form)}{cr}",
                      f'    phonetic_source: "{source}"{cr}']
    return "\n".join(lines), left


# --- Reading the cards ------------------------------------------------------

@dataclass
class Card:
    cid: str
    target: str
    ipa: str | None
    phonetic: str | None
    file: Path
    # Whether the file has the card as a block (`  - id: "x"`), which is the
    # only shape `patch` writes into.
    block: bool = True
    phonetic_source: str | None = None


def core_cards(decks: Path, lang: str) -> list[Card]:
    """Every card of the language's core decks (`part: core`, a vocab deck),
    in file order."""
    cards: list[Card] = []
    for path in sorted((decks / lang).glob("*.yaml")):
        raw = vd._load_raw(path)
        if not isinstance(raw, dict) or raw.get("part") != "core" \
                or raw.get("kind") not in (None, "vocab"):
            continue
        text = path.read_text(encoding="utf-8")
        for card in raw.get("cards") or []:
            if not isinstance(card, dict) or not vd._is_str(card.get("id")) \
                    or not vd._is_str(card.get("target")):
                continue
            block = bool(re.search(
                rf'(?m)^  - id: "?{re.escape(card["id"])}"?\s*$', text))
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
