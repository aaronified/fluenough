"""Facets of a card, as the review bot, the validator and the index read them
(ADR-0058, work package W9). Pure Python, no I/O.

The app writes a review as one answer per facet (`facets` in a review file,
`lib/core/review/facets.dart`) and a receipt of the text seen for each
(`receipts`, `review_receipt.dart`). This module is the tools' side of that:

- the facet names and the pointer tags each may carry (kept equal to the
  Dart enums by `tools/test_review_facets.py`);
- [normalize_fix_text], the Dart `normalizeFixText` in Python: Unicode NFC,
  then any run of white space becomes one space and the ends are trimmed
  (`unicodedata` is the source `tools/gen_nfc_tables.py` writes the app's
  tables from, so the two agree);
- [hash_of_seen], a receipt's hash of the text a reviewer saw;
- [facet_status], the Dart `facetStatus`: where a facet stands, from its
  checks, by the one quorum rule of `tools/review_quorum.py`.

Nothing here shows a count to anyone: the quorum is a number in the tools
and the app, never in a screen or a published file.
"""

from __future__ import annotations

import hashlib
import re
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))

from review_quorum import (  # noqa: E402
    PROVISIONAL, QUORUM_NEEDS_VERIFIED, REVIEW_QUORUM, facet_reached_quorum, tier_of)

# The facets, by the name a review file and a deck use (`Facet.wire`), in
# the order of the Dart enum.
FACETS = ("word", "reading", "ipa", "meaning", "example", "note", "unit",
          "offence", "audio")

# The pointer tags and the facets each may be put on (`PointerTag`).
TAG_FACETS: dict[str, frozenset[str]] = {
    "meaning_wrong": frozenset({"meaning"}),
    "reading_wrong": frozenset({"reading"}),
    "ipa_wrong": frozenset({"ipa"}),
    "spelling_wrong": frozenset({"word", "example"}),
    "unnatural_or_rare": frozenset({"word", "meaning", "example"}),
    "wrong_register": frozenset({"word", "meaning", "example"}),
    "offensive": frozenset({"word", "meaning", "example", "offence"}),
    "example_wrong": frozenset({"example"}),
    "note_wrong": frozenset({"note"}),
    "wrong_unit": frozenset({"unit"}),
    "audio_wrong": frozenset({"audio"}),
}

# The facets whose flag may carry replacement text, and the proposal field
# (tools/proposals.py FIELD_OF_PART values) a fix on each becomes. The others
# (example, unit, offence, audio) are only pointed at: a fix on one is
# recorded with the flag and left for the owner.
FIELD_OF_FACET = {
    "word": "target",
    "reading": "reading",
    "ipa": "ipa",
    "meaning": "native",
    "note": "notes",
}

# The facet a proposal field is the text of: the other way round.
FACET_OF_FIELD = {field: facet for facet, field in FIELD_OF_FACET.items()}

# The facets whose flag may carry a fix (`isTextFacet` in the app). A fix sent
# on any other facet (unit, offence, audio) is dropped when the answer is read.
TEXT_FACETS = ("word", "reading", "ipa", "meaning", "example", "note")

# The same white space as `_whitespaceRun` in lib/core/review/fix_text.dart,
# without U+FEFF and the zero-width characters.
_WHITESPACE_RUN = re.compile(
    "[\t\n\u000B\f\r \u0085   -     　]+")
_EDGE_SPACE = re.compile("^ | $")

# How many hex characters of the SHA-256 a receipt keeps
# (`receiptHashLength` in review_receipt.dart).
RECEIPT_HASH_LENGTH = 16


def normalize_fix_text(text: str) -> str:
    """[text] in the form two fixes are compared in: NFC, white space
    collapsed to one space and trimmed. Nothing else (case, punctuation and
    the zero-width joiners are as typed); the per-script rules are the
    to-do of `normalizeFixText`."""
    return _EDGE_SPACE.sub("", _WHITESPACE_RUN.sub(" ", unicodedata.normalize("NFC", text)))


def same_fix_text(a: str, b: str) -> bool:
    return normalize_fix_text(a) == normalize_fix_text(b)


