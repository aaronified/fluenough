#!/usr/bin/env python3
"""Where a card belongs, from Suggest a change (#477): a move suggested
through the review file, the review bot and tools/proposals.py. The meaning
never changes, and a new theme goes by pull request, so a move to a deck the
language's path does not list is refused.

Stdlib `unittest` plus PyYAML. Every test works on a copy of
tools/fixtures/b1/zz, a made-up language, in a temporary directory. No
network.
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
import review_bot as rb  # noqa: E402
import validate_decks as vd  # noqa: E402
from test_proposals import ALICE, BOB, TOOLS  # noqa: E402

LANG = 'language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }'

TRAVEL = f"""\
schema: 1
id: "zz-travel"
part: "core"
kind: "vocab"
{LANG}
license: "CC-BY-SA-4.0"
tags: ["unreviewed"]
cards:
  - id: "zz-9201"
    target: "రైలు"
    reading: "railu"
    pos: "noun"
"""

TRAVEL_EN = """\
schema: 1
id: "zz-en-travel"
kind: "layer"
core: "zz-travel"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Travel"
license: "CC-BY-SA-4.0"
cards:
  "zz-9201":
    native: "train"
"""

# The fixture's path with the travel unit, and a deck it does not list.
UNIT = '  - decks: ["zz-travel"]\n    words: 1\n    milestone: "A1"\n'
UNLISTED = TRAVEL.replace("zz-travel", "zz-unlisted")


def move_suggestion(now: str, text: str, why: str = "") -> dict:
    """A move as the app writes it in the review file
    (lib/core/review/deck_review.dart, Suggestion.toJson)."""
    s = {"part": "place", "now": now, "text": text}
    if why:
        s["why"] = why
    return s


class Place(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        shutil.copytree(TOOLS / "fixtures" / "b1" / "zz", self.root / "decks" / "zz")
        zz = self.root / "decks" / "zz"
        (zz / "zz-travel.yaml").write_text(TRAVEL, encoding="utf-8")
        (zz / "en" / "zz-en-travel.yaml").write_text(TRAVEL_EN, encoding="utf-8")
        (zz / "zz-unlisted.yaml").write_text(UNLISTED, encoding="utf-8")
        path = zz / "zz-path.yaml"
        text = path.read_text(encoding="utf-8")
        path.write_text(text.replace(
            '  - decks: ["zz-grammar-case-endings"]', UNIT + '  - decks: ["zz-grammar-case-endings"]'),
            encoding="utf-8")
        self.home = zz / "zz-home.yaml"
        self.home_en = zz / "en" / "zz-en-home.yaml"
        self.travel = zz / "zz-travel.yaml"
        self.travel_en = zz / "en" / "zz-en-travel.yaml"

    def propose(self, now: str, text: str, by: str = ALICE, card: str = "zz-9004"):
        facts = rb.suggestion_facts(move_suggestion(now, text))
        assert facts is not None
        result = pr.Proposed()
        pr.propose(self.root, pr.Suggestion("zz", now, pr.Proposal(
            card, *facts, by, "2026-10-17")), result)
        return result

    def cards(self, path: Path) -> list[str]:
        return [e.card for e in pr._entries_in(path, pr._load(path))]

    def test_a_move_keeps_the_id_and_the_card_in_both_files(self) -> None:
        result = self.propose("zz-en-home", "zz-en-travel")
        self.assertEqual(len(result.added), 1, result)
        # The review file names the course's decks; the proposal, their cores.
        self.assertEqual((result.added[0].now, result.added[0].text),
                         ("zz-home", "zz-travel"))
        before = pr.entries(self.root, "zz", "zz-9004")[0].data
        applied = pr.apply(self.root, "zz", result.added[0].id)
        self.assertEqual(applied.outcome, "applied")
        self.assertNotIn("zz-9004", self.cards(self.home))
        self.assertNotIn("zz-9004", self.cards(self.home_en))
        self.assertEqual(self.cards(self.travel), ["zz-9201", "zz-9004"])
        self.assertEqual(self.cards(self.travel_en), ["zz-9201", "zz-9004"])
        moved = [e for e in pr.entries(self.root, "zz", "zz-9004") if e.form == "core"][0]
        self.assertEqual(moved.data, {k: v for k, v in before.items() if k != "proposed"})
        for path in (self.home, self.home_en, self.travel, self.travel_en):
            self.assertEqual(vd.validate(path).errors, [], path)

    def test_a_move_applies_only_while_the_card_is_where_it_was_seen(self) -> None:
        result = self.propose("zz-en-home", "zz-en-travel")
        other = self.propose("zz-en-home", "zz-en-travel", by=BOB)
        self.assertEqual(pr.apply(self.root, "zz", result.added[0].id).outcome, "applied")
        self.assertEqual(pr.apply(self.root, "zz", other.added[0].id).outcome, "missing")

    def test_a_deck_the_path_does_not_list_is_refused(self) -> None:
        # A new theme goes by pull request: the deck exists, the path has no unit for it.
        self.assertEqual(len(self.propose("zz-en-home", "zz-unlisted").unsupported), 1)
        self.assertEqual(len(self.propose("zz-en-home", "zz-nowhere").unsupported), 1)
        self.assertEqual(len(self.propose("zz-en-home", "zz-home").unsupported), 1)
        # A script or grammar deck is not a theme either: another kind.
        self.assertEqual(
            len(self.propose("zz-en-home", "zz-grammar-case-endings").unsupported), 1)
        self.assertIn("zz-9004", self.cards(self.home))

    def test_a_move_to_a_deck_with_no_layer_in_the_language_changes_nothing(self) -> None:
        self.travel_en.unlink()
        result = self.propose("zz-en-home", "zz-travel")
        self.assertEqual(len(result.added), 1)
        self.assertEqual(pr.apply(self.root, "zz", result.added[0].id).outcome, "unsupported")
        self.assertIn("zz-9004", self.cards(self.home))
        self.assertNotIn("zz-9004", self.cards(self.travel))

    def test_the_last_card_of_a_deck_is_not_moved_out(self) -> None:
        result = self.propose("zz-en-travel", "zz-home", card="zz-9201")
        self.assertEqual(len(result.added), 1)
        self.assertEqual(pr.apply(self.root, "zz", result.added[0].id).outcome, "unsupported")
        self.assertEqual(self.cards(self.travel), ["zz-9201"])

    def test_the_review_file_reads_a_move(self) -> None:
        facts = rb.suggestion_facts(move_suggestion("zz-en-home", "zz-en-travel", "Fits travel"))
        self.assertEqual(facts, ("place", "zz-en-home", "zz-en-travel"))
        # A move with no target names nothing.
        self.assertIsNone(rb.suggestion_facts({"part": "place", "now": "zz-en-home"}))


if __name__ == "__main__":
    unittest.main()
