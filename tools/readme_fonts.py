#!/usr/bin/env python3
"""Build the fonts the README's screenshots are drawn in.

    python3 tools/readme_fonts.py path/to/noto-bengali out/fonts

A widget test draws text in Ahem, a font of boxes, and turns font fallback
off, so Roboto alone cannot show a Bengali word the way a phone does, where
Noto Sans Bengali fills in what Roboto lacks. This merges the two instead:
each weight of the Flutter SDK's Roboto gets the Bengali glyphs of the
nearest weight of Noto Sans Bengali, scaled to Roboto's units, and is
written as `Roboto-<Weight>.ttf` in the output directory, which
tools/readme_gifs/readme_gifs_test.dart loads as Roboto (README_GIFS_FONTS).

The Noto directory holds static `NotoSansBengali-*.ttf` files, from
https://github.com/notofonts/bengali (OFL-1.1). Needs fontTools
(`pip install fonttools`); nothing else in tools/ does, and only this
script, which no check runs, imports it.
"""

from __future__ import annotations

import argparse
import io
import os
import shutil
import sys
from pathlib import Path

# Roboto's weights in the SDK, and the weight each stands for.
ROBOTO = {
    "Light": 300,
    "Regular": 400,
    "Medium": 500,
    "Bold": 700,
    "Black": 900,
}


def flutter_fonts(flutter_root: Path | None) -> Path:
    """The SDK's material_fonts directory: from [flutter_root], else
    FLUTTER_ROOT, else the `flutter` on PATH."""
    if flutter_root is None:
        env = os.environ.get("FLUTTER_ROOT")
        if env:
            flutter_root = Path(env)
        else:
            flutter = shutil.which("flutter")
            if flutter is None:
                raise SystemExit("flutter is not on PATH; pass --flutter-root")
            flutter_root = Path(flutter).resolve().parent.parent
    fonts = flutter_root / "bin" / "cache" / "artifacts" / "material_fonts"
    if not (fonts / "Roboto-Regular.ttf").is_file():
        raise SystemExit(f"no Roboto in {fonts}")
    return fonts


def nearest(weights: dict[Path, int], weight: int) -> Path:
    """The file whose weight is closest to [weight], the heavier on a tie."""
    return min(weights, key=lambda p: (abs(weights[p] - weight), -weights[p]))


def combining_marks(noto_sans: Path, roboto: Path) -> io.BytesIO:
    """The IPA letters (U+0250-02FF), combining diacritics (U+0300-036F) and
    Latin Extended Additional (U+1E00-1EFF) of [noto_sans], scaled to
    Roboto's units, as a font to merge in: Roboto lacks some, such as the
    candrabindu U+0310 a Bengali reading can carry, or an IPA letter of a
    card's pronunciation, which would draw as a box."""
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.scaleUpem import scale_upem

    font = TTFont(noto_sans)
    options = subset.Options()
    options.layout_features = ["mark", "mkmk"]
    options.notdef_outline = False
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[*range(0x250, 0x300), *range(0x300, 0x370), *range(0x1E00, 0x1F00)])
    subsetter.subset(font)
    scale_upem(font, TTFont(roboto)["head"].unitsPerEm)
    out = io.BytesIO()
    font.save(out)
    out.seek(0)
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("noto", type=Path, help="directory of NotoSansBengali-*.ttf")
    parser.add_argument("out", type=Path, help="directory to write Roboto-*.ttf to")
    parser.add_argument("--flutter-root", type=Path, default=None)
    parser.add_argument(
        "--marks",
        type=Path,
        default=None,
        help="directory of NotoSans-*.ttf, whose combining marks "
        "(IPA letters and combining marks) are added, as readings and IPA use them",
    )
    args = parser.parse_args(argv)

    from fontTools.merge import Merger, Options
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.scaleUpem import scale_upem

    sdk = flutter_fonts(args.flutter_root)
    notos = sorted(args.noto.glob("NotoSansBengali-*.ttf"))
    if not notos:
        print(f"no NotoSansBengali-*.ttf in {args.noto}", file=sys.stderr)
        return 2
    weights = {p: TTFont(p)["OS/2"].usWeightClass for p in notos}
    mark_weights = {}
    if args.marks is not None:
        sans = sorted(args.marks.glob("NotoSans-*.ttf"))
        if not sans:
            print(f"no NotoSans-*.ttf in {args.marks}", file=sys.stderr)
            return 2
        mark_weights = {p: TTFont(p)["OS/2"].usWeightClass for p in sans}
    args.out.mkdir(parents=True, exist_ok=True)
    for name, weight in ROBOTO.items():
        roboto = sdk / f"Roboto-{name}.ttf"
        noto_path = nearest(weights, weight)
        noto = TTFont(noto_path)
        scale_upem(noto, TTFont(roboto)["head"].unitsPerEm)
        scaled = io.BytesIO()
        noto.save(scaled)
        scaled.seek(0)
        parts = [str(roboto), scaled]
        if mark_weights:
            parts.append(combining_marks(nearest(mark_weights, weight), roboto))
        merged = Merger(Options(drop_tables=["vmtx", "vhea", "MATH"])).merge(parts)
        target = args.out / f"Roboto-{name}.ttf"
        merged.save(target)
        print(f"{target.name}: Roboto {name} + {noto_path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
