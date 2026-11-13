#!/usr/bin/env python3
"""The deck header fields `genre`, `level`, `hidden`, `professional`,
`section`, `weave` and `pattern_family`, the genres' rules (modes, pos,
register, usage notes, creators), and the card `source` block with its
public-domain floor (wiki/Plan-Deck-Kinds-And-Topics.md, D1 to D4, D7).

One failing deck per rule, each made from the valid fixture set.
"""

from __future__ import annotations

import datetime
import shutil
import unittest

import kinds_testlib as k
from kinds_testlib import KindsCase, card, CULTURE, CULTURE_LAYER, MEDICINE, MULTIWORD, \
    PATH, PROVERBS, READING, SECTIONS, CREATORS, RECS

import validate_decks as vd


class PureFunctions(unittest.TestCase):
    def test_a_date_is_a_year_a_span_or_circa(self) -> None:
        self.assertEqual(vd.parse_years(1892), (1892, 1892))
        self.assertEqual(vd.parse_years("1892-1909"), (1892, 1909))
        self.assertEqual(vd.parse_years("c. 1750"), (1750, 1750))
        self.assertIsNone(vd.parse_years("1909-1892"))
        self.assertIsNone(vd.parse_years("last year"))
        self.assertIsNone(vd.parse_years(True))

    def test_the_term_table(self) -> None:
        self.assertEqual(vd.pd_term("IN"), 60)
        self.assertEqual(vd.pd_term("BD"), 60)
        self.assertEqual(vd.pd_term("CN"), 50)
        self.assertEqual(vd.pd_term("ES"), 70)
        self.assertEqual(vd.pd_term("ZZ"), 70)

    def test_the_floor_is_died_plus_term_before_this_year(self) -> None:
        today = datetime.date(2026, 6, 1)
        # 1966 + 60 = 2026, not before 2026; 1965 + 60 = 2025 is.
        self.assertIsNotNone(vd.public_domain_problem(
            {"author_died": 1966, "jurisdiction": "IN"}, today=today))
        self.assertIsNone(vd.public_domain_problem(
            {"author_died": 1965, "jurisdiction": "IN"}, today=today))
        self.assertIsNotNone(vd.public_domain_problem(
            {"author_died": 1965, "jurisdiction": "ES"}, today=today))
        self.assertIsNone(vd.public_domain_problem(
            {"author_died": 1950, "jurisdiction": "CN"}, today=today))

    def test_an_anonymous_work_needs_a_date_before_1900(self) -> None:
        today = datetime.date(2026, 6, 1)
        ok = {"author": "anonymous", "date": "c. 1750", "jurisdiction": "ES"}
        self.assertIsNone(vd.public_domain_problem(ok, today=today))
        self.assertIsNotNone(vd.public_domain_problem(
            {**ok, "date": 1950}, today=today))
        self.assertIsNotNone(vd.public_domain_problem(
            {"author": "Someone", "date": 1800}, today=today))

    def test_image_sizes_are_read_from_the_header(self) -> None:
        png = (k.FIXTURE / "creators" / "images" / "zz-ejemplo-autora.png").read_bytes()
        self.assertEqual(vd.image_size(png), (16, 16))
        self.assertIsNone(vd.image_size(b"not an image"))


class Fixture(KindsCase):
    def test_the_fixture_set_is_valid(self) -> None:
        self.assertValid()

    def test_a_deck_without_the_new_fields_is_unchanged(self) -> None:
        self.assertEqual(self.errors("zz/zz-words.yaml"), [])


