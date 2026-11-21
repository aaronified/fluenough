"""The mail bot's side of signed reviewer keys (ADR-0058, decision 8; W7).

A review mail from a keyed reviewer carries the key as a secret proof, as
`reviewer_key` in its review files. [KeyGate.check] decides what the mail is
worth, once the sender check has passed:

* no key: the code stays Provisional;
* a key that is not signed by the owner's public key, or is on the denylist
  (`assets/reviewer/denylist.txt`), or whose id is bound to another rater
  code, or whose code is bound to another key, or that is used too often:
  the mail is HELD for the owner;
* a good key: the FIRST such mail binds the key id to the mail's rater code,
  and from then on only that code may use it. The code's tier is the key's.
  Because a tier belongs to a code, binding upgrades the code's earlier
  reviews to Verified weight at once (owner, 2026-11-21: "3. Yes.").

**The key is a secret and never leaves this module.** [KeyGate.check] removes
`reviewer_key` from the review files it is given, whatever it decides, so
nothing later can put it in an issue, a PR, a deck or a log. Nothing here
prints a key, a key id or a code: the log says counts only.

**The bindings are private.** A key id bound to a rater code, and the code's
tier, must never be public: a public tier would make Verified codes easy to
pick out. They live where the bot already keeps the rater-code-to-sender
records: records in a Gmail label of the Fluenough inbox (`fluenough/keys`),
written with IMAP APPEND ([GmailBindings]). That needs nothing new from the
owner. [MemoryBindings] is the same interface for tests.

The tier map ([KeyGate.tiers]) feeds `review_quorum.set_tiers`, which the
quorum rule reads when `QUORUM_NEEDS_VERIFIED` is turned on (it is off).
"""

from __future__ import annotations

import datetime
import email
import email.message
import email.policy
import email.utils
import imaplib
import os
import re
import sys
from dataclasses import dataclass, field
from typing import Callable

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import reviewer_keys as rk  # noqa: E402
from review_quorum import PROVISIONAL  # noqa: E402

# The Gmail label holding the bindings and the key uses.
KEYS = "fluenough/keys"

# What a key proof comes to.
NONE = "none"          # no key in the mail: Provisional
DISABLED = "disabled"  # keys, or the private store, are not set up: ignored
HELD = "held"          # left to the owner
OK = "ok"              # a good key, bound to this code

# Mails per key in a day. Owner-set; a real reviewer sends a few a day.
DAILY_LIMIT = 30
WINDOW = datetime.timedelta(hours=24)

RECORD = re.compile(r"^(bind|use) ([0-9a-f]{16})$")


@dataclass(frozen=True)
class Gate:
    """What a mail's key proof comes to: [status] and, for [OK], the key's
    [tier]. [reason] is for the counts in the log, never a key or an id."""
    status: str
    tier: str = PROVISIONAL
    reason: str = ""


# --- The private store ----------------------------------------------------------------

class MemoryBindings:
    """The store in memory: for tests, and the whole interface."""

    def __init__(self, ready: bool = True) -> None:
        self.ready = ready
        self.bound: dict[str, tuple[str, str]] = {}   # key id -> (code, tier)
        self.used: dict[str, list[datetime.datetime]] = {}
        self.fail_writes = False

    def code_of(self, key_id: str) -> str | None:
        found = self.bound.get(key_id)
        return found[0] if found else None

    def key_id_of(self, code: str) -> str | None:
        return next((k for k, (c, _) in self.bound.items() if c == code), None)

    def bind(self, key_id: str, code: str, tier: str) -> bool:
        if self.fail_writes:
            return False
        self.bound[key_id] = (code, tier)
        return True

    def uses(self, key_id: str, now: datetime.datetime) -> int:
        return sum(1 for t in self.used.get(key_id, []) if now - t < WINDOW)

    def record_use(self, key_id: str, now: datetime.datetime) -> bool:
        if self.fail_writes:
            return False
        self.used.setdefault(key_id, []).append(now)
        return True

    def tiers(self) -> dict[str, tuple[str, str]]:
        """code -> (tier, key id) of every binding."""
        return {code: (tier, key_id)
                for key_id, (code, tier) in self.bound.items()}


