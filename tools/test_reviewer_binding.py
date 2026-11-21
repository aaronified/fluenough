"""The mail bot and signed reviewer keys (ADR-0058, W7): the gate, the private
bindings in the Gmail label, and the mail job around them.

The key pair is a throwaway made here from a fixed seed; nothing in this file
is the owner's key. The reviewer's mail files carry the key as the app writes
it (`reviewer_key` in the review file).
"""

from __future__ import annotations

import datetime
import email
import email.message
import email.policy
import imaplib
import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import ed25519  # noqa: E402
import mail_to_issues  # noqa: E402
import review_facets as rf  # noqa: E402
import review_quorum as rq  # noqa: E402
import reviewer_binding as rb  # noqa: E402
import reviewer_keys as rk  # noqa: E402
from test_mail_to_issues import (  # noqa: E402
    CODE, ENV, OTHER, FakeImap, mail, review_file, review_mail)

SEED = bytes(range(1, 33))
RING = rk.Keyring({1: ed25519.public_key(SEED)}, frozenset({"00000000000000a1"}))
NOW = datetime.datetime(2026, 11, 21, 12, 0, tzinfo=datetime.timezone.utc)
KEY_ID = "0123456789abcdef"


def key(key_id: str = KEY_ID, tier: str = "verified",
        courses: tuple[str, ...] = ("te/en",)) -> str:
    return rk.sign_key(SEED, key_id, list(courses), tier, "2026-11-21", 1)


def files_with(proof: str | None, code: str = CODE) -> list[dict]:
    data = review_file(code)
    if proof is not None:
        data["reviewer_key"] = proof
    return [data]


def gate(bindings: rb.MemoryBindings | None = None, ring: rk.Keyring = RING,
         limit: int = 3) -> rb.KeyGate:
    return rb.KeyGate(ring, bindings or rb.MemoryBindings(), limit=limit,
                      now=lambda: NOW)


