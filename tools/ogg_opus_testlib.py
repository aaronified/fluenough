"""Tiny Ogg Opus files for the tests, assembled by hand (ADR-0059, #734).

The validator reads a recording's own bytes (the `OpusHead` header, the last
page's granule position), so a test needs a stream with those and nothing
else: the packets here are filler, not audio that decodes, and no ffmpeg is
needed. The pages are well formed, CRC included.
"""

from __future__ import annotations

import struct

OPUS_RATE = 48000
PACKET_SECONDS = 0.02   # one packet is 20 ms


def _crc_table() -> list[int]:
    table = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            r = ((r << 1) ^ 0x04C11DB7) if r & 0x80000000 else (r << 1)
        table.append(r & 0xFFFFFFFF)
    return table


_TABLE = _crc_table()


def _crc(data: bytes) -> int:
    crc = 0
    for b in data:
        crc = ((crc << 8) & 0xFFFFFFFF) ^ _TABLE[((crc >> 24) & 0xFF) ^ b]
    return crc


def _lacing(size: int) -> list[int]:
    return [255] * (size // 255) + [size % 255]


def _page(flags: int, granule: int, serial: int, seq: int, packets: list[bytes]) -> bytes:
    table = bytes(v for p in packets for v in _lacing(len(p)))
    head = (b"OggS" + bytes([0, flags]) + struct.pack("<q", granule)
            + struct.pack("<III", serial, seq, 0) + bytes([len(table)]) + table)
    body = b"".join(packets)
    crc = struct.pack("<I", _crc(head + body))
    return head[:22] + crc + head[26:] + body


def make_opus(seconds: float = 1.0, kbps: float = 32, channels: int = 1,
              pre_skip: int = 312) -> bytes:
    """An Ogg Opus stream of [seconds] at about [kbps], with [channels] in its
    `OpusHead`. Its size is kbps * 125 * seconds, plus a few hundred bytes of
    headers."""
    serial = 0x464C5545
    head = (b"OpusHead" + bytes([1, channels]) + struct.pack("<H", pre_skip)
            + struct.pack("<I", 24000) + struct.pack("<h", 0) + bytes([0]))
    tags = b"OpusTags" + struct.pack("<I", 5) + b"tests" + struct.pack("<I", 0)
    pages = [_page(0x02, 0, serial, 0, [head]), _page(0, 0, serial, 1, [tags])]
    count = max(1, round(seconds / PACKET_SECONDS))
    size = max(1, round(kbps * 125 * PACKET_SECONDS))
    per_page = max(1, 250 // len(_lacing(size)))
    seq = 2
    for first in range(0, count, per_page):
        n = min(per_page, count - first)
        last = first + n >= count
        granule = pre_skip + (first + n) * round(OPUS_RATE * PACKET_SECONDS)
        pages.append(_page(0x04 if last else 0, granule, serial, seq,
                           [bytes(size)] * n))
        seq += 1
    return b"".join(pages)


def make_vorbis() -> bytes:
    """An Ogg file that is Vorbis, not Opus: the wrong codec in the right
    container."""
    head = b"\x01vorbis" + bytes(23)
    return (_page(0x02, 0, 1, 0, [head]) + _page(0x04, 48000, 1, 1, [bytes(100)]))
