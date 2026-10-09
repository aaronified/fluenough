#!/usr/bin/env python3
"""Card ids name the language, a card is written once, and other decks list
it by ref (ADR-0018). Grammar cells may list several forms (#144).

Stdlib `unittest` plus PyYAML, like the validator itself.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks

TOOLS = Path(__file__).resolve().parent


def vocab(deck_id: str, cards: str, native: str = "en") -> str:
    names = {"en": "eng, name: English", "bn": "ben, name: Bengali"}
    return f"""\
schema: 1
id: {deck_id}
name: Probe
language: {{ code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }}
native: {{ code: {native}, iso639_3: {names[native]} }}
license: CC0-1.0
cards:
{cards}"""


WRITTEN = """\
  - id: es-9001
    target: "perro"
    native: "dog"
    notes: "Also a hot dog."
"""


class CardIds(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def reports(self, **files: str) -> list[validate_decks.Report]:
        out = []
        for stem, text in files.items():
            path = self.tmp / f"{stem.replace('_', '-')}.yaml"
            path.write_text(text, encoding="utf-8")
            out.append(validate_decks.validate(path))
        return out

    def across(self, **files: str) -> list[str]:
        reports = self.reports(**files)
        for rep in reports:
            self.assertEqual(rep.errors, [], rep.path)
        return validate_decks.check_cards_across(reports)

    def test_a_card_id_names_the_language_and_a_number(self) -> None:
        for bad in ("es-en-probe-0001", "hi-0001", "es-1", "es-abcd"):
            with self.subTest(bad=bad):
                (rep,) = self.reports(
                    es_en_probe=vocab("es-en-probe", WRITTEN.replace("es-9001", bad)))
                self.assertTrue(any("id must be es-" in e for e in rep.errors),
                                rep.errors)

    def test_a_card_is_written_once_in_its_language(self) -> None:
        problems = self.across(
            es_en_a=vocab("es-en-a", WRITTEN),
            es_en_b=vocab("es-en-b", WRITTEN),
        )
        self.assertEqual(len(problems), 1)
        self.assertIn("already written", problems[0])
        self.assertIn("ref: es-9001", problems[0])

    def test_a_ref_lists_a_card_written_in_another_deck(self) -> None:
        ref = '  - ref: es-9001\n    native: "dog (the pet)"\n'
        self.assertEqual(
            self.across(es_en_a=vocab("es-en-a", WRITTEN),
                        es_en_b=vocab("es-en-b", ref)),
            [])

    def test_a_ref_to_a_card_no_deck_writes(self) -> None:
        problems = self.across(es_en_b=vocab("es-en-b", "  - ref: es-9999\n"))
        self.assertEqual(len(problems), 1)
        self.assertIn("no deck writes card es-9999", problems[0])

    def test_a_pair_names_a_card_written_in_the_language(self) -> None:
        paired = WRITTEN + '    pair: es-9002\n'
        partner = '  - id: es-9002\n    target: "pero"\n    native: "but"\n'
        self.assertEqual(self.across(es_en_a=vocab("es-en-a", paired),
                                     es_en_b=vocab("es-en-b", partner)), [])
        # The language's files on disk beside a given file count (ADR-0036),
        # so the partner's deck goes before the deck is checked without it.
        (self.tmp / "es-en-b.yaml").unlink()
        problems = self.across(es_en_a=vocab("es-en-a", paired))
        self.assertEqual(len(problems), 1)
        self.assertIn("pair names card es-9002", problems[0])

    def test_a_pair_is_another_card_of_the_language(self) -> None:
        for bad in ("es-9001", "hi-0001", "dog"):
            with self.subTest(bad=bad):
                (rep,) = self.reports(es_en_a=vocab(
                    "es-en-a", WRITTEN + f'    pair: "{bad}"\n'))
                self.assertTrue(any("pair" in e for e in rep.errors), rep.errors)

    def test_a_ref_to_a_card_its_own_deck_writes(self) -> None:
        (rep,) = self.reports(es_en_a=vocab("es-en-a", WRITTEN + "  - ref: es-9001\n"))
        self.assertTrue(any("already in the deck" in e for e in rep.errors), rep.errors)

    def test_a_ref_cannot_change_the_card_itself(self) -> None:
        for field in ("target", "alt_target", "pos", "gender", "audio"):
            with self.subTest(field=field):
                (rep,) = self.reports(es_en_b=vocab(
                    "es-en-b", f'  - ref: es-9001\n    {field}: "x"\n'))
                self.assertTrue(any("belongs to the card" in e for e in rep.errors),
                                rep.errors)

    def test_a_ref_from_another_native_language_gives_its_own(self) -> None:
        problems = self.across(
            es_en_a=vocab("es-en-a", WRITTEN),
            es_bn_b=vocab("es-bn-b", "  - ref: es-9001\n", native="bn"),
        )
        self.assertEqual(len(problems), 1)
        self.assertIn("needs its own native", problems[0])
        self.assertEqual(
            self.across(
                es_en_a=vocab("es-en-a", WRITTEN),
                es_bn_b=vocab("es-bn-b", '  - ref: es-9001\n    native: "কুকুর"\n',
                              native="bn"),
            ),
            [])

    def test_a_ref_checks_its_examples_as_a_card_does(self) -> None:
        (rep,) = self.reports(es_en_b=vocab(
            "es-en-b", '  - ref: es-9001\n    examples: [{ target: "x" }]\n'))
        self.assertTrue(any("needs both target and native" in e for e in rep.errors),
                        rep.errors)

    def test_a_file_checked_alone_is_held_to_the_repository(self) -> None:
        taken = next(iter(validate_decks._repo_card_defs("es")))
        reports = self.reports(es_en_new=vocab(
            "es-en-new", WRITTEN.replace("es-9001", taken)))
        problems = validate_decks.check_cards_across(reports)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn(f"card {taken} is already written in", problems[0])

    def test_next_id_follows_the_highest_in_the_language(self) -> None:
        out = subprocess.run(
            [sys.executable, str(TOOLS / "validate_decks.py"), "--next-id", "bn"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        taken = validate_decks._repo_card_defs("bn")
        self.assertRegex(out, r"^bn-[0-9]{4,}$")
        self.assertNotIn(out, taken)
        self.assertEqual(int(out.split("-")[1]),
                         max(int(c.split("-")[1]) for c in taken) + 1)


GRAMMAR = """\
schema: 1
id: es-en-grammar-probe
name: Probe
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: Present
  slot_name: person
  slots: [yo, tú]
  prompt: "{lemma} ({gloss}) — {slot}"
  entries:
    - lemma: hablar
      gloss: to speak
      forms: { yo: FORM, tú: hablas }
"""


class CellAlternatives(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def errors(self, form: str) -> list[str]:
        path = self.tmp / "es-en-grammar-probe.yaml"
        path.write_text(GRAMMAR.replace("FORM", form), encoding="utf-8")
        return validate_decks.validate(path).errors

    def test_a_cell_may_list_its_forms(self) -> None:
        self.assertEqual(self.errors('["hablo", "hablo yo"]'), [])

    def test_a_listed_cell_has_forms_and_no_repeats(self) -> None:
        self.assertTrue(any("list non-empty strings" in e for e in self.errors("[]")))
        self.assertTrue(any("a form twice" in e
                            for e in self.errors('["hablo", "hablo"]')))


if __name__ == "__main__":
    unittest.main()
