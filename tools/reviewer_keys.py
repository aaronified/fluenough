#!/usr/bin/env python3
"""Signed reviewer keys (ADR-0058, decision 8; issue #1658, work package W7).

A Verified reviewer gets a key from the owner. The key says who it is (a
random id), which courses it unlocks, its tier (Verified or Trusted) and the
day it was issued, signed with the OWNER'S PRIVATE Ed25519 key. The public
key ships in the app and in the mail bot (`assets/reviewer/public_keys.json`);
the denylist of revoked key ids is `assets/reviewer/denylist.txt` (ids only).

THE OWNER runs `keygen` and `mint` on their own machine. No agent, workflow or
server ever generates or holds the private key.

    python3 tools/reviewer_keys.py keygen --private ~/fluenough-owner.key
        Writes the private seed (never commit it) and prints the public key
        to put in assets/reviewer/public_keys.json.
    python3 tools/reviewer_keys.py mint --private ~/fluenough-owner.key \\
            --courses te/en,bn --tier verified [--note "Asha, Bengali"]
        Prints one key to send to a reviewer. The note stays on your screen:
        it is never in the key.
    python3 tools/reviewer_keys.py verify FLK1.…
        Checks a key against the committed public keys and denylist.

The text of a key, `FLK1.<payload>.<signature>` (base64url, no padding):

* payload: compact JSON with the keys `c` (courses, sorted: `te/en` for a
  course, `te` for every course of a language), `i` (issue date,
  YYYY-MM-DD), `k` (key id, 16 lower-case hex), `p` (version of the public
  key that checks it) and `t` (`v` Verified, `t` Trusted), exactly as
  [encode_payload] writes it, so a payload has one form and a key is
  accepted only in that form;
* signature: Ed25519 over `fluenough-reviewer-key-v1\\n` + payload.

`lib/core/review/reviewer_key.dart` reads the same keys in the app, and
`test/fixtures/reviewer_key_vectors.json` is read by the tests of both.
Standard library only.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import datetime
import json
import os
import re
import secrets
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ed25519  # noqa: E402

PREFIX = "FLK1."
DOMAIN = b"fluenough-reviewer-key-v1\n"
MAX_PAYLOAD = 1024
MAX_COURSES = 40
VERIFIED = "verified"
TRUSTED = "trusted"
TIER_CODES = {"v": VERIFIED, "t": TRUSTED}
CODE_OF_TIER = {tier: code for code, tier in TIER_CODES.items()}

KEY_ID = re.compile(r"[0-9a-f]{16}")
COURSE = re.compile(r"[a-z]{2,3}(/[a-z]{2,3})?")
DATE = re.compile(r"\d{4}-\d{2}-\d{2}", re.ASCII)
TOKEN = re.compile(r"FLK1\.[A-Za-z0-9_.\-]+")

ROOT = Path(__file__).resolve().parent.parent
KEYRING_DIR = ROOT / "assets" / "reviewer"
PUBLIC_KEYS = "public_keys.json"
DENYLIST = "denylist.txt"

# The statuses of [check].
OK = "ok"
MALFORMED = "malformed"
DISABLED = "disabled"
UNKNOWN_KEY = "unknown_key"
BAD_SIGNATURE = "bad_signature"
REVOKED = "revoked"


class KeyError_(ValueError):
    """A key that is not well formed."""


@dataclass(frozen=True)
class ReviewerKey:
    key_id: str
    courses: tuple[str, ...]
    tier: str
    issued: str
    version: int

    def unlocks(self, target: str, native: str) -> bool:
        """Whether the key unlocks [target] taught from [native]."""
        return target in self.courses or f"{target}/{native}" in self.courses


@dataclass(frozen=True)
class Checked:
    status: str
    key: ReviewerKey | None = None

    @property
    def ok(self) -> bool:
        return self.status == OK


# --- The text of a key -------------------------------------------------------------

def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _unb64(text: str) -> bytes:
    """[text] from unpadded base64url, only in its one canonical form."""
    if not re.fullmatch(r"[A-Za-z0-9_-]*", text) or len(text) % 4 == 1:
        raise KeyError_("not base64url")
    try:
        data = base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))
    except (binascii.Error, ValueError) as error:
        raise KeyError_("not base64url") from error
    if _b64(data) != text:
        raise KeyError_("not canonical")
    return data


def _valid_date(text: str) -> bool:
    if not DATE.fullmatch(text):
        return False
    try:
        datetime.date.fromisoformat(text)
    except ValueError:
        return False
    return True


def encode_payload(key_id: str, courses: list[str], tier: str, issued: str,
                   version: int) -> bytes:
    """The one form of a payload. Raises [KeyError_] for values a key may
    not hold."""
    code = CODE_OF_TIER.get(tier)
    unique = sorted(set(courses))
    if code is None:
        raise KeyError_("tier")
    if not KEY_ID.fullmatch(key_id):
        raise KeyError_("key id")
    if not unique or len(unique) > MAX_COURSES \
            or not all(COURSE.fullmatch(c) for c in unique):
        raise KeyError_("courses")
    if not _valid_date(issued):
        raise KeyError_("date")
    if not isinstance(version, int) or isinstance(version, bool) \
            or not 1 <= version <= 99:
        raise KeyError_("version")
    # Every value is plain ASCII with nothing to escape, so the text is
    # written by hand: the same bytes in Dart and Python.
    listed = ",".join(f'"{c}"' for c in unique)
    return (f'{{"c":[{listed}],"i":"{issued}","k":"{key_id}",'
            f'"p":{version},"t":"{code}"}}').encode("ascii")


def parse_payload(payload: bytes) -> ReviewerKey:
    """The key a payload says; [KeyError_] unless it is in its one form."""
    if len(payload) > MAX_PAYLOAD:
        raise KeyError_("too long")
    try:
        data = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as error:
        raise KeyError_("not JSON") from error
    if not isinstance(data, dict) or set(data) != {"c", "i", "k", "p", "t"}:
        raise KeyError_("fields")
    c, i, k, p, t = (data[x] for x in "cikpt")
    if not isinstance(c, list) or not all(isinstance(x, str) for x in c) \
            or not isinstance(i, str) or not isinstance(k, str) \
            or not isinstance(p, int) or isinstance(p, bool) \
            or not isinstance(t, str) or t not in TIER_CODES:
        raise KeyError_("types")
    if encode_payload(k, c, TIER_CODES[t], i, p) != payload:
        raise KeyError_("form")
    return ReviewerKey(k, tuple(c), TIER_CODES[t], i, p)


def parse(text: str) -> tuple[ReviewerKey, bytes, bytes]:
    """[text], as pasted (whitespace anywhere is ignored, since a mail wraps
    lines), as the key, its payload and its signature. [KeyError_] if it is
    not a key: nothing here checks the signature."""
    plain = re.sub(r"\s+", "", text or "")
    if not plain.startswith(PREFIX):
        raise KeyError_("prefix")
    parts = plain[len(PREFIX):].split(".")
    if len(parts) != 2:
        raise KeyError_("parts")
    payload, signature = _unb64(parts[0]), _unb64(parts[1])
    if len(signature) != ed25519.SIGNATURE_LENGTH:
        raise KeyError_("signature length")
    return parse_payload(payload), payload, signature


def sign_key(seed: bytes, key_id: str, courses: list[str], tier: str,
             issued: str, version: int) -> str:
    """A key's text, signed by [seed]."""
    payload = encode_payload(key_id, courses, tier, issued, version)
    signature = ed25519.sign(seed, DOMAIN + payload)
    return f"{PREFIX}{_b64(payload)}.{_b64(signature)}"