class Header(KindsCase):
    def culture(self, change) -> None:
        self.edit(CULTURE, change)

    def test_an_unknown_genre_is_refused(self) -> None:
        self.culture(lambda d: d.__setitem__("genre", "poetry"))
        self.assertRejected("genre: must be one of")

    def test_a_level_is_one_of_the_six(self) -> None:
        self.culture(lambda d: d.__setitem__("level", "A3"))
        self.assertIn("level: must be one of A1, A2, B1, B2, C1, C2",
                      "\n".join(self.errors(CULTURE)))

    def test_hidden_and_weave_are_booleans(self) -> None:
        self.culture(lambda d: d.update({"hidden": "yes", "weave": "no"}))
        errors = "\n".join(self.errors(CULTURE))
        self.assertIn("hidden: must be true or false", errors)
        self.assertIn("weave: must be true or false", errors)

    def test_a_genre_deck_needs_a_level(self) -> None:
        self.culture(lambda d: d.pop("level"))
        self.assertIn("level: is required on a culture deck", "\n".join(self.errors(CULTURE)))

    def test_a_genre_names_the_kinds_it_may_have(self) -> None:
        self.edit(PROVERBS, lambda d: d.__setitem__("kind", "grammar"))
        self.assertIn("a proverbs deck is vocab", "\n".join(self.errors(PROVERBS)))

    def test_a_professional_deck_is_hidden_and_names_its_profession(self) -> None:
        self.edit(MEDICINE, lambda d: d.pop("hidden"))
        self.assertIn("a professional deck is hidden: true",
                      "\n".join(self.errors(MEDICINE)))
        self.edit(MEDICINE, lambda d: (d.__setitem__("hidden", True), d.pop("professional")))
        self.assertIn("a professional deck names its profession",
                      "\n".join(self.errors(MEDICINE)))

    def test_professional_is_only_for_a_professional_deck(self) -> None:
        self.culture(lambda d: d.__setitem__("professional", "medicine"))
        self.assertIn("only a professional deck names a profession",
                      "\n".join(self.errors(CULTURE)))

    def test_pattern_family_is_only_for_a_multiword_deck(self) -> None:
        self.culture(lambda d: d.__setitem__("pattern_family", "phrasal"))
        self.assertIn("only a multiword deck has a pattern_family",
                      "\n".join(self.errors(CULTURE)))

    def test_a_layer_takes_these_fields_from_its_core(self) -> None:
        self.edit(CULTURE_LAYER, lambda d: d.__setitem__("genre", "culture"))
        self.assertIn("a layer takes genre from its core",
                      "\n".join(self.errors(CULTURE_LAYER)))
        self.edit(CULTURE_LAYER, lambda d: (d.pop("genre"), d.__setitem__("hidden", True)))
        self.assertIn("a layer takes hidden from its core",
                      "\n".join(self.errors(CULTURE_LAYER)))

    def test_a_culture_deck_is_tagged_unreviewed_or_reviewed(self) -> None:
        self.culture(lambda d: d.__setitem__("tags", ["beginner"]))
        self.assertIn('tagged "unreviewed" until a reviewer checks it',
                      "\n".join(self.errors(CULTURE)))

    def test_a_reviewed_deck_has_every_card_checked(self) -> None:
        self.edit(PROVERBS, lambda d: d.__setitem__("tags", ["reviewed"]))
        self.assertIn("the deck is tagged reviewed, so every card needs checked_by",
                      "\n".join(self.errors(PROVERBS)))

    def test_a_card_is_never_easier_than_its_deck(self) -> None:
        self.culture(lambda d: card(d, "zz-9201").__setitem__("level", "A1"))
        self.assertIn("level A1 is below the deck's A2", "\n".join(self.errors(CULTURE)))

    def test_a_card_level_is_one_of_the_six(self) -> None:
        self.culture(lambda d: card(d, "zz-9201").__setitem__("level", "easy"))
        self.assertIn("level must be one of", "\n".join(self.errors(CULTURE)))

    def test_a_deck_without_a_genre_may_still_have_levels(self) -> None:
        self.edit("zz/zz-words.yaml", lambda d: (d.__setitem__("level", "B1"),
                                                 card(d, "zz-9001").__setitem__("level", "A1")))
        self.assertIn("level A1 is below the deck's B1",
                      "\n".join(self.errors("zz/zz-words.yaml")))


