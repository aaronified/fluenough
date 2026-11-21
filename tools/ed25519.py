"""Ed25519 (RFC 8032) in pure Python: key from seed, sign, verify.

Standard library only, on purpose: the deck and mail tools take no new
package (AGENTS.md rule 6). It follows the RFC's reference code and is not
constant time, which is fine here: [sign] runs only on the owner's own
machine (`tools/reviewer_keys.py mint`), and [verify] handles public data.
`lib/core/review/ed25519.dart` is the same verification in Dart, and
`test/fixtures/reviewer_key_vectors.json` is read by the tests of both.
"""

from __future__ import annotations

import hashlib

_P = 2 ** 255 - 19
_Q = 2 ** 252 + 27742317777372353535851937790883648493
_D = -121665 * pow(121666, _P - 2, _P) % _P
_I = pow(2, (_P - 1) // 4, _P)

SEED_LENGTH = 32
PUBLIC_LENGTH = 32
SIGNATURE_LENGTH = 64


def _sha512(data: bytes) -> bytes:
    return hashlib.sha512(data).digest()


def _recover_x(y: int, sign: int) -> int | None:
    if y >= _P:
        return None
    x2 = (y * y - 1) * pow(_D * y * y + 1, _P - 2, _P) % _P
    if x2 == 0:
        return None if sign else 0
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P != 0:
        x = x * _I % _P
    if (x * x - x2) % _P != 0:
        return None
    if (x & 1) != sign:
        x = _P - x
    return x


_GY = 4 * pow(5, _P - 2, _P) % _P
_GX = _recover_x(_GY, 0)
_G = (_GX, _GY, 1, _GX * _GY % _P)
_ZERO = (0, 1, 1, 0)


def _add(a: tuple, b: tuple) -> tuple:
    a_ = (a[1] - a[0]) * (b[1] - b[0]) % _P
    b_ = (a[1] + a[0]) * (b[1] + b[0]) % _P
    c = 2 * a[3] * b[3] * _D % _P
    d = 2 * a[2] * b[2] % _P
    e, f, g, h = b_ - a_, d - c, d + c, b_ + a_
    return (e * f % _P, g * h % _P, f * g % _P, e * h % _P)


def _mul(s: int, point: tuple) -> tuple:
    result = _ZERO
    while s > 0:
        if s & 1:
            result = _add(result, point)
        point = _add(point, point)
        s >>= 1
    return result


def _equal(a: tuple, b: tuple) -> bool:
    return ((a[0] * b[2] - b[0] * a[2]) % _P == 0
            and (a[1] * b[2] - b[1] * a[2]) % _P == 0)


def _compress(point: tuple) -> bytes:
    zinv = pow(point[2], _P - 2, _P)
    x, y = point[0] * zinv % _P, point[1] * zinv % _P
    return int(y | ((x & 1) << 255)).to_bytes(32, "little")


def _decompress(data: bytes) -> tuple | None:
    if len(data) != 32:
        return None
    y = int.from_bytes(data, "little")
    sign = y >> 255
    y &= (1 << 255) - 1
    x = _recover_x(y, sign)
    if x is None:
        return None
    return (x, y, 1, x * y % _P)


def _expand(seed: bytes) -> tuple[int, bytes]:
    h = _sha512(seed)
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8
    a |= 1 << 254
    return a, h[32:]


def public_key(seed: bytes) -> bytes:
    """The 32-byte public key of the 32-byte [seed]."""
    if len(seed) != SEED_LENGTH:
        raise ValueError("an Ed25519 seed is 32 bytes")
    a, _ = _expand(seed)
    return _compress(_mul(a, _G))


def sign(seed: bytes, message: bytes) -> bytes:
    """The 64-byte signature of [message] by the key of [seed]."""
    a, prefix = _expand(seed)
    public = _compress(_mul(a, _G))
    r = int.from_bytes(_sha512(prefix + message), "little") % _Q
    big_r = _compress(_mul(r, _G))
    h = int.from_bytes(_sha512(big_r + public + message), "little") % _Q
    s = (r + h * a) % _Q
    return big_r + int(s).to_bytes(32, "little")


def _small_order(point: tuple) -> bool:
    return _equal(_mul(8, point), _ZERO)


def verify(public: bytes, message: bytes, signature: bytes) -> bool:
    """Whether [signature] is [public]'s valid signature of [message]. Never
    raises on bad input: a wrong length, a point off the curve, a non-canonical
    encoding, a small-order public key or R, or a scalar that is not reduced is
    False (stricter than RFC 8032, which allows small-order points)."""
    if len(public) != PUBLIC_LENGTH or len(signature) != SIGNATURE_LENGTH:
        return False
    a = _decompress(public)
    r = _decompress(signature[:32])
    if a is None or r is None or _small_order(a) or _small_order(r):
        return False
    s = int.from_bytes(signature[32:], "little")
    if s >= _Q:
        return False
    h = int.from_bytes(_sha512(signature[:32] + public + message), "little") % _Q
    return _equal(_mul(s, _G), _add(r, _mul(h, a)))
