#!/usr/bin/env python3
"""Tests for the parts of validate_decks.py that are not about a deck's content.

Stdlib `unittest` plus PyYAML, the same two things the validator itself needs,
so a deck contributor can run these without a Flutter toolchain.

Every test here builds a throwaway repository in a temporary directory and
runs the validator as a subprocess against it. That is deliberate: the bug
these were first written for was one of resolution — a check read
`pubspec.yaml` from the working directory, so it passed silently when run from
anywhere else — and a test that imports the function and calls it in-process
cannot see that. The check now is that decks/index.json is current (#210).
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
import validate_decks
import yaml

REPO = Path(__file__).resolve().parent.parent
VALIDATOR = REPO / "tools" / "validate_decks.py"
INDEXER = REPO / "tools" / "deck_index.py"
SAMPLE_DECK = REPO / "tools" / "fixtures" / "index" / "es-en-core-100.yaml"


class IndexCheck(unittest.TestCase):
    """decks/index.json must be current, from any directory (#210)."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

        (self.tmp / "tools").mkdir()
        shutil.copy(VALIDATOR, self.tmp / "tools" / "validate_decks.py")
        shutil.copy(INDEXER, self.tmp / "tools" / "deck_index.py")
        shutil.copy(REPO / "tools" / "rater_codes.py", self.tmp / "tools" / "rater_codes.py")

        (self.tmp / "decks" / "es").mkdir(parents=True)
        shutil.copy(SAMPLE_DECK, self.tmp / "decks" / "es")
        self.write_path("es", ["es-core-100"])
        # The sample deck's pictures, which the validator looks for beside
        # the tools directory it runs from.
        shutil.copytree(VALIDATOR.parent.parent / "assets" / "pictures",
                        self.tmp / "assets" / "pictures")
        self.write_index()

    def write_path(self, lang: str, decks: list[str]) -> None:
        """The path every language with a deck needs (ADR-0013, ADR-0036),
        listing core ids."""
        (self.tmp / "decks" / lang / f"{lang}-path.yaml").write_text(
            f"schema: 1\nkind: path\nid: {lang}-path\nlanguage: {lang}\n"
            f"units:\n  - [{', '.join(decks)}]\n",
            encoding="utf-8",
        )

    def write_index(self) -> None:
        result = subprocess.run(
            [sys.executable, str(self.tmp / "tools" / "deck_index.py")],
            cwd=self.tmp, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def add_language(self) -> None:
        """A second language, after the index was written."""
        hi = self.tmp / "decks" / "hi"
        hi.mkdir()
        deck = SAMPLE_DECK.read_text(encoding="utf-8")
        deck = deck.replace("id: es-en-core-100", "id: hi-en-probe")
        deck = deck.replace("code: es", "code: hi")
        deck = deck.replace("name: Spanish", "name: Hindi")
        deck = deck.replace("tts: es-ES", "tts: hi-IN")
        deck = deck.replace("id: es-0", "id: hi-0")
        (hi / "hi-en-probe.yaml").write_text(deck, encoding="utf-8")
        self.write_path("hi", ["hi-probe"])

    def run_validator(
        self, target: str, cwd: Path
    ) -> subprocess.CompletedProcess:
        validator = self.tmp / "tools" / "validate_decks.py"
        return subprocess.run(
            [sys.executable, str(validator), target],
            cwd=cwd,
            capture_output=True,
            text=True,
            check=False,
        )

    def _passes_when_the_index_is_current(self) -> None:
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def _fails_when_the_index_is_missing(self) -> None:
        (self.tmp / "decks" / "index.json").unlink()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("decks/index.json is missing", result.stdout)

    def _fails_when_a_language_is_added_after_it(self) -> None:
        self.add_language()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("decks/index.json is out of date", result.stdout)
        self.write_index()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def _fails_when_a_deck_changes_after_it(self) -> None:
        deck = self.tmp / "decks" / "es" / "es-en-core-100.yaml"
        deck.write_text(deck.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("out of date", result.stdout)

    def _a_hidden_language_is_still_validated(self) -> None:
        """A hidden language is left out of the index, but still checked.
        No language is hidden now, so the copied tool hides Japanese."""
        tool = self.tmp / "tools" / "deck_index.py"
        tool.write_text(tool.read_text(encoding="utf-8").replace(
            "HIDDEN: set[str] = set()", 'HIDDEN: set[str] = {"ja"}'),
            encoding="utf-8")
        shutil.copytree(REPO / "decks" / "ja", self.tmp / "decks" / "ja")
        shutil.copy(REPO / "decks" / "themes.yaml", self.tmp / "decks" / "themes.yaml")
        self.write_index()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

        deck = self.tmp / "decks" / "ja" / "ja-en-hiragana.yaml"
        deck.write_text(
            deck.read_text(encoding="utf-8").replace("schema: 1", "schema: 9"),
            encoding="utf-8",
        )
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("ja-en-hiragana.yaml", result.stdout)
        self.assertNotIn("index.json", result.stdout)

    def _fails_from_a_different_working_directory(self) -> None:
        """The check reads decks/ beside the tools, not the working
        directory's: run from the parent, it still finds the stale index."""
        self.add_language()
        result = self.run_validator(f"{self.tmp.name}/decks/", self.tmp.parent)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("out of date", result.stdout)

    def _absolute_paths_do_not_produce_false_failures(self) -> None:
        result = self.run_validator(str(self.tmp / "decks"), self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)

    def _absolute_path_still_catches_a_real_miss(self) -> None:
        self.add_language()
        result = self.run_validator(str(self.tmp / "decks"), self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("out of date", result.stdout)

    def _one_deck_alone_skips_the_index(self) -> None:
        """Validating one file cannot say the index is current; the run over
        decks/ does."""
        self.add_language()
        result = self.run_validator("decks/hi/hi-en-probe.yaml", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)

    def _a_deck_outside_the_repo_skips_the_index(self) -> None:
        """Validating a deck you are drafting elsewhere is legitimate."""
        elsewhere = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, elsewhere, True)
        shutil.copy(SAMPLE_DECK, elsewhere)

        result = self.run_validator(str(elsewhere), self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)

    def _a_language_with_a_deck_needs_a_path(self) -> None:
        (self.tmp / "decks" / "es" / "es-path.yaml").unlink()
        result = self.run_validator("decks/", self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("es has no path; add es-path.yaml in decks/es/", result.stdout)

    def _one_deck_validates_alone_when_its_path_is_on_disk(self) -> None:
        result = self.run_validator("decks/es/es-en-core-100.yaml", self.tmp)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_a_failing_run_ends_with_every_error_and_a_passing_one_has_none(self) -> None:
        """CI's log is long and the tail is what can be read, so a failing
        run repeats each error, cross-file and per-file, in a closing
        "Errors:" section; a passing run has no such section."""
        passing = self.run_validator("decks/", self.tmp)
        self.assertEqual(passing.returncode, 0, passing.stdout + passing.stderr)
        self.assertNotIn("Errors:", passing.stdout)

        (self.tmp / "decks" / "index.json").unlink()
        deck = self.tmp / "decks" / "es" / "es-en-core-100.yaml"
        deck.write_text(
            deck.read_text(encoding="utf-8").replace("schema: 1", "schema: 9"),
            encoding="utf-8",
        )
        failing = self.run_validator("decks/", self.tmp)
        self.assertEqual(failing.returncode, 1, failing.stdout)
        out = failing.stdout
        head, sep, tail = out.rpartition("\nErrors:\n")
        self.assertTrue(sep, out)
        self.assertEqual(out.count("\nErrors:\n"), 1)
        # The section is the last thing printed and holds only error lines.
        lines = tail.splitlines()
        self.assertTrue(lines and all(x.startswith("  error: ") for x in lines), tail)
        # The cross-file error, as printed above, is repeated.
        self.assertIn("error: decks/index.json is missing", head)
        self.assertTrue(any("decks/index.json is missing" in x for x in lines), tail)
        # Every per-file error is repeated with its file.
        per_file = [x.strip().removeprefix("error   ") for x in head.splitlines()
                    if x.startswith("  error   ")]
        self.assertTrue(per_file, head)
        for e in per_file:
            self.assertIn(f"  error: decks/es/es-en-core-100.yaml: {e}", lines)
        # The deck summary stays where it was, before the section.
        self.assertIn("decks valid", head)

    def test_the_index_check_passes_only_while_the_index_is_current(self) -> None:
        cases = (
            self._passes_when_the_index_is_current,
            self._fails_when_the_index_is_missing,
            self._fails_when_a_language_is_added_after_it,
            self._fails_when_a_deck_changes_after_it,
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

    def test_a_hidden_language_and_any_working_directory_are_checked(self) -> None:
        cases = (
            self._a_hidden_language_is_still_validated,
            self._fails_from_a_different_working_directory,
            self._absolute_paths_do_not_produce_false_failures,
            self._absolute_path_still_catches_a_real_miss,
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

    def test_one_deck_alone_skips_the_index(self) -> None:
        cases = (
            self._one_deck_alone_skips_the_index,
            self._a_deck_outside_the_repo_skips_the_index,
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

    def test_a_language_with_a_deck_needs_a_path(self) -> None:
        cases = (
            self._a_language_with_a_deck_needs_a_path,
            self._one_deck_validates_alone_when_its_path_is_on_disk,
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


# From test_validate_content.py.
# Content rules: ISO 639-3 codes on every language, and facts files.
#
# Both are described in docs/DECK-FORMAT.md. Stdlib `unittest` plus PyYAML, like
# the validator itself.


VOCAB = """\
schema: 1
id: hi-en-probe
name: Probe
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC-BY-SA-4.0
cards:
  - id: hi-0001
    target: घर
    native: the house
    reading: "ghar"
"""

FACTS_HEADER = """\
schema: 1
id: hi-en-probe
name: Hindi facts
kind: facts
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
license: CC-BY-SA-4.0
facts:
"""


def fact(n: int, **fields: str) -> str:
    """One fact, written in English unless `fields` says otherwise."""
    lines = [f"  - id: hi-fact-{n:03d}"]
    text = fields.pop("text", f'{{ en: "Fact number {n}." }}')
    lines.append(f"    text: {text}")
    for key, value in fields.items():
        lines.append(f"    {key}: {value}")
    return "\n".join(lines) + "\n"


def facts_file(count: int = 30, extra: str = "", header: str = FACTS_HEADER) -> str:
    return header + "".join(fact(n) for n in range(1, count + 1)) + extra


class Validated(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def report(self, text: str) -> validate_decks.Report:
        path = self.tmp / "hi-en-probe.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def assertValid(self, text: str) -> validate_decks.Report:
        report = self.report(text)
        self.assertEqual(report.errors, [])
        return report

    def assertRejected(self, text: str, needle: str) -> None:
        errors = self.report(text).errors
        self.assertTrue(
            any(needle in e for e in errors),
            f"expected an error containing {needle!r}, got {errors}",
        )


class Iso6393Codes(Validated):
    def _a_deck_with_both_codes_is_valid(self) -> None:
        self.assertValid(VOCAB)

    def _both_language_blocks_need_one(self) -> None:
        for block, old in (
            ("language", "iso639_3: hin, "),
            ("native", "iso639_3: eng, "),
        ):
            with self.subTest(block):
                self.assertRejected(VOCAB.replace(old, ""), "iso639_3 must be")

    def _it_must_be_three_lowercase_letters(self) -> None:
        for bad in ("hi", "hind", "HIN", "h1n", '"hin\\n"', "true"):
            with self.subTest(bad=bad):
                self.assertRejected(VOCAB.replace("iso639_3: hin", f"iso639_3: {bad}"),
                                    "iso639_3 must be")

    def _a_facts_file_needs_one_on_its_language(self) -> None:
        self.assertRejected(facts_file().replace("iso639_3: hin, ", ""), "iso639_3 must be")

    def test_iso639_3_is_required_as_three_lowercase_letters(self) -> None:
        cases = (
            self._a_deck_with_both_codes_is_valid,
            self._both_language_blocks_need_one,
            self._it_must_be_three_lowercase_letters,
            self._a_facts_file_needs_one_on_its_language,
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


class DeckIds(Validated):
    """A deck id names the language learned, then the one it is taught from."""

    def _both_languages_lead_the_id(self) -> None:
        self.assertValid(VOCAB)

    def _an_id_without_the_source_language_is_rejected(self) -> None:
        for bad in ("hi-probe", "en-hi-probe", "hi-enprobe"):
            with self.subTest(bad=bad):
                self.assertRejected(VOCAB.replace("id: hi-en-probe", f"id: {bad}"),
                                    "must start with 'hi-en-'")

    def _a_facts_file_names_only_its_language(self) -> None:
        path = self.tmp / "hi-facts.yaml"
        path.write_text(facts_file().replace("id: hi-en-probe", "id: hi-facts"),
                        encoding="utf-8")
        self.assertEqual(validate_decks.validate(path).errors, [])

    def test_a_deck_id_leads_with_both_languages(self) -> None:
        cases = (
            self._both_languages_lead_the_id,
            self._an_id_without_the_source_language_is_rejected,
            self._a_facts_file_names_only_its_language,
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


class FactsFiles(Validated):
    def _thirty_facts_are_valid(self) -> None:
        self.assertValid(facts_file(30))

    def _twenty_nine_are_not_enough(self) -> None:
        self.assertRejected(facts_file(29), "at least 30 facts without a contrast")

    def _contrast_facts_do_not_count_towards_the_thirty(self) -> None:
        extra = fact(90, contrast="en")
        self.assertRejected(facts_file(29, extra), "has 29")
        self.assertValid(facts_file(30, extra))

    def _a_contrast_fact_must_be_written_in_its_language(self) -> None:
        extra = fact(90, contrast="bn")
        self.assertRejected(facts_file(30, extra), "text needs a 'bn' entry")

    def _a_partial_translation_warns_but_does_not_fail(self) -> None:
        extra = fact(91, text='{ en: "One more.", bn: "আরও একটি।" }')
        report = self.assertValid(facts_file(30, extra))
        self.assertTrue(any("'bn'" in w and "1 daily facts" in w for w in report.warnings),
                        report.warnings)

    def _fact_ids_are_unique(self) -> None:
        self.assertRejected(facts_file(30, fact(1)), "duplicate fact id")

    def _fact_ids_match_the_id_pattern(self) -> None:
        text = facts_file(30).replace("id: hi-fact-001", "id: Hi_Fact_1")
        self.assertRejected(text, "id must match")

    def _unknown_fields_are_rejected(self) -> None:
        self.assertRejected(facts_file(30, fact(90, colour="blue")), "unknown field 'colour'")

    def _text_must_be_a_mapping_of_codes_to_text(self) -> None:
        cases = {
            "a plain string": ('"Just text."', "text must map language codes"),
            "a bad code": ('{ english: "Text." }', "text key must be"),
            "a bare false": ('{ false: "Tekst." }', "Quote the code"),
            "a boolean value": ("{ en: true }", "parsed as the boolean"),
            "an empty value": ('{ en: "" }', "must be non-empty text"),
        }
        for name, (text, needle) in cases.items():
            with self.subTest(name):
                self.assertRejected(facts_file(30, fact(90, text=text)), needle)

    def _contrast_must_be_a_language_code(self) -> None:
        self.assertRejected(facts_file(30, fact(90, contrast='"English"')),
                            "contrast must be")

    def _a_facts_file_has_no_native(self) -> None:
        header = FACTS_HEADER.replace(
            "license:", "native: { code: en, iso639_3: eng, name: English }\nlicense:")
        self.assertRejected(facts_file(30, header=header), "a facts file has no native")

    def _a_facts_file_has_no_cards(self) -> None:
        self.assertRejected(facts_file(30) + "cards: []\n", "uses facts, not cards")

    def _other_decks_have_no_facts(self) -> None:
        self.assertRejected(VOCAB + "facts: []\n", "only valid on a facts file")

    def _a_grammar_deck_has_no_facts(self) -> None:
        grammar = VOCAB.replace("name: Probe", "name: Probe\nkind: grammar").split("cards:")[0]
        grammar += (
            "pattern:\n  name: P\n  slot_name: person\n  slots: [yo]\n"
            '  prompt: "{lemma} {gloss} {slot}"\n'
            "  entries:\n    - { lemma: hablar, gloss: to speak, forms: { yo: hablo } }\n"
            "facts: []\n"
        )
        self.assertRejected(grammar, "only valid on a facts file")

    def _a_facts_file_has_no_pattern(self) -> None:
        self.assertRejected(facts_file(30) + "pattern: {}\n", "uses facts, not cards or a pattern")

    def _an_empty_facts_list_is_rejected(self) -> None:
        self.assertRejected(FACTS_HEADER.replace("facts:\n", "facts: []\n"),
                            "facts: must be a non-empty list")

    def _each_fact_must_be_a_mapping(self) -> None:
        self.assertRejected(facts_file(30, '  - "just a string"\n'), "must be a mapping")

    def _fact_tags_must_be_a_list_of_text(self) -> None:
        self.assertRejected(facts_file(30, fact(90, tags="script")), "tags must be a list")

    def _fact_source_must_be_text(self) -> None:
        self.assertRejected(facts_file(30, fact(90, source="1990")), "not text")

    def _contrast_facts_do_not_count_towards_a_language(self) -> None:
        # 30 English facts; Bengali appears only on a contrast fact, so it has
        # no contrast-free facts and should not be warned about as if it did.
        extra = fact(90, contrast="bn", text='{ bn: "তুলনা।" }')
        report = self.assertValid(facts_file(30, extra))
        self.assertFalse(any("'bn'" in w for w in report.warnings), report.warnings)

    def _a_file_with_no_english_warns(self) -> None:
        text = facts_file(30).replace('{ en: "Fact number', '{ bn: "Fact number')
        report = self.assertValid(text)
        self.assertTrue(any("'en'" in w and "0 daily facts" in w for w in report.warnings),
                        report.warnings)

    def test_a_facts_file_needs_thirty_facts_in_its_language(self) -> None:
        cases = (
            self._thirty_facts_are_valid,
            self._twenty_nine_are_not_enough,
            self._contrast_facts_do_not_count_towards_the_thirty,
            self._a_contrast_fact_must_be_written_in_its_language,
            self._a_partial_translation_warns_but_does_not_fail,
            self._fact_ids_are_unique,
            self._fact_ids_match_the_id_pattern,
            self._unknown_fields_are_rejected,
            self._text_must_be_a_mapping_of_codes_to_text,
            self._contrast_must_be_a_language_code,
            self._a_facts_file_has_no_native,
            self._a_facts_file_has_no_cards,
            self._other_decks_have_no_facts,
            self._a_grammar_deck_has_no_facts,
            self._a_facts_file_has_no_pattern,
            self._an_empty_facts_list_is_rejected,
            self._each_fact_must_be_a_mapping,
            self._fact_tags_must_be_a_list_of_text,
            self._fact_source_must_be_text,
            self._contrast_facts_do_not_count_towards_a_language,
            self._a_file_with_no_english_warns,
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

THEMES = """\
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: market, name: "Market" }
"""


class Themes(Validated):
    """The shared theme path, and theme decks (ADR-0010)."""

    def write(self, name: str, text: str) -> Path:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return path

    def _a_themes_file_is_valid(self) -> None:
        report = validate_decks.validate(self.write("themes.yaml", THEMES))
        self.assertEqual(report.errors, [])
        self.assertEqual(report.themes, ["first-words", "market"])

    def _a_malformed_themes_file_is_rejected(self) -> None:
        for bad, needle in (
            (THEMES.replace("id: market", "id: first-words"), "listed twice"),
            (THEMES.replace("id: market", "id: Market"), "id must match"),
            (THEMES.replace(', name: "Market"', ""), "needs a name"),
            (THEMES + "cards: []\n", "unknown field"),
            ("schema: 1\nkind: themes\nthemes: []\n", "non-empty"),
        ):
            with self.subTest(needle):
                errors = validate_decks.validate(self.write("themes.yaml", bad)).errors
                self.assertTrue(any(needle in e for e in errors), errors)

    def _a_vocab_deck_may_name_a_theme(self) -> None:
        report = self.assertValid(VOCAB.replace("license:", "theme: market\nlicense:"))
        self.assertEqual(report.theme_key, ("hi", "en", "market"))

    def _only_a_vocab_deck_takes_a_theme(self) -> None:
        self.assertRejected(
            facts_file().replace("license:", "theme: market\nlicense:"),
            "only a vocab deck teaches a theme",
        )

    def _across_files_a_theme_must_exist_and_be_used_once(self) -> None:
        themes = validate_decks.validate(self.write("themes.yaml", THEMES))

        def deck(theme: str, name: str) -> validate_decks.Report:
            text = VOCAB.replace("license:", f"theme: {theme}\nlicense:")
            return validate_decks.validate(self.write(name, text))

        good = deck("market", "a.yaml")
        self.assertEqual(validate_decks.check_themes_across([themes, good]), [])
        unknown = deck("weather", "b.yaml")
        again = deck("market", "c.yaml")
        problems = validate_decks.check_themes_across([themes, good, unknown, again])
        self.assertTrue(any("'weather' is not in" in p for p in problems), problems)
        self.assertTrue(any("already has a 'market' deck" in p for p in problems), problems)

    def test_a_theme_exists_and_is_used_once(self) -> None:
        cases = (
            self._a_themes_file_is_valid,
            self._a_malformed_themes_file_is_rejected,
            self._a_vocab_deck_may_name_a_theme,
            self._only_a_vocab_deck_takes_a_theme,
            self._across_files_a_theme_must_exist_and_be_used_once,
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


class Scripts(Validated):
    """`script` is an open list, checked with a warning (ADR-0009)."""

    def _the_indic_starter_scripts_are_known(self) -> None:
        for script in ("bengali", "gujarati", "telugu", "devanagari", "arabic"):
            with self.subTest(script):
                report = self.assertValid(
                    VOCAB.replace("script: devanagari", f"script: {script}")
                )
                self.assertFalse(
                    [w for w in report.warnings if "not one the validator knows" in w]
                )

    def _an_unknown_script_is_a_warning_not_an_error(self) -> None:
        report = self.assertValid(VOCAB.replace("script: devanagari", "script: ethiopic"))
        self.assertTrue(any("'ethiopic' is not one" in w for w in report.warnings))

    def _a_script_that_is_not_a_lowercase_name_is_an_error(self) -> None:
        for bad in ("Bengali", "5", '""', "true", "bengali script"):
            with self.subTest(bad=bad):
                self.assertRejected(
                    VOCAB.replace("script: devanagari", f"script: {bad}"),
                    "script must be a lowercase script name",
                )

    def test_an_unknown_script_warns_and_a_malformed_one_fails(self) -> None:
        cases = (
            self._the_indic_starter_scripts_are_known,
            self._an_unknown_script_is_a_warning_not_an_error,
            self._a_script_that_is_not_a_lowercase_name_is_an_error,
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


GRAMMAR = """\
schema: 1
id: hi-en-probe
name: Probe
kind: grammar
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC-BY-SA-4.0
pattern:
  name: P
  slot_name: person
  slots: ["मैं (m)", "मैं (f)"]
  prompt: "{lemma} ({gloss}) — {slot}"
  entries:
"""


def entry(lemma: str, key: str | None = None) -> str:
    key_line = f"      key: {key}\n" if key is not None else ""
    return (f'    - lemma: "{lemma}"\n{key_line}      gloss: "g"\n'
            f'      forms: {{ "मैं (m)": "a", "मैं (f)": "b" }}\n')


class PatternKeys(Validated):
    def _an_ascii_lemma_needs_no_key(self) -> None:
        self.assertValid(GRAMMAR + entry("jaanaa"))

    def _a_devanagari_lemma_with_a_key_is_valid(self) -> None:
        self.assertValid(GRAMMAR + entry("जाना", "jaanaa") + entry("आना", "aanaa"))

    def _a_devanagari_lemma_needs_a_key(self) -> None:
        self.assertRejected(GRAMMAR + entry("जाना"), "cannot go into a card id")

    def _a_key_must_be_an_id(self) -> None:
        self.assertRejected(GRAMMAR + entry("जाना", "Jaana"), "key must match")

    def _two_rows_cannot_share_an_id_part(self) -> None:
        self.assertRejected(GRAMMAR + entry("जाना", "jaanaa") + entry("jaanaa"),
                            "already names another row")

    def _the_prompt_is_retired_optional_and_flagged_where_given(self) -> None:
        given = self.assertValid(GRAMMAR + entry("jaanaa"))
        self.assertTrue(any("prompt is retired" in w for w in given.warnings),
                        given.warnings)
        left_out = self.assertValid(
            GRAMMAR.replace('  prompt: "{lemma} ({gloss}) — {slot}"\n', "")
            + entry("jaanaa"))
        self.assertEqual(left_out.warnings, [])
        self.assertRejected(
            GRAMMAR.replace("{lemma} ({gloss}) — {slot}", "{lemma} {nope}")
            + entry("jaanaa"), "unknown placeholder")

    def test_a_lemma_that_cannot_go_into_an_id_needs_a_key(self) -> None:
        cases = (
            self._an_ascii_lemma_needs_no_key,
            self._a_devanagari_lemma_with_a_key_is_valid,
            self._a_devanagari_lemma_needs_a_key,
            self._a_key_must_be_an_id,
            self._two_rows_cannot_share_an_id_part,
            self._the_prompt_is_retired_optional_and_flagged_where_given,
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


NUMBERS = """\
schema: 1
id: hi-numbers
name: Hindi numbers
kind: numbers
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
license: CC-BY-SA-4.0
words:
  1: "एक"
  2: ["दो"]
hundreds: { 1: "एक सौ", 2: "दो सौ", 3: "दो सौ", 4: "दो सौ", 5: "दो सौ", 6: "दो सौ", 7: "दो सौ", 8: "दो सौ", 9: "दो सौ" }
thousands: { 1: "एक हज़ार", 2: "दो हज़ार", 3: "दो हज़ार", 4: "दो हज़ार", 5: "दो हज़ार", 6: "दो हज़ार", 7: "दो हज़ार", 8: "दो हज़ार", 9: "दो हज़ार" }
"""

NUMBER_DECK = """\
schema: 1
id: hi-en-numbers-big
name: Tens and big numbers
theme: numbers-big
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC-BY-SA-4.0
cards:
  - { id: hi-0001, target: "एक", native: "1", reading: "ek" }
  - { id: hi-0002, target: "दो", native: "2", reading: "do" }
  - { id: hi-0003, target: "सौ", native: "100", reading: "sau" }
  - { id: hi-0004, target: "हज़ार", native: "1000", reading: "hazaar" }
"""


class Numbers(Validated):
    """A language's number rules, and the words its number decks teach (ADR-0011)."""

    def write(self, name: str, text: str) -> validate_decks.Report:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path)

    def _a_numbers_file_is_valid(self) -> None:
        report = self.write("hi-numbers.yaml", NUMBERS)
        self.assertEqual(report.errors, [])
        self.assertEqual(report.number_words[0], "hi")
        self.assertIn("हज़ार", report.number_words[1])

    def _its_id_names_its_language(self) -> None:
        report = self.write("hi-numbers.yaml", NUMBERS.replace("id: hi-numbers", "id: hindi"))
        self.assertTrue(any("must be 'hi-numbers'" in e for e in report.errors), report.errors)

    def _hundreds_and_thousands_need_every_digit(self) -> None:
        report = self.write("hi-numbers.yaml", NUMBERS.replace(', 9: "दो सौ" }', " }"))
        self.assertTrue(any("missing [9]" in e for e in report.errors), report.errors)

    def _words_are_keyed_by_numbers_below_a_hundred(self) -> None:
        report = self.write("hi-numbers.yaml", NUMBERS.replace('  1: "एक"', '  100: "एक"'))
        self.assertTrue(any("from 1 to 99" in e for e in report.errors), report.errors)

    def _every_word_must_be_taught_by_a_number_deck(self) -> None:
        rules = self.write("hi-numbers.yaml", NUMBERS)
        deck = self.write("hi-en-numbers-big.yaml", NUMBER_DECK)
        self.assertEqual(deck.errors, [])
        self.assertEqual(validate_decks.check_numbers_across([rules, deck]), [])

        untaught = self.write("hi-en-numbers-big.yaml", NUMBER_DECK.replace('"हज़ार"', '"हजार"'))
        problems = validate_decks.check_numbers_across([rules, untaught])
        self.assertTrue(any("teaches: हज़ार" in p for p in problems), problems)

    def _rules_with_no_number_deck_are_refused(self) -> None:
        rules = self.write("hi-numbers.yaml", NUMBERS)
        problems = validate_decks.check_numbers_across([rules])
        self.assertTrue(any("no hi deck teaches a number theme" in p for p in problems), problems)

    def test_number_rules_spell_every_number_a_deck_teaches(self) -> None:
        cases = (
            self._a_numbers_file_is_valid,
            self._its_id_names_its_language,
            self._hundreds_and_thousands_need_every_digit,
            self._words_are_keyed_by_numbers_below_a_hundred,
            self._every_word_must_be_taught_by_a_number_deck,
            self._rules_with_no_number_deck_are_refused,
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


class Icons(Validated):
    """A language's icon: a letter or two, the same in all its decks (ADR-0027)."""

    def with_icon(self, icon: str) -> str:
        return VOCAB.replace("tts: hi-IN }", f"tts: hi-IN, icon: {icon} }}", 1)

    def _a_letter_or_two_is_an_icon(self) -> None:
        self.assertValid(self.with_icon('"हि"'))

    def _too_long_or_padded_is_not(self) -> None:
        for icon in ('"हिन्दी"', '" हि"'):
            with self.subTest(icon=icon):
                self.assertRejected(self.with_icon(icon), "icon must be a letter or two")

    def _across_files_a_language_gives_one_icon(self) -> None:
        def deck(name: str, text: str) -> validate_decks.Report:
            path = self.tmp / name
            path.write_text(text, encoding="utf-8")
            return validate_decks.validate(path)

        first = deck("a.yaml", self.with_icon('"हि"'))
        same = deck("b.yaml", self.with_icon('"हि"'))
        self.assertEqual(validate_decks.check_icons_across([first, same]), [])
        other = deck("c.yaml", self.with_icon('"न"'))
        none = deck("d.yaml", VOCAB)
        for odd, needle in ((other, "'न' in"), (none, "no icon in")):
            with self.subTest(needle=needle):
                problems = validate_decks.check_icons_across([first, same, odd])
                self.assertEqual(len(problems), 1, problems)
                self.assertIn("the hi decks give different icons", problems[0])
                self.assertIn(needle, problems[0])

    def test_a_language_gives_one_icon_of_a_letter_or_two(self) -> None:
        cases = (
            self._a_letter_or_two_is_an_icon,
            self._too_long_or_padded_is_not,
            self._across_files_a_language_gives_one_icon,
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


def vocab_note(note: str) -> str:
    """The probe deck, its one card carrying [note]."""
    return VOCAB + f'    notes: "{note}"\n'


class Transliteration(Validated):
    """Script quoted in prose carries its reading: లేదు (lēdu)."""

    def _a_word_with_its_reading_is_valid(self) -> None:
        self.assertValid(vocab_note("नहीं (nahī̃) is 'not', the opposite of हाँ (hā̃)."))

    def _a_word_without_its_reading_is_rejected(self) -> None:
        self.assertRejected(vocab_note("नहीं is 'not', the opposite of हाँ."),
                            "no transliteration")

    def _each_word_needs_its_own(self) -> None:
        self.assertRejected(vocab_note("नहीं (nahī̃) is 'not', the opposite of हाँ."),
                            "'हाँ'")

    def _the_reading_may_come_first(self) -> None:
        self.assertValid(vocab_note("Said nahī̃ (नहीं)."))

    def _a_question_mark_may_sit_between(self) -> None:
        self.assertValid(vocab_note("To a friend: कैसे हो? (kaise ho?)"))

    def _a_suffix_reads_with_its_hyphen(self) -> None:
        self.assertValid(vocab_note("-ने (-ne) marks the doer."))

    def _a_digit_reads_as_itself(self) -> None:
        self.assertValid(vocab_note("The digit is ३ (3)."))

    def _a_virama_alone_needs_none(self) -> None:
        self.assertValid(vocab_note("The stroke ् means no vowel follows."))

    def _the_word_fields_are_not_prose(self) -> None:
        # target is the word itself; VOCAB's card has घर with no parentheses.
        self.assertValid(VOCAB)

    def _a_fact_for_hindi_speakers_is_written_in_devanagari(self) -> None:
        text = '{ en: "हाँ (hā̃) is yes.", hi: "हाँ का अर्थ है yes।" }'
        self.assertValid(facts_file(29, fact(30, text=text)))

    def _another_script_in_it_still_needs_a_reading(self) -> None:
        text = '{ en: "হ্যাঁ (hêm̐) is yes.", hi: "बांग्ला में হ্যাঁ का अर्थ है हाँ।" }'
        self.assertRejected(facts_file(29, fact(30, text=text)), "'হ্যাঁ'")

    def _in_the_readers_own_script_is_enough(self) -> None:
        text = '{ en: "হ্যাঁ (hêm̐) is yes.", hi: "बांग्ला में হ্যাঁ (हैं) का अर्थ है हाँ।" }'
        self.assertValid(facts_file(29, fact(30, text=text)))

    def test_a_word_in_another_script_has_its_reading(self) -> None:
        cases = (
            self._a_word_with_its_reading_is_valid,
            self._a_word_without_its_reading_is_rejected,
            self._each_word_needs_its_own,
            self._the_reading_may_come_first,
            self._a_question_mark_may_sit_between,
            self._a_suffix_reads_with_its_hyphen,
            self._a_digit_reads_as_itself,
            self._a_virama_alone_needs_none,
            self._the_word_fields_are_not_prose,
            self._a_fact_for_hindi_speakers_is_written_in_devanagari,
            self._another_script_in_it_still_needs_a_reading,
            self._in_the_readers_own_script_is_enough,
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


# From test_validate_deck_parity.py.
# Decks the app's parser rejects must fail validation too.
#
# `lib/core/data/deck_parser.dart` is built never to reject a deck this validator
# accepts, because a deck that passes CI and then fails on a device is invisible
# until someone opens the app. These are the cases where PyYAML or Python used to
# be more lenient than the parser.
#
# Stdlib `unittest` plus PyYAML, like the validator itself.


DECK = """\
schema: 1
id: es-en-probe
name: Probe
language: {{ code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }}
native: {{ code: en, iso639_3: eng, name: English }}
license: CC-BY-SA-4.0
cards:
  - id: {card_id}
    target: la casa
    native: the house
{extra}"""


def deck(card_id: str = "es-0001", extra: str = "") -> str:
    return DECK.format(card_id=card_id, extra=extra)


class ParserParity(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def errors(self, text: str) -> list[str]:
        path = self.tmp / "es-en-probe.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def assertRejected(self, text: str, needle: str) -> None:
        errors = self.errors(text)
        self.assertTrue(
            any(needle in e for e in errors),
            f"expected an error containing {needle!r}, got {errors}",
        )

    def _the_probe_deck_is_valid(self) -> None:
        self.assertEqual(self.errors(deck()), [])

    def _a_duplicate_key_is_rejected(self) -> None:
        self.assertRejected(deck() + "name: Probe again\n", "duplicate key 'name'")

    def _a_duplicate_key_inside_a_card_is_rejected(self) -> None:
        self.assertRejected(deck(extra="    native: the home\n"), "duplicate key 'native'")

    def _a_merge_key_is_rejected(self) -> None:
        text = deck().replace(
            "native: { code: en, iso639_3: eng, name: English }",
            "base: &en { code: en, iso639_3: eng, name: English }\nnative: { <<: *en }",
        )
        self.assertRejected(text, "merge key")

    def _a_boolean_schema_is_rejected(self) -> None:
        for value in ("true", "yes", "on"):
            with self.subTest(value=value):
                self.assertRejected(deck().replace("schema: 1", f"schema: {value}"), "schema")

    def _an_id_ending_in_a_newline_is_rejected(self) -> None:
        self.assertRejected(deck(card_id='"es-0001\\n"'), "id must be")

    def _a_code_or_tts_tag_ending_in_a_newline_is_rejected(self) -> None:
        cases = {
            "code": ("code: es,", 'code: "es\\n",', "code must be"),
            "tts": ("tts: es-ES", 'tts: "es-ES\\n"', "tts must be"),
        }
        for name, (old, new, needle) in cases.items():
            with self.subTest(name):
                self.assertRejected(deck().replace(old, new, 1), needle)

    def _free_text_that_is_not_text_is_rejected(self) -> None:
        cases = {
            "notes on a card": deck(extra="    notes: 1990\n"),
            "gender on a card": deck(extra="    gender: 1\n"),
            "audio on a card": deck(extra="    audio: true\n"),
            "description": deck() + "description: 2019\n",
            "source": deck() + "source: 2019\n",
            "an author url": deck() + "authors: [{ name: A, url: 5 }]\n",
        }
        for name, text in cases.items():
            with self.subTest(name):
                self.assertRejected(text, "not text")

    def _free_text_that_is_a_list_or_mapping_is_rejected(self) -> None:
        # Notes may now be a list of typed notes (ADR-0036), each a mapping.
        for value, needle in (("[a]", "notes[0] must be a mapping"),
                              ("{ a: b }", "must be text")):
            with self.subTest(value=value):
                self.assertRejected(deck(extra=f"    notes: {value}\n"), needle)
        self.assertRejected(deck(extra="    gender: [a]\n"), "must be text")

    def _pattern_notes_that_are_not_text_are_rejected(self) -> None:
        text = """\
schema: 1
id: es-en-probe
name: Probe
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC-BY-SA-4.0
pattern:
  name: P
  slot_name: person
  slots: [yo]
  prompt: "{lemma} ({gloss}) {slot}"
  notes: 1990
  entries:
    - { lemma: hablar, gloss: to speak, forms: { yo: hablo } }
"""
        self.assertRejected(text, "not text")

    def _the_native_block_is_checked_like_language(self) -> None:
        cases = {
            "rtl as text": '{ code: en, iso639_3: eng, name: English, rtl: "yes" }',
            "an empty script": '{ code: en, iso639_3: eng, name: English, script: "" }',
            "a bad tts tag": '{ code: en, iso639_3: eng, name: English, tts: "en_GB" }',
        }
        for name, block in cases.items():
            with self.subTest(name):
                text = deck().replace(
                    "native: { code: en, iso639_3: eng, name: English }", f"native: {block}"
                )
                self.assertTrue(self.errors(text), f"{name} was accepted")

    def test_what_the_app_refuses_the_validator_refuses(self) -> None:
        cases = (
            self._the_probe_deck_is_valid,
            self._a_duplicate_key_is_rejected,
            self._a_duplicate_key_inside_a_card_is_rejected,
            self._a_merge_key_is_rejected,
            self._a_boolean_schema_is_rejected,
            self._an_id_ending_in_a_newline_is_rejected,
            self._a_code_or_tts_tag_ending_in_a_newline_is_rejected,
            self._free_text_that_is_not_text_is_rejected,
            self._free_text_that_is_a_list_or_mapping_is_rejected,
            self._pattern_notes_that_are_not_text_are_rejected,
            self._the_native_block_is_checked_like_language,
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


class PlainScalars(unittest.TestCase):
    """The validator reads plain (unquoted) scalars as YAML 1.2's core schema
    does, which is how the app's `package:yaml` reads them (ADR-0036). One
    case per row of the table in docs/DECK-FORMAT.md, "YAML values"; each
    value here was checked against `package:yaml` 3.1 (`loadYaml`), which
    agrees with the table in every case."""

    def read(self, scalar: str) -> object:
        return yaml.load(f"k: {scalar}\n", Loader=validate_decks.DeckLoader)["k"]

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def errors(self, text: str) -> list[str]:
        path = self.tmp / "es-en-probe.yaml"
        path.write_text(text, encoding="utf-8")
        return validate_decks.validate(path).errors

    def _true_and_false_in_three_spellings_are_booleans(self) -> None:
        for scalar, value in (("true", True), ("True", True), ("TRUE", True),
                              ("false", False), ("False", False), ("FALSE", False)):
            with self.subTest(scalar=scalar):
                self.assertIs(self.read(scalar), value)
        rtl = "native: { code: en, iso639_3: eng, name: English, rtl: True }"
        self.assertEqual(self.errors(deck().replace(
            "native: { code: en, iso639_3: eng, name: English }", rtl)), [])

    def _digits_are_a_decimal_integer(self) -> None:
        for scalar, value in (("060", 60), ("-5", -5), ("+7", 7), ("00", 0), ("1", 1)):
            with self.subTest(scalar=scalar):
                self.assertEqual(self.read(scalar), value)
                self.assertIs(type(self.read(scalar)), int)
        # 060 is 60, not YAML 1.1's octal 48, to both readers.
        self.assertEqual(self.errors(deck().replace("schema: 1", "schema: 01")), [])

    def _0o_and_0x_are_octal_and_hexadecimal(self) -> None:
        self.assertEqual(self.read("0o17"), 15)
        self.assertEqual(self.read("0x1F"), 31)
        self.assertEqual(self.read("0x1f"), 31)
        self.assertEqual(self.errors(deck().replace("schema: 1", "schema: 0x1")), [])

    def _decimals_and_infinities_are_floats(self) -> None:
        for scalar, value in (("1.5", 1.5), (".5", 0.5), ("1.", 1.0), ("1e3", 1000.0),
                              ("-1.5e-3", -0.0015), ("+.5", 0.5), (".inf", float("inf")),
                              ("-.Inf", float("-inf")), ("+.INF", float("inf"))):
            with self.subTest(scalar=scalar):
                self.assertEqual(self.read(scalar), value)
                self.assertIs(type(self.read(scalar)), float)
        for scalar in (".nan", ".NaN", ".NAN"):
            value = self.read(scalar)
            self.assertNotEqual(value, value)
        self.assertTrue(any("not text" in e
                            for e in self.errors(deck(extra="    gender: 1.5\n"))))

    def _null_in_its_spellings_is_null(self) -> None:
        for scalar in ("null", "Null", "NULL", "~", ""):
            with self.subTest(scalar=scalar):
                self.assertIsNone(self.read(scalar))
        # A null reading is a reading left out.
        self.assertEqual(self.errors(deck(extra="    gender: ~\n")), [])

    def _anything_else_is_a_string(self) -> None:
        for scalar in ("yes", "no", "on", "off", "y", "n", "Yes", "NO", "1_000", "1:30",
                       "0b101", "2001-12-14", "tRUE", "nULL", "-.nan", "+0x1F", "0O17",
                       "1e", "."):
            with self.subTest(scalar=scalar):
                self.assertEqual(self.read(scalar), scalar)
        # The hiragana の romanises to no: a bare no is that text now, as
        # in the app; YAML 1.1 read it as false.
        self.assertEqual(self.errors(deck(extra="    reading: no\n")), [])
        self.assertTrue(any("schema" in e
                            for e in self.errors(deck().replace("schema: 1",
                                                                "schema: 1_000"))))
        # A bare yes where a boolean is wanted is refused by both readers.
        self.assertTrue(any("phrasebook must be true" in e
                            for e in self.errors(deck(extra="    phrasebook: yes\n"))))

    def _a_plain_key_resolves_as_a_value_does(self) -> None:
        keys = yaml.load("on: 1\nno: 2\n7: 3\nfalse: 4\n",
                         Loader=validate_decks.DeckLoader)
        self.assertEqual(list(keys), ["on", "no", 7, False])

    def test_plain_values_are_typed_as_yaml_1_2_types_them(self) -> None:
        cases = (
            self._true_and_false_in_three_spellings_are_booleans,
            self._digits_are_a_decimal_integer,
            self._0o_and_0x_are_octal_and_hexadecimal,
            self._decimals_and_infinities_are_floats,
            self._null_in_its_spellings_is_null,
            self._anything_else_is_a_string,
            self._a_plain_key_resolves_as_a_value_does,
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
