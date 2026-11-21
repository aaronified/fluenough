"""Signed reviewer keys: the format, the checks and the owner's commands.

The shared cases are in `test/fixtures/reviewer_key_vectors.json`, which
`test/reviewer_key_test.dart` reads too. The throwaway key pair is made here,
never read from the repository, and nothing here is the owner's key.
"""

from __future__ import annotations

import datetime
import json
import os
import stat
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import ed25519  # noqa: E402
import reviewer_keys as rk  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ALL = json.loads((ROOT / "test" / "fixtures" / "reviewer_key_vectors.json")
                 .read_text(encoding="utf-8"))
VECTORS = ALL["reviewer_keys"]
SEED = bytes(range(32))
KEYRING = rk.Keyring({1: ed25519.public_key(SEED)}, frozenset({"00000000000000a1"}))


def minted(courses=("te/en", "bn"), tier="verified", key_id="0123456789abcdef"):
    return rk.sign_key(SEED, key_id, list(courses), tier, "2026-11-21", 1)


class SharedCasesTest(unittest.TestCase):
    def test_every_case(self) -> None:
        keyring = rk.Keyring(
            {VECTORS["version"]: rk._unb64(VECTORS["public_key"])},
            frozenset(VECTORS["denylist"]))
        for case in VECTORS["cases"]:
            with self.subTest(case["name"]):
                got = rk.check(case["key"], keyring)
                self.assertEqual(got.status, case["status"])
                if "key_id" in case:
                    self.assertEqual(got.key.key_id, case["key_id"])
                    self.assertEqual(sorted(got.key.courses), case["courses"])
                    self.assertEqual(got.key.tier, case["tier"])
                    self.assertEqual(got.key.issued, case["issued"])


class FormatTest(unittest.TestCase):
    def test_round_trip(self) -> None:
        got = rk.check(minted(), KEYRING)
        self.assertTrue(got.ok)
        self.assertEqual(got.key.courses, ("bn", "te/en"))
        self.assertTrue(got.key.unlocks("te", "en"))
        self.assertTrue(got.key.unlocks("bn", "hi"))
        self.assertFalse(got.key.unlocks("te", "hi"))

    def test_the_payload_has_one_form(self) -> None:
        self.assertEqual(
            rk.encode_payload("0123456789abcdef", ["te/en", "bn", "bn"],
                              "verified", "2026-11-21", 1),
            b'{"c":["bn","te/en"],"i":"2026-11-21","k":"0123456789abcdef",'
            b'"p":1,"t":"v"}')

    def test_refuses_what_a_key_may_not_hold(self) -> None:
        many = [f"a{chr(97 + i // 26)}{chr(97 + i % 26)}" for i in range(41)]
        for args in (("XYZ", ["te"], "verified", "2026-11-21", 1),
                     ("0123456789abcdef", [], "verified", "2026-11-21", 1),
                     ("0123456789abcdef", ["TE"], "verified", "2026-11-21", 1),
                     ("0123456789abcdef", ["te"], "owner", "2026-11-21", 1),
                     ("0123456789abcdef", ["te"], "verified", "21-11-2026", 1),
                     ("0123456789abcdef", ["te"], "verified", "2026-11-21", 0),
                     ("0123456789abcdef", many, "verified", "2026-11-21", 1)):
            with self.subTest(args):
                with self.assertRaises(rk.KeyError_):
                    rk.encode_payload(*args)

    def test_strip_keys(self) -> None:
        text = f"before {minted()} after FL-7K3M-Q9TD-6"
        self.assertNotIn("FLK1", rk.strip_keys(text))
        self.assertIn("FL-7K3M-Q9TD-6", rk.strip_keys(text))

    def test_disabled_until_a_real_public_key(self) -> None:
        committed = rk.read_public_keys(
            (ROOT / "assets" / "reviewer" / "public_keys.json").read_text())
        # What is committed is a placeholder or a real key: never a test key.
        tests = {v["public"] for v in ALL["ed25519_valid"]}
        tests.add(VECTORS["public_key"])
        for key in committed.values():
            self.assertNotIn(key.hex(), tests)
            self.assertNotIn(rk._b64(key), tests)
        empty = rk.Keyring({}, frozenset())
        self.assertFalse(empty.enabled)
        self.assertEqual(rk.check(minted(), empty).status, rk.DISABLED)
        self.assertEqual(rk.check("junk", empty).status, rk.MALFORMED)

    def test_the_committed_files_are_read(self) -> None:
        self.assertIsInstance(rk.load_keyring().denylist, frozenset)
        self.assertEqual(rk.read_public_keys("not json"), {})
        self.assertEqual(rk.read_public_keys(
            '{"keys": [{"version": 1, "public_key": "PLACEHOLDER"}]}'), {})

    def test_denylist_reads_ids_only(self) -> None:
        text = "# comment\n0123456789ABCDEF  # shouted\nnot an id\n\nfedcba9876543210\n"
        self.assertEqual(rk.read_denylist(text),
                         {"0123456789abcdef", "fedcba9876543210"})

    def test_revoked_key_still_reports_its_id(self) -> None:
        got = rk.check(minted(key_id="00000000000000a1"), KEYRING)
        self.assertEqual(got.status, rk.REVOKED)
        self.assertEqual(got.key.key_id, "00000000000000a1")


class OwnerCommandsTest(unittest.TestCase):
    def test_keygen_mint_verify(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            private = Path(tmp) / "owner.key"
            entry = json.loads(rk.keygen(private, 3))
            self.assertEqual(entry["version"], 3)
            if os.name == "posix":
                self.assertEqual(stat.S_IMODE(private.stat().st_mode), 0o600)
            with self.assertRaises(FileExistsError):
                rk.keygen(private)
            seed = rk.read_seed(private)
            text, key_id = rk.mint(seed, ["te/en"], "trusted", 3,
                                   datetime.date(2026, 11, 21))
            ring = rk.Keyring({3: rk._unb64(entry["public_key"])}, frozenset())
            got = rk.check(text, ring)
            self.assertTrue(got.ok)
            self.assertEqual((got.key.key_id, got.key.tier, got.key.issued),
                             (key_id, "trusted", "2026-11-21"))
            # The public key entry the owner commits is read back.
            self.assertEqual(
                rk.read_public_keys(json.dumps({"keys": [entry]})),
                {3: rk._unb64(entry["public_key"])})

    def test_the_private_seed_is_not_in_a_key(self) -> None:
        self.assertNotIn(SEED.hex(), minted())

    def test_main_refuses_to_overwrite_and_bad_courses(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            private = Path(tmp) / "owner.key"
            self.assertEqual(rk.main(["keygen", "--private", str(private)]), 0)
            self.assertEqual(rk.main(["keygen", "--private", str(private)]), 2)
            self.assertEqual(rk.main(
                ["mint", "--private", str(private), "--courses", "TE"]), 2)
            ring = Path(tmp) / "ring"
            ring.mkdir()
            self.assertEqual(rk.main(["verify", "junk", "--keyring", str(ring)]), 1)


if __name__ == "__main__":
    unittest.main()
