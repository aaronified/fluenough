#!/usr/bin/env python3
"""The B1 deck format in the validator (ADR-0035): cores and layers, the
phrasebook, rules decks, sentences' rules, typed notes, the Wiktionary mark,
bases, and the B1 plan in a path.

Each test copies tools/fixtures/b1/zz, Appendix A of the format's spec in a
made-up language with no decks in the repository, into a temporary
directory, breaks one thing, and checks the exact message and where. The
fixture itself is the passing case of every rule; a rule with more than one
valid shape has its own passing case too.

Stdlib `unittest` plus PyYAML, like the validator itself.
"""

from __future__ import annotations

import contextlib
import io
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_decks  # noqa: E402

TOOLS = Path(__file__).resolve().parent
FIXTURE = TOOLS / "fixtures" / "b1" / "zz"
CORE = "zz-home.yaml"
LAYER = "en/zz-en-home.yaml"
RULES = "zz-grammar-case-endings.yaml"
RULES_LAYER = "en/zz-en-grammar-case-endings.yaml"
PATH = "zz-en-path.yaml"
EXTRA = "zz-en-extra.yaml"

LANGUAGE = {"code": "zz", "iso639_3": "zzz", "name": "Testlang", "script": "telugu",
            "tts": "te-IN", "icon": "తె"}
NATIVES = {"en": {"code": "en", "iso639_3": "eng", "name": "English"},
           "bn": {"code": "bn", "iso639_3": "ben", "name": "Bengali"}}
CAT = {"id": "zz-9501", "target": "పిల్లి", "reading": "pilli", "native": "cat",
       "pos": "noun"}


def load(path: Path) -> object:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=validate_decks.DeckLoader)


def dump(data: object) -> str:
    return yaml.safe_dump(data, allow_unicode=True, sort_keys=False, width=1000)


def single(deck_id: str = "zz-en-extra", cards: list | None = None,
           native: str = "en", **extra: object) -> dict:
    """A single-file deck of the zz language."""
    deck = {"schema": 1, "id": deck_id, "name": "Extra", "language": dict(LANGUAGE),
            "native": dict(NATIVES[native]), "license": "CC0-1.0",
            "cards": cards if cards is not None else [dict(CAT)]}
    deck.update(extra)
    return deck


def card(deck: dict, cid: str) -> dict:
    """A card of a core or a single-file deck, by its id or ref."""
    return next(c for c in deck["cards"] if cid in (c.get("id"), c.get("ref")))


class B1Case(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.dir = self.tmp / "zz"
        shutil.copytree(FIXTURE, self.dir)

    # Files ------------------------------------------------------------------

    def p(self, rel: str) -> Path:
        return self.dir / rel

    def data(self, rel: str) -> dict:
        return load(self.p(rel))

    def put(self, rel: str, data: object) -> Path:
        path = self.p(rel)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data if isinstance(data, str) else dump(data), encoding="utf-8")
        return path

    def edit(self, rel: str, change) -> None:
        data = self.data(rel)
        change(data)
        self.put(rel, data)

    def drop_phrasebook_card(self, cid: str) -> None:
        """Takes a card out of the core and its layer."""
        self.edit(CORE, lambda d: d["cards"].remove(card(d, cid)))
        self.edit(LAYER, lambda d: d["cards"].pop(cid))

    # Running ----------------------------------------------------------------

    def errors(self, rel: str) -> list[str]:
        """The errors of one file, validated alone."""
        return validate_decks.validate(self.p(rel)).errors

    def run_main(self, *rels: str) -> list[str]:
        """The validator's output, on the files given or the whole tree."""
        targets = [str(self.p(r)) for r in rels] or [str(self.dir)]
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            self.code = validate_decks.main(["validate_decks.py", *targets])
        return out.getvalue().splitlines()

    def section(self, lines: list[str], rel: str) -> list[str]:
        """The lines printed under one file's header."""
        header = None
        found: list[str] = []
        for line in lines:
            if line.split(" ", 1)[0] in ("FAIL", "warn", "info"):
                header = line.split(" ", 1)[1]
            elif line.startswith("  ") and header == str(self.p(rel)):
                found.append(line)
        return found

    # Assertions -------------------------------------------------------------

    def assertError(self, rel: str, where: str, msg: str) -> None:
        errors = self.errors(rel)
        self.assertIn(f"{where}: {msg}", errors)

    def assertNoError(self, rel: str, needle: str = "") -> None:
        errors = [e for e in self.errors(rel) if needle in e]
        self.assertEqual(errors, [])

    def assertAcross(self, line: str, *rels: str) -> None:
        lines = self.run_main(*rels)
        self.assertIn(f"error: {line}", lines)

    def assertNotAcross(self, needle: str, *rels: str) -> None:
        lines = self.run_main(*rels)
        self.assertEqual([x for x in lines if x.startswith("error:") and needle in x], [])

    def assertWarned(self, rel: str, where: str, msg: str, *rels: str) -> None:
        self.assertIn(f"  warning {where}: {msg}", self.section(self.run_main(*rels), rel))

    def assertInfo(self, rel: str, where: str, msg: str, *rels: str) -> None:
        self.assertIn(f"  info    {where}: {msg}", self.section(self.run_main(*rels), rel))

    def assertClean(self, *rels: str) -> list[str]:
        """No error, per file or across."""
        lines = self.run_main(*rels)
        self.assertEqual([x for x in lines if x.startswith(("error", "FAIL", "  error"))],
                         [])
        self.assertEqual(self.code, 0)
        return lines


class TheFixture(B1Case):
    """Appendix A: valid together, with its infos and its path's warnings."""

    def test_the_tree_validates_with_infos_and_level_warnings(self) -> None:
        lines = self.assertClean()
        self.assertEqual(self.section(lines, LAYER),
                         ["  info    cards: covers 20 of 20 cards of zz-home (100%)"])
        self.assertEqual(self.section(lines, RULES_LAYER),
                         ["  info    rules: covers 4 of 4 rules of zz-grammar-case-endings"])
        self.assertEqual(self.section(lines, PATH), [
            "  warning units: plans 64 words up to B1, outside 2,000–3,500; check the sizes",
            "  warning units: A1 plans 4 words, far from about 700 (350–1,050)",
            "  warning units: A2 plans 0 words, far from about 900 (450–1,350)",
            "  warning units: B1 plans 60 words, far from about 1,200 (600–1,800)",
            "  info    units: B1 plan: A1 4 words (about 700), A2 +0 (about 900), B1 +60 "
            "(about 1,200); 64 in all; 4 grammar topics; 1 units planned",
        ])
        self.assertIn("info " + str(self.p(LAYER)), lines)
        self.assertEqual(lines[-1], "5/5 decks valid, 1 with warnings.")

    def test_each_file_validates_alone_against_the_rest_on_disk(self) -> None:
        for rel in (CORE, LAYER, RULES, RULES_LAYER):
            with self.subTest(rel=rel):
                self.assertClean(rel)
        # A path alone lists decks not given, as on main; nothing else.
        lines = self.run_main(PATH)
        self.assertEqual([x for x in lines if x.startswith("error")
                          and not x.endswith("which is not a deck")], [])
        self.assertIn("  info    units: B1 plan: A1 4 words (about 700), A2 +0 (about 900), "
                      "B1 +60 (about 1,200); 64 in all; 4 grammar topics; 1 units planned",
                      lines)

    def test_the_fixture_in_the_repository_validates(self) -> None:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = validate_decks.main(["validate_decks.py", str(FIXTURE)])
        self.assertEqual(code, 0, out.getvalue())


class Dispatch(B1Case):
    """Section 2.2: a layer, then a core, then anything else as today."""

    def test_a_file_both_layer_and_core_is_a_layer_with_a_part_error(self) -> None:
        self.edit(LAYER, lambda d: d.update(part="core"))
        self.assertError(LAYER, "part", 'a layer has no part; only a core is marked '
                                        'part: "core"')
        self.assertEqual(validate_decks.validate(self.p(LAYER)).part, "layer")
        self.assertNoError(CORE)

    def test_another_part_is_an_error_and_the_file_a_single_file_deck(self) -> None:
        self.put(EXTRA, single(part="layer"))
        self.assertError(EXTRA, "part", 'must be "core", or left out on a single-file '
                                        "deck; got 'layer'")
        self.assertNotIn("root: unknown field 'part'", self.errors(EXTRA))
        self.put(EXTRA, single())
        self.assertNoError(EXTRA)

    def test_a_single_file_deck_refuses_what_belongs_to_cores_and_layers(self) -> None:
        cases = {
            "core": ({"core": "zz-home"}, "core", 'only a layer names a core (kind: "layer")'),
            "table": ({"table": {}}, "table", "only a rules core has table; a rules deck "
                                              "is written as a core and layers"),
            "rules": ({"rules": []}, "rules", "only a rules core has rules; a rules deck "
                                              "is written as a core and layers"),
            "kind": ({"kind": "rules"}, "kind", 'a rules deck is written as a core and '
                                                'layers; see "Rules decks" in '
                                                'docs/DECK-FORMAT.md'),
        }
        for name, (extra, where, msg) in cases.items():
            with self.subTest(name):
                self.put(EXTRA, single(**extra))
                self.assertError(EXTRA, where, msg)
                self.assertFalse(any("unknown field" in e for e in self.errors(EXTRA)))


class CoreHeader(B1Case):
    """Sections 2.1 and 2.2: a core's header and id."""

    def test_the_learners_language_is_in_each_layer(self) -> None:
        cases = {
            "native": ("native", "a core file has no native: the language it is taught "
                                 "from is in each layer, in decks/zz/<native>/"),
            "name": ("name", "a core file's name is in each layer, in the learner's "
                             "language"),
            "description": ("description", "a core file's description is in each layer, "
                                           "in the learner's language"),
        }
        for key, (where, msg) in cases.items():
            with self.subTest(key):
                self.setUp()
                value = dict(NATIVES["en"]) if key == "native" else "Home"
                self.edit(CORE, lambda d: d.update({key: value}))
                self.assertError(CORE, where, msg)
        self.setUp()
        self.edit(CORE, lambda d: d.update(colour="blue"))
        self.assertError(CORE, "root", "unknown field 'colour'")

    def test_the_id_is_the_language_and_a_name_and_the_stem(self) -> None:
        for bad in ("zz-house", "zz-Home", "home"):
            with self.subTest(bad=bad):
                self.edit(CORE, lambda d: d.update(id=bad))
                self.assertError(CORE, "id", f"must be zz- and a name, the filename "
                                             f"stem, got {bad!r}")

    def test_the_names_of_the_files_beside_the_decks_are_reserved(self) -> None:
        names = {"facts": "facts file", "numbers": "number rules",
                 "romanisation": "romanisation file", "script": "script guide",
                 "sounds": "sounds file", "path": "path"}
        for name, what in names.items():
            with self.subTest(name):
                rel = f"zz-{name}.yaml"
                self.put(rel, dict(self.data(CORE), id=f"zz-{name}"))
                self.assertError(rel, "id", f"'zz-{name}' is the name of the language's "
                                            f"{what}; give the core another name")
                self.p(rel).unlink()

    def test_a_core_name_does_not_start_with_a_native_code(self) -> None:
        # en is the folder of the English layers.
        self.put("zz-en-things.yaml", dict(self.data(CORE), id="zz-en-things"))
        self.assertError("zz-en-things.yaml", "id",
                         "'zz-en-things' reads as a deck of the zz-en course; a core's "
                         "name does not start with a native language's code")
        # bn is the native of a single-file deck, with no folder.
        self.put("zz-bn-words.yaml", single("zz-bn-words", native="bn"))
        self.put("zz-bn-things.yaml", dict(self.data(CORE), id="zz-bn-things"))
        self.assertError("zz-bn-things.yaml", "id",
                         "'zz-bn-things' reads as a deck of the zz-bn course; a core's "
                         "name does not start with a native language's code")
        self.put("zz-big-things.yaml", dict(self.data(CORE), id="zz-big-things"))
        self.assertNoError("zz-big-things.yaml", "reads as a deck")

    def test_a_core_id_is_its_own_even_when_validated_alone(self) -> None:
        self.put("en/zz-thing.yaml", "schema: 1\n")
        self.put("zz-thing.yaml", dict(self.data(CORE), id="zz-thing"))
        self.assertError("zz-thing.yaml", "id",
                         f"'zz-thing' is also the id of {self.p('en/zz-thing.yaml')}; a "
                         f"core's id is its own")
        # The duplicate-stem check catches the two only when given together.
        self.p("en/zz-thing.yaml").unlink()
        self.assertNoError("zz-thing.yaml", "also the id")

    def test_a_core_lives_in_its_languages_folder(self) -> None:
        self.put("en/zz-away.yaml", dict(self.data(CORE), id="zz-away"))
        self.assertError("en/zz-away.yaml", "root",
                         "a core file lives in decks/zz/, the folder of its language; "
                         "this one is in 'en'")
        self.assertNoError(CORE, "lives in")

    def test_a_core_is_vocab_grammar_or_rules(self) -> None:
        self.edit(CORE, lambda d: d.update(kind="reading"))
        self.assertError(CORE, "kind", "a core is vocab, grammar or rules, got 'reading'; "
                                       "a reading deck stays a single-file deck")
        self.edit(CORE, lambda d: d.update(kind="facts"))
        errors = [e for e in self.errors(CORE) if e.startswith("kind:")]
        self.assertEqual(errors, ["kind: a core is vocab, grammar or rules, got 'facts'"])

    def test_content_belongs_to_one_kind_of_core(self) -> None:
        self.edit(CORE, lambda d: d.update(table={}, pattern={}))
        self.assertError(CORE, "table", "only a rules core has table")
        self.assertError(CORE, "pattern", "only a grammar core has a pattern")
        self.edit(RULES, lambda d: d.update(cards=[]))
        self.assertError(RULES, "cards", "only a vocab core has cards")

    def test_a_core_gives_its_languages_icon(self) -> None:
        self.edit(RULES, lambda d: d["language"].update(icon="Z"))
        lines = self.run_main()
        self.assertTrue(any(x.startswith("error: the zz decks give different icons")
                            for x in lines), lines)