class GmailBindings(MemoryBindings):
    """The store as records in the Gmail label [KEYS], read once per run
    before the inbox is selected: `bind <id>` with the code and tier in its
    body, and `use <id>` with its Date header. Written by APPEND, so nothing
    is sent. [ready] is False when the label cannot be read, and then keys
    are ignored rather than half-honoured."""

    def __init__(self, imap: imaplib.IMAP4) -> None:
        super().__init__(ready=False)
        self.imap = imap

    def load(self) -> None:
        self.ready = False
        self.bound.clear()
        self.used.clear()
        try:
            self.imap.create(KEYS)  # NO when it is there already, which is fine
            status, _ = self.imap.select(KEYS, readonly=True)
            if status != "OK":
                return
            status, found = self.imap.search(None, "ALL")
            if status != "OK":
                return
            for number in (found[0] or b"").split():
                status, data = self.imap.fetch(number, "(BODY.PEEK[])")
                if status != "OK":
                    return
                raw = next(part[1] for part in data if isinstance(part, tuple))
                self._read(email.message_from_bytes(raw, policy=email.policy.default))
            self.ready = True
        except (imaplib.IMAP4.error, OSError, StopIteration):
            self.ready = False

    def _read(self, record: email.message.Message) -> None:
        match = RECORD.match(str(record.get("Subject", "")).strip())
        if not match:
            return
        kind, key_id = match.groups()
        if kind == "bind":
            body = record.get_body(preferencelist=("plain",))
            lines = (body.get_content() if body else "").split("\n")
            code, tier = lines[0].strip(), (lines[1].strip() if len(lines) > 1 else "")
            if code and tier in (rk.VERIFIED, rk.TRUSTED):
                self.bound[key_id] = (code, tier)
        else:
            try:
                at = email.utils.parsedate_to_datetime(str(record.get("Date", "")))
            except (TypeError, ValueError):
                return
            if at.tzinfo is None:
                at = at.replace(tzinfo=datetime.timezone.utc)
            self.used.setdefault(key_id, []).append(at)

    def _append(self, record: email.message.EmailMessage) -> bool:
        """Writes [record]. A dropped connection is raised, as in the rater
        records: the run stops before the mail is filed, so it is not filed
        unchecked and again."""
        try:
            status, _ = self.imap.append(KEYS, "(\\Seen)", None, record.as_bytes())
        except (imaplib.IMAP4.abort, OSError):
            raise
        except imaplib.IMAP4.error:
            return False
        return status == "OK"

    def bind(self, key_id: str, code: str, tier: str) -> bool:
        record = email.message.EmailMessage()
        record["Subject"] = f"bind {key_id}"
        record.set_content(f"{code}\n{tier}\n")
        if not self._append(record):
            return False
        return super().bind(key_id, code, tier)

    def record_use(self, key_id: str, now: datetime.datetime) -> bool:
        record = email.message.EmailMessage()
        record["Subject"] = f"use {key_id}"
        record["Date"] = email.utils.format_datetime(now)
        record.set_content("use\n")
        if not self._append(record):
            return False
        return super().record_use(key_id, now)


# --- The gate -----------------------------------------------------------------------------

def _clock() -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc)


@dataclass
class KeyGate:
    keyring: rk.Keyring
    bindings: MemoryBindings
    limit: int = DAILY_LIMIT
    now: Callable[[], datetime.datetime] = _clock
    # Counts for the log: never a key, an id or a code.
    counts: dict[str, int] = field(default_factory=dict)
    _decided: dict[str, Gate] = field(default_factory=dict)

    def _count(self, name: str) -> None:
        self.counts[name] = self.counts.get(name, 0) + 1

    @staticmethod
    def proof_of(files: list[dict]) -> tuple[str | None, bool]:
        """(the key the files carry, whether they carry anything wrong): one
        key, the same in every file that has one. Removes it from every
        file, whatever comes of it."""
        found: set[str] = set()
        odd = False
        for f in files:
            if "reviewer_key" not in f:
                continue
            proof = f.pop("reviewer_key")
            if isinstance(proof, str) and proof.strip():
                found.add(re.sub(r"\s+", "", proof))
            else:
                odd = True
        return (next(iter(found)) if len(found) == 1 else None,
                odd or len(found) > 1)

    def check(self, files: list[dict], code: str, mail: str = "",
              count: bool = True) -> Gate:
        """What the key proof in [files], the review files of one mail by
        rater [code], comes to. Call it once the sender check has passed.

        [mail] names the mail, so that a second ask about it, from the filing
        and then from the proposals, gets the first answer and counts one use.
        With [count] False a mail already counted at filing is only decided
        again, not counted again. The key is removed from [files]."""
        if mail and mail in self._decided:
            self.proof_of(files)
            return self._decided[mail]
        proof, wrong = self.proof_of(files)
        gate = self._decide(proof, wrong, code, count)
        if mail:
            self._decided[mail] = gate
        return gate

    def _decide(self, proof: str | None, wrong: bool, code: str,
                count: bool) -> Gate:
        if wrong:
            self._count("held: files disagree about the key")
            return Gate(HELD, reason="key files disagree")
        if proof is None:
            return Gate(NONE)
        if not self.keyring.enabled or not self.bindings.ready:
            self._count("ignored: keys or private store not set up")
            return Gate(DISABLED, reason="not set up")
        checked = rk.check(proof, self.keyring)
        if not checked.ok or checked.key is None:
            self._count(f"held: key {checked.status}")
            return Gate(HELD, reason=checked.status)
        key = checked.key
        bound = self.bindings.code_of(key.key_id)
        if bound is not None and bound != code:
            self._count("held: key bound to another code")
            return Gate(HELD, reason="bound to another code")
        if bound is None:
            other = self.bindings.key_id_of(code)
            if other is not None and other != key.key_id:
                self._count("held: code bound to another key")
                return Gate(HELD, reason="code has another key")
            if not self.bindings.bind(key.key_id, code, key.tier):
                self._count("held: could not write the binding")
                return Gate(HELD, reason="binding not written")
            self._count("bound")
        now = self.now()
        if count:
            if self.bindings.uses(key.key_id, now) >= self.limit:
                self._count("held: rate limit")
                return Gate(HELD, reason="rate limit")
            if not self.bindings.record_use(key.key_id, now):
                self._count("held: could not write the use")
                return Gate(HELD, reason="use not written")
        self._count("accepted")
        return Gate(OK, tier=key.tier)

    def held(self, mail: str) -> bool:
        """Whether the mail named [mail] was held for the owner."""
        found = self._decided.get(mail)
        return found is not None and found.status == HELD

    def tiers(self) -> dict[str, str]:
        """rater code -> tier, for every binding whose key is not revoked:
        what `review_quorum.set_tiers` takes."""
        if not self.keyring.enabled or not self.bindings.ready:
            return {}
        return {code: tier
                for code, (tier, key_id) in self.bindings.tiers().items()
                if key_id not in self.keyring.denylist}
