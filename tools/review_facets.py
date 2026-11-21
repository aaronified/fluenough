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
    PROVISIONAL, QUORUM_NEEDS_VERIFIED, REVIEW_QUORUM, facet_reached_quorum)

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
    return Answer(rater, kept, fix if isinstance(fix, str) else "")


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