class CoreCards(B1Case):
    """Section 2.3: a core card has the language side only."""

    def test_the_native_side_is_in_each_layer(self) -> None:
        for key, value in (("native", "home"), ("alt_native", ["house"]),
                           ("wiktionary", True)):
            with self.subTest(key):
                self.setUp()
                self.edit(CORE, lambda d: card(d, "zz-9001").update({key: value}))
                self.assertError(CORE, "card zz-9001", f"a core card's {key!r} is in each "
                                                       f"layer, under cards.zz-9001")

    def test_a_core_card_has_no_pair_a_pair_note_names_the_partner(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(pair="zz-9004"))
        self.assertError(CORE, "card zz-9001",
                         'pair: in a core file a pair note names the partner, { kind: '
                         '"pair", ref: ... }; Hear takes its sound-alike from there')

    def test_a_core_card_has_its_target(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").pop("target"))
        self.assertError(CORE, "card zz-9001", "target is required and must be a "
                                               "non-empty string")

    def test_a_core_ref_gives_no_native_side(self) -> None:
        self.put(EXTRA, single())
        self.edit(CORE, lambda d: d["cards"].append({"ref": "zz-9501", "native": "cat"}))
        self.assertError(CORE, "ref zz-9501", "a core card's 'native' is in each layer, "
                                              "under cards.zz-9501")
        self.edit(CORE, lambda d: card(d, "zz-9501").pop("native"))
        self.assertNoError(CORE)

    def test_a_core_example_is_named_by_its_target(self) -> None:
        examples = [{"target": "ఇల్లు పెద్దది.", "reading": "illu peddadi."},
                    {"target": "ఇల్లు పెద్దది.", "reading": "illu peddadi."}]
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=examples))
        self.assertError(CORE, "card zz-9001", "examples[1] has the same target as "
                                               "examples[0]; a layer names an example by "
                                               "its target")
        self.edit(CORE, lambda d: card(d, "zz-9001")["examples"].pop())
        self.assertNoError(CORE)
        self.edit(CORE, lambda d: card(d, "zz-9001")["examples"][0].update(native="x"))
        self.assertError(CORE, "card zz-9001", "examples[0]: a core example's 'native' is "
                                               "in each layer, under cards.zz-9001.examples")

    def test_keys_that_are_texts_are_nfc_already(self) -> None:
        decomposed = "café"
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            examples=[{"target": f"ఇల్లు {decomposed}", "reading": "illu cafe"}]))
        self.assertError(CORE, "card zz-9001", "examples[0].target is not NFC-normalised; "
                                               "a layer names the example by it")
        self.edit(CORE, lambda d: card(d, "zz-9002")["bases"][0].update(
            word="ఇంటికి".replace("ి", "ి")))  # unchanged: already NFC
        self.assertNoError(CORE, "bases[0].word is not NFC")
        self.edit(CORE, lambda d: card(d, "zz-9002").update(
            target=f"నేను {decomposed} వెళ్తాను.",
            bases=[{"word": decomposed, "ref": "zz-9001"},
                   {"word": "వెళ్తాను", "ref": "zz-9003"}]))
        self.assertError(CORE, "card zz-9002", "bases[0].word is not NFC-normalised")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={f"ఇల్లు {decomposed}": "house café"}))
        self.assertError(LAYER, "cards.zz-9001.examples",
                         f"key {'ఇల్లు ' + decomposed!r} is not NFC-normalised")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].pop("examples"))
        self.edit(LAYER, lambda d: d["cards"]["zz-9002"].update(bases={decomposed: "x"}))
        self.assertError(LAYER, "cards.zz-9002.bases",
                         f"key {decomposed!r} is not NFC-normalised")
        self.edit(LAYER, lambda d: d["cards"]["zz-9002"].pop("bases"))
        self.assertNoError(LAYER, "NFC")


class CardIds(B1Case):
    """Section 2.4: one namespace of card ids, cores and layers included."""

    def test_a_core_card_written_again_in_a_single_file_deck_is_caught(self) -> None:
        self.put(EXTRA, single(cards=[{"id": "zz-9001", "target": "ఇల్లు",
                                        "reading": "illu", "native": "house"}]))
        self.assertAcross(f"{self.p(EXTRA)}: card zz-9001 is already written in "
                          f"{self.p(CORE)}; list it here with ref: zz-9001", EXTRA)
        self.put(EXTRA, single(cards=[{"ref": "zz-9001"}]))
        self.assertNotAcross("zz-9001", EXTRA)

    def test_a_layer_only_card_is_written_once_too(self) -> None:
        self.put(EXTRA, single())
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9501": {
            "target": "పిల్లి", "reading": "pilli", "native": "cat", "pos": "noun"}}))
        self.assertAcross(f"{self.p(LAYER)}: card zz-9501 is already written in "
                          f"{self.p(EXTRA)}; list it here with ref: zz-9501", LAYER)

    def test_a_ref_to_a_core_card_resolves_through_a_layer_of_its_native(self) -> None:
        self.put(EXTRA, single(cards=[{"ref": "zz-9001"}]))
        self.assertNotAcross("zz-9001", EXTRA)
        self.put("zz-bn-extra.yaml", single("zz-bn-extra", [{"ref": "zz-9001"}], "bn"))
        self.assertAcross(f"{self.p('zz-bn-extra.yaml')}: ref zz-9001: the card is "
                          f"written for learners from ['en']; this deck is taught from "
                          f"'bn', so the ref needs its own native", "zz-bn-extra.yaml")
        self.put("zz-bn-extra.yaml", single("zz-bn-extra", [
            {"ref": "zz-9001", "native": "বাড়ি (bāṛi)"}], "bn"))
        self.assertNotAcross("zz-9001", "zz-bn-extra.yaml")

    def test_a_core_ref_must_name_a_written_card(self) -> None:
        self.edit(CORE, lambda d: d["cards"].append({"ref": "zz-9999"}))
        self.assertAcross(f"{self.p(CORE)}: ref zz-9999: no deck writes card zz-9999")

    def test_next_id_sees_a_cores_card_and_a_layer_only_card(self) -> None:
        decks = self.tmp / "decks"
        decks.mkdir()
        shutil.copytree(self.dir, decks / "zz")
        root = validate_decks.ROOT
        validate_decks.ROOT = self.tmp
        self.addCleanup(setattr, validate_decks, "ROOT", root)
        self.assertEqual(validate_decks.next_card_id("zz"), "zz-9116")
        layer = decks / "zz" / LAYER
        data = load(layer)
        data["cards"]["zz-9200"] = {"target": "పిల్లి", "reading": "pilli",
                                    "native": "cat", "pos": "noun"}
        layer.write_text(dump(data), encoding="utf-8")
        self.assertEqual(validate_decks.next_card_id("zz"), "zz-9201")


class GrammarCore(B1Case):
    """Section 2.5: a grammar core keeps the language side of its table."""

    CORE_FILE = "zz-grammar-past.yaml"
    LAYER_FILE = "en/zz-en-grammar-past.yaml"

    def setUp(self) -> None:
        super().setUp()
        self.put(self.CORE_FILE, {
            "schema": 1, "id": "zz-grammar-past", "part": "core", "kind": "grammar",
            "language": dict(LANGUAGE), "license": "CC0-1.0",
            "pattern": {"slots": ["నేను", "నువ్వు"], "entries": [{
                "lemma": "వెళ్ళు", "key": "vellu", "reading": "veḷḷu",
                "forms": {"నేను": "వెళ్ళాను", "నువ్వు": "వెళ్ళావు"},
                "readings": {"నేను": "veḷḷānu", "నువ్వు": "veḷḷāvu"}}]}})
        self.put(self.LAYER_FILE, {
            "schema": 1, "id": "zz-en-grammar-past", "kind": "layer",
            "core": "zz-grammar-past", "native": dict(NATIVES["en"]),
            "name": "Past tense", "license": "CC0-1.0",
            "pattern": {"name": "Past tense", "slot_name": "person",
                        "prompt": "{lemma} ({gloss}) — {slot}",
                        "slots": {"నేను": "I, నేను (nēnu)", "నువ్వు": "you, నువ్వు (nuvvu)"},
                        "entries": {"vellu": "to go"},
                        "notes": "The past adds -ఆ- (-ā-) before the person ending."}})

    def test_the_grammar_core_and_its_layer_are_valid(self) -> None:
        self.assertClean(self.CORE_FILE, self.LAYER_FILE)

    def test_the_names_and_glosses_are_each_layers(self) -> None:
        for key in ("name", "slot_name", "prompt", "notes"):
            with self.subTest(key):
                self.edit(self.CORE_FILE, lambda d: d["pattern"].update({key: "x"}))
                self.assertError(self.CORE_FILE, "pattern", f"a core pattern's {key!r} is "
                                                            f"in each layer, under pattern")
                self.edit(self.CORE_FILE, lambda d: d["pattern"].pop(key))
        self.edit(self.CORE_FILE, lambda d: d["pattern"]["entries"][0].update(gloss="go"))
        self.assertError(self.CORE_FILE, "pattern.entries[వెళ్ళు]",
                         "a core entry's gloss is in each layer, under "
                         "pattern.entries.vellu")

    def test_the_layer_glosses_every_entry_and_names_only_the_cores(self) -> None:
        self.edit(self.LAYER_FILE, lambda d: d["pattern"].update(entries={"ra": "come"}))
        self.assertError(self.LAYER_FILE, "pattern.entries", "gives no gloss for 'vellu'")
        self.assertError(self.LAYER_FILE, "pattern.entries", "'ra' is not an entry of the "
                                                             "core")
        self.edit(self.LAYER_FILE, lambda d: d["pattern"]["slots"].update(
            {"వాళ్ళు": "they, వాళ్ళు (vāḷḷu)"}))
        self.assertError(self.LAYER_FILE, "pattern.slots", "'వాళ్ళు' is not a slot of the core")
        self.edit(self.LAYER_FILE, lambda d: d["pattern"].pop("name"))
        self.assertError(self.LAYER_FILE, "pattern", "name is required")

    def test_slots_labels_are_optional(self) -> None:
        self.edit(self.LAYER_FILE, lambda d: d["pattern"].pop("slots"))
        self.assertNoError(self.LAYER_FILE)


