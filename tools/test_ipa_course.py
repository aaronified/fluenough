"""The IPA course's content rules (owner, #534): every symbol has an example
where a letter is said with its sound and one where it is not; symbols that
learners mix up stand next to each other; every card id is kept."""
import unittest
from pathlib import Path

import yaml

IPA = Path(__file__).resolve().parent.parent / "decks" / "ipa"
# Cards that still lack an example where a letter has the sound, and are
# listed to a speaker (docs/plans/ipa-course.md, "Questions").
NO_SOUNDING_EXAMPLE_YET = {
    "ipa-0088", "ipa-0091", "ipa-0105", "ipa-0113", "ipa-0119", "ipa-0133",
    "ipa-0138", "ipa-0141", "ipa-0146", "ipa-0147", "ipa-0151", "ipa-0153",
    "ipa-0154", "ipa-0155", "ipa-0161", "ipa-0162", "ipa-0167", "ipa-0168",
    "ipa-0170", "ipa-0171", "ipa-0172", "ipa-0173", "ipa-0174", "ipa-0176",
    "ipa-0177", "ipa-0178", "ipa-0179",
}
# The concept units (2026-10-26): their cards are terms and ideas, not
# symbols. `ipa-terms` and `ipa-notation` keep the contrast rule below;
# `ipa-what` holds history and structure, which have no sound to contrast, so
# its examples are optional, but any it gives still name their language.
CONCEPT_DECKS_WITHOUT_CONTRAST = {"ipa-what"}
CONFUSABLE = [("ɒ", "ɔ"), ("ʈ", "t̪"), ("ɪ", "i"), ("ɾ", "r"), ("ɖ", "d̪"),
              ("θ", "ð"), ("e", "ɛ"), ("ɹ", "ɾ"), ("ʃ", "ɕ"), ("ɑ", "ɒ")]


def decks():
    for f in sorted(IPA.glob("ipa-*.yaml")):
        raw = yaml.safe_load(f.read_text(encoding="utf-8"))
        if raw.get("part") == "core" and raw.get("kind") == "vocab":
            yield f.stem, raw["cards"]


class IpaCourse(unittest.TestCase):
    def _ids_are_kept(self):
        ids = sorted(c["id"] for _, cards in decks() for c in cards)
        self.assertEqual(ids, [f"ipa-{i:04d}" for i in range(1, 200)])

    def _every_symbol_has_examples_of_both_kinds(self):
        for deck, cards in decks():
            for c in cards:
                ex = c.get("examples") or []
                self.assertTrue(all("language" in e for e in ex), c["id"])
                if deck in CONCEPT_DECKS_WITHOUT_CONTRAST:
                    continue
                self.assertTrue(any(e.get("sounds") is False for e in ex),
                                f"{c['id']} has no example without the sound")
                if c["id"] not in NO_SOUNDING_EXAMPLE_YET:
                    self.assertTrue(any(e.get("sounds") is not False for e in ex),
                                    f"{c['id']} has no example with the sound")
                else:
                    self.assertFalse(any(e.get("sounds") is not False for e in ex),
                                     f"{c['id']} now has one: shorten the list")


    def test_ids_are_kept_and_every_symbol_has_examples(self) -> None:
        cases = (
            self._ids_are_kept,
            self._every_symbol_has_examples_of_both_kinds,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


if __name__ == "__main__":
    unittest.main()
