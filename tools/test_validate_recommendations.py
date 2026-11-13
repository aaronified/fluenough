#!/usr/bin/env python3
"""The recommendations file, decks/recommendations/<code>.yaml (wiki/Plan-
Deck-Kinds-And-Topics.md, D13): popular works found elsewhere and taught
about, never reproduced, with authored questions and legal links only."""

from __future__ import annotations

import unittest
from pathlib import Path
from unittest import mock

import validate_decks
from kinds_testlib import KindsCase, RECS

BOOK = "zz-rec-cartas-de-prueba"
FILM = "zz-rec-una-pelicula"


def rec(data: dict, rid: str = BOOK) -> dict:
    return next(r for r in data["recommendations"] if r["id"] == rid)


class Recommendations(KindsCase):
    def check(self, change, needle: str) -> None:
        self.edit(RECS, change)
        self.assertIn(needle, "\n".join(self.errors(RECS)))

    def reject(self, change, needle: str) -> None:
        self.edit(RECS, change)
        self.assertRejected(needle)

    def test_the_fixture_file_is_valid(self) -> None:
        self.assertEqual(self.errors(RECS), [])
        self.assertValid()

    def test_the_file_is_named_for_its_language(self) -> None:
        self.check(lambda d: d.__setitem__("id", "recommendations-xx"),
                   "must be recommendations-zz")

    def test_unknown_keys_are_refused(self) -> None:
        self.check(lambda d: d.__setitem__("note", "x"), "unknown field 'note'")

    def test_a_recommendation_holds_no_text_of_the_work(self) -> None:
        self.check(lambda d: rec(d).__setitem__("excerpt", "Querida amiga..."),
                   "unknown field 'excerpt': a recommendation holds no text of the work")

    def test_an_id_is_the_languages_rec_id(self) -> None:
        self.check(lambda d: rec(d).__setitem__("id", "zz-cartas"), "id must be zz-rec-")

    def test_an_id_is_unique(self) -> None:
        self.check(lambda d: rec(d, FILM).__setitem__("id", BOOK),
                   "duplicate recommendation id")

    def test_a_medium_is_one_of_seven(self) -> None:
        self.check(lambda d: rec(d).__setitem__("medium", "poster"),
                   "medium must be one of book, film, series, song, play, podcast, comic")

    def test_a_title_has_its_reading_where_needed(self) -> None:
        self.check(lambda d: rec(d).__setitem__("title", {"text": "కన్యాశుల్కం"}),
                   "needs its reading")

    def test_a_creator_is_required(self) -> None:
        self.check(lambda d: rec(d).pop("creator"), "creator is required")

    def test_a_year_is_not_in_the_future(self) -> None:
        self.check(lambda d: rec(d).__setitem__("year", 2030), "year must be a year")

    def test_a_level_is_one_of_the_six(self) -> None:
        self.check(lambda d: rec(d).__setitem__("level", "easy"), "level must be one of")

    def test_a_book_names_its_script(self) -> None:
        self.check(lambda d: rec(d).pop("script"), "a book names the script it is printed in")

    def test_only_a_book_has_a_script(self) -> None:
        self.check(lambda d: rec(d, FILM).__setitem__("script", "latin"),
                   "only a book has a script")

    def test_a_briefing_has_an_english_entry(self) -> None:
        self.check(lambda d: rec(d).__setitem__("briefing", {"es": "Libro"}),
                   "text needs en")

    # Questions

    def test_there_are_three_to_eight_questions(self) -> None:
        self.check(lambda d: rec(d)["questions"].pop(), "questions must be a list of 3 to 8")
        self.restore(RECS)
        self.check(lambda d: rec(d).__setitem__(
            "questions", [dict(rec(d)["questions"][0], id=f"q{n}") for n in range(9)]),
            "questions must be a list of 3 to 8")

    def test_a_question_id_is_unique(self) -> None:
        self.check(lambda d: rec(d)["questions"][1].__setitem__("id", "q1"),
                   "duplicate question id 'q1'")

    def test_an_answer_is_one_of_the_options(self) -> None:
        self.check(lambda d: rec(d)["questions"][0].__setitem__("answer", 3),
                   "answer must be the number of the right option, from 1 to 2")

    def test_options_are_two_to_four(self) -> None:
        self.check(lambda d: rec(d)["questions"][0]["options"].__setitem__("en", ["only"]),
                   "options.en must be a list of 2 to 4 options")

    def test_every_language_gives_the_same_number_of_options(self) -> None:
        self.check(lambda d: rec(d)["questions"][0]["options"].__setitem__(
            "es", ["a", "b", "c"]), "every language gives the same number of options")

    def test_a_question_has_an_english_prompt(self) -> None:
        self.check(lambda d: rec(d)["questions"][0].__setitem__("prompt", {"es": "?"}),
                   "prompt needs en")

    # Legal links

    def test_a_legal_link_is_https(self) -> None:
        self.check(lambda d: rec(d)["legal"][0].__setitem__("url", "http://example.org/x"),
                   "url must be an https link")

    def test_a_legal_link_has_a_known_kind(self) -> None:
        self.check(lambda d: rec(d)["legal"][0].__setitem__("kind", "torrent"),
                   "kind must be one of library, publisher, store, stream, archive")

    def test_a_pirate_host_is_refused(self) -> None:
        self.check(lambda d: rec(d)["legal"][0].__setitem__(
            "url", "https://libgen.is/book/123"), "libgen.is is on the deny list")

    def test_a_subdomain_of_a_pirate_host_is_refused(self) -> None:
        self.check(lambda d: rec(d)["legal"][0].__setitem__(
            "url", "https://cdn.libgen.is/book/123"), "is on the deny list")

    def test_a_trailing_dot_host_is_refused(self) -> None:
        self.check(lambda d: rec(d)["legal"][0].__setitem__(
            "url", "https://libgen.is./book/123"), "is on the deny list")

    def test_an_uppercase_host_is_refused(self) -> None:
        self.check(lambda d: rec(d)["legal"][0].__setitem__(
            "url", "https://CDN.LibGen.IS./book/123"), "is on the deny list")

    def test_look_alike_hosts_are_allowed(self) -> None:
        def change(d: dict) -> None:
            rec(d)["legal"] = [{"kind": "store", "url": "https://notlibgen.is/x"},
                               {"kind": "store", "url": "https://libgen.is.example.org/x"}]
        self.edit(RECS, change)
        self.assertEqual(self.errors(RECS), [])

    def test_a_missing_deny_list_is_an_error(self) -> None:
        with mock.patch.object(validate_decks, "PIRATE_HOSTS",
                               Path("/nonexistent/pirate_hosts.txt")):
            errs = "\n".join(self.errors(RECS))
        self.assertIn("pirate_hosts.txt is missing or empty, the pirate-host deny "
                      "list cannot run", errs)

    def test_stores_and_streams_are_allowed(self) -> None:
        def change(d: dict) -> None:
            rec(d)["legal"] = [{"kind": "store", "url": "https://example.com/buy"},
                               {"kind": "stream", "url": "https://example.net/watch"}]
        self.edit(RECS, change)
        self.assertEqual(self.errors(RECS), [])

    # Reviewed, quoted

    def test_a_reviewed_recommendation_is_checked(self) -> None:
        self.check(lambda d: rec(d).__setitem__("tags", ["reviewed"]),
                   "is tagged reviewed, so it needs checked_by")

    def test_quoted_in_is_a_core_id(self) -> None:
        self.check(lambda d: rec(d).__setitem__("quoted_in", "nope"),
                   "quoted_in must be the core id of a zz culture deck")

    def test_quoted_in_names_a_deck_of_the_language(self) -> None:
        self.reject(lambda d: rec(d).__setitem__("quoted_in", "zz-nada"),
                    "quoted_in 'zz-nada' is no deck of zz")

    def test_the_quoting_deck_cites_the_same_creator(self) -> None:
        self.reject(lambda d: rec(d).__setitem__("quoted_in", "zz-proverbs-ejemplo"),
                    "quoted_in 'zz-proverbs-ejemplo' has no card citing the same creator")

    # Across files

    def test_a_creator_must_be_in_the_creators_file(self) -> None:
        self.reject(lambda d: rec(d).__setitem__("creator", ["zz-nadie"]),
                    "creator 'zz-nadie' is not in the creators file of zz")

    def test_a_work_is_not_older_than_its_creator(self) -> None:
        self.reject(lambda d: rec(d).__setitem__("year", 1800),
                    "year 1800 is before zz-ejemplo-autora was born (1850)")


if __name__ == "__main__":
    unittest.main()