class LayerHeader(B1Case):
    """Section 2.6: a layer's header, and its core."""

    def test_the_core_is_a_core_file_in_the_folder_above(self) -> None:
        cases = {
            "Zz Home": "must be the id of a core file, such as 'te-home', got 'Zz Home'",
            "zz-nothing": f"no core file zz-nothing.yaml in {self.dir}; a layer's core is "
                          f"in the folder above it",
            "zz-en-path": 'zz-en-path.yaml is not a core: it has no part: "core"',
        }
        for core, msg in cases.items():
            with self.subTest(core):
                self.edit(LAYER, lambda d: d.update(core=core))
                # Only the core error: without its core nothing else is checked.
                self.assertEqual(self.errors(LAYER), [f"core: {msg}"])

    def test_the_id_is_the_cores_with_its_native(self) -> None:
        self.edit(LAYER, lambda d: d.update(id="zz-en-house"))
        self.assertError(LAYER, "id", "a layer of zz-home taught from en has id "
                                      "'zz-en-home', got 'zz-en-house'")
        self.assertError(LAYER, "id", "is 'zz-en-house' but the filename stem is "
                                      "'zz-en-home'")

    def test_a_layer_lives_in_its_natives_folder(self) -> None:
        self.put("bn/zz-en-home.yaml", self.data(LAYER))
        self.assertError("bn/zz-en-home.yaml", "root",
                         "a layer lives in decks/zz/en/, the folder of its native "
                         "language; this one is in 'bn'")
        self.assertNoError(LAYER, "root")

    def test_the_language_and_theme_are_the_cores(self) -> None:
        self.edit(LAYER, lambda d: d.update(language=dict(LANGUAGE), theme="home",
                                            colour="blue"))
        self.assertError(LAYER, "language", "a layer takes its language from its core, "
                                            "zz-home")
        self.assertError(LAYER, "theme", "a layer takes its theme from its core, zz-home")
        self.assertError(LAYER, "root", "unknown field 'colour'")

    def test_a_layer_has_what_its_cores_kind_has(self) -> None:
        self.edit(LAYER, lambda d: d.update(pattern={}, table={}))
        self.assertError(LAYER, "pattern", "only a layer of a grammar core has pattern")
        self.assertError(LAYER, "table", "only a layer of a rules core has table")
        self.edit(RULES_LAYER, lambda d: d.update(cards={}))
        self.assertError(RULES_LAYER, "cards", "only a layer of a vocab core has cards")
        self.edit(LAYER, lambda d: d.update(cards=[]))
        self.assertError(LAYER, "cards", "a layer's cards is a mapping of card id to what "
                                         "this language gives it")

    def test_every_key_is_a_string(self) -> None:
        self.put(LAYER, self.p(LAYER).read_text(encoding="utf-8")
                 .replace('"zz-9002":', '"zz-9002":\n    1: "x"', 1))
        self.assertError(LAYER, "cards.zz-9002", "key 1 was read as int; quote it")
        self.put(LAYER, self.p(LAYER).read_text(encoding="utf-8") + "2.5: \"x\"\n")
        self.assertError(LAYER, "root", "key 2.5 was read as float; quote it")

    def test_the_script_checks_run_with_the_cores_language(self) -> None:
        # A layer-only card without a reading, in the core's script.
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9200": {
            "target": "పిల్లి", "native": "cat", "pos": "noun"}}))
        report = validate_decks.validate(self.p(LAYER))
        self.assertIn("cards.zz-9200: no reading, but script is 'telugu'; learners will "
                      "need one", report.warnings)
        # The romanisation file is beside the core, not the layer.
        self.put("zz-romanisation.yaml", {
            "schema": 1, "kind": "romanisation", "id": "zz-romanisation",
            "language": "zz", "scheme": "ISO 15919.", "standard": "ISO 15919",
            "equivalents": []})
        self.edit(LAYER, lambda d: d["cards"]["zz-9200"].update(reading="Pilli"))
        self.assertError(LAYER, "reading", "'Pilli' is not in the zz romanisation: "
                                           "lowercase ISO 15919 letters, no capitals")
        self.edit(LAYER, lambda d: d["cards"]["zz-9200"].update(reading="pilli"))
        self.assertNoError(LAYER)


class LayerCards(B1Case):
    """Section 2.6: a layer's entries for its core's cards, and its own."""

    def with_ref(self) -> None:
        """The core lists zz-9501, written in a single-file deck, by ref."""
        self.put(EXTRA, single())
        self.edit(CORE, lambda d: d["cards"].append({"ref": "zz-9501"}))

    def test_an_entry_gives_only_the_native_side(self) -> None:
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(target="x", pos="noun"))
        for key in ("pos", "target"):
            self.assertError(LAYER, "cards.zz-9001",
                             f"{key!r} belongs to the word, in the core; a layer gives "
                             f"native, alt_native, notes, examples, bases and wiktionary")

    def test_a_card_the_core_writes_needs_its_native(self) -> None:
        self.edit(LAYER, lambda d: d["cards"]["zz-9004"].pop("native"))
        self.assertError(LAYER, "cards.zz-9004", "native is required: without it the card "
                                                 "is not taught from English")

    def test_a_ref_entry_may_leave_native_out(self) -> None:
        self.with_ref()
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9501": {"wiktionary": True}}))
        self.assertNoError(LAYER)
        self.assertInfo(LAYER, "cards", "covers 21 of 21 cards of zz-home (100%)")

    def test_a_ref_entry_names_notes_and_examples_only_where_the_ref_gives_them(self) -> None:
        self.with_ref()
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9501": {
            "notes": {"x": "y"}, "examples": {"x": "y"}}}))
        self.assertError(LAYER, "cards.zz-9501.notes", "the core lists zz-9501 by ref "
                                                       "without notes; give them in the "
                                                       "core's ref")
        self.assertError(LAYER, "cards.zz-9501.examples", "the core lists zz-9501 by ref "
                                                          "without examples; give them in "
                                                          "the core's ref")
        self.edit(CORE, lambda d: card(d, "zz-9501").update(
            notes=[{"id": "tail", "kind": "usage"}]))
        self.edit(LAYER, lambda d: d["cards"]["zz-9501"].update(notes={"tail": "Curly."}))
        self.edit(LAYER, lambda d: d["cards"]["zz-9501"].pop("examples"))
        self.assertNoError(LAYER)

    def test_an_entry_for_no_card_of_the_core_gives_its_target(self) -> None:
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9300": {"native": "dog"},
                                                       "dog": {"native": "dog"}}))
        self.assertError(LAYER, "cards.zz-9300", "zz-9300 is not a card of zz-home; a card "
                                                 "only this layer has gives its target too")
        self.assertError(LAYER, "cards.dog", "id must be zz- and at least four digits, such "
                                             "as zz-0001, got 'dog'")

    def test_a_layer_only_card_is_a_full_card(self) -> None:
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9200": {
            "target": "పిల్లి", "reading": "pilli", "pos": "noun", "pair": "zz-9001",
            "notes": [{"kind": "pair", "ref": "zz-9001", "text": "Not ఇల్లు (illu)."}]}}))
        self.assertError(LAYER, "cards.zz-9200", "native is required and must be a "
                                                 "non-empty string")
        self.edit(LAYER, lambda d: d["cards"]["zz-9200"].update(native="cat"))
        self.assertNoError(LAYER)

    def test_notes_name_the_cores_notes(self) -> None:
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(notes="Before an ending."))
        self.assertError(LAYER, "cards.zz-9001.notes", "a mapping of the core note's id to "
                                                       "its text")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(notes={"nope": "x",
                                                                      "stem": ""}))
        self.assertError(LAYER, "cards.zz-9001.notes.nope", "the core card has no note 'nope'")
        self.assertError(LAYER, "cards.zz-9001.notes.stem", "must be non-empty text")

    def test_examples_and_bases_name_the_cores(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            examples=[{"target": "ఇల్లు రా.", "reading": "illu rā.",
                       "bases": [{"word": "రా", "base": "రా", "reading": "rā"}]}]))
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            bases=[{"word": "ఇల్లు", "base": "ఇల్లు", "reading": "illu"}]))
        good = {"examples": {"ఇల్లు రా.": {"native": "Home, come.",
                                          "bases": {"రా": "to come"}}},
                "bases": {"ఇల్లు": {"meaning": "house", "wiktionary": True}}}
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(good))
        self.assertNoError(LAYER)
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={"ఇల్లు పో.": "Home, go."}, bases={"ఇంటికి": "home"}))
        self.assertError(LAYER, "cards.zz-9001.examples.ఇల్లు పో.",
                         "the core card has no example with this target")
        self.assertError(LAYER, "cards.zz-9001.bases.ఇంటికి",
                         "the core card has no inline base for 'ఇంటికి'; a base given by "
                         "ref takes its meaning from that card")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(examples=["x"]))
        self.assertError(LAYER, "cards.zz-9001.examples",
                         "a mapping of an example's target, as the core writes it, to its "
                         "translation")
        # A base given by ref takes its meaning from its card.
        self.edit(LAYER, lambda d: d["cards"]["zz-9002"].update(bases={"ఇంటికి": "home"}))
        self.assertError(LAYER, "cards.zz-9002.bases.ఇంటికి",
                         "the core card has no inline base for 'ఇంటికి'; a base given by "
                         "ref takes its meaning from that card")

    def test_what_the_layer_leaves_out_is_warned_of(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            examples=[{"target": "ఇల్లు రా.", "reading": "illu rā."}],
            bases=[{"word": "ఇల్లు", "base": "ఇల్లు", "reading": "illu"}]))
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].pop("notes"))
        warnings = validate_decks.validate(self.p(LAYER)).warnings
        self.assertIn("cards.zz-9001: note 'stem' has no text here, so learners from "
                      "English do not see it", warnings)
        self.assertIn("cards.zz-9001: example 'ఇల్లు రా.' has no translation here, so it "
                      "is not shown", warnings)
        self.assertIn("cards.zz-9001: the inline base 'ఇల్లు' has no meaning here; it is "
                      "shown without one", warnings)
        self.assertEqual(validate_decks.validate(self.p(CORE)).warnings, [])

    def test_coverage_is_an_info_line(self) -> None:
        self.edit(LAYER, lambda d: d["cards"].pop("zz-9002"))
        self.assertInfo(LAYER, "cards", "covers 19 of 20 cards of zz-home (95%)")

    def test_placeholders_in_a_layers_note_count_the_cores_words(self) -> None:
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"]["notes"].update(
            stem="{1} or {2}, not {0}."))
        self.assertError(LAYER, "cards.zz-9001.notes.stem", "uses {2}, but the note has 1 "
                                                            "words")
        self.assertError(LAYER, "cards.zz-9001.notes.stem", "{0} is not a placeholder: "
                                                            "placeholders count from {1}, "
                                                            "without leading zeros")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"]["notes"].update(stem="No words."))
        self.assertIn("cards.zz-9001.notes.stem: never uses {1}, ఇంటి-",
                      validate_decks.validate(self.p(LAYER)).warnings)


class LayersAcross(B1Case):
    """Sections 2.8 and 10.4: layers as decks of their course."""

    def in_repository(self) -> Path:
        """The tree under a decks/ of its own, as the repository is."""
        decks = self.tmp / "repo" / "decks"
        decks.mkdir(parents=True)
        shutil.move(str(self.dir), str(decks / "zz"))
        self.dir = decks / "zz"
        root = validate_decks.ROOT
        validate_decks.ROOT = self.tmp / "repo"
        self.addCleanup(setattr, validate_decks, "ROOT", root)
        return decks

    def test_a_layer_validated_alone_finds_its_path_beside_its_core(self) -> None:
        self.in_repository()
        self.assertNotAcross("has no path", LAYER)
        self.p(PATH).unlink()
        self.assertAcross(f"{self.p(LAYER)}: zz from en has no path; add zz-en-path.yaml "
                          f"beside its decks", LAYER)

    def test_a_core_no_layer_names_is_warned_of(self) -> None:
        self.assertEqual(self.section(self.run_main(CORE), CORE), [])
        self.p(LAYER).unlink()
        self.assertWarned(CORE, "root", "no layer names this core, so no learner is "
                                        "taught it", CORE)

    def test_every_layer_of_the_course_is_on_its_path(self) -> None:
        self.edit(PATH, lambda d: d["units"][0].update(decks=["zz-en-extra"]))
        self.put(EXTRA, single())
        self.assertAcross(f"{self.p(PATH)}: does not list 'zz-en-home'; every deck of zz "
                          f"from en is on its path")

    def test_a_layer_whose_core_has_a_theme_is_a_theme_deck(self) -> None:
        self.put("../themes.yaml", {"schema": 1, "kind": "themes",
                                    "themes": [{"id": "home", "name": "Home"},
                                               {"id": "health", "name": "Health"}]})
        self.edit(PATH, lambda d: d["units"][0].update(decks=["zz-en-home", "*"]))
        files = (CORE, LAYER, RULES, RULES_LAYER, PATH, "../themes.yaml")
        self.assertAcross(f"{self.p(PATH)}: the unit [zz-en-home] ends in '*' but has no "
                          f"theme deck to say which decks it takes", *files)
        self.edit(CORE, lambda d: d.update(theme="home"))
        self.assertClean(*files)


