import unittest
from pathlib import Path

import validate_sample_decks as v

SAMPLE = Path(__file__).resolve().parent.parent / "test" / "fixtures" / "sample-decks"


class SampleDecks(unittest.TestCase):
    @unittest.skipUnless((SAMPLE / "decks").is_dir(), "no sample deck")
    def test_the_sample_passes_even_with_real_decks_in_the_checkout(self):
        # In CI, decks/ is a real decks/ beside the sample (main's frozen copy,
        # or the decks-live branch): the sample must not be held against it.
        self.assertEqual(v.main(["validate_sample_decks.py"]), 0)

    def test_a_folder_without_decks_is_a_bad_argument(self):
        self.assertEqual(v.main(["validate_sample_decks.py", "/nonexistent"]), 2)


if __name__ == "__main__":
    unittest.main()
