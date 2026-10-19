#!/usr/bin/env python3
"""The IPA course's format (ADR-0041): an example's `language` and `sounds`,
a language block's `typed`, and `script: ipa`, which needs no reading, no
tts tag and no B1 plan.

Uses the B1 fixture and helpers of test_validate_b1. Stdlib `unittest` plus
PyYAML, like the validator itself.
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from test_validate_b1 import CAT, CORE, EXTRA, LAYER, B1Case, card, single  # noqa: E402

YES = {"target": "ఇల్లు", "language": "te", "sounds": True}
NO = {"target": "इल्लू", "language": "hi", "sounds": False}


class IpaExamples(B1Case):

    def test_a_core_example_may_give_its_language_and_sounds(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=[YES, NO]))
        self.assertNoError(CORE, "examples[")

    def test_the_translations_stay_in_the_layer(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(examples=[YES, NO]))
        self.edit(LAYER, lambda d: d["cards"]["zz-9001"].update(
            examples={"ఇల్లు": "house", "इल्लू": "not a word"}))
        self.assertNoError(LAYER)

    def test_sounds_is_a_boolean(self) -> None:
        for bad in ("false", 0, None):
            self.edit(CORE, lambda d, b=bad: card(d, "zz-9001").update(
                examples=[dict(YES, sounds=b)]))
            self.assertError(CORE, "card zz-9001",
                             "examples[0].sounds must be true or false")

    def test_language_is_a_code(self) -> None:
        self.edit(CORE, lambda d: card(d, "zz-9001").update(
            examples=[dict(YES, language="Telugu")]))
        self.assertError(CORE, "card zz-9001", "examples[0].language must be a 2-3 "
                                               "letter language code, got 'Telugu'")

    def test_a_single_file_example_may_give_them(self) -> None:
        ex = {"target": "పిల్లి.", "native": "A cat.", "language": "te",
              "sounds": False}
        self.put(EXTRA, single(cards=[dict(CAT, examples=[ex])]))
        self.assertNoError(EXTRA)
        self.put(EXTRA, single(cards=[dict(CAT, examples=[dict(ex, sounds="no")])]))
        self.assertError(EXTRA, "card zz-9501", "examples[0].sounds must be true or false")


class IpaLanguageBlock(B1Case):
    IPA = {"code": "ipa", "iso639_3": "zxx", "name": "IPA", "script": "ipa",
           "typed": False, "icon": "ə"}

    def test_typed_is_a_boolean(self) -> None:
        self.put(EXTRA, single(language=dict(self.IPA)))
        self.assertNoError(EXTRA, "typed")
        self.put(EXTRA, single(language=dict(self.IPA, typed="false")))
        self.assertError(EXTRA, "language", "typed must be a boolean")

    def test_the_ipa_script_needs_no_reading_and_no_tts(self) -> None:
        self.put(EXTRA, single(language=dict(self.IPA)))
        self.assertNoError(EXTRA, "reading")
        self.assertNoError(EXTRA, "script")
        self.assertNoError(EXTRA, "tts")

    def test_a_bracketed_ipa_is_narrow_and_only_for_the_ipa_course(self) -> None:
        ex = {"target": "pin", "native": "pin", "language": "en", "ipa": "[pʰɪn]"}
        self.put(EXTRA, single(language=dict(self.IPA),
                               cards=[dict(CAT, examples=[ex])]))
        self.assertNoError(EXTRA, "not a broad IPA")
        self.put(EXTRA, single(cards=[dict(CAT, examples=[ex])]))
        self.assertError(EXTRA, "ipa", "'[pʰɪn]' is not a broad IPA "
                         "transcription: IPA letters and marks only, "
                         "without / / or [ ]")


if __name__ == "__main__":
    unittest.main()