def phrase(k: int) -> tuple[str, dict, dict]:
    """A phrasebook card, as the fixture's: its id, core card and layer entry."""
    cid = f"zz-9{100 + k}"
    return cid, {"id": cid, "target": f"అమ్మ {k}!", "reading": f"amma {k}!",
                 "pos": "phrase", "phrasebook": True}, {"native": f"Mother {k}!"}


class Phrasebook(B1Case):
    """Section 3: 15 to 25 survival chunks per course, taught first."""

    def phrasebook_of(self, n: int) -> None:
        """The course's phrasebook made n cards long."""
        for k in range(n + 1, 16):
            self.drop_phrasebook_card(phrase(k)[0])
        for k in range(16, n + 1):
            cid, core_card, entry = phrase(k)
            self.edit(CORE, lambda d: d["cards"].append(core_card))
            self.edit(LAYER, lambda d: d["cards"].update({cid: entry}))

    def test_phrasebook_is_true_or_left_out(self) -> None:
        for value in ("true", False, "yes", 1):
            with self.subTest(value=value):
                self.edit(CORE, lambda d: card(d, "zz-9101").update(phrasebook=value))
                self.assertError(CORE, "card zz-9101", f"phrasebook must be true, unquoted, "
                                                       f"or left out; got {value!r}")
        # A bare yes is the string "yes" (YAML 1.2), refused as the app refuses it.
        self.setUp()
        text = self.p(CORE).read_text(encoding="utf-8")
        self.put(CORE, text.replace("phrasebook: true }", "phrasebook: yes }", 1))
        self.assertError(CORE, "card zz-9101", "phrasebook must be true, unquoted, or left "
                                               "out; got 'yes'")

    def test_a_ref_cannot_give_phrasebook(self) -> None:
        self.put(EXTRA, single(cards=[{"ref": "zz-9101", "phrasebook": True}]))
        self.assertError(EXTRA, "ref zz-9101", "a ref cannot give 'phrasebook': it belongs "
                                               "to the card itself, where it is written")

    def test_a_course_has_15_to_25_phrasebook_cards(self) -> None:
        for n, ok in ((14, False), (15, True), (25, True), (26, False)):
            with self.subTest(n=n):
                self.setUp()
                self.phrasebook_of(n)
                line = (f"{self.p(PATH)}: phrasebook: the zz-en course has {n} phrasebook "
                        f"cards; a course's phrasebook has 15 to 25 (zz-en-home)")
                if ok:
                    self.assertNotAcross("phrasebook:")
                else:
                    self.assertAcross(line)

    def test_none_is_an_error_only_with_a_plan(self) -> None:
        self.phrasebook_of(0)
        self.assertAcross(f"{self.p(PATH)}: phrasebook: the zz-en course has 0 phrasebook "
                          f"cards; a course's phrasebook has 15 to 25 (none)")
        # A course whose path has no plan is checked only once it has one.
        self.put("zz-bn-words.yaml", single("zz-bn-words", native="bn", cards=[
            {"id": "zz-9601", "target": "కుక్క", "reading": "kukka", "native": "কুকুর (kukur)"}]))
        self.put("zz-bn-path.yaml", {"schema": 1, "kind": "path", "id": "zz-bn-path",
                                     "language": "zz", "native": "bn",
                                     "units": [["zz-bn-words"]]})
        self.assertNotAcross("phrasebook:", "zz-bn-path.yaml", "zz-bn-words.yaml")
        self.edit("zz-bn-words.yaml", lambda d: card(d, "zz-9601").update(phrasebook=True))
        self.assertAcross(f"{self.p('zz-bn-path.yaml')}: phrasebook: the zz-bn course has 1 "
                          f"phrasebook cards; a course's phrasebook has 15 to 25 "
                          f"(zz-bn-words)", "zz-bn-path.yaml", "zz-bn-words.yaml")

    def test_a_bengali_layers_phrasebook_counts_for_bengali_learners_only(self) -> None:
        self.put("bn/zz-bn-home.yaml", {
            "schema": 1, "id": "zz-bn-home", "kind": "layer", "core": "zz-home",
            "native": dict(NATIVES["bn"]), "name": "বাড়ি (bāṛi)", "license": "CC0-1.0",
            "cards": {"zz-9004": {"native": "মা (mā)", "notes": {"address": "আদর (ādar)."}},
                      "zz-9150": {"target": "అమ్మ!", "reading": "amma!", "pos": "phrase",
                                  "native": "মা! (mā!)", "phrasebook": True}}})
        lines = self.run_main()
        self.assertNotIn("the zz-en course has", "\n".join(lines))
        self.assertIn(f"error: {self.p('bn/zz-bn-home.yaml')}: phrasebook: the zz-bn course "
                      f"has 1 phrasebook cards; a course's phrasebook has 15 to 25 "
                      f"(zz-bn-home)", lines)

    def test_the_phrasebook_comes_first(self) -> None:
        self.put(EXTRA, single(cards=[dict(CAT, pos="other")]))
        self.edit(PATH, lambda d: d["units"].insert(0, {"decks": ["zz-en-extra"], "words": 1}))
        self.assertAcross(f"{self.p(PATH)}: units[1]: zz-en-home teaches phrasebook card "
                          f"zz-9101; the phrasebook comes first, in a deck of units[0]")
        # An alphabet unit first is exempt: the phrasebook is in the first
        # unit that is not.
        self.edit(PATH, lambda d: d.update(alphabet=["zz-en-extra"]))
        self.edit(PATH, lambda d: d["units"].__setitem__(0, ["zz-en-extra"]))
        self.assertNotAcross("the phrasebook comes first")
        # A later deck may list a phrasebook card by ref.
        self.put(EXTRA, single(cards=[dict(CAT, pos="other"), {"ref": "zz-9101"}]))
        self.edit(PATH, lambda d: d.update(alphabet=[]))
        self.edit(PATH, lambda d: d["units"].pop(0))
        self.edit(PATH, lambda d: d["units"][1]["decks"].append("zz-en-extra"))
        self.assertNotAcross("the phrasebook comes first")


class RulesCore(B1Case):
    """Section 4.2: a rules core's table and rules."""

    def table(self, change) -> None:
        self.edit(RULES, lambda d: change(d["table"]))

    def test_the_table_is_required_and_a_mapping(self) -> None:
        self.edit(RULES, lambda d: d.pop("table"))
        self.assertError(RULES, "table", "is required on a rules deck")
        self.edit(RULES, lambda d: d.update(table=[]))
        self.assertError(RULES, "table", "must be a mapping")
        self.edit(RULES, lambda d: d.update(table={"colour": "blue"}))
        self.assertError(RULES, "table", "unknown field 'colour'")

    def test_applies_to_names_the_rows_kind(self) -> None:
        self.table(lambda t: t.pop("applies_to"))
        self.assertError(RULES, "table.applies_to", 'is required: which words are its rows, '
                                                    'as { pos: ["noun"] }')
        self.table(lambda t: t.update(applies_to={"pos": ["phrase"]}))
        self.assertError(RULES, "table.applies_to.pos",
                         "must be a non-empty list of parts of speech from ['adj', 'adv', "
                         "'noun', 'other', 'particle', 'pronoun', 'verb'], got ['phrase']")
        self.table(lambda t: t.update(applies_to={"pos": ["noun"], "tags": "x",
                                                  "except": ["foo"]}))
        self.assertError(RULES, "table.applies_to", "tags must be a list")
        self.assertError(RULES, "table.applies_to.except", "must list zz card ids, got "
                                                           "['foo']")
        self.table(lambda t: t.update(applies_to={"pos": ["noun"], "tags": ["home"],
                                                  "except": ["zz-9030"]}))
        self.assertNoError(RULES, "applies_to")

    def test_slots_are_slot_keys(self) -> None:
        self.table(lambda t: t.update(slots=[]))
        self.assertError(RULES, "table.slots", "must be a non-empty list of slot keys")
        for bad in ("on", "1st", "Lo", "no"):
            with self.subTest(bad=bad):
                self.table(lambda t: t.update(slots=["lo", bad, "to", "nunci"]))
                self.assertError(RULES, "table.slots",
                                 f"slots[1] must start with a letter and match [a-z0-9-]+, "
                                 f"and not be a YAML 1.1 boolean word, got {bad!r}")
        self.table(lambda t: t.update(slots=["lo", "lo", "to", "nunci"]))
        self.assertError(RULES, "table.slots", "slots contains duplicates")

    def test_rows(self) -> None:
        self.table(lambda t: t.update(rows="x"))
        self.assertError(RULES, "table.rows", "must be a non-empty list of rows")
        self.setUp()
        self.table(lambda t: t["rows"].append("x"))
        self.assertError(RULES, "table.rows[2]", "must be a mapping")
        self.table(lambda t: t["rows"].__setitem__(2, {"word": "zz-1", "colour": "x"}))
        self.assertError(RULES, "table.rows[2]", "unknown field 'colour'")
        self.assertError(RULES, "table.rows[2]", "word must be the id of a zz card, got "
                                                 "'zz-1'")

    def test_a_row_has_its_own_word_and_id_part(self) -> None:
        self.table(lambda t: t["rows"].append(dict(t["rows"][0])))
        self.assertError(RULES, "table.rows[zz-9001]", "zz-9001 has a row already")
        self.setUp()
        self.table(lambda t: t["rows"][1].update(key="Amma"))
        self.assertError(RULES, "table.rows[zz-9004]", "key must match [a-z0-9-]+, got "
                                                       "'Amma'")
        self.table(lambda t: t["rows"][1].update(key="9001"))
        self.assertError(RULES, "table.rows[zz-9004]", "'9001' already names another row; "
                                                       "give one of them a key")
        # A key that keeps an old grammar entry's cell ids may start with a digit.
        self.table(lambda t: t["rows"][1].update(key="amma"))
        self.assertNoError(RULES)

    def test_every_form_is_listed_with_its_reading(self) -> None:
        self.table(lambda t: t["rows"][0]["forms"].pop("nunci"))
        self.assertError(RULES, "table.rows[zz-9001]", "forms missing slots: ['nunci']")
        self.setUp()
        self.table(lambda t: t["rows"][0].pop("readings"))
        self.assertError(RULES, "table.rows[zz-9001]", "readings is required: the script "
                                                       "is 'telugu'")
        self.setUp()
        self.table(lambda t: t["rows"][0]["forms"].update(lo=["ఇంట్లో", "ఇంట్లో"]))
        self.assertError(RULES, "table.rows[zz-9001]", "forms['lo'] lists a form twice")
        self.setUp()
        self.table(lambda t: t["rows"][0]["forms"].update(ki=None, to=None, nunci=None))
        self.table(lambda t: t["rows"][0]["readings"].update(ki=None, to=None, nunci=None))
        report = validate_decks.validate(self.p(RULES))
        self.assertEqual(report.errors, [])
        self.assertIn("table.rows[zz-9001]: has one form only, so its grammar questions "
                      "cannot offer a choice", report.warnings)

    def test_rules(self) -> None:
        self.edit(RULES, lambda d: d.pop("rules"))
        self.assertError(RULES, "rules", "is required on a rules deck: a non-empty list of "
                                         "rules")
        self.setUp()
        self.edit(RULES, lambda d: d["rules"].append("x"))
        self.assertError(RULES, "rules[4]", "must be a mapping")
        self.edit(RULES, lambda d: d["rules"].__setitem__(4, {"id": "rule-x", "colour": 1}))
        self.assertError(RULES, "rules[4]", "unknown field 'colour'")
        self.assertError(RULES, "rules[4]", "id must be zz-rule- and a name, such as "
                                            "zz-rule-past, got 'rule-x'")
        self.assertError(RULES, "rules[4]", "slots must be a non-empty list of the table's "
                                            "slots")
        self.setUp()
        self.edit(RULES, lambda d: d["rules"].append({"id": "zz-rule-lo", "slots": ["x"]}))
        self.assertError(RULES, "rule zz-rule-lo", "duplicate rule id")
        self.assertError(RULES, "rule zz-rule-lo", "'x' is not a slot of the table")

    def test_every_slot_belongs_to_one_rule(self) -> None:
        self.edit(RULES, lambda d: d["rules"][1].update(slots=["ki", "lo"]))
        self.assertError(RULES, "rule zz-rule-ki", "'lo' is also in rule zz-rule-lo; a slot "
                                                   "belongs to one rule")
        self.setUp()
        self.edit(RULES, lambda d: d["rules"].pop())
        self.assertError(RULES, "table.slots", "'nunci' belongs to no rule")
        self.setUp()
        # A rule may make several of the table's slots.
        self.edit(RULES, lambda d: d["rules"].pop())
        self.edit(RULES, lambda d: d["rules"][2].update(slots=["to", "nunci"]))
        self.edit(RULES_LAYER, lambda d: d["rules"].pop("zz-rule-nunci"))
        self.assertClean(RULES, RULES_LAYER)

    def test_a_rules_words_have_their_readings(self) -> None:
        self.edit(RULES, lambda d: d["rules"][0]["words"][0].pop("reading"))
        self.assertError(RULES, "rule zz-rule-lo", "words[0] needs word, and its reading in a "
                                                   "script that needs one")

    def test_keys_in_the_table_and_rules_are_strings(self) -> None:
        text = self.p(RULES).read_text(encoding="utf-8")
        self.put(RULES, text.replace('"nunci": "ఇంటి నుంచి" }', '"nunci": "ఇంటి నుంచి", 1: "x" }', 1))
        self.assertError(RULES, "table.rows[0].forms", "key 1 was read as int; quote it")

    def test_a_rules_core_has_no_cards_pattern_or_theme(self) -> None:
        self.edit(RULES, lambda d: d.update(pattern={}, theme="home"))
        self.assertError(RULES, "pattern", "only a grammar core has a pattern")
        self.assertError(RULES, "theme", "only a vocab deck teaches a theme")


