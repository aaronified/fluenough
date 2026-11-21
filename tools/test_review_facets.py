#!/usr/bin/env python3
"""Facets as the tools read them (ADR-0058, W9): the normalisation and the
receipt hash, kept equal to the app's (`lib/core/review/fix_text.dart`,
`review_receipt.dart`), the facet and tag names, and the facet status under
the one quorum rule.

Stdlib `unittest`. Nothing here touches decks/.
"""

from __future__ import annotations

import hashlib
import re
import sys
import unicodedata
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import proposals as pr  # noqa: E402
import review_facets as rf  # noqa: E402
import review_quorum as rq  # noqa: E402

LIB = Path(__file__).resolve().parent.parent / "lib" / "core" / "review"
A, B, C = "FL-AAAA-AAAA-A", "FL-BBBB-BBBB-B", "FL-CCCC-CCCC-C"


def dart(name: str) -> str:
    return (LIB / name).read_text(encoding="utf-8")


def expand(chars: str) -> set[str]:
    """The characters of the inside of a regular expression's `[...]`, ranges
    `a-b` expanded; escapes already replaced by the characters."""
    out: set[str] = set()
    i = 0
    while i < len(chars):
        if i + 2 < len(chars) and chars[i + 1] == "-":
            out.update(chr(c) for c in range(ord(chars[i]), ord(chars[i + 2]) + 1))
            i += 3
        else:
            out.add(chars[i])
            i += 1
    return out


def unescape(text: str) -> str:
    text = re.sub(r"\\u([0-9A-Fa-f]{4})", lambda m: chr(int(m.group(1), 16)), text)
    for escape, char in (("\\t", "\t"), ("\\n", "\n"), ("\\f", "\f"), ("\\r", "\r")):
        text = text.replace(escape, char)
    return text