def hash_of_seen(text: str | None) -> str:
    """A receipt's hash: SHA-256 of the UTF-8 of the normalised text, cut to
    RECEIPT_HASH_LENGTH hex characters (`hashOfSeen`). No text hashes as the
    empty text."""
    digest = hashlib.sha256(normalize_fix_text(text or "").encode("utf-8"))
    return digest.hexdigest()[:RECEIPT_HASH_LENGTH]


@dataclass(frozen=True)
class Answer:
    """What one rater said about one facet: right (no tags), or flagged with
    pointer tags and perhaps a fix."""
    rater: str
    tags: tuple[str, ...] = ()
    fix: str = ""

    @property
    def right(self) -> bool:
        return not self.tags


def read_answer(facet: str, rater: str, raw: object) -> Answer | None:
    """The answer a review file's `facets[facet]` holds, or None when it is
    not one: `{"ok": true}`, or `{"tags": [...], "fix": "..."}`. A flag whose
    tags are all unknown, or do not belong on [facet], is dropped, never
    turned into "right"; an unknown tag among good ones is dropped alone
    (`FacetAnswer.fromJson`)."""
    if facet not in FACETS or not isinstance(raw, dict):
        return None
    tags = raw.get("tags")
    if tags is None:
        return Answer(rater) if raw.get("ok") is True else None
    if not isinstance(tags, list):
        return None
    kept = tuple(dict.fromkeys(t for t in tags if isinstance(t, str)
                               and facet in TAG_FACETS.get(t, ())))
    if not kept:
        return None
    fix = raw.get("fix")
    if facet not in TEXT_FACETS or not isinstance(fix, str):
        fix = ""
    return Answer(rater, kept, fix)


def read_answers(rater: str, raw: object) -> dict[str, Answer]:
    """Every facet answer of a review file card's `facets` object, by facet;
    an entry that is not an answer is left out and the others stay."""
    if not isinstance(raw, dict):
        return {}
    out: dict[str, Answer] = {}
    for facet in FACETS:
        if facet in raw:
            answer = read_answer(facet, rater, raw[facet])
            if answer is not None:
                out[facet] = answer
    return out


def read_receipts(raw: object, card: str) -> dict[str, str]:
    """A review file card's `receipts`: the hash of the text seen, by facet.
    A receipt of another card, or one that is not whole, is left out."""
    out: dict[str, str] = {}
    if not isinstance(raw, list):
        return out
    for item in raw:
        if not isinstance(item, dict):
            continue
        named = item.get("card", card)
        facet, seen = item.get("facet"), item.get("hash")
        if named == card and facet in FACETS and isinstance(seen, str) and seen:
            out[facet] = seen
    return out


# --- What a facet's checks say ---------------------------------------------------

@dataclass(frozen=True)
class Check:
    """One rater's check of one facet, in the order they were made."""
    rater: str
    endorses: bool = True
    fix: str = ""
    tier: str = PROVISIONAL

    @property
    def key(self) -> str:
        return self.rater.strip().upper()


def facet_status(checks: Iterable[Check], quorum: int = REVIEW_QUORUM,
                 needs_verified: bool = QUORUM_NEEDS_VERIFIED) -> str:
    """Where a facet stands: "unchecked", "checking" (right, fewer than the
    quorum), "settled", "flagged" (a tag and no fix two agree on, nobody
    disagreeing), "agreed_fix" (the quorum of flags proposing one text after
    normalisation) or "contested" (one says right and another flags, or two
    propose different texts). One answer counts for each rater, the latest
    (`facetStatus`)."""
    latest: dict[str, Check] = {}
    for c in checks:
        if c.key:
            latest[c.key] = c
    if not latest:
        return "unchecked"
    flagged = [c for c in latest.values() if not c.endorses]
    if not flagged:
        settled = facet_reached_quorum(
            [(c.key, c.tier, True) for c in latest.values()], quorum, needs_verified)
        return "settled" if settled else "checking"
    if len(flagged) < len(latest):
        return "contested"
    with_fix = [c for c in flagged if c.fix]
    if len(with_fix) < quorum:
        return "flagged"
    first = with_fix[0].fix
    return "agreed_fix" if all(same_fix_text(c.fix, first) for c in with_fix) else "contested"


def settled(checks: Iterable[Check], quorum: int = REVIEW_QUORUM,
            needs_verified: bool = QUORUM_NEEDS_VERIFIED) -> bool:
    """Whether [checks] give a facet the quorum, by the one rule
    (`facet_reached_quorum`): the same as [facet_status] saying "settled"."""
    return facet_status(checks, quorum, needs_verified) == "settled"