class RowsAcross(B1Case):
    """Sections 4.3 and 4.4: rows against the language's words."""

    def test_a_row_is_a_taught_word_of_the_tables_kind(self) -> None:
        cases = {
            "zz-9999": "no vocab deck writes card zz-9999",
            "zz-9006": "zz-9006 is a pronoun, not one of noun",
            "zz-9101": "zz-9101 is a phrasebook card; its words are taught as words",
        }
        for word, msg in cases.items():
            with self.subTest(word):
                self.setUp()
                self.edit(RULES, lambda d: d["table"]["rows"][1].update(word=word))
                self.assertAcross(f"{self.p(RULES)}: table.rows[{word}]: {msg}")

    def test_a_row_is_not_also_an_exception(self) -> None:
        self.edit(RULES, lambda d: d["table"]["applies_to"].update({"except": ["zz-9001"]}))
        self.assertAcross(f"{self.p(RULES)}: table.rows[zz-9001]: zz-9001 is both a row and "
                          f"in applies_to.except")
        self.edit(RULES, lambda d: d["table"]["applies_to"].update({"except": ["zz-9999"]}))
        self.assertAcross(f"{self.p(RULES)}: table.applies_to.except: no deck writes card "
                          f"zz-9999")

    def test_a_rows_word_has_its_reading(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9004").pop("reading"))
        self.assertAcross(f"{self.p(RULES)}: table.rows[zz-9004]: zz-9004 has no reading, "
                          f"but the script is 'telugu'; a typed cell shows the word with its "
                          f"reading")

    def test_every_noun_a_b1_deck_teaches_has_its_row(self) -> None:
        cat = {"id": "zz-9007", "target": "పిల్లి", "reading": "pilli", "pos": "noun",
               "notes": [{"id": "tail", "kind": "usage"}]}
        self.edit(CORE, lambda d: d["cards"].insert(1, cat))
        self.edit(LAYER, lambda d: d["cards"].update(
            {"zz-9007": {"native": "cat", "notes": {"tail": "Also a shy person."}}}))
        self.assertAcross(f"{self.p(RULES)}: table: zz-9007 (పిల్లి) is a noun taught in "
                          f"zz-en-home but has no row; add its forms, or list it in "
                          f"applies_to.except")
        self.edit(RULES, lambda d: d["table"]["applies_to"].update({"except": ["zz-9007"]}))
        self.assertNotAcross("has no row")

    def test_a_noun_on_no_plan_needs_no_row(self) -> None:
        self.put(EXTRA, single())
        self.assertNotAcross("has no row", RULES, EXTRA)

    def test_a_rule_id_is_defined_once_in_the_language(self) -> None:
        other = self.data(RULES)
        other.update(id="zz-grammar-more")
        self.put("zz-grammar-more.yaml", other)
        self.assertAcross(f"{self.p(RULES)}: rule zz-rule-lo: is also defined in "
                          f"{self.p('zz-grammar-more.yaml')}", RULES)


class RulesLayer(B1Case):
    """Section 4.5: a rules core's layer."""

    def table(self, change) -> None:
        self.edit(RULES_LAYER, lambda d: change(d["table"]))

    def test_the_table_has_its_slot_name_and_every_label(self) -> None:
        self.table(lambda t: t.pop("slot_name"))
        self.assertError(RULES_LAYER, "table.slot_name", "is required")
        self.table(lambda t: t["slots"].pop("nunci"))
        self.assertError(RULES_LAYER, "table.slots", "gives no label for 'nunci'")
        self.table(lambda t: t["slots"].update(lu="by {meaning}"))
        self.assertError(RULES_LAYER, "table.slots", "'lu' is not a slot of the core")

    def test_a_labels_only_placeholder_is_meaning(self) -> None:
        self.table(lambda t: t["slots"].update(lo="in {word}"))
        self.assertError(RULES_LAYER, "table.slots.lo",
                         "uses unknown placeholder {word}; a label may use {meaning}, and "
                         "the word is shown with every typed cell")
        self.table(lambda t: t["slots"].update(lo="inside"))
        self.assertNoError(RULES_LAYER)

    def test_prompts_name_rows_and_slots_of_the_core(self) -> None:
        self.table(lambda t: t["prompts"].update({"zz-9999": {"lo": "x"},
                                                  "zz-9004": {"lu": "x"}}))
        self.assertError(RULES_LAYER, "table.prompts", "'zz-9999' is not a row of the core")
        self.assertError(RULES_LAYER, "table.prompts", "'lu' is not a slot of the core")

    def test_rules_have_a_name_and_an_explanation(self) -> None:
        self.edit(RULES_LAYER, lambda d: d["rules"].update({"zz-rule-past": {}}))
        self.assertError(RULES_LAYER, "rules", "'zz-rule-past' is not a rule of the core")
        self.edit(RULES_LAYER, lambda d: d["rules"].update({"zz-rule-lo": {}}))
        self.assertError(RULES_LAYER, "rules.zz-rule-lo", "name is required")
        self.assertError(RULES_LAYER, "rules.zz-rule-lo", "explanation is required")

    def test_an_explanations_placeholders_count_the_rules_words(self) -> None:
        self.edit(RULES_LAYER, lambda d: d["rules"]["zz-rule-to"].update(
            explanation="{1} and {2}, not {01}."))
        self.assertError(RULES_LAYER, "rules.zz-rule-to.explanation",
                         "uses {2}, but the rule has 1 words")
        self.assertError(RULES_LAYER, "rules.zz-rule-to.explanation",
                         "{01} is not a placeholder: placeholders count from {1}, without "
                         "leading zeros")
        self.edit(RULES_LAYER, lambda d: d["rules"]["zz-rule-to"].update(
            explanation="With."))
        self.assertIn("rules.zz-rule-to.explanation: never uses {1}, -తో",
                      validate_decks.validate(self.p(RULES_LAYER)).warnings)

    def test_a_rule_the_layer_leaves_out_is_not_asked(self) -> None:
        self.edit(RULES_LAYER, lambda d: d["rules"].pop("zz-rule-nunci"))
        self.assertInfo(RULES_LAYER, "rules", "covers 3 of 4 rules of "
                                              "zz-grammar-case-endings; the cells of "
                                              "zz-rule-nunci are not asked")
        self.assertClean()


class Modes(B1Case):
    """Section 4.7: grammarUnderstood is only for a rules table's cells."""

    def test_a_card_or_a_ref_cannot_name_it(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(modes=["grammarUnderstood"]))
        self.assertError(CORE, "card zz-9001", "grammarUnderstood is only for a rules "
                                               "table's cells")
        self.put(EXTRA, single(cards=[{"ref": "zz-9001", "modes": ["grammarUnderstood"]}]))
        self.assertError(EXTRA, "ref zz-9001", "grammarUnderstood is only for a rules "
                                               "table's cells")
        self.put(EXTRA, single(cards=[{"ref": "zz-9001", "modes": ["recognition"]}]))
        self.assertNoError(EXTRA)


class SentenceRules(B1Case):
    """Section 5: the rules a sentence uses."""

    def test_rules_is_a_list_of_the_languages_rule_ids(self) -> None:
        cases = {
            "zz-rule-ki": 'rules must be a list of rule ids, such as ["zz-rule-past"]',
            ("ki",): "rules[0] must be a zz rule id, zz-rule- and a name, got 'ki'",
            ("zz-rule-ki", "zz-rule-ki"): "rules lists 'zz-rule-ki' twice",
        }
        for value, msg in cases.items():
            with self.subTest(value=value):
                rules = list(value) if isinstance(value, tuple) else value
                self.edit(CORE, lambda d: card(d, "zz-9002").update(rules=rules))
                self.assertError(CORE, "card zz-9002", msg)

    def test_a_ref_cannot_give_rules(self) -> None:
        self.put(EXTRA, single(cards=[{"ref": "zz-9002", "rules": ["zz-rule-ki"]}]))
        self.assertError(EXTRA, "ref zz-9002", "a ref cannot give 'rules': it belongs to "
                                               "the card itself, where it is written")

    def test_a_rule_named_is_defined_by_a_rules_deck_of_the_language(self) -> None:
        self.assertNotAcross("rules names", CORE)
        self.edit(CORE, lambda d: card(d, "zz-9002").update(rules=["zz-rule-past"]))
        self.assertAcross(f"{self.p(CORE)}: card zz-9002: rules names zz-rule-past, which "
                          f"no rules deck of zz defines", CORE)
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9200": {
            "target": "ఇంట్లో", "reading": "iṇṭlō", "native": "at home", "pos": "adv",
            "rules": ["zz-rule-on"]}}))
        self.assertAcross(f"{self.p(LAYER)}: cards.zz-9200: rules names zz-rule-on, which "
                          f"no rules deck of zz defines", LAYER)