class Modes(KindsCase):
    def test_a_culture_card_is_not_typed(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201").__setitem__(
            "modes", ["recognition", "production"]))
        self.assertIn("mode 'production' is not allowed on a culture card",
                      "\n".join(self.errors(CULTURE)))

    def test_a_proverb_is_only_recognised_and_heard(self) -> None:
        self.edit(PROVERBS, lambda d: card(d, "zz-9401").__setitem__(
            "modes", ["recognition", "grammar"]))
        self.assertIn("mode 'grammar' is not allowed on a proverbs card",
                      "\n".join(self.errors(PROVERBS)))

    def test_a_multiword_verb_may_be_produced(self) -> None:
        self.edit(MULTIWORD, lambda d: card(d, "zz-9501").__setitem__(
            "modes", ["recognition", "production", "listening", "grammar"]))
        self.assertEqual(self.errors(MULTIWORD), [])

    def test_a_professional_card_is_not_a_grammar_cell(self) -> None:
        self.edit(MEDICINE, lambda d: card(d, "zz-9601").__setitem__("modes", ["grammar"]))
        self.assertIn("mode 'grammar' is not allowed on a professional card",
                      "\n".join(self.errors(MEDICINE)))

    def test_a_mode_outside_the_fixed_set_is_still_refused(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201").__setitem__("modes", ["dance"]))
        self.assertIn("unknown mode 'dance'", "\n".join(self.errors(CULTURE)))


class GenreCards(KindsCase):
    def test_a_proverb_has_pos_phrase(self) -> None:
        self.edit(PROVERBS, lambda d: card(d, "zz-9401").__setitem__("pos", "noun"))
        self.assertIn("pos must be phrase on a proverbs card",
                      "\n".join(self.errors(PROVERBS)))
        self.edit(PROVERBS, lambda d: card(d, "zz-9401").pop("pos"))
        self.assertIn("pos must be phrase on a proverbs card",
                      "\n".join(self.errors(PROVERBS)))

    def test_a_proverb_has_a_register(self) -> None:
        self.edit(PROVERBS, lambda d: card(d, "zz-9401").pop("register"))
        self.assertIn("a proverbs card has a register", "\n".join(self.errors(PROVERBS)))

    def test_a_multiword_card_has_a_usage_note(self) -> None:
        self.edit(MULTIWORD, lambda d: card(d, "zz-9501").pop("notes"))
        self.assertIn("a multiword card has a note of kind usage",
                      "\n".join(self.errors(MULTIWORD)))

    def test_a_culture_card_names_its_creator(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201").pop("creator"))
        self.assertIn("a culture card names its creator by id",
                      "\n".join(self.errors(CULTURE)))

    def test_an_anonymous_culture_card_needs_no_creator(self) -> None:
        def change(d: dict) -> None:
            c = card(d, "zz-9201")
            c.pop("creator")
            c["source"] = {"author": "anonymous", "collection": "Coplas de prueba",
                           "date": "c. 1600", "edition": "Colección de prueba",
                           "basis": "oral-tradition", "jurisdiction": "ES",
                           "rights_checked": "2026-11-12", "work": "Copla"}
        self.edit(CULTURE, change)
        self.assertEqual(self.errors(CULTURE), [])

    def test_an_anonymous_source_has_no_creator(self) -> None:
        def change(d: dict) -> None:
            c = card(d, "zz-9201")
            c["source"]["author"] = "anonymous"
        self.edit(CULTURE, change)
        self.assertIn("an anonymous source has no creator",
                      "\n".join(self.errors(CULTURE)))

    def test_a_creator_id_is_the_languages(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201").__setitem__("creator", "xx-person"))
        self.assertIn("creator must be a creator id of the language",
                      "\n".join(self.errors(CULTURE)))


class Paths(KindsCase):
    def test_a_path_may_name_a_visible_genre_deck(self) -> None:
        self.assertValid()
        self.assertIn("zz-culture-ejemplo", self.data(PATH)["units"][1]["decks"])

    def test_a_path_may_not_name_a_hidden_deck(self) -> None:
        self.edit(PATH, lambda d: d["units"].append(["zz-medicine-registro"]))
        self.assertRejected("a hidden deck: a hidden deck is on no path")

    def test_a_genre_deck_need_not_be_on_the_path(self) -> None:
        self.assertAccepted("does not list 'zz-proverbs-ejemplo'")

    def test_an_ordinary_deck_must_still_be_on_the_path(self) -> None:
        self.edit(PATH, lambda d: d["units"].pop(0))
        self.assertRejected("does not list 'zz-words'")


class Sections(KindsCase):
    def test_a_genre_must_be_listed_in_sections(self) -> None:
        def change(d: dict) -> None:
            d["genres"] = [g for g in d["genres"] if g["id"] != "multiword"]
        self.edit(SECTIONS, change)
        self.assertRejected("genre: 'multiword' is not listed in decks/sections.yaml")

    def test_a_profession_must_be_listed_in_sections(self) -> None:
        self.edit(SECTIONS, lambda d: d.__setitem__("professions", []))
        self.assertRejected("professional: 'medicine' is not listed in decks/sections.yaml")

    def test_a_section_must_be_listed_in_sections(self) -> None:
        self.edit(CULTURE, lambda d: d.__setitem__("section", "elsewhere"))
        self.assertRejected("section: 'elsewhere' is not listed in decks/sections.yaml")

    def test_without_a_sections_file_the_ids_are_not_checked(self) -> None:
        self.p(SECTIONS).unlink()
        code, text = self.run_main()
        self.assertEqual(code, 0, text)


class SourceBlock(KindsCase):
    """D4, rules 1 to 9, on the culture deck's first card."""

    def source(self, change, cid: str = "zz-9201", rel: str = CULTURE) -> list[str]:
        self.edit(rel, lambda d: change(card(d, cid)["source"]))
        return self.errors(rel)

    def assertSource(self, change, needle: str, cid: str = "zz-9201") -> None:
        self.assertIn(needle, "\n".join(self.source(change, cid)))

    def test_every_culture_card_has_a_source(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201").pop("source"))
        self.assertIn("a culture card has a source block", "\n".join(self.errors(CULTURE)))

    def test_a_source_is_a_mapping(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201").__setitem__("source", "a book"))
        self.assertIn("source must be a mapping", "\n".join(self.errors(CULTURE)))

    def test_the_required_keys(self) -> None:
        for key in ("author", "date", "jurisdiction", "rights_checked"):
            with self.subTest(key=key):
                self.assertSource(lambda s, key=key: s.pop(key), f"{key} is required")
                self.restore(CULTURE)

    def test_a_culture_source_names_its_work(self) -> None:
        self.assertSource(lambda s: s.pop("work"), "work is required on a culture card")

    def test_an_edition_or_a_url_is_needed(self) -> None:
        self.assertSource(lambda s: s.pop("edition"), "needs an edition or a url")

    def test_a_url_is_https(self) -> None:
        self.assertSource(lambda s: s.__setitem__("url", "http://example.org/x"),
                          "url must be an https link")

    def test_a_basis_is_one_of_four(self) -> None:
        self.assertSource(lambda s: s.__setitem__("basis", "fair-use"),
                          "basis must be one of public-domain, licensed, quotation")

    def test_a_date_is_a_year_a_span_or_circa(self) -> None:
        self.assertSource(lambda s: s.__setitem__("date", "long ago"),
                          "date must be a year, a span")

    def test_a_jurisdiction_is_two_capitals(self) -> None:
        self.assertSource(lambda s: s.__setitem__("jurisdiction", "spain"),
                          "jurisdiction must be an ISO 3166-1 alpha-2 code")

    def test_unknown_source_keys_are_refused(self) -> None:
        self.assertSource(lambda s: s.__setitem__("page", 12), "unknown field 'page'")

    def test_public_domain_needs_the_author_to_have_died(self) -> None:
        self.assertSource(lambda s: s.pop("author_died"),
                          "public-domain needs author_died")

    def test_public_domain_fails_the_floor(self) -> None:
        self.assertSource(lambda s: s.__setitem__("author_died", 1990),
                          "may still be protected")

    def test_the_floor_follows_the_jurisdiction(self) -> None:
        # 1960 + 70 = 2030 in Spain, but 1960 + 60 = 2020 in India.
        self.assertSource(lambda s: s.__setitem__("author_died", 1960),
                          "author_died 1960 + 70 years")
        self.restore(CULTURE)
        errors = self.source(lambda s: s.update({"author_died": 1960, "jurisdiction": "IN"}))
        self.assertNotIn("may still be protected", "\n".join(errors))

    def test_an_anonymous_public_domain_work_is_old(self) -> None:
        def change(s: dict) -> None:
            s.pop("author_died")
            s["author"] = "anonymous"
            s["date"] = 1950
        self.edit(CULTURE, lambda d: (card(d, "zz-9201").pop("creator"),
                                      change(card(d, "zz-9201")["source"])))
        self.assertIn("an anonymous work is public domain only when published before 1900",
                      "\n".join(self.errors(CULTURE)))

    def test_a_licensed_source_needs_a_free_licence(self) -> None:
        self.assertSource(lambda s: s.__setitem__("licence", "CC-BY-NC-4.0"),
                          "a licensed source needs licence", cid="zz-9202")
        self.restore(CULTURE)
        self.assertSource(lambda s: s.pop("licence_url"),
                          "a licensed source needs licence_url", cid="zz-9202")

    def test_a_quotation_is_short(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9203").__setitem__(
            "target", " ".join(["palabra"] * 26)))
        self.assertIn("a quotation is at most 25 words; this is 26",
                      "\n".join(self.errors(CULTURE)))

    def test_a_quotation_names_its_exception(self) -> None:
        self.assertSource(lambda s: s.pop("licence"),
                          "a quotation names the exception that allows it", cid="zz-9203")

    def test_a_deck_has_at_most_five_quotations(self) -> None:
        def change(d: dict) -> None:
            for n in range(6):
                c = {"id": f"zz-92{50 + n}", "target": f"Frase {n}.", "pos": "phrase",
                     "creator": "zz-ejemplo-poeta",
                     "source": dict(card(d, "zz-9203")["source"])}
                d["cards"].append(c)
        self.edit(CULTURE, change)
        errors = "\n".join(self.errors(CULTURE))
        self.assertIn("7 quotation cards; at most 5 per deck", errors)

    def test_oral_tradition_is_for_proverbs(self) -> None:
        self.assertSource(lambda s: s.__setitem__("basis", "oral-tradition"),
                          "basis oral-tradition is for proverbs")

    def test_an_oral_tradition_names_its_collection(self) -> None:
        self.edit(PROVERBS, lambda d: card(d, "zz-9401")["source"].pop("collection"))
        self.assertIn("an oral-tradition source names its collection or region",
                      "\n".join(self.errors(PROVERBS)))

    def test_rights_are_not_checked_in_the_future(self) -> None:
        self.assertSource(lambda s: s.__setitem__("rights_checked", "2027-01-01"),
                          "rights_checked 2027-01-01 is in the future")

    def test_rights_checked_is_a_date(self) -> None:
        self.assertSource(lambda s: s.__setitem__("rights_checked", "yesterday"),
                          "rights_checked must be a date written YYYY-MM-DD")

    def test_the_work_is_not_dated_after_the_check(self) -> None:
        self.assertSource(lambda s: s.__setitem__("date", 2030),
                          "is after rights_checked")

    def test_a_proverb_needs_a_source_too(self) -> None:
        self.edit(PROVERBS, lambda d: card(d, "zz-9401").pop("source"))
        self.assertIn("a proverbs card has a source block",
                      "\n".join(self.errors(PROVERBS)))

    def test_a_reading_passage_needs_a_source_block(self) -> None:
        self.edit(READING, lambda d: d["passages"][0].__setitem__("source", "a book"))
        self.assertIn("a culture card has a source block",
                      "\n".join(self.errors(READING)))

    def test_a_reading_passage_source_is_checked_like_a_card(self) -> None:
        self.edit(READING, lambda d: d["passages"][0]["source"].__setitem__(
            "author_died", 2000))
        self.assertIn("may still be protected", "\n".join(self.errors(READING)))

    def test_an_ordinary_reading_deck_keeps_its_text_source(self) -> None:
        def change(d: dict) -> None:
            for key in ("genre", "level"):
                d.pop(key)
            d["tags"] = ["beginner"]
            d["passages"][0].pop("creator")
            d["passages"][0].pop("level")
            d["passages"][0]["source"] = "A book of letters."
        self.edit(READING, change)
        self.assertEqual(self.errors(READING), [])

    def test_a_source_does_not_belong_to_a_layer(self) -> None:
        self.edit(CULTURE_LAYER, lambda d: d["cards"]["zz-9201"].__setitem__(
            "source", {"author": "x"}))
        self.assertTrue(self.errors(CULTURE_LAYER))


class AcrossFiles(KindsCase):
    """The source block against the creators file."""

    def test_a_card_names_a_creator_of_the_file(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201").__setitem__(
            "creator", "zz-nadie"))
        self.assertRejected("creator 'zz-nadie' is not in")

    def test_the_source_author_is_the_creator(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201")["source"].__setitem__(
            "author", "Otra Persona"))
        self.assertRejected("source.author 'Otra Persona' is none of zz-ejemplo-autora's names")

    def test_the_work_is_not_older_than_its_creator(self) -> None:
        self.edit(CULTURE, lambda d: card(d, "zz-9201")["source"].__setitem__("date", 1800))
        self.assertRejected("source date 1800 is before zz-ejemplo-autora was born (1850)")

    def test_without_a_creators_file_a_creator_is_unknown(self) -> None:
        shutil.rmtree(self.p("creators"))
        self.assertRejected("there is no decks/creators/zz.yaml")

    def test_a_reviewed_culture_deck_needs_its_creators_checked(self) -> None:
        def change(d: dict) -> None:
            d["tags"] = ["reviewed"]
            for c in d["cards"]:
                c["checked_by"] = ["FL-0000-0000-0"]
        self.edit(CULTURE, change)
        code, text = self.run_main()
        # checked_by is a rater code: whatever the code, the creator has none.
        self.assertIn("but creator zz-ejemplo-autora has no checked_by", text)

    def _add_a_creator_no_card_names(self) -> None:
        def change(d: dict) -> None:
            d["creators"].append({
                "id": "zz-ejemplo-solo", "name": {"zz": {"text": "Sola Prueba"}},
                "born": 1900, "era": "moderna",
                "bio": {"en": "A made-up creator no card names."}})
        self.edit(CREATORS, change)

    def test_a_creator_no_card_or_recommendation_names_warns(self) -> None:
        self._add_a_creator_no_card_names()
        code, text = self.run_main()
        self.assertEqual(code, 0, text)
        self.assertIn("creator zz-ejemplo-solo: no card cites this creator yet", text)

    def test_a_creator_only_a_recommendation_names_is_cited(self) -> None:
        self._add_a_creator_no_card_names()
        self.edit(RECS, lambda d: d["recommendations"][1]["creator"].append(
            "zz-ejemplo-solo"))
        code, text = self.run_main()
        self.assertEqual(code, 0, text)
        self.assertNotIn("no card cites this creator yet", text)


if __name__ == "__main__":
    unittest.main()