# --- What an entry publishes (the shape of `facet_checks`) -------------------------
# Shared by tools/proposals.py (the bot's edits) and tools/validate_decks.py.

def filled(value: object) -> bool:
    if isinstance(value, str):
        return bool(value.strip())
    return bool(value)


def owned_facets_of(data: dict, holds_card: bool) -> list[str]:
    """The facets a card entry [data] holds the text of, in the order of
    FACETS: the word, reading, IPA and audio where they are written, the
    meaning where `native` is, an example or a note where the entry has one;
    and, for the entry that holds the card itself ([holds_card]: a single
    file's, a core's, a layer's own), its place in a unit and, for a rude word,
    its offence rating. A core and its layer each own their part, so the merged
    card's facets are the two entries' together, as `facetsOf` has them in
    the app."""
    return [f for f, owned in (
        ("word", filled(data.get("target"))),
        ("reading", filled(data.get("reading"))),
        ("ipa", filled(data.get("ipa"))),
        ("meaning", filled(data.get("native"))),
        ("example", filled(data.get("examples"))),
        ("note", filled(data.get("notes"))),
        ("unit", holds_card),
        ("offence", holds_card and data.get("register") == "offensive"),
        ("audio", filled(data.get("audio"))),
    ) if owned]


def read_facet_data(raw: object) -> dict[str, dict]:
    """A card entry's `facet_checks` [raw], in the form the bot edits: for
    each facet that has any, `{"by": [codes], "flags": [{"by", "tags",
    "fix"}]}`. Read leniently: what is not of that shape is left out."""
    out: dict[str, dict] = {}
    if not isinstance(raw, dict):
        return out
    for facet in FACETS:
        item = raw.get(facet)
        if not isinstance(item, dict):
            continue
        by = item.get("by") if isinstance(item.get("by"), list) else []
        flags = item.get("flags") if isinstance(item.get("flags"), list) else []
        found = {
            "by": [c for c in by if isinstance(c, str)],
            "flags": [
                {"by": f["by"],
                 "tags": [t for t in f.get("tags", []) if isinstance(t, str)]
                 if isinstance(f.get("tags"), list) else [],
                 "fix": f["fix"] if isinstance(f.get("fix"), str) else ""}
                for f in flags if isinstance(f, dict) and isinstance(f.get("by"), str)],
        }
        if found["by"] or found["flags"]:
            out[facet] = found
    return out


def checks_of(codes: list[str], held: dict[str, dict], facet: str) -> list[Check]:
    """The checks of [facet] an entry lists, oldest first. ONE source of truth:
    an entry that carries `facet_checks` ([held] not empty) is read from it
    alone, and its `checked_by` is a mirror the bot keeps (the codes right on
    every facet the entry owns), ignored here; an entry with none is a legacy
    one, and each code of its `checked_by` is a bare "right" on every facet it
    owns."""
    # A rater's tier is the bot's private knowledge (signed reviewer keys,
    # tools/reviewer_binding.py): Provisional unless a binding says more, and
    # it matters only while QUORUM_NEEDS_VERIFIED is on.
    if not held:
        return [Check(code, tier=tier_of(code)) for code in codes]
    item = held.get(facet, {"by": [], "flags": []})
    return [*(Check(code, tier=tier_of(code)) for code in item["by"]),
            *(Check(f["by"], False, f["fix"], tier_of(f["by"])) for f in item["flags"])]


def entry_settled(codes: list[str], held: dict[str, dict], data: dict,
                  holds_card: bool) -> bool | None:
    """Whether every facet the entry owns has the quorum; None when it owns
    none, so that it asks nothing of a reviewer."""
    owned = owned_facets_of(data, holds_card)
    if not owned:
        return None
    return all(settled(checks_of(codes, held, f)) for f in owned)


def entry_open(codes: list[str], held: dict[str, dict], data: dict,
               holds_card: bool) -> bool:
    """Whether some facet the entry owns is flagged, contested or has an
    agreed fix waiting: a card with one is not reviewed, whatever else."""
    return any(facet_status(checks_of(codes, held, f)) in ("flagged", "contested", "agreed_fix")
               for f in owned_facets_of(data, holds_card))