class SingleFileNotes(B1Case):
    """Section 6.1: typed notes on a single-file card."""

    def notes(self, notes: object) -> list[str]:
        self.put(EXTRA, single(cards=[dict(CAT, notes=notes)], tags=["unreviewed"]))
        return self.errors(EXTRA)

    def test_valid_notes(self) -> None:
        good = [
            {"kind": "pair", "ref": "zz-9001", "text": "Not ఇల్లు (illu)."},
            {"kind": "culture", "text": "Cats keep the rice store safe.",
             "source": "https://example.org/cats"},
            {"kind": "usage", "text": "Also a timid person."},
            {"kind": "behaviour", "id": "plural", "text": "Its plural is {1}.",
             "words": [{"word": "పిల్లులు", "reading": "pillulu"}]},
            {"kind": "note", "text": "A note."},
        ]
        self.assertEqual(self.notes(good), [])
        self.assertEqual(self.notes("Today's text, one note."), [])
        # A blank string is no notes, never one empty note.
        self.assertEqual(self.notes("  "), [])
        report = validate_decks.validate(self.p(EXTRA))
        self.assertEqual(report.cards[0].notes, [])

    def test_bad_notes(self) -> None:
        def note(**fields: object) -> list[dict]:
            return [dict({"kind": "usage", "text": "A note."}, **fields)]
        cases = [
            ({"a": "b"}, "notes must be text, or a list of notes, each with a kind and "
                         "its text"),
            ([], "notes must not be an empty list; leave it out"),
            (["a"], "notes[0] must be a mapping"),
            (note(colour="blue"), "notes[0]: unknown field 'colour'"),
            (note(kind="tip"), "notes[0].kind must be one of behaviour, culture, note, "
                               "pair, usage, got 'tip'"),
            (note(text=""), "notes[0].text is required and must be non-empty text"),
            (note(id="on"), "notes[0].id must start with a letter and match [a-z0-9-]+, "
                            "and not be a YAML 1.1 boolean word, got 'on'"),
            (note(id="1a"), "notes[0].id must start with a letter and match [a-z0-9-]+, "
                            "and not be a YAML 1.1 boolean word, got '1a'"),
            (note(id="x") + note(id="x"), "notes[1].id 'x' is used twice"),
            (note(kind="pair", ref="cat"), "notes[0].ref: a pair note names its partner, "
                                           "the id of another zz card, got 'cat'"),
            (note(kind="pair"), "notes[0].ref: a pair note names its partner, the id of "
                                "another zz card, got None"),
            (note(kind="pair", ref="zz-9501"), "notes[0].ref names the card itself"),
            (note(ref="zz-9001"), "notes[0].ref is only for a pair note"),
            (note(kind="culture"), "notes[0].source: a culture note names where its "
                                   "claims can be checked"),
            (note(words="x"), "notes[0].words must be a list of { word, reading }"),
            (note(words=[{"word": "పిల్లులు"}]), "notes[0].words[0] needs word, and its "
                                                 "reading in a script that needs one"),
            (note(text="{1} and {2}", words=[{"word": "పిల్లులు", "reading": "pillulu"}]),
             "notes[0].text uses {2}, but the note has 1 words"),
            (note(text="{0}"), "notes[0].text {0} is not a placeholder: placeholders count "
                               "from {1}, without leading zeros"),
            (note(text="{01}"), "notes[0].text {01} is not a placeholder: placeholders "
                                "count from {1}, without leading zeros"),
        ]
        for notes, msg in cases:
            with self.subTest(msg):
                self.assertIn(f"card zz-9501: {msg}", self.notes(notes))
        # Other braces are literal, and a numbers file's "{x}" is no placeholder.
        self.assertEqual(self.notes(note(text="{x}, { 1 } and a lone {.")), [])
        self.notes(note(words=[{"word": "పిల్లులు", "reading": "pillulu"}]))
        self.assertIn("card zz-9501: notes[0].text never uses {1}, పిల్లులు",
                      validate_decks.validate(self.p(EXTRA)).warnings)

    def test_a_ref_in_a_single_file_deck_may_give_typed_notes(self) -> None:
        self.put(EXTRA, single(cards=[{"ref": "zz-9001", "notes": [
            {"kind": "pair", "ref": "zz-9004", "text": "Not అమ్మ (amma)."}]}]))
        self.assertClean(EXTRA)

    def test_a_pair_notes_partner_is_written_in_the_language(self) -> None:
        self.notes([{"kind": "pair", "ref": "zz-9999", "text": "Not this."}])
        self.assertAcross(f"{self.p(EXTRA)}: card zz-9501: notes[0].ref names card zz-9999, "
                          f"which no deck writes", EXTRA)


class CoreNotes(B1Case):
    """Sections 6.2 and 6.3: a core's notes hold the facts; layers the text."""

    def test_a_core_note_has_an_id_and_no_text(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(notes="Before an ending."))
        self.assertError(CORE, "card zz-9001", "notes must be a list of notes in a core "
                                               "file; their text is in each layer")
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            notes=[{"kind": "usage"}, {"id": "stem", "kind": "usage", "text": "x"}]))
        self.assertError(CORE, "card zz-9001", "notes[0].id is required in a core file: each "
                                               "layer names the note by it")
        self.assertError(CORE, "card zz-9001", "notes[1].text: a core note's text is in each "
                                               "layer, under cards.zz-9001.notes.stem")

    def test_a_core_pair_note_names_a_card_of_the_language(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001")["notes"].append(
            {"id": "pair", "kind": "pair", "ref": "zz-9999"}))
        self.assertAcross(f"{self.p(CORE)}: card zz-9001: notes[1].ref names card zz-9999, "
                          f"which no deck writes", CORE)


class NotesAcross(B1Case):
    """Section 6.5: partners taught, word cards with notes, culture tags."""

    def test_a_pair_notes_partner_is_taught_in_the_course(self) -> None:
        pair = [{"kind": "pair", "ref": "zz-9001", "text": "Not ఇల్లు (illu)."}]
        self.put(EXTRA, single(cards=[dict(CAT, notes=pair)]))
        self.assertNotAcross("minimal-pair", EXTRA)
        self.put("zz-bn-extra.yaml", single("zz-bn-extra", native="bn", cards=[
            {"id": "zz-9601", "target": "కుక్క", "reading": "kukka",
             "native": "কুকুর (kukur)", "notes": pair}]))
        self.assertAcross(f"{self.p('zz-bn-extra.yaml')}: card zz-9601: notes[0].ref names "
                          f"zz-9001, which no zz-bn deck teaches; the minimal-pair panel "
                          f"shows both words with their meanings", "zz-bn-extra.yaml")

    def test_a_core_pair_notes_partner_is_taught_from_the_layers_language(self) -> None:
        self.edit(CORE, lambda d: d["cards"].insert(0, {
            "id": "zz-9008", "target": "కాలం", "reading": "kālam", "pos": "other",
            "notes": [{"id": "time", "kind": "usage"}]}))
        self.edit(CORE, lambda d: card(d, "zz-9001")["notes"].append(
            {"id": "pair", "kind": "pair", "ref": "zz-9008"}))
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"]["notes"].update(
            pair="Not కాలం (kālam), time."))
        self.assertAcross(f"{self.p(LAYER)}: cards.zz-9001.notes.pair: the partner zz-9008 "
                          f"is not taught from English; translate it in a zz-en deck, or "
                          f"leave this note's text out")
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9008": {
            "native": "time", "notes": {"time": "Also a season."}}}))
        self.assertNotAcross("the partner")

    def test_a_word_card_of_a_b1_deck_has_notes(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9004").pop("notes"))
        self.edit(LAYER, lambda d: d["cards"]["zz-9004"].pop("notes"))
        self.assertWarned(CORE, "card zz-9004", "no notes; every word card should have one "
                                                "or more (pair, culture, usage, behaviour, "
                                                "note)")
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9200": {
            "target": "పోవు", "reading": "pōvu", "native": "to go away", "pos": "verb"}}))
        self.assertWarned(LAYER, "cards.zz-9200", "no notes; every word card should have "
                                                  "one or more (pair, culture, usage, "
                                                  "behaviour, note)")

    def test_a_word_card_on_no_plan_is_not_warned_of(self) -> None:
        self.put(EXTRA, single())
        self.assertEqual(self.section(self.run_main(EXTRA), EXTRA), [])

    def test_a_pair_in_a_b1_deck_has_its_pair_note(self) -> None:
        verb = {"target": "పోవు", "reading": "pōvu", "native": "to go away", "pos": "verb",
                "pair": "zz-9003", "notes": [{"kind": "usage", "text": "Rude."}]}
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9200": verb}))
        self.assertWarned(LAYER, "cards.zz-9200", "pair names zz-9003, but no pair note does; "
                                                  "the minimal-pair button needs a pair note")
        verb["notes"].append({"kind": "pair", "ref": "zz-9003", "text": "Not వెళ్ళు (veḷḷu)."})
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9200": verb}))
        self.assertNotIn("pair names", "\n".join(self.run_main()))

    def test_culture_notes_are_tagged_unreviewed_or_reviewed(self) -> None:
        culture = {"id": "school", "kind": "culture", "source": "https://example.org/x"}
        self.edit(CORE, lambda d: card(d, "zz-9001")["notes"].append(culture))
        self.assertNoError(CORE, "tags")
        for tags, msg in (([], 'has culture notes, so it is tagged "unreviewed" until a '
                               'speaker checks them, then "reviewed" (#99)'),
                          (["reviewed", "unreviewed"], '"reviewed" and "unreviewed" '
                                                       'together; a deck is one or the other')):
            with self.subTest(tags=tags):
                self.edit(CORE, lambda d: d.update(tags=tags))
                self.assertError(CORE, "tags", msg)
        self.edit(CORE, lambda d: d.update(tags=["reviewed"]))
        self.assertNoError(CORE, "tags")
        # A layer-only card's culture note: the tag is the layer's.
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9200": {
            "target": "పండుగ", "reading": "paṇḍuga", "native": "festival", "pos": "other",
            "notes": [{"kind": "culture", "text": "Sankranti is in January.",
                       "source": "https://example.org/y"}]}}))
        self.assertError(LAYER, "tags", 'has culture notes, so it is tagged "unreviewed" '
                                        'until a speaker checks them, then "reviewed" (#99)')


class Wiktionary(B1Case):
    """Section 7: the mark that Wiktionary has an entry: true, or left out."""

    def test_wiktionary_is_true_or_left_out(self) -> None:
        self.put(EXTRA, single(cards=[dict(CAT, wiktionary=False)]))
        self.assertError(EXTRA, "card zz-9501", "wiktionary must be true, or left out where "
                                                "Wiktionary has no entry; got False")
        self.put(EXTRA, single(cards=[dict(CAT, wiktionary=True), {
            "ref": "zz-9001", "wiktionary": "yes"}]))
        self.assertError(EXTRA, "ref zz-9001", "wiktionary must be true, or left out where "
                                               "Wiktionary has no entry; got 'yes'")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(wiktionary=1))
        self.assertError(LAYER, "cards.zz-9001", "wiktionary must be true, or left out "
                                                 "where Wiktionary has no entry; got 1")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(wiktionary=True))
        self.assertNoError(LAYER)


class Bases(B1Case):
    """Section 8.2: bases, per file."""

    SENTENCE = {"id": "zz-9502", "target": "పిల్లి ఇంటికి వచ్చింది.",
                "reading": "pilli iṇṭiki vaccindi.", "native": "The cat came home.",
                "pos": "phrase"}

    def bases(self, bases: object, **extra: object) -> list[str]:
        sentence = dict(self.SENTENCE, bases=bases, **extra)
        self.put(EXTRA, single(cards=[dict(CAT), sentence]))
        return self.errors(EXTRA)

    def test_valid_bases(self) -> None:
        good = [{"word": "పిల్లి", "ref": "zz-9501"}, {"word": "ఇంటికి", "ref": "zz-9001"},
                {"word": "వచ్చింది", "base": "వచ్చు", "reading": "vaccu",
                 "meaning": "to come", "wiktionary": True, "ipa": "ʋat͡ʃːu"}]
        example = {"target": "పిల్లి వచ్చింది.", "native": "The cat came.",
                   "bases": [{"word": "వచ్చింది", "base": "వచ్చు", "reading": "vaccu",
                              "meaning": "to come"}]}
        self.assertEqual(self.bases(good, examples=[example]), [])

    def test_bad_bases(self) -> None:
        full = {"word": "వచ్చింది", "base": "వచ్చు", "reading": "vaccu", "meaning": "to come"}
        cases = [
            ("x", "bases must be a list of { word, ref } or { word, base, reading }"),
            (["x"], "bases[0] must be a mapping"),
            ([dict(full, colour=1)], "bases[0]: unknown field 'colour'"),
            ([{"ref": "zz-9001"}], "bases[0].word is required and must be a non-empty "
                                   "string"),
            ([dict(full, ref="zz-9001")], "bases[0] gives ref or base, not both"),
            ([{"word": "ఇంటికి"}], "bases[0] needs ref, or base and its reading"),
            ([{"word": "ఇంటికి", "ref": "home"}], "bases[0].ref must be the id of a zz card, "
                                                  "got 'home'"),
            ([{"word": "ఇంటికి", "ref": "zz-9502"}], "bases[0].ref names the card itself"),
            ([{"word": "వచ్చింది", "base": "వచ్చు", "meaning": "to come"}],
             "bases[0]: no reading, but script is 'telugu'; give the base's reading"),
            ([{"word": "వచ్చింది", "base": "వచ్చు", "reading": "vaccu"}],
             "bases[0].meaning is required beside base"),
            ([dict(full, wiktionary=False)], "bases[0].wiktionary must be true, or left out "
                                             "where Wiktionary has no entry; got False"),
            ([{"word": "ఇల్లు", "ref": "zz-9001"}], "bases[0].word 'ఇల్లు' is not a word of "
                                                   "the target"),
            ([{"word": "ఇంటికి", "ref": "zz-9001"}, {"word": "ఇంటికి", "ref": "zz-9001"}],
             "bases[1].word 'ఇంటికి' is given twice"),
            ([{"word": "ఇంటికి", "ref": "zz-9001", "reading": "iṇṭiki"}],
             "bases[0].reading is only for a base written in full"),
            ([{"word": "ఇంటికి", "ref": "zz-9001", "meaning": "home"}],
             "bases[0].meaning is only for a base written in full"),
        ]
        for bases, msg in cases:
            with self.subTest(msg):
                self.assertIn(f"card zz-9502: {msg}", self.bases(bases))
        example = {"target": "పిల్లి వచ్చింది.", "native": "The cat came.",
                   "bases": [{"word": "ఇంటికి", "ref": "zz-9001"}]}
        self.assertIn("card zz-9502: examples[0].bases[0].word 'ఇంటికి' is not a word of "
                      "examples[0].target", self.bases([], examples=[example]))

    def test_a_core_base_has_its_meaning_in_each_layer(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9002")["bases"][1].update(
            ref=None, base="వెళ్ళు", reading="veḷḷu", meaning="to go", wiktionary=True))
        self.edit(CORE, lambda d: card(d, "zz-9002")["bases"][1].pop("ref"))
        for key in ("meaning", "wiktionary"):
            self.assertError(CORE, "card zz-9002", f"bases[1].{key}: a core file's meanings "
                                                   f"are in each layer, under "
                                                   f"cards.zz-9002.bases")

    def test_a_ref_cannot_give_bases(self) -> None:
        self.put(EXTRA, single(cards=[{"ref": "zz-9002", "bases": []}]))
        self.assertError(EXTRA, "ref zz-9002", "a ref cannot give 'bases': it belongs to "
                                               "the card itself, where it is written")

    def test_a_bases_card_is_written_in_the_language(self) -> None:
        self.bases([{"word": "ఇంటికి", "ref": "zz-9999"}])
        self.assertAcross(f"{self.p(EXTRA)}: card zz-9502: bases[0].ref names card zz-9999, "
                          f"which no deck writes", EXTRA)


