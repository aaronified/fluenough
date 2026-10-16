"""Rater codes, as the app makes them (lib/core/review/rater_code.dart).

Shared by the mail job, which reads the code a review came with, and the
validator, which checks the code a proposal names (ADR-0038). Stdlib only.

A code is written FL-XXXX-XXXX-C: eight symbols of Crockford's base32 and
a check symbol that catches a single typo or two swapped neighbours.
"""

from __future__ import annotations

import re

# Crockford's base32, without I, L, O and U, as lib/core/review/rater_code.dart.
CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


def _gf_times(a: int, b: int) -> int:
    """[a] times [b] in GF(32), modulo x^5 + x^2 + 1."""
    product = 0
    while b:
        if b & 1:
            product ^= a
        b >>= 1
        a <<= 1
        if a & 0x20:
            a ^= 0x25
    return product


def check_symbol(body: str) -> str:
    """The check symbol of a rater code's eight symbols, as the app makes
    it: a weighted sum in GF(32), the weights 2, 4, 8, ... in turn."""
    total, weight = 0, 1
    for symbol in body:
        weight = _gf_times(weight, 2)
        total ^= _gf_times(weight, CROCKFORD.index(symbol))
    return CROCKFORD[total]


def rater_code(text: object) -> str | None:
    """[text] as a rater code, written FL-XXXX-XXXX-C, or None if it is not
    one or its check fails. Read as loosely as the app reads it."""
    if not isinstance(text, str):
        return None
    plain = re.sub(r"[\s-]", "", text.upper())
    if plain.startswith("FL") and len(plain) == 11:
        plain = plain[2:]
    plain = plain.replace("I", "1").replace("L", "1").replace("O", "0")
    if len(plain) != 9 or any(c not in CROCKFORD for c in plain):
        return None
    if check_symbol(plain[:8]) != plain[8]:
        return None
    return f"FL-{plain[:4]}-{plain[4:8]}-{plain[8]}"