def strip_keys(text: str) -> str:
    """[text] with every key in it removed: for anything that might be
    published."""
    return TOKEN.sub("[key removed]", text)


# --- The public keys and the denylist ----------------------------------------------

@dataclass(frozen=True)
class Keyring:
    """The public keys by version and the revoked key ids."""
    public_keys: dict[int, bytes]
    denylist: frozenset[str]

    @property
    def enabled(self) -> bool:
        """False until a real public key is committed: the placeholder
        decodes to none, and with no key nothing is accepted."""
        return bool(self.public_keys)


def read_public_keys(text: str) -> dict[int, bytes]:
    """The public keys in [text], `{"keys": [{"version": 1, "public_key":
    "<base64url>"}]}`. An entry that is not a 32-byte key (the committed
    placeholder) is left out."""
    try:
        data = json.loads(text)
    except ValueError:
        return {}
    keys: dict[int, bytes] = {}
    entries = data.get("keys") if isinstance(data, dict) else None
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict):
            continue
        version, raw = entry.get("version"), entry.get("public_key")
        if not isinstance(version, int) or isinstance(version, bool) \
                or not isinstance(raw, str):
            continue
        try:
            key = _unb64(raw)
        except KeyError_:
            continue
        if len(key) == ed25519.PUBLIC_LENGTH:
            keys[version] = key
    return keys


def read_denylist(text: str) -> frozenset[str]:
    """The key ids in [text], one per line; `#` starts a comment."""
    ids = set()
    for line in text.splitlines():
        word = line.split("#", 1)[0].strip().lower()
        if KEY_ID.fullmatch(word):
            ids.add(word)
    return frozenset(ids)