class GateTest(unittest.TestCase):
    def tearDown(self) -> None:
        rq.set_tiers({})

    def test_no_key_is_provisional(self) -> None:
        self.assertEqual(gate().check(files_with(None), CODE).status, rb.NONE)

    def test_the_first_good_key_binds_and_later_mails_pass(self) -> None:
        store = rb.MemoryBindings()
        g = gate(store)
        first = g.check(files_with(key()), CODE)
        self.assertEqual((first.status, first.tier), (rb.OK, "verified"))
        self.assertEqual(store.code_of(KEY_ID), CODE)
        again = g.check(files_with(key()), CODE)
        self.assertEqual(again.status, rb.OK)

    def test_another_code_with_the_key_is_held(self) -> None:
        store = rb.MemoryBindings()
        g = gate(store)
        g.check(files_with(key()), CODE)
        self.assertEqual(g.check(files_with(key(), OTHER), OTHER).status, rb.HELD)
        # And nothing was bound to the other code.
        self.assertIsNone(store.key_id_of(OTHER))

    def test_a_code_bound_to_one_key_does_not_take_a_second(self) -> None:
        g = gate()
        g.check(files_with(key()), CODE)
        second = key("fedcba9876543210")
        self.assertEqual(g.check(files_with(second), CODE).status, rb.HELD)

    def test_a_bad_key_is_held(self) -> None:
        other = rk.sign_key(bytes(32), KEY_ID, ["te/en"], "verified",
                            "2026-11-21", 1)
        revoked = key("00000000000000a1")
        for proof in (other, revoked, "FLK1.garbage", "FL-7K3M-Q9TD-6",
                      key()[:-4]):
            with self.subTest(proof[:12]):
                self.assertEqual(
                    gate().check(files_with(proof), CODE).status, rb.HELD)

    def test_a_revoked_key_that_was_bound_is_held_and_its_tier_gone(self) -> None:
        store = rb.MemoryBindings()
        open_ring = rk.Keyring(RING.public_keys, frozenset())
        gate(store, open_ring).check(files_with(key()), CODE)
        self.assertEqual(gate(store, open_ring).tiers(), {CODE: "verified"})
        revoking = rk.Keyring(RING.public_keys, frozenset({KEY_ID}))
        later = gate(store, revoking)
        self.assertEqual(later.check(files_with(key()), CODE).status, rb.HELD)
        self.assertEqual(later.tiers(), {})

    def test_files_that_disagree_about_the_key_are_held(self) -> None:
        files = files_with(key()) + files_with(key("fedcba9876543210"))
        self.assertEqual(gate().check(files, CODE).status, rb.HELD)
        self.assertEqual(
            gate().check(files_with(""), CODE).status, rb.HELD)
        self.assertEqual(
            gate().check(files_with(7), CODE).status, rb.HELD)  # type: ignore[arg-type]

    def test_keys_are_ignored_until_set_up(self) -> None:
        for g in (gate(ring=rk.Keyring({}, frozenset())),
                  gate(rb.MemoryBindings(ready=False))):
            files = files_with(key())
            self.assertEqual(g.check(files, CODE).status, rb.DISABLED)
            self.assertEqual(g.tiers(), {})
            self.assertNotIn("reviewer_key", files[0])

    def test_the_key_is_taken_out_whatever_comes_of_it(self) -> None:
        for proof in (key(), "FLK1.garbage", "", key("00000000000000a1")):
            files = files_with(proof) + files_with(proof)
            gate().check(files, CODE)
            for f in files:
                self.assertNotIn("reviewer_key", f)
        self.assertNotIn("reviewer_key", json.dumps(files))

    def test_a_key_is_limited_per_day(self) -> None:
        g = gate(limit=2)
        outcomes = [g.check(files_with(key()), CODE, f"mail{i}").status
                    for i in range(4)]
        self.assertEqual(outcomes, [rb.OK, rb.OK, rb.HELD, rb.HELD])
        self.assertTrue(g.held("mail3"))
        self.assertFalse(g.held("mail0"))

    def test_the_limit_is_for_one_day(self) -> None:
        store = rb.MemoryBindings()
        store.bind(KEY_ID, CODE, "verified")
        store.used[KEY_ID] = [NOW - datetime.timedelta(hours=25)] * 5 \
            + [NOW - datetime.timedelta(hours=1)]
        self.assertEqual(
            gate(store, limit=2).check(files_with(key()), CODE).status, rb.OK)

    def test_a_mail_counts_once_and_a_recheck_counts_none(self) -> None:
        store = rb.MemoryBindings()
        g = gate(store, limit=5)
        g.check(files_with(key()), CODE, "m1")
        g.check(files_with(key()), CODE, "m1")
        self.assertEqual(len(store.used[KEY_ID]), 1)
        later = gate(store, limit=5)
        later.check(files_with(key()), CODE, "m2", count=False)
        self.assertEqual(len(store.used[KEY_ID]), 1)

    def test_a_binding_that_cannot_be_written_holds_the_mail(self) -> None:
        store = rb.MemoryBindings()
        store.fail_writes = True
        self.assertEqual(
            gate(store).check(files_with(key()), CODE).status, rb.HELD)

    def test_counts_never_hold_a_key_an_id_or_a_code(self) -> None:
        g = gate()
        g.check(files_with(key()), CODE)
        g.check(files_with(key(), OTHER), OTHER)
        text = json.dumps(g.counts)
        for secret in (key(), KEY_ID, CODE, OTHER):
            self.assertNotIn(secret, text)

    def test_binding_upgrades_the_codes_earlier_reviews(self) -> None:
        by = [CODE, OTHER]
        before = rf.settled(rf.checks_of(by, {}, "meaning"), needs_verified=True)
        self.assertFalse(before)
        g = gate()
        g.check(files_with(key()), CODE)
        rq.set_tiers(g.tiers())
        # The same two reviews, one now by a Verified code: they count.
        self.assertTrue(rf.settled(rf.checks_of(by, {}, "meaning"),
                                   needs_verified=True))
        # Without the switch nothing changed for anyone.
        rq.set_tiers({})
        self.assertTrue(rf.settled(rf.checks_of(by, {}, "meaning")))
        self.assertFalse(rq.QUORUM_NEEDS_VERIFIED)


