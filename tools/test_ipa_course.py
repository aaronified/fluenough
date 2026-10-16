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
CONFUSABLE = [("ɒ", "ɔ"), ("ʈ", "t̪"), ("ɪ", "i"), ("ɾ", "r"), ("ɖ", "d̪"),
              ("θ", "ð"), ("e", "ɛ"), ("ɹ", "ɾ"), ("ʃ", "ɕ"), ("ɑ", "ɒ")]


def decks():
    for f in sorted(IPA.glob("ipa-*.yaml")):
        raw = yaml.safe_load(f.read_text(encoding="utf-8"))
        if raw.get("part") == "core" and raw.get("kind") == "vocab":
            yield f.stem, raw["cards"]


class IpaCourse(unittest.TestCase):
    def test_ids_are_kept(self):
        ids = sorted(c["id"] for _, cards in decks() for c in cards)
        self.assertEqual(ids, [f"ipa-{i:04d}" for i in range(1, 180)])

    def test_every_symbol_has_examples_of_both_kinds(self):
        for deck, cards in decks():
            for c in cards:
                ex = c.get("examples") or []
                self.assertTrue(all("language" in e for e in ex), c["id"])
                self.assertTrue(any(e.get("sounds") is False for e in ex),
                                f"{c['id']} has no example without the sound")
                if c["id"] not in NO_SOUNDING_EXAMPLE_YET:
                    self.assertTrue(any(e.get("sounds") is not False for e in ex),
                                    f"{c['id']} has no example with the sound")
                else:
                    self.assertFalse(any(e.get("sounds") is not False for e in ex),
                                     f"{c['id']} now has one: shorten the list")

    def test_confusable_symbols_are_adjacent(self):
        for a, b in CONFUSABLE:
            for deck, cards in decks():
                targets = [c["target"] for c in cards]
                if a in targets and b in targets:
                    self.assertEqual(abs(targets.index(a) - targets.index(b)), 1,
                                     f"{a} and {b} in {deck}")
                    break


if __name__ == "__main__":
    unittest.main()