class BasesCoverage(B1Case):
    """Section 8.3: in a B1 deck every word of a text is taught or based."""

    def test_a_word_not_taught_as_a_card_has_its_base(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9002").pop("bases"))
        self.assertAcross(f"{self.p(CORE)}: card zz-9002: 'ఇంటికి' is not a word the zz-en "
                          f"course teaches as a card, and has no bases entry; add {{ word: "
                          f"\"ఇంటికి\", ref: ... }}, or {{ word: \"ఇంటికి\", base: ..., "
                          f"reading: ... }}")

    def test_an_example_is_checked_where_the_layer_shows_it(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            examples=[{"target": "ఇల్లు చిన్నది.", "reading": "illu cinnadi."}]))
        # Without a translation the example is not shown, so not checked.
        self.assertNotAcross("is not a word the zz-en course teaches")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={"ఇల్లు చిన్నది.": "The house is small."}))
        self.assertAcross(f"{self.p(CORE)}: card zz-9001: examples[0]: 'చిన్నది' is not a "
                          f"word the zz-en course teaches as a card, and has no bases entry; "
                          f"add {{ word: \"చిన్నది\", ref: ... }}, or {{ word: \"చిన్నది\", "
                          f"base: ..., reading: ... }}")

    def test_a_word_taught_only_from_another_language_is_not_taught(self) -> None:
        self.edit(CORE, lambda d: d["cards"].insert(0, {
            "id": "zz-9010", "target": "పిల్లి", "reading": "pilli", "pos": "other",
            "notes": [{"id": "tail", "kind": "usage"}]}))
        self.edit(CORE, lambda d: card(d, "zz-9002").update(
            target="నేను పిల్లి ఇంటికి వెళ్తాను.", reading="nēnu pilli iṇṭiki veḷtānu."))
        self.put("bn/zz-bn-home.yaml", {
            "schema": 1, "id": "zz-bn-home", "kind": "layer", "core": "zz-home",
            "native": dict(NATIVES["bn"]), "name": "বাড়ি (bāṛi)", "license": "CC0-1.0",
            "cards": {"zz-9010": {"native": "বিড়াল (biṛāl)", "notes": {"tail": "লেজ (lej)."}}}})
        self.assertAcross(f"{self.p(CORE)}: card zz-9002: 'పిల్లి' is not a word the zz-en "
                          f"course teaches as a card, and has no bases entry; add {{ word: "
                          f"\"పిల్లి\", ref: ... }}, or {{ word: \"పిల్లి\", base: ..., "
                          f"reading: ... }}")
        self.edit(LAYER, lambda d: d["cards"].update({"zz-9010": {
            "native": "cat", "notes": {"tail": "Also a shy person."}}}))
        self.assertNotAcross("is not a word the zz-en course teaches")

    def test_a_deck_on_no_plan_is_not_checked(self) -> None:
        self.put(EXTRA, single(cards=[dict(CAT), dict(Bases.SENTENCE)]))
        self.assertNotAcross("is not a word", EXTRA)

    def test_a_script_without_spaces_cannot_be_checked_yet(self) -> None:
        self.edit(CORE, lambda d: d["language"].update(script="thai"))
        self.assertAcross(f"{self.p(PATH)}: units[0]: zz-en-home is in the thai script, "
                          f"written without spaces; bases cannot be checked until the format "
                          f"gives its words (OPEN-26)")


class PathUnits(B1Case):
    """Section 10.2: a path's units, list or mapping, and its B1 plan."""

    def units(self, change) -> list[str]:
        self.edit(PATH, lambda d: change(d["units"]))
        return self.errors(PATH)

    def assertUnits(self, change, line: str) -> None:
        self.setUp()
        self.assertIn(line, self.units(change))

    def test_a_unit_is_a_list_or_a_mapping(self) -> None:
        self.assertUnits(lambda u: u.__setitem__(0, "zz-en-home"),
                         "units[0]: must be a list of deck ids, or a mapping with decks or "
                         "planned")
        self.assertUnits(lambda u: u[0].update(colour="blue"),
                         "units[0]: unknown field 'colour' in a unit")
        self.assertUnits(lambda u: u[0].update(planned={"id": "zz-en-x", "theme": "x",
                                                        "words": 1}),
                         "units[0]: has decks or planned, not both")
        self.assertUnits(lambda u: u[0].pop("decks"), "units[0]: has neither decks nor "
                                                      "planned")
        self.assertUnits(lambda u: u[0].update(decks=[]),
                         "units[0].decks: must be a non-empty list of deck ids")
        self.assertUnits(lambda u: u[0].update(decks=["zz-en-home", "zz-en-home"]),
                         "units[0].decks: deck 'zz-en-home' is listed twice")

    def test_words_is_a_whole_number(self) -> None:
        for value in (-1, True, 4.5, "4"):
            self.assertUnits(lambda u: u[0].update(words=value),
                             f"units[0].words: must be a whole number of words, 0 or more, "
                             f"got {value!r}")
        self.setUp()
        text = self.p(PATH).read_text(encoding="utf-8")
        self.put(PATH, text.replace("words: 4", "words: 1_000"))
        self.assertIn("units[0].words: must be a whole number of words, 0 or more, got "
                      "'1_000'", self.errors(PATH))
        self.assertUnits(lambda u: u[2]["planned"].update(words=0),
                         "units[2].words: must be a whole number of words, 1 or more, got 0")
        self.setUp()
        self.assertNotIn("units[0].words", " ".join(self.units(
            lambda u: u[0].update(words=0))))

    def test_words_and_grammar_are_given_once(self) -> None:
        self.assertUnits(lambda u: u[2].update(words=60),
                         "units[2]: words is given both in planned and beside it")
        self.assertUnits(lambda u: u[2].update(planned={"id": "zz-en-if", "grammar": "if",
                                                        "words": 10}, grammar=["if"]),
                         "units[2]: grammar is given both in planned and beside it")

    def test_grammar_is_a_topic_or_a_list_of_them(self) -> None:
        self.assertUnits(lambda u: u[1].update(grammar=5),
                         'units[1].grammar: must be a grammar topic id or a list of them, '
                         'such as ["past"], got 5')
        self.assertUnits(lambda u: u[1].update(grammar=["lo", "ki", "to", "nunci", "lo"]),
                         "units[1].grammar: 'lo' is listed twice")
        self.setUp()
        self.assertEqual(self.units(lambda u: u[2].update(
            planned={"id": "zz-en-grammar-if", "grammar": "conditional"})), [])

    def test_milestones(self) -> None:
        self.assertUnits(lambda u: u[0].update(milestone="C1"),
                         'units[0].milestone: must be "A1", "A2" or "B1", got \'C1\'')
        self.assertUnits(lambda u: (u[0].update(milestone="A2"), u[1].update(milestone="A1")),
                         "units: the B1 plan needs the milestones A1, A2 and B1, each once "
                         "and in that order; found A2, A1, B1")
        self.assertUnits(lambda u: u[1].update(milestone="A1"),
                         "units[1]: milestone 'A1' is already on units[0]")
        self.assertUnits(lambda u: [x.pop("milestone") for x in u],
                         "units: the B1 plan needs the milestones A1, A2 and B1, each once "
                         "and in that order; found none")

    def test_a_planned_unit(self) -> None:
        self.assertUnits(lambda u: u[2].update(planned="zz-en-health"),
                         "units[2].planned: must be a mapping with id, and theme or grammar")
        self.assertUnits(lambda u: u[2]["planned"].update(size=1),
                         "units[2].planned: unknown field 'size'")
        self.assertUnits(lambda u: u[2]["planned"].update(id="zz-bn-health"),
                         "units[2].planned.id: must be a deck id starting with zz-en-, the "
                         "course, got 'zz-bn-health'")
        self.assertUnits(lambda u: u[2]["planned"].update(grammar="if"),
                         "units[2].planned: names theme or grammar, not both")
        self.assertUnits(lambda u: u[2]["planned"].pop("theme"),
                         "units[2].planned: needs a theme or a grammar topic")
        self.assertUnits(lambda u: u[2]["planned"].update(theme="Health"),
                         "units[2].planned.theme: must be a theme id, got 'Health'")
        self.assertUnits(lambda u: u[2]["planned"].pop("words"),
                         "units[2].planned: a planned theme unit gives its size in words")

    def test_a_planned_unit_names_its_passages(self) -> None:
        self.assertUnits(lambda u: u[2].pop("reading_passages"),
                         "units[2]: a planned unit names its listening_passages and its "
                         "reading_passages (b1-plans.md: each planned unit names its "
                         "listening and reading passages)")
        self.assertUnits(lambda u: u[2].update(listening_passages=[]),
                         "units[2].listening_passages: must be a non-empty list of short "
                         "descriptions")
        # A written unit may name them too, and need not.
        self.setUp()
        self.assertEqual(self.units(lambda u: u[0].update(
            reading_passages=["A note on the door"])), [])

    def test_the_wildcard_alone_carries_no_plan(self) -> None:
        self.assertUnits(lambda u: u.append({"decks": ["*"], "words": 3}),
                         'units[3]: a unit of "*" alone cannot carry a milestone or a plan')
        self.setUp()
        self.assertEqual(self.units(lambda u: u.append(["*"])), [])

    def test_every_unit_up_to_b1_is_sized(self) -> None:
        self.assertUnits(lambda u: u[1].pop("grammar"),
                         "units[1]: a unit up to B1 gives its planned size (words) or its "
                         "grammar topics (grammar)")
        self.assertUnits(lambda u: u.insert(0, ["zz-en-extra"]),
                         'units[0]: a unit up to B1 is a mapping with its words or grammar; '
                         'only an alphabet unit or "*" alone stays a list')
        self.setUp()
        self.edit(PATH, lambda d: d.update(alphabet=["zz-en-extra"]))
        self.assertEqual(self.units(lambda u: u.insert(0, ["zz-en-extra"])), [])
        # A unit after B1 needs no size.
        self.setUp()
        self.assertEqual(self.units(lambda u: u.append(["zz-en-extra"])), [])

    def test_a_topic_is_planned_once(self) -> None:
        self.assertUnits(lambda u: u[0].update(grammar=["lo"]),
                         "units[1]: grammar topic 'lo' is already planned in units[0]")

    def test_planned_units_end_at_b1_and_are_planned_once(self) -> None:
        later = {"planned": {"id": "zz-en-food", "theme": "food", "words": 50},
                 "listening_passages": ["x"], "reading_passages": ["y"]}
        self.assertUnits(lambda u: u.append(later),
                         "units[3]: a planned unit after the B1 mark; a B1 plan ends at B1")
        twice = dict(later, planned={"id": "zz-en-health", "theme": "health", "words": 5},
                     milestone="B1")
        self.assertUnits(lambda u: (u[2].pop("milestone"), u.append(twice)),
                         "units[3].planned.id: 'zz-en-health' is planned twice, also in "
                         "units[2]")
        self.assertUnits(lambda u: u[2]["planned"].update(id="zz-en-home"),
                         "units[2].planned.id: 'zz-en-home' is planned and also listed as a "
                         "deck in units[0]")

    def test_a_path_without_a_mapping_unit_has_no_plan(self) -> None:
        self.put(PATH, {"schema": 1, "kind": "path", "id": "zz-en-path", "language": "zz",
                        "native": "en",
                        "units": [["zz-en-home"], ["zz-en-grammar-case-endings"], ["*"]]})
        report = validate_decks.validate(self.p(PATH))
        self.assertEqual(report.errors, [])
        self.assertFalse(report.plan.has_plan)


