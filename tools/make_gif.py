#!/usr/bin/env python3
"""Assemble a directory of PNG frames into a looping, palette-optimised GIF.

    python3 tools/make_gif.py build/readme_gifs/today docs/screenshots/today.gif

The frames are `frame_NNN.png`, as test/tools/readme_gifs_test.dart writes
them, played in name order. Every frame is scaled to --width and mapped to
one palette taken from a sample of them all, without dithering: an app's
flat colours compress far better undithered, and one palette keeps colours
from flickering between frames. Runs of identical frames become one longer
frame. If the GIF comes out over --max-bytes, it is made again narrower
(to 300 px), then with fewer colours (to 64), then narrower again (to
240 px), until it fits or cannot shrink further.

Needs Pillow (`pip install pillow`); nothing else in tools/ does.
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path


def frame_paths(directory: Path) -> list[Path]:
    """The frames in [directory], in play order."""
    return sorted(directory.glob("frame_*.png"))


def encode(frames, width: int, colors: int, fps: float) -> bytes:
    """[frames], scaled to [width] and mapped to one palette of [colors],
    as a GIF that loops forever at [fps]."""
    from PIL import Image

    scaled = []
    for frame in frames:
        rgb = frame.convert("RGB")
        if rgb.width != width:
            height = round(rgb.height * width / rgb.width)
            rgb = rgb.resize((width, height), Image.Resampling.LANCZOS)
        scaled.append(rgb)
    # One palette from a sample of the frames, stacked.
    sample = scaled[:: max(1, len(scaled) // 12)]
    sheet = Image.new("RGB", (width, sum(f.height for f in sample)))
    y = 0
    for f in sample:
        sheet.paste(f, (0, y))
        y += f.height
    palette = sheet.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    mapped = [
        f.quantize(palette=palette, dither=Image.Dither.NONE) for f in scaled
    ]
    out = io.BytesIO()
    mapped[0].save(
        out,
        format="GIF",
        save_all=True,
        append_images=mapped[1:],
        duration=round(1000 / fps),
        loop=0,
        optimize=True,
        disposal=1,
    )
    return out.getvalue()


def make_gif(
    frames_dir: Path,
    out: Path,
    *,
    fps: float = 11,
    width: int = 360,
    colors: int = 128,
    max_bytes: int = 1_500_000,
) -> tuple[int, int, int]:
    """Writes [out] from [frames_dir]; returns its size in bytes, and the
    width and colours it was made with."""
    from PIL import Image

    paths = frame_paths(frames_dir)
    if not paths:
        raise SystemExit(f"no frame_*.png in {frames_dir}")
    frames = [Image.open(p) for p in paths]
    while True:
        data = encode(frames, width, colors, fps)
        if len(data) <= max_bytes:
            break
        # Narrower first, as far as a README shows it crisply, then fewer
        # colours, then narrower still.
        if width > 300:
            width = max(300, width - 20)
        elif colors > 64:
            colors = max(64, colors - 16)
        elif width > 240:
            width = max(240, width - 20)
        else:
            break
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    return len(data), width, colors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("frames", type=Path, help="directory of frame_NNN.png")
    parser.add_argument("out", type=Path, help="the GIF to write")
    parser.add_argument("--fps", type=float, default=11)
    parser.add_argument("--width", type=int, default=360)
    parser.add_argument("--colors", type=int, default=128)
    parser.add_argument("--max-bytes", type=int, default=1_500_000)
    args = parser.parse_args(argv)
    size, width, colors = make_gif(
        args.frames,
        args.out,
        fps=args.fps,
        width=args.width,
        colors=args.colors,
        max_bytes=args.max_bytes,
    )
    print(f"{args.out}: {size / 1e6:.2f} MB, {width} px wide, {colors} colours")
    if size > args.max_bytes:
        print("over --max-bytes even at the smallest settings", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