class Normalising(unittest.TestCase):
    def test_nfc_and_white_space(self) -> None:
        # The same word typed composed and decomposed, in Latin and Devanagari
        # (the nukta letter is a composition exclusion), is one fix.
        for a, b in (("é", "é"), ("क़", "क़"),
                     ("क़", "क़"), ("가", "가")):
            with self.subTest(a=a.encode("unicode_escape")):
                self.assertTrue(rf.same_fix_text(a, b))
        self.assertEqual(rf.normalize_fix_text("  a  \t b　c\n"), "a b c")
        self.assertTrue(rf.same_fix_text("kaala   ", " kaala"))

    def test_nothing_else_is_changed(self) -> None:
        # Case, punctuation and the joiners are as typed: dropping one can
        # change a word.
        self.assertFalse(rf.same_fix_text("Kala", "kala"))
        self.assertFalse(rf.same_fix_text("a‍b", "ab"))
        self.assertFalse(rf.same_fix_text("a.", "a"))
        self.assertEqual(rf.normalize_fix_text(""), "")

    def test_the_white_space_is_the_apps(self) -> None:
        source = re.search(r"_whitespaceRun = RegExp\(r'\[(.*?)\]\+'\)",
                           dart("fix_text.dart"), re.S)
        self.assertIsNotNone(source)
        app = expand(unescape(source.group(1)))
        ours = expand(rf._WHITESPACE_RUN.pattern[1:-2])
        self.assertEqual(app, ours)

    def test_the_composition_is_the_apps(self) -> None:
        """A port of `nfc` of the app, from its tables in nfc_data.dart (made
        from `unicodedata` by tools/gen_nfc_tables.py), agrees with
        `unicodedata` on text of the scripts the decks use. A failure means
        nfc_data.dart or fix_text.dart has moved and one side must follow."""
        data = dart("nfc_data.dart")

        def table(name: str) -> str:
            found = re.search(rf"const String {name} =\s*'([^']*)';", data)
            self.assertIsNotNone(found, name)
            return found.group(1)

        decomposition = {int(e.split(":")[0], 16): [int(x, 16) for x in e.split(":")[1].split()]
                         for e in table("nfcDecompositions").split(";") if e}
        classes = {int(e.split(":")[0], 16): int(e.split(":")[1])
                   for e in table("nfcCombiningClasses").split(";") if e}
        composition = {tuple(int(x, 16) for x in e.split(":")[0].split()): int(e.split(":")[1], 16)
                       for e in table("nfcCompositions").split(";") if e}

        def app_nfc(text: str) -> str:
            runes: list[int] = []
            for ch in text:
                cp = ord(ch)
                s = cp - 0xAC00
                if 0 <= s < 11172:
                    runes += [0x1100 + s // 588, 0x1161 + (s % 588) // 28]
                    if s % 28:
                        runes.append(0x11A7 + s % 28)
                else:
                    runes += decomposition.get(cp, [cp])
            for i in range(1, len(runes)):
                c = classes.get(runes[i], 0)
                j = i
                while c and j > 0 and classes.get(runes[j - 1], 0) > c:
                    runes[j - 1], runes[j] = runes[j], runes[j - 1]
                    j -= 1

            def pair(first: int, second: int) -> int | None:
                l, v = first - 0x1100, second - 0x1161
                if 0 <= l < 19 and 0 <= v < 21:
                    return 0xAC00 + (l * 21 + v) * 28
                s, t = first - 0xAC00, second - 0x11A7
                if 0 <= s < 11172 and s % 28 == 0 and 0 < t < 28:
                    return first + t
                return composition.get((first, second))

            out: list[int] = []
            starter, last = -1, 0
            for r in runes:
                c = classes.get(r, 0)
                if starter >= 0:
                    blocked = len(out) - 1 != starter and last >= c
                    joined = None if blocked else pair(out[starter], r)
                    if joined is not None:
                        out[starter] = joined
                        continue
                if c == 0:
                    starter = len(out)
                out.append(r)
                last = c
            return "".join(map(chr, out))

        # Whole blocks of the scripts the decks use, each letter alone and
        # with a nukta, a virama and an accent after it, and Hangul.
        marks = "़়्̣́ా்"
        blocks = [(0x00C0, 0x024F), (0x0900, 0x097F), (0x0980, 0x09FF),
                  (0x0A80, 0x0AFF), (0x0B80, 0x0BFF), (0x0C00, 0x0C7F),
                  (0x0D00, 0x0D7F), (0x1E00, 0x1EFF), (0x3040, 0x30FF),
                  (0xAC00, 0xAC00 + 600)]
        checked = 0
        for lo, hi in blocks:
            for cp in range(lo, hi + 1):
                ch = chr(cp)
                for text in (ch, ch + marks, marks[:2] + ch, ch + marks[::-1]):
                    expected = unicodedata.normalize("NFC", text)
                    # Dart's tables are Unicode 15.1; a newer Python knows
                    # characters those do not, and they are not compared.
                    if unicodedata.unidata_version > "15.1.0" and any(
                            unicodedata.decomposition(c) and c not in decomposition
                            and unicodedata.normalize("NFD", c) != c for c in text):
                        continue
                    self.assertEqual(app_nfc(text), expected, text.encode("unicode_escape"))
                    checked += 1
        self.assertGreater(checked, 5000)


class Hashing(unittest.TestCase):
    def test_a_receipt_hash_is_sha256_of_the_normalised_text(self) -> None:
        want = hashlib.sha256("kala nila".encode("utf-8")).hexdigest()[:16]
        self.assertEqual(rf.hash_of_seen("kala nila"), want)
        self.assertEqual(rf.hash_of_seen(" kala  nila "), want)
        self.assertEqual(rf.hash_of_seen("é"), rf.hash_of_seen("é"))
        self.assertEqual(len(want), rf.RECEIPT_HASH_LENGTH)

    def test_no_text_hashes_as_the_empty_text(self) -> None:
        self.assertEqual(rf.hash_of_seen(None), rf.hash_of_seen(""))
        self.assertEqual(rf.hash_of_seen(""), hashlib.sha256(b"").hexdigest()[:16])

    def test_the_length_is_the_apps(self) -> None:
        found = re.search(r"receiptHashLength = (\d+)", dart("review_receipt.dart"))
        self.assertEqual(int(found.group(1)), rf.RECEIPT_HASH_LENGTH)


class Names(unittest.TestCase):
    def test_the_facets_are_the_apps_in_order(self) -> None:
        enum = re.search(r"enum Facet \{(.*?)\n  const Facet", dart("facets.dart"), re.S).group(1)
        self.assertEqual(tuple(re.findall(r"\w+\('(\w+)'\)", enum)), rf.FACETS)

    def test_the_tags_and_their_facets_are_the_apps(self) -> None:
        enum = re.search(r"enum PointerTag \{(.*?)\n  const PointerTag", dart("facets.dart"),
                         re.S).group(1)
        app = {}
        for wire, facets in re.findall(r"\w+\('(\w+)', <Facet>\{(.*?)\}\)", enum, re.S):
            wires = {"unitPlacement": "unit", "offenceRating": "offence"}
            app[wire] = frozenset(wires.get(f, f) for f in re.findall(r"Facet\.(\w+)", facets))
        self.assertEqual(app, rf.TAG_FACETS)

    def test_a_fix_goes_to_a_field_of_the_facet(self) -> None:
        self.assertEqual(rf.FIELD_OF_FACET["meaning"], "native")
        self.assertEqual(rf.FACET_OF_FIELD["target"], "word")


class Answers(unittest.TestCase):
    def test_right_and_flagged(self) -> None:
        self.assertEqual(rf.read_answer("word", A, {"ok": True}), rf.Answer(A))
        flag = rf.read_answer("reading", A, {"tags": ["reading_wrong"], "fix": "kaala"})
        self.assertEqual(flag, rf.Answer(A, ("reading_wrong",), "kaala"))
        self.assertFalse(flag.right)

    def test_what_is_not_an_answer_is_left_out_never_made_right(self) -> None:
        for raw in (None, "ok", [], {}, {"ok": False}, {"tags": "x"}, {"tags": []},
                    # a tag that does not belong on the facet
                    {"tags": ["ipa_wrong"]}, {"tags": ["nonsense"]}):
            with self.subTest(raw=raw):
                self.assertIsNone(rf.read_answer("reading", A, raw))
        # An unknown tag among good ones is dropped alone.
        self.assertEqual(rf.read_answer("reading", A, {"tags": ["x", "reading_wrong"]}).tags,
                         ("reading_wrong",))
        self.assertIsNone(rf.read_answer("colour", A, {"ok": True}))

    def test_a_fix_on_a_facet_that_is_not_text_is_dropped(self) -> None:
        for facet, tag in (("unit", "wrong_unit"), ("audio", "audio_wrong"),
                           ("offence", "offensive")):
            with self.subTest(facet):
                got = rf.read_answer(facet, A, {"tags": [tag], "fix": "something"})
                self.assertEqual(got, rf.Answer(A, (tag,), ""))
        got = rf.read_answer("example", A, {"tags": ["example_wrong"], "fix": "x"})
        self.assertEqual(got.fix, "x")

    def test_a_card_keeps_the_good_answers(self) -> None:
        got = rf.read_answers(A, {"word": {"ok": True}, "reading": {"tags": ["zzz"]},
                                  "colour": {"ok": True}, "meaning": 3})
        self.assertEqual(list(got), ["word"])
        self.assertEqual(rf.read_answers(A, None), {})

    def test_receipts_of_the_card(self) -> None:
        got = rf.read_receipts([
            {"card": "zz-1", "facet": "word", "hash": "abc", "decision": "right"},
            {"facet": "reading", "hash": "def"},
            {"card": "zz-2", "facet": "meaning", "hash": "ghi"},
            {"card": "zz-1", "facet": "colour", "hash": "x"},
            {"card": "zz-1", "facet": "ipa", "hash": ""},
            "junk"], "zz-1")
        self.assertEqual(got, {"word": "abc", "reading": "def"})
        self.assertEqual(rf.read_receipts(None, "zz-1"), {})


class Vectors(unittest.TestCase):
    def test_the_shared_cases(self) -> None:
        import json
        path = Path(__file__).resolve().parent.parent / "test" / "support" / "facet_status_cases.json"
        cases = json.loads(path.read_text(encoding="utf-8"))["cases"]
        self.assertGreater(len(cases), 10)
        for case in cases:
            with self.subTest(case["name"]):
                checks = []
                for c in case["checks"]:
                    answer = c["answer"]
                    right = answer == "right"
                    checks.append(rf.Check(c["rater"], right,
                                           "" if right else answer.get("fix", ""),
                                           c.get("tier", rq.PROVISIONAL)))
                nv = case.get("needs_verified", False)
                lang = case.get("language")
                self.assertEqual(rf.facet_status(checks, needs_verified=nv, language=lang),
                                 case["status"])
                self.assertEqual(rf.settled(checks, needs_verified=nv, language=lang),
                                 case["settled"])


class Status(unittest.TestCase):
    """The same cases as the app's `facetStatus` (test/review_quorum_test)."""

    def checks(self, *spec: tuple) -> list[rf.Check]:
        return [rf.Check(*s) for s in spec]

    def test_unchecked_checking_settled(self) -> None:
        self.assertEqual(rf.facet_status([]), "unchecked")
        self.assertEqual(rf.facet_status(self.checks((A,))), "checking")
        self.assertEqual(rf.facet_status(self.checks((A,), (B,))), "settled")
        # A code counts once, however often it answered, and in any case.
        self.assertEqual(rf.facet_status(self.checks((A,), (A.lower(),))), "checking")

    def test_a_flag_makes_a_facet_unsettled_whatever_the_rest_say(self) -> None:
        self.assertEqual(rf.facet_status(self.checks((A,), (B,), (C, False))), "contested")
        self.assertEqual(rf.facet_status(self.checks((A, False))), "flagged")
        self.assertFalse(rf.settled(self.checks((A,), (B,), (C, False))))
        self.assertTrue(rf.settled(self.checks((A,), (B,))))

    def test_the_latest_answer_of_a_rater_counts(self) -> None:
        # Right, then a flag: no longer a check. A flag, then right: it is.
        self.assertEqual(rf.facet_status(self.checks((A,), (B,), (B, False))), "contested")
        self.assertEqual(rf.facet_status(self.checks((A,), (B, False), (B,))), "settled")
        self.assertEqual(rf.facet_status(self.checks((A, False, "x"), (A,))), "checking")

    def test_the_same_fix_after_normalisation_is_agreed(self) -> None:
        agreed = self.checks((A, False, "kaala"), (B, False, " kaala "))
        self.assertEqual(rf.facet_status(agreed), "agreed_fix")
        self.assertEqual(rf.facet_status(self.checks((A, False, "é"),
                                                     (B, False, "é"))), "agreed_fix")
        self.assertEqual(rf.facet_status(
            self.checks((A, False, "kaala"), (B, False, "kala"))), "contested")
        # One fix and one bare flag: flagged, nothing to apply.
        self.assertEqual(rf.facet_status(
            self.checks((A, False, "kaala"), (B, False))), "flagged")

    def test_the_verified_requirement_is_a_switch(self) -> None:
        self.assertFalse(rq.QUORUM_NEEDS_VERIFIED)
        two = self.checks((A,), (B,))
        self.assertEqual(rf.facet_status(two, needs_verified=True), "checking")
        verified = [rf.Check(A, tier=rq.VERIFIED), rf.Check(B)]
        self.assertEqual(rf.facet_status(verified, needs_verified=True), "settled")


CASES = Path(__file__).resolve().parent.parent / "test" / "support" / "comparison_fold_cases.json"


class ComparisonFolds(unittest.TestCase):
    """The same vectors as `test/script_folds_test.dart`."""

    def load(self) -> dict:
        import json
        return json.loads(CASES.read_text(encoding="utf-8"))

    def test_the_shared_pairs(self) -> None:
        pairs = self.load()["pairs"]
        self.assertGreater(len(pairs), 40)
        for case in pairs:
            with self.subTest(case["name"]):
                self.assertEqual(
                    rf.same_fix_in(case["a"], case["b"], case["language"],
                                   case.get("case_insensitive", False)),
                    case["same"])

    def test_the_shared_keys(self) -> None:
        for case in self.load()["keys"]:
            with self.subTest(case["name"]):
                self.assertEqual(
                    rf.comparison_key(case["text"], case["language"],
                                      case.get("case_insensitive", False)),
                    case["key"])

    def test_the_registry_is_the_one_the_app_has(self) -> None:
        mine = [{"id": i, "languages": sorted(langs),
                 "map": {f"{k:04X}": None if v is None else f"{v:04X}"
                         for k, v in m.items()}}
                for i, langs, m in rf.COMPARISON_FOLDS]
        self.assertEqual(mine, self.load()["folds"])

    def test_a_fold_never_maps_to_a_letter_of_another_word(self) -> None:
        # Every mapped code point is a variant form: the targets are the
        # Persian/Urdu yeh and kaf and the extended digits, or dropped.
        allowed = {0x06CC, 0x06A9, *range(0x06F0, 0x06FA), None}
        for _id, _langs, mapping in rf.COMPARISON_FOLDS:
            self.assertLessEqual(set(mapping.values()), allowed)

    def test_the_text_itself_is_never_changed(self) -> None:
        typed = "\u0643\u0640\u064A \u0661"
        rf.comparison_key(typed, "ur")
        self.assertEqual(typed, "\u0643\u0640\u064A \u0661")
        self.assertEqual(rf.normalize_fix_text(typed), typed)

    def test_the_status_uses_the_folds_of_the_language(self) -> None:
        one = "\u06A9\u064A"
        two = "\u06A9\u06CC"
        checks = [rf.Check(A, False, one), rf.Check(B, False, two)]
        self.assertEqual(rf.facet_status(checks), "contested")
        self.assertEqual(rf.facet_status(checks, language="ur"), "agreed_fix")
        self.assertEqual(rf.facet_status(checks, language="ps"), "contested")


class Comparison(unittest.TestCase):
    """The blind-pass comparison: `compareFacet`, `compareAnswers`."""

    def test_agreed_right(self) -> None:
        got = rf.compare_facet([rf.Check(A), rf.Check(B)])
        self.assertEqual((got.status, got.fixes, got.needs_human), ("settled", (), False))

    def test_agreed_fix_after_the_folds_keeps_the_first_text(self) -> None:
        yeh, farsi = "\u06A9\u064A", "\u06A9\u06CC"
        got = rf.compare_facet([rf.Check(A, False, yeh), rf.Check(B, False, farsi)], "ur")
        self.assertEqual(got.status, "agreed_fix")
        self.assertEqual(got.agreed_fix, yeh)
        self.assertEqual(got.fixes, (yeh,))
        self.assertFalse(got.needs_human)

    def test_rival_fixes_keep_the_order_proposed(self) -> None:
        got = rf.compare_facet([rf.Check(A, False, "kala"), rf.Check(B, False, "kaala"),
                                rf.Check(C, False, " kala ")])
        self.assertEqual(got.status, "contested")
        self.assertEqual(got.fixes, ("kala", "kaala"))
        self.assertTrue(got.needs_pick)
        self.assertIsNone(got.agreed_fix)

    def test_right_against_a_flag_is_contested(self) -> None:
        got = rf.compare_facet([rf.Check(A), rf.Check(B, False, "x")])
        self.assertEqual((got.status, got.fixes), ("contested", ("x",)))
        self.assertFalse(got.needs_pick)

    def test_a_flag_with_no_fix(self) -> None:
        got = rf.compare_facet([rf.Check(A, False)])
        self.assertTrue(got.flagged_no_fix)
        self.assertTrue(got.needs_human)

    def test_a_later_answer_of_a_rater_replaces_the_earlier(self) -> None:
        got = rf.compare_facet([rf.Check(A, False, "x"), rf.Check(A, False, "y")])
        self.assertEqual(got.fixes, ("y",))

    def test_per_facet_over_several_reviewers(self) -> None:
        flag = rf.Answer(A, ("spelling_wrong",), "\u06A9\u064A")
        flag2 = rf.Answer(B, ("spelling_wrong",), "\u06A9\u06CC")
        right = rf.Answer(A)
        got = rf.compare_answers(
            {A: {"word": flag, "meaning": right}, B: {"word": flag2, "meaning": rf.Answer(B)}},
            "ur", "en")
        self.assertEqual(sorted(got), ["meaning", "word"])
        self.assertEqual(got["word"].status, "agreed_fix")
        self.assertEqual(got["meaning"].status, "settled")
        # Without the course, the word is compared by NFC alone.
        self.assertEqual(rf.compare_answers({A: {"word": flag}, B: {"word": flag2}})["word"].status,
                         "contested")

    def test_the_language_of_a_facet(self) -> None:
        self.assertEqual(rf.language_of_facet("word", "ur", "en"), "ur")
        self.assertEqual(rf.language_of_facet("example", "ur", "en"), "ur")
        self.assertEqual(rf.language_of_facet("meaning", "ur", "en"), "en")
        self.assertEqual(rf.language_of_facet("note", "ur", "en"), "en")
        self.assertIsNone(rf.language_of_facet("reading", "ur", "en"))
        self.assertIsNone(rf.language_of_facet("ipa", "ur", "en"))


class TheBotUsesTheSameComparison(unittest.TestCase):
    """The bot's callers pass the facet's language, so that it and the app
    (and the coverage table) call the same fixes the same."""

    def test_the_language_of_a_facet_of_a_deck(self) -> None:
        self.assertEqual(pr.fix_language("ur", "ur-en-home", "word"), "ur")
        self.assertEqual(pr.fix_language("ur", "ur-en-home", "meaning"), "en")
        self.assertEqual(pr.fix_language("ur", "ur-en-home", "note"), "en")
        self.assertIsNone(pr.fix_language("ur", "ur-en-home", "reading"))
        # A core deck names no native: its meaning has no script rules.
        self.assertIsNone(pr.fix_language("ur", "ur-home", "meaning"))
        self.assertEqual(pr.fix_language("ur", "ur-home", "word"), "ur")
        self.assertIsNone(rf.fold_language("word", None, "en"))

    def test_settled_and_entry_checks_take_the_language(self) -> None:
        held = {"word": {"by": [], "flags": [
            {"by": A, "tags": ["spelling_wrong"], "fix": "\u0643\u062A\u0627\u0628"},
            {"by": B, "tags": ["spelling_wrong"], "fix": "\u06A9\u062A\u0627\u0628"}]}}
        data = {"target": "x"}
        urdu = rf.checks_of([], held, "word", "ur")
        self.assertEqual(rf.facet_status(urdu, language="ur"), "agreed_fix")
        self.assertEqual(rf.facet_status(urdu), "contested")
        # Agreement is not "settled" (nobody says it is right), either way.
        self.assertFalse(rf.settled(urdu, language="ur"))
        self.assertFalse(rf.entry_settled([], held, data, False, "ur", "en"))
        self.assertTrue(rf.entry_open([], held, data, False, "ur", "en"))

    def test_exact_text_agreement_is_unchanged(self) -> None:
        for language in (None, "ur", "te"):
            self.assertTrue(rf.same_fix_in("\u06A9\u062A\u0627\u0628", "\u06A9\u062A\u0627\u0628", language))
            self.assertEqual(rf.same_fix_in(" kala ", "kala", language), rf.same_fix_text(" kala ", "kala"))


if __name__ == "__main__":
    unittest.main()