class PlansAcross(B1Case):
    """Section 10.3: a B1 plan against the decks."""

    def health(self, native: str = "en") -> str:
        """A core zz-health, and its layer for [native]."""
        self.put("zz-health.yaml", {
            "schema": 1, "id": "zz-health", "part": "core", "language": dict(LANGUAGE),
            "license": "CC0-1.0",
            "cards": [{"id": "zz-9701", "target": "జ్వరం", "reading": "jvaraṁ",
                       "pos": "noun"}]})
        rel = f"{native}/zz-{native}-health.yaml"
        self.put(rel, {"schema": 1, "id": f"zz-{native}-health", "kind": "layer",
                       "core": "zz-health", "native": dict(NATIVES[native]),
                       "name": "Health", "license": "CC0-1.0",
                       "cards": {"zz-9701": {"native": "fever"}}})
        return rel

    def test_a_planned_deck_does_not_exist_yet(self) -> None:
        rel = self.health()
        line = (f"{self.p(PATH)}: units[2].planned.id: zz-en-health already exists "
                f"({self.p(rel)}); list it under decks in place of planned")
        self.assertAcross(line)
        self.assertAcross(line, PATH)
        # A core with no layer of the course: not the course's deck yet.
        self.setUp()
        self.health("bn")
        self.assertNotAcross("already exists", PATH)

    def test_a_planned_single_file_deck_exists_too(self) -> None:
        self.put("zz-en-health.yaml", single("zz-en-health"))
        self.assertAcross(f"{self.p(PATH)}: units[2].planned.id: zz-en-health already "
                          f"exists ({self.p('zz-en-health.yaml')}); list it under decks in "
                          f"place of planned", PATH)

    def test_grammar_topics_name_a_rule_or_a_grammar_deck_of_the_unit(self) -> None:
        self.put("zz-en-grammar-be.yaml", {
            "schema": 1, "id": "zz-en-grammar-be", "name": "Be", "kind": "grammar",
            "language": dict(LANGUAGE), "native": dict(NATIVES["en"]), "license": "CC0-1.0",
            "pattern": {"name": "Be", "slot_name": "person", "slots": ["నేను"],
                        "prompt": "{lemma} ({gloss}) — {slot}",
                        "entries": [{"lemma": "ఉండు", "key": "undu", "gloss": "to be",
                                     "forms": {"నేను": "ఉన్నాను"},
                                     "readings": {"నేను": "unnānu"}}]}})
        self.edit(PATH, lambda d: d["units"][1].update(
            decks=["zz-en-grammar-case-endings", "zz-en-grammar-be"],
            grammar=["lo", "ki", "to", "nunci", "be"]))
        self.assertNotAcross(".grammar:")
        self.edit(PATH, lambda d: d["units"][1]["grammar"].append("past"))
        self.assertAcross(f"{self.p(PATH)}: units[1].grammar: 'past' is taught by none of the "
                          f"unit's decks; name a rule (zz-rule-past) of a rules deck it "
                          f"lists, or a deck zz-en-grammar-past it lists")
        # A unit listing a deck that is nowhere is not checked.
        self.edit(PATH, lambda d: d["units"][1]["decks"].append("zz-en-missing"))
        self.assertNotAcross(".grammar:")

    def test_a_path_needs_its_plan_once_the_language_has_a_core(self) -> None:
        self.put(PATH, {"schema": 1, "kind": "path", "id": "zz-en-path", "language": "zz",
                        "native": "en", "units": [["zz-en-home", "zz-en-grammar-case-endings"]]})
        self.assertAcross(f"{self.p(PATH)}: units: zz has core files "
                          f"(zz-grammar-case-endings), so this path needs its B1 plan: the "
                          f"milestones A1, A2 and B1, in that order", PATH)
        # A language with no core keeps its list paths.
        zy = self.tmp / "zy"
        zy.mkdir()
        (zy / "zy-en-path.yaml").write_text(dump({
            "schema": 1, "kind": "path", "id": "zy-en-path", "language": "zy",
            "native": "en", "units": [["zy-en-words"]]}), encoding="utf-8")
        words = single("zy-en-words")
        words["language"] = dict(LANGUAGE, code="zy")
        words["cards"] = [dict(CAT, id="zy-9501")]
        (zy / "zy-en-words.yaml").write_text(dump(words), encoding="utf-8")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = validate_decks.main(["v", str(zy)])
        self.assertEqual(code, 0, out.getvalue())

    def test_a_b1_deck_still_single_file_is_warned_of(self) -> None:
        self.put(EXTRA, single(cards=[dict(CAT, pos="other",
                                           notes=[{"kind": "usage", "text": "Shy."}])]))
        self.edit(PATH, lambda d: d["units"][0]["decks"].append("zz-en-extra"))
        self.edit(PATH, lambda d: d["units"][0].update(words=5))
        self.assertWarned(PATH, "units[0]", "zz-en-extra is a single-file deck; a deck in a "
                                            "B1 plan is split into a core and its layers as "
                                            "the plan is written")

    def test_a_unit_with_more_words_than_planned_is_warned_of(self) -> None:
        self.edit(PATH, lambda d: d["units"][0].update(words=3))
        self.assertWarned(PATH, "units[0]", "has 4 words, more than the 3 planned; raise "
                                            "words")
        self.edit(PATH, lambda d: d["units"][0].update(words=4))
        self.assertNotIn("more than the", "\n".join(self.run_main()))

    def test_sizes_near_the_levels_are_not_warned_of(self) -> None:
        self.edit(PATH, lambda d: (d["units"][0].update(words=700),
                                   d["units"][1].update(words=900),
                                   d["units"][2]["planned"].update(words=1200)))
        self.assertEqual(self.section(self.run_main(), PATH), [
            "  info    units: B1 plan: A1 700 words (about 700), A2 +900 (about 900), "
            "B1 +1200 (about 1,200); 2800 in all; 4 grammar topics; 1 units planned"])

    def test_a_planned_theme_is_in_the_themes_file(self) -> None:
        themes = self.tmp / "themes.yaml"
        files = (CORE, LAYER, RULES, RULES_LAYER, PATH, "../themes.yaml")
        themes.write_text(dump({"schema": 1, "kind": "themes",
                                "themes": [{"id": "home", "name": "Home"}]}), encoding="utf-8")
        self.assertWarned(PATH, "units[2].planned.theme", "'health' is not in "
                                                          "decks/themes.yaml; add it before "
                                                          "the deck is written", *files)
        themes.write_text(dump({"schema": 1, "kind": "themes",
                                "themes": [{"id": "health", "name": "Health"}]}),
                          encoding="utf-8")
        self.assertNotIn("is not in decks/themes.yaml", "\n".join(self.run_main(*files)))


class ScriptInProse(B1Case):
    """Section 11: a layer's prose is its native language's; a core's is the
    language learnt's."""

    def test_a_layers_prose_needs_readings_for_the_language_learnt(self) -> None:
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(native="a ఇల్లు, a home"))
        self.assertError(LAYER, "cards.zz-9001.native",
                         "'ఇల్లు' has no transliteration beside it; write its ISO 15919 "
                         "reading in parentheses, as లేదు (lēdu)")
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            native="a ఇల్లు (illu), a home"))
        self.assertNoError(LAYER)

    def test_a_slot_key_is_not_a_language_code(self) -> None:
        # "lo" would read as Lao, whose prose may follow a word with its own
        # script in brackets. A layer's prose is English throughout.
        self.edit(RULES_LAYER, lambda d: d["table"]["prompts"]["zz-9001"].update(
            lo="at ఇంట్లో (ఇంట్లో)"))
        self.assertError(RULES_LAYER, "table.prompts.zz-9001.lo",
                         "'ఇంట్లో' has no transliteration beside it; write its ISO 15919 "
                         "reading in parentheses, as లేదు (lēdu)")

    def test_a_bengali_layers_own_words_need_no_reading(self) -> None:
        bn = {"schema": 1, "id": "zz-bn-home", "kind": "layer", "core": "zz-home",
              "native": dict(NATIVES["bn"]), "name": "বাড়ি", "license": "CC0-1.0",
              "cards": {"zz-9004": {"native": "মা", "notes": {"address": "আদর।"}}}}
        self.put("bn/zz-bn-home.yaml", bn)
        self.assertNoError("bn/zz-bn-home.yaml")
        bn["cards"]["zz-9004"]["native"] = "అమ్మ"
        self.put("bn/zz-bn-home.yaml", bn)
        self.assertError("bn/zz-bn-home.yaml", "cards.zz-9004.native",
                         "'అమ్మ' has no transliteration beside it; write its ISO 15919 "
                         "reading in parentheses, as లేదు (lēdu)")

    def test_a_cores_own_words_need_no_reading(self) -> None:
        self.assertNoError(CORE)
        self.edit(CORE, lambda d: d.update(source="ইল্লু"))
        self.assertNoError(CORE, "transliteration")

    def test_a_paths_passages_are_prose(self) -> None:
        self.edit(PATH, lambda d: d["units"][2].update(
            listening_passages=["Going to the ఇల్లు"]))
        self.assertError(PATH, "units.2.listening_passages.0",
                         "'ఇల్లు' has no transliteration beside it; write its ISO 15919 "
                         "reading in parentheses, as లేదు (lēdu)")

    def test_placeholders_are_checked_before_they_are_filled(self) -> None:
        # The fixture's note "{1}" stands for ఇంటి- (iṇṭi-): no reading needed.
        self.assertNoError(LAYER)


class Compatibility(unittest.TestCase):
    """Section 12: today's decks print what they printed before."""

    def test_todays_decks_get_no_info_and_no_b1_message(self) -> None:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = validate_decks.main(["validate_decks.py",
                                        str(validate_decks.ROOT / "decks")])
        lines = out.getvalue().splitlines()
        self.assertEqual(code, 0, lines)
        self.assertEqual([x for x in lines if x.startswith(("info ", "  info"))], [])
        self.assertEqual([x for x in lines if x.startswith(("error", "FAIL"))], [])


class CountsAsWord(unittest.TestCase):
    """Section 8.5: what counts as one of a unit's words."""

    def test_counts_as_word(self) -> None:
        f = validate_decks.counts_as_word
        self.assertTrue(f({"target": "ఇల్లు", "pos": "noun"}, "vocab"))
        self.assertTrue(f({"target": "ఇల్లు"}, "vocab"))
        self.assertTrue(f({"target": "పని చేయు", "pos": "verb"}, "vocab"))
        self.assertFalse(f({"target": "పని చేయు", "pos": "other"}, "vocab"))
        self.assertFalse(f({"target": "ఇల్లు", "pos": "phrase"}, "vocab"))
        self.assertFalse(f({"target": "అమ్మ!", "phrasebook": True}, "vocab"))
        self.assertFalse(f({"target": "ఇల్లు", "pos": "noun"}, "grammar"))
        self.assertTrue(f({"target": "నేను", "pos": "pronoun"}, "vocab"))


if __name__ == "__main__":
    unittest.main()
