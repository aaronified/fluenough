"""Ed25519 in pure Python against RFC 8032's vectors and shared vectors.

`test/fixtures/reviewer_key_vectors.json` is also read by
`test/ed25519_test.dart`, so the Python and Dart verifiers stay equal.
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import ed25519  # noqa: E402

VECTORS = json.loads((Path(__file__).resolve().parent.parent / "test" / "fixtures"
                      / "reviewer_key_vectors.json").read_text(encoding="utf-8"))


class Ed25519Test(unittest.TestCase):
    def test_valid_vectors(self) -> None:
        for v in VECTORS["ed25519_valid"]:
            with self.subTest(v["name"]):
                seed = bytes.fromhex(v["seed"])
                msg = bytes.fromhex(v["message"])
                self.assertEqual(ed25519.public_key(seed).hex(), v["public"])
                self.assertEqual(ed25519.sign(seed, msg).hex(), v["signature"])
                self.assertTrue(ed25519.verify(
                    bytes.fromhex(v["public"]), msg, bytes.fromhex(v["signature"])))

    def test_rfc_8032_test_1_and_2(self) -> None:
        first = VECTORS["ed25519_valid"][0]
        self.assertEqual(
            first["signature"],
            "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555f"
            "b8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b")
        second = VECTORS["ed25519_valid"][1]
        self.assertEqual(
            second["signature"],
            "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da08"
            "5ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00")

    def test_invalid_vectors_are_refused(self) -> None:
        for v in VECTORS["ed25519_invalid"]:
            with self.subTest(v["name"]):
                self.assertFalse(ed25519.verify(
                    bytes.fromhex(v["public"]), bytes.fromhex(v["message"]),
                    bytes.fromhex(v["signature"])))

    def test_wrong_lengths_do_not_raise(self) -> None:
        self.assertFalse(ed25519.verify(b"", b"", b""))
        with self.assertRaises(ValueError):
            ed25519.public_key(b"short")


if __name__ == "__main__":
    unittest.main()
