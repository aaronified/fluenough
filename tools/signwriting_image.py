#!/usr/bin/env python3
"""Draws a sign written in Formal SignWriting (FSW) as the card's own image
(ADR-0056).

    python3 tools/signwriting_image.py --fonts DIR 'M507x507S1f720487x492' out.webp

A sign language has no sound and no letters that a phone's text layout can
set: SignWriting is two-dimensional, each symbol placed at its own x and y in
a sign box, so a font cannot draw a sign (ADR-0056). The deck therefore keeps
the sign as FSW text, `target_scripts: { signwriting: "M507x507S..." }`, and
ships a picture of it, `image`, which this tool draws from that text,
deterministically. The app shows the picture; the FSW is the source of truth
that the validator checks and this tool redraws it from.

Maintainers only, like `pictures.py` (which needs ffmpeg): it needs Pillow
(`pip install Pillow`) and the two Sutton SignWriting fonts, which are not in
the repository (10 MB, SIL OFL-1.1, Center for Sutton Movement Writing):

    npm pack @sutton-signwriting/font-ttf   # MIT; font/SuttonSignWritingFill.ttf
    tar xzf sutton-signwriting-font-ttf-*.tgz  # and ...Line.ttf, in package/font

`--fonts` names the folder that holds both. The deck tools themselves stay
stdlib and PyYAML: nothing here is imported by the validator or the index.

How a sign is drawn: every symbol is two glyphs, a Fill (white) and a Line
(black), at its key's code point (`S` + 3 hex digits of base symbol, a fill
digit and a rotation digit), placed at its x and y. The sign is scaled
so that it fits a 256 pixel square, centred on white, so a
picture is the same in the light and the dark theme.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# One sign: a box (B, L, M or R, with its width and height) and at least one
# symbol with its position. Styling is refused. This is the grammar of the
# draft-slevinski-formal-signwriting specification, the same as
# `FSW_RE` in validate_decks.py.
SYMBOL = re.compile(r"S([123][0-9a-f]{2})([0-5])([0-9a-f])(\d{3})x(\d{3})")
SIGN = re.compile(r"[BLMR](\d{3})x(\d{3})((?:S[123][0-9a-f]{2}[0-5][0-9a-f]\d{3}x\d{3})+)")
SIDE = 256  # pixels: "about 256" (Deck Format, "A card's own image")
FONT_PX = 30  # the fonts' design size: one unit of FSW is one pixel at this size


def key_id(base: int, fill: int, rot: int) -> int:
    """The id of a symbol in the fonts: ISWA 2010's numbering."""
    return (base - 0x100) * 96 + fill * 16 + rot + 1


def parse(fsw: str) -> list[tuple[int, int, int, int, int]]:
    """The symbols of one FSW sign as (base, fill, rotation, x, y)."""
    m = SIGN.fullmatch(fsw)
    if not m:
        raise ValueError(f"not one unstyled FSW sign: {fsw!r}")
    return [(int(b, 16), int(f), int(r, 16), int(x), int(y))
            for b, f, r, x, y in SYMBOL.findall(m.group(3))]


def draw(fsw: str, fonts: Path):
    from PIL import Image, ImageDraw, ImageFont  # imported here: stdlib elsewhere

    symbols = parse(fsw)

    def font(name: str, size: int):
        return ImageFont.truetype(str(fonts / f"SuttonSignWriting{name}.ttf"), size)

    # The extent of the sign, drawn once at 1x to measure each symbol.
    line1 = font("Line", FONT_PX)
    boxes = []
    for base, fill, rot, x, y in symbols:
        l, t, r, b = line1.getbbox(chr(key_id(base, fill, rot) + 0xF0000))
        boxes.append((x, y, x + (r - l), y + (b - t)))
    x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
    w, h = x1 - x0, y1 - y0
    # Scaled to fit with 8 pixels of margin, at most 6x so a single hand
    # symbol is not blown up to fill the square.
    scale = min(6.0, (SIDE - 16) / max(w, h, 1))
    fill_f, line_f = font("Fill", FONT_PX * scale), font("Line", FONT_PX * scale)
    img = Image.new("RGB", (SIDE, SIDE), (255, 255, 255))
    d = ImageDraw.Draw(img)
    ox = (SIDE - w * scale) / 2
    oy = (SIDE - h * scale) / 2
    for base, fill, rot, x, y in symbols:
        pos = (round(ox + (x - x0) * scale), round(oy + (y - y0) * scale))
        i = key_id(base, fill, rot)
        d.text(pos, chr(i + 0x100000), font=fill_f, fill=(255, 255, 255))
        d.text(pos, chr(i + 0xF0000), font=line_f, fill=(0, 0, 0))
    return img


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--fonts", required=True, type=Path,
                    help="folder with SuttonSignWritingFill.ttf and ...Line.ttf")
    ap.add_argument("fsw", nargs="?", help="one FSW sign")
    ap.add_argument("out", nargs="?", type=Path, help="the .webp to write")
    args = ap.parse_args()
    if not (args.fsw and args.out):
        ap.error("give the FSW sign and the output file")
    try:
        draw(args.fsw, args.fonts).save(args.out, "WEBP", quality=90, method=6)
    except (ValueError, OSError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