class Keys(FakeImap):
    """[FakeImap] plus the label of key bindings."""

    def __init__(self, *args, keys: list[bytes] | None = None,
                 keys_label: bool = True, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self.keys = list(keys or [])
        self.keys_label = keys_label
        self.stored: list[tuple[bytes, str]] = []

    def create(self, box: str):
        if box == rb.KEYS:
            return "NO", [b"[ALREADYEXISTS] Duplicate folder name"]
        return super().create(box)

    def select(self, box: str, readonly: bool = False):
        if box == rb.KEYS:
            assert readonly
            if not self.keys_label:
                return "NO", [b"[NONEXISTENT] Unknown Mailbox"]
            self.selected = box
            return "OK", [b"1"]
        return super().select(box, readonly)

    def search(self, charset, *criteria):
        if self.selected == rb.KEYS:
            return "OK", [b" ".join(
                str(i + 1).encode() for i in range(len(self.keys)))]
        return super().search(charset, *criteria)

    def fetch(self, number: bytes, what: str):
        if self.selected == rb.KEYS:
            raw = self.keys[int(number) - 1]
            return "OK", [(b"1 (BODY[] {n}", raw), b")"]
        return super().fetch(number, what)

    def append(self, box: str, flags, date_time, message: bytes):
        if box == rb.KEYS:
            self.keys.append(message)
            return "OK", [b"APPEND completed"]
        return super().append(box, flags, date_time, message)

    def store(self, number: bytes, command: str, label: str) -> None:
        self._alive()
        assert command == "+X-GM-LABELS"
        self.stored.append((number, label))


class GmailBindingsTest(unittest.TestCase):
    def test_bindings_and_uses_survive_a_new_run(self) -> None:
        imap = Keys([])
        store = rb.GmailBindings(imap)
        store.load()
        self.assertTrue(store.ready)
        self.assertTrue(store.bind(KEY_ID, CODE, "trusted"))
        self.assertTrue(store.record_use(KEY_ID, NOW))
        self.assertEqual(len(imap.keys), 2)
        fresh = rb.GmailBindings(imap)
        fresh.load()
        self.assertTrue(fresh.ready)
        self.assertEqual(fresh.code_of(KEY_ID), CODE)
        self.assertEqual(fresh.tiers(), {CODE: ("trusted", KEY_ID)})
        self.assertEqual(fresh.uses(KEY_ID, NOW), 1)
        self.assertEqual(
            fresh.uses(KEY_ID, NOW + datetime.timedelta(hours=25)), 0)

    def test_records_that_are_not_ours_are_passed_over(self) -> None:
        junk = email.message.EmailMessage()
        junk["Subject"] = "hello"
        junk.set_content("x")
        half = email.message.EmailMessage()
        half["Subject"] = f"bind {KEY_ID}"
        half.set_content("only a code\n")
        imap = Keys([], keys=[junk.as_bytes(), half.as_bytes()])
        store = rb.GmailBindings(imap)
        store.load()
        self.assertTrue(store.ready)
        self.assertIsNone(store.code_of(KEY_ID))

    def test_an_unreadable_label_is_not_ready(self) -> None:
        store = rb.GmailBindings(Keys([], keys_label=False))
        store.load()
        self.assertFalse(store.ready)

    def test_a_dropped_connection_is_raised_not_swallowed(self) -> None:
        imap = Keys([])
        store = rb.GmailBindings(imap)
        store.load()
        imap.drops_on_append = False
        imap.append = mock.Mock(  # type: ignore[method-assign]
            side_effect=imaplib.IMAP4.abort("reset"))
        with self.assertRaises(imaplib.IMAP4.abort):
            store.bind(KEY_ID, CODE, "verified")

    def test_a_refused_write_is_false(self) -> None:
        imap = Keys([])
        store = rb.GmailBindings(imap)
        store.load()
        imap.append = mock.Mock(  # type: ignore[method-assign]
            return_value=("NO", [b"[OVERQUOTA]"]))
        self.assertFalse(store.bind(KEY_ID, CODE, "verified"))
        self.assertIsNone(store.code_of(KEY_ID))


def keyed(proof: str | None, code: str = CODE,
          sender: str = "reviewer@example.com") -> email.message.EmailMessage:
    return review_mail(f"[Fluenough review] {code} (te)",
                       files_with(proof, code), sender=sender)


def run(imap: Keys, ring: rk.Keyring = RING) -> tuple[list[dict], str]:
    filed: list[dict] = []
    out = io.StringIO()
    with mock.patch.object(rk, "load_keyring", return_value=ring), \
            redirect_stdout(out):
        mail_to_issues.run(ENV, imap, filed.append)
    return filed, out.getvalue()


class MailJobTest(unittest.TestCase):
    def tearDown(self) -> None:
        rq.set_tiers({})

    def test_a_keyed_review_is_filed_and_binds_without_a_trace(self) -> None:
        imap = Keys([keyed(key())])
        filed, log = run(imap)
        self.assertEqual(len(filed), 1)
        text = json.dumps(filed) + log
        for secret in (key(), "FLK1", KEY_ID):
            self.assertNotIn(secret, text)
        self.assertNotIn(mail_to_issues.HELD, filed[0]["labels"])
        self.assertEqual(imap.stored, [(b"1", "fluenough-filed")])
        subjects = [email.message_from_bytes(
            r, policy=email.policy.default)["Subject"] for r in imap.keys]
        self.assertEqual(subjects, [f"bind {KEY_ID}", f"use {KEY_ID}"])
        # The bound code's tier is known to the quorum rule, privately.
        self.assertEqual(rq.tier_of(CODE), "verified")
        self.assertNotIn("verified", json.dumps(filed).lower())

    def test_the_key_on_another_code_is_held_and_never_proposed(self) -> None:
        bound = email.message.EmailMessage()
        bound["Subject"] = f"bind {KEY_ID}"
        bound.set_content(f"{CODE}\nverified\n")
        imap = Keys([keyed(key(), OTHER)], keys=[bound.as_bytes()])
        filed, log = run(imap)
        self.assertIn(mail_to_issues.HELD, filed[0]["labels"])
        self.assertIn("Held for the owner", filed[0]["body"])
        self.assertEqual(imap.stored, [(b"1", "fluenough-filed"),
                                       (b"1", "fluenough-proposed")])
        for secret in (key(), KEY_ID, "FLK1"):
            self.assertNotIn(secret, json.dumps(filed) + log)
        # Nothing was bound to the other code.
        self.assertEqual(len(imap.keys), 1)

    def test_a_keyless_review_is_filed_as_before(self) -> None:
        imap = Keys([keyed(None)])
        filed, _ = run(imap)
        self.assertEqual(filed[0]["labels"], ["review", "from-app", "lang: te"])
        self.assertEqual(imap.keys, [])

    def test_a_different_sender_does_not_bind_a_key(self) -> None:
        tied = email.message.EmailMessage()
        tied["Subject"] = CODE
        tied.set_content("someone.else@example.com")
        imap = Keys([keyed(key())], raters=[tied.as_bytes()])
        filed, _ = run(imap)
        self.assertIn("sender does not match", filed[0]["labels"])
        self.assertEqual(imap.keys, [])

    def test_while_no_public_key_is_committed_keys_are_ignored(self) -> None:
        imap = Keys([keyed(key())])
        filed, log = run(imap, rk.Keyring({}, frozenset()))
        self.assertEqual(len(filed), 1)
        self.assertEqual(imap.keys, [])
        self.assertNotIn("FLK1", json.dumps(filed) + log)
        self.assertIn("reviewer keys are off", log)

    def test_an_unreadable_binding_store_ignores_keys(self) -> None:
        imap = Keys([keyed(key())], keys_label=False)
        filed, log = run(imap)
        self.assertEqual(len(filed), 1)
        self.assertNotIn(mail_to_issues.HELD, filed[0]["labels"])
        self.assertNotIn("FLK1", json.dumps(filed) + log)

    def test_a_key_in_a_bug_report_is_cut_from_the_public_issue(self) -> None:
        text = f"It crashed. My key is {key()} ok\n\n---\nKind: Bug\nScreen: /x"
        issue = mail_to_issues.issue_from(mail("[Fluenough] Bug: crash", text))
        self.assertNotIn("FLK1", json.dumps(issue))
        self.assertIn("[key removed]", issue["body"])

    def test_the_proposals_never_see_the_key(self) -> None:
        seen: list = []

        class Bot:
            threshold = 1

            def review(self, key_: str, code: str, review) -> str:
                seen.append(repr(review))
                return "merged"

            def questions(self, *args) -> str:
                return "nothing"

            def sweep(self) -> dict:
                return {"applied": 0, "waiting": 0, "outdated": 0}

            def sweep_flags(self) -> dict:
                return {"open": 0, "merged": 0, "closed": 0}

        imap = Keys([keyed(key())])
        filed: list[dict] = []
        with mock.patch.object(rk, "load_keyring", return_value=RING), \
                redirect_stdout(io.StringIO()) as out:
            mail_to_issues.run(ENV, imap, filed.append, bot=Bot())
        self.assertEqual(len(seen), 1)
        for secret in (key(), "FLK1", KEY_ID):
            self.assertNotIn(secret, seen[0] + out.getvalue())
        # One use only: counted at filing, not again for the proposals.
        uses = [r for r in imap.keys if b"Subject: use" in r]
        self.assertEqual(len(uses), 1)


if __name__ == "__main__":
    unittest.main()
