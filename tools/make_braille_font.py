#!/usr/bin/env python3
"""Builds assets/fonts/BrailleShadow.ttf, the font that draws every braille
cell (U+2800 to U+28FF) with all its dot positions (#835, ADR-0043).

A raised dot is a filled circle and an unraised one a thin ring (a "shadow
dot", as the UEB manual draws them), so a lone dot's column and row can be
read on a phone. The font is one colour, so the ring is an outline: it takes
the text colour, light or dark, and stays faint by being thin.

The cell has the standard proportions: dots 2.5 mm apart in a column and a
row, 6 mm from one cell's dot to the next cell's. A six-dot cell shows six
positions; a cell using dot 7 or 8 shows the eight-dot cell's four rows.

    pip install fonttools
    python3 tools/make_braille_font.py            # writes the font
    python3 tools/make_braille_font.py out.ttf    # writes it elsewhere

The font is licensed under the SIL Open Font License 1.1, like the generator
(assets/fonts/OFL.txt).
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

OUT = Path(__file__).resolve().parent.parent / "assets" / "fonts" / \
    "BrailleShadow.ttf"

FAMILY = "Fluenough Braille Shadow"
UPM = 1000
# 100 units to the millimetre.
PITCH = 250            # dot to dot, across and down
ADVANCE = 600          # one cell to the next
RAISED = 75            # radius of a raised dot (1.5 mm across)
RING_OUTER = 70
RING_INNER = 46        # a ring 24 units thick: thin, but never lost
LEFT = (ADVANCE - PITCH) // 2   # x of the left column; the right is PITCH on
BASE = 100             # y of the lowest of the six-dot cell's rows
ASCENT, DESCENT = 800, -300

# The bit of each dot in the cell's code point, and its (column, row from
# the top): 1-2-3 down the left, 4-5-6 down the right, 7 and 8 beneath.
DOTS = {1: (0, 0), 2: (0, 1), 3: (0, 2), 4: (1, 0), 5: (1, 1), 6: (1, 2),
        7: (0, 3), 8: (1, 3)}


def _centre(dot: int) -> tuple[int, int]:
    col, row = DOTS[dot]
    # Dots 1 to 6 sit where they do in every cell; 7 and 8 hang below.
    top = BASE + 2 * PITCH
    return LEFT + col * PITCH, top - row * PITCH


def _circle(pen, cx: int, cy: int, r: int, clockwise: bool) -> None:
    """A closed contour of eight off-curve points, whose implied on-curve
    midpoints lie on the circle of radius [r]."""
    r_off = r / math.cos(math.pi / 8)
    sign = -1 if clockwise else 1
    points = []
    for k in range(8):
        a = sign * (math.pi / 8 + k * math.pi / 4)
        points.append((round(cx + r_off * math.cos(a)),
                       round(cy + r_off * math.sin(a))))
    pen.qCurveTo(*points, None)
    pen.closePath()


def cell_glyph(code: int):
    """The glyph of the cell U+2800 + [code]."""
    rows = 4 if code & 0xC0 else 3
    pen = TTGlyphPen(None)
    for dot in range(1, 9):
        if dot > 6 and rows == 3:
            break
        cx, cy = _centre(dot)
        if code & (1 << (dot - 1)):
            _circle(pen, cx, cy, RAISED, clockwise=True)
        else:
            # TrueType fills what the winding says: the hole turns the
            # other way from the ring's outside.
            _circle(pen, cx, cy, RING_OUTER, clockwise=True)
            _circle(pen, cx, cy, RING_INNER, clockwise=False)
    return pen.glyph()


def build(path: Path = OUT) -> Path:
    names = [".notdef", "space"] + [f"braille{c:02X}" for c in range(256)]
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(names)
    cmap = {0x20: "space", 0xA0: "space"}
    cmap.update({0x2800 + c: f"braille{c:02X}" for c in range(256)})
    fb.setupCharacterMap(cmap)
    empty = TTGlyphPen(None).glyph()
    glyphs = {".notdef": empty, "space": empty}
    glyphs.update({f"braille{c:02X}": cell_glyph(c) for c in range(256)})
    fb.setupGlyf(glyphs)
    glyf = fb.font["glyf"]
    metrics = {}
    for name, glyph in glyphs.items():
        glyph.recalcBounds(glyf)
        metrics[name] = (ADVANCE, getattr(glyph, "xMin", 0) or 0)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupNameTable({
        "familyName": FAMILY,
        "styleName": "Regular",
        "uniqueFontIdentifier": f"{FAMILY} 1.0",
        "fullName": f"{FAMILY} Regular",
        "psName": "FluenoughBrailleShadow-Regular",
        "version": "Version 1.000",
        "copyright": "Copyright 2026 The Fluenough Authors. This Font "
                     "Software is licensed under the SIL Open Font "
                     "License, Version 1.1.",
        "licenseDescription": "This Font Software is licensed under the "
                              "SIL Open Font License, Version 1.1. "
                              "https://openfontlicense.org",
        "licenseInfoURL": "https://openfontlicense.org",
    })
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT,
                sTypoLineGap=0, usWinAscent=ASCENT, usWinDescent=-DESCENT,
                usWeightClass=400, fsType=0)
    fb.setupPost()
    fb.font["head"].created = fb.font["head"].modified = 0
    path.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(path))
    return path


if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    print(build(target))