def load_keyring(directory: Path = KEYRING_DIR) -> Keyring:
    def read(name: str) -> str:
        try:
            return (directory / name).read_text(encoding="utf-8")
        except OSError:
            return ""
    return Keyring(read_public_keys(read(PUBLIC_KEYS)),
                   read_denylist(read(DENYLIST)))


def check(text: str, keyring: Keyring) -> Checked:
    """What [keyring] says of the key [text]: [OK], or why not. The same
    order as the app: form, then whether a real public key is committed, then
    the key's public-key version, the signature, and the denylist."""
    try:
        key, payload, signature = parse(text)
    except KeyError_:
        return Checked(MALFORMED)
    if not keyring.enabled:
        return Checked(DISABLED)
    public = keyring.public_keys.get(key.version)
    if public is None:
        return Checked(UNKNOWN_KEY)
    if not ed25519.verify(public, DOMAIN + payload, signature):
        return Checked(BAD_SIGNATURE)
    if key.key_id in keyring.denylist:
        return Checked(REVOKED, key)
    return Checked(OK, key)


# --- The owner's commands --------------------------------------------------------------

def keygen(private: Path, version: int = 1) -> str:
    """Writes a new private seed to [private], which must not exist, readable
    by its owner only, and returns the JSON entry for
    `assets/reviewer/public_keys.json`."""
    seed = secrets.token_bytes(ed25519.SEED_LENGTH)
    descriptor = os.open(private, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="ascii") as out:
        out.write(seed.hex() + "\n")
    entry = {"version": version, "public_key": _b64(ed25519.public_key(seed))}
    return json.dumps(entry)


def read_seed(private: Path) -> bytes:
    try:
        seed = bytes.fromhex(private.read_text(encoding="ascii").strip())
    except (OSError, ValueError) as error:
        raise SystemExit(f"Cannot read a private key from {private}.") from error
    if len(seed) != ed25519.SEED_LENGTH:
        raise SystemExit(f"{private} does not hold a 32-byte private key.")
    return seed


def mint(seed: bytes, courses: list[str], tier: str, version: int = 1,
         today: datetime.date | None = None,
         key_id: str | None = None) -> tuple[str, str]:
    """(key text, key id) for a new key."""
    key_id = key_id or secrets.token_hex(8)
    issued = (today or datetime.date.today()).isoformat()
    return sign_key(seed, key_id, courses, tier, issued, version), key_id


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    k = sub.add_parser("keygen", help="make the owner's key pair (once)")
    k.add_argument("--private", type=Path, required=True,
                   help="where to write the private key; must not exist")
    k.add_argument("--version", type=int, default=1)
    m = sub.add_parser("mint", help="make a reviewer key")
    m.add_argument("--private", type=Path, required=True)
    m.add_argument("--courses", required=True,
                   help="comma-separated: te/en, bn (a language, every course)")
    m.add_argument("--tier", choices=(VERIFIED, TRUSTED), default=VERIFIED)
    m.add_argument("--version", type=int, default=1)
    m.add_argument("--note", default="", help="for you only; not in the key")
    v = sub.add_parser("verify", help="check a key")
    v.add_argument("key", nargs="?", help="the key (default: standard input)")
    v.add_argument("--keyring", type=Path, default=KEYRING_DIR)
    args = parser.parse_args(argv)
    if args.command == "keygen":
        try:
            entry = keygen(args.private, args.version)
        except FileExistsError:
            print(f"{args.private} exists; not overwritten.", file=sys.stderr)
            return 2
        print(f"Private key written to {args.private}. Keep it offline; "
              "never commit it.")
        print("Put this in assets/reviewer/public_keys.json under \"keys\":")
        print(entry)
        return 0
    if args.command == "mint":
        courses = [c.strip() for c in args.courses.split(",") if c.strip()]
        try:
            text, key_id = mint(read_seed(args.private), courses, args.tier,
                                args.version)
        except KeyError_ as error:
            print(f"Cannot mint: {error} is not valid.", file=sys.stderr)
            return 2
        note = f" ({args.note})" if args.note else ""
        print(f"Key id {key_id}{note}: keep this id to revoke the key.",
              file=sys.stderr)
        print(text)
        return 0
    text = args.key if args.key else sys.stdin.read()
    result = check(text, load_keyring(args.keyring))
    if result.key:
        print(f"{result.status}: id {result.key.key_id}, {result.key.tier}, "
              f"issued {result.key.issued}, courses "
              f"{', '.join(result.key.courses)}")
    else:
        print(result.status)
    return 0 if result.ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
