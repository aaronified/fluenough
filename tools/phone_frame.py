#!/usr/bin/env python3
"""Put a screenshot inside a phone silhouette, for the README.

    python3 tools/phone_frame.py build/readme_gifs/static/home.png docs/screenshots/home.png

The silhouette is drawn here, with Pillow, from the screenshot's own size:
a rounded bezel in a light silver with a thin darker rim, so that it shows
on both the light and the dark README, a camera dot at the top of the screen,
and three side buttons. Everything outside the phone is transparent. The
result is written as a palette PNG (with transparency), made narrower until
it fits --max-bytes.

`tools/make_gif.py --phone` frames every frame of a GIF the same way, with
[frame_phone].

Needs Pillow (`pip install pillow`); nothing else in tools/ does.
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path

# The bezel's colours: silver body, a darker rim, the screen's edge line.
BODY = (226, 229, 234, 255)
RIM = (128, 134, 143, 255)
EDGE = (30, 32, 36, 255)
CAMERA = (22, 24, 28, 255)
CAMERA_RING = (70, 74, 82, 255)

# Drawn this many times too large, then shrunk, for smooth curves.
_SUPERSAMPLE = 4


def margins(width: int) -> tuple[int, int]:
    """The bezel's thickness and the side buttons' reach, for a screen
    [width] pixels wide."""
    return max(6, round(width * 0.04)), max(3, round(width * 0.012))


def status_band(width: int) -> int:
    """The height of the blank band above the screenshot, where the camera
    dot sits so that it never covers the app."""
    return round(width * 0.075)


def gesture_pill(width: int) -> tuple[int, int]:
    """The Android gesture handle's width and thickness for a screen
    [width] pixels wide: 144 x 14 on a 1440 px screen."""
    return round(width * 0.1), max(3, round(width * 0.0097))


def nav_band(width: int) -> int:
    """The height of the thin band below the app's navigation bar that holds
    the gesture handle."""
    return gesture_pill(width)[1] * 3


def frame_size(screen_size: tuple[int, int]) -> tuple[int, int]:
    """The size of the framed image for a screen of [screen_size]."""
    width, height = screen_size
    bezel, button = margins(width)
    return (
        width + 2 * (bezel + button),
        height + status_band(width) + nav_band(width) + 2 * bezel,
    )


# Where an owner's crop of the real status bar can be dropped in, by theme:
# `status-bar-light.png` and `status-bar-dark.png`.
FRAME_DIR = Path(__file__).resolve().parent.parent / "docs" / "screenshots" / "frame"


def _is_dark(colour) -> bool:
    r, g, b = colour[:3]
    return 0.299 * r + 0.587 * g + 0.114 * b < 128


def _status_bar(width: int, background, frame_dir: Path | None):
    """The status band, [width] wide: the owner's crop for the screen's
    theme if there is one in [frame_dir], else one drawn here (time, small
    notification icons, and signal, wifi and battery)."""
    from PIL import Image, ImageDraw, ImageFont

    height = status_band(width)
    dark = _is_dark(background)
    crop = (frame_dir or FRAME_DIR) / f"status-bar-{'dark' if dark else 'light'}.png"
    if crop.is_file():
        with Image.open(crop) as img:
            return img.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
    ink = (245, 246, 248) if dark else (28, 30, 34)
    ss = 4
    band = Image.new("RGB", (width * ss, height * ss), background)
    d = ImageDraw.Draw(band)
    mid = height * ss / 2
    unit = height * ss * 0.5  # the icons' height
    # Time, at the left.
    try:
        font = ImageFont.load_default(size=round(height * ss * 0.5))
    except TypeError:  # an old Pillow: the fixed-size font
        font = ImageFont.load_default()
    d.text((width * ss * 0.06, mid), "9:41", fill=ink, font=font, anchor="lm")
    # Notification icons after it: a few small shapes.
    x = width * ss * 0.06 + height * ss * 1.7
    r = unit * 0.28
    d.ellipse([x, mid - r, x + 2 * r, mid + r], fill=ink)
    x += unit * 0.9
    d.rounded_rectangle([x, mid - r, x + 2 * r, mid + r], radius=r * 0.4, fill=ink)
    x += unit * 0.9
    d.polygon([(x, mid + r), (x + r, mid - r), (x + 2 * r, mid + r)], fill=ink)
    # System icons at the right: battery, then signal bars, then wifi.
    right = width * ss * 0.94
    bw, bh = unit * 0.95, unit * 0.5
    d.rounded_rectangle(
        [right - bw, mid - bh / 2, right, mid + bh / 2],
        radius=bh * 0.25,
        outline=ink,
        width=max(2, round(unit * 0.07)),
    )
    pad = unit * 0.1
    d.rounded_rectangle(
        [right - bw + pad * 1.6, mid - bh / 2 + pad * 1.6, right - bw * 0.3, mid + bh / 2 - pad * 1.6],
        radius=bh * 0.1,
        fill=ink,
    )
    d.rectangle([right + unit * 0.04, mid - bh * 0.15, right + unit * 0.1, mid + bh * 0.15], fill=ink)
    x = right - bw - unit * 0.5
    for i in range(4):
        h = unit * (0.2 + 0.14 * i)
        d.rectangle([x - unit * 0.62 + i * unit * 0.16, mid + unit * 0.3 - h, x - unit * 0.62 + i * unit * 0.16 + unit * 0.1, mid + unit * 0.3], fill=ink)
    x -= unit * 0.95
    cy = mid + unit * 0.32
    for k, rad in enumerate((unit * 0.62, unit * 0.4, unit * 0.18)):
        d.pieslice([x - rad, cy - rad, x + rad, cy + rad], 225, 315, fill=ink if k != 1 else background)
        # An arc ring: the next smaller pie, cut out in the background.
    d.pieslice([x - unit * 0.3, cy - unit * 0.3, x + unit * 0.3, cy + unit * 0.3], 225, 315, fill=ink)
    return band.resize((width, height), Image.Resampling.LANCZOS)


def _gesture_band(width: int, background):
    """The band below the navigation bar, with the gesture handle."""
    from PIL import Image, ImageDraw

    height = nav_band(width)
    pill_w, pill_h = gesture_pill(width)
    ss = 4
    band = Image.new("RGB", (width * ss, height * ss), background)
    colour = (176, 180, 186) if _is_dark(background) else (112, 116, 122)
    left = (width - pill_w) / 2 * ss
    top = (height - pill_h) / 2 * ss
    ImageDraw.Draw(band).rounded_rectangle(
        [left, top, left + pill_w * ss, top + pill_h * ss],
        radius=pill_h * ss / 2,
        fill=colour,
    )
    return band.resize((width, height), Image.Resampling.LANCZOS)


def frame_phone(screen, frame_dir: Path | None = None):
    """[screen] (a Pillow image) inside a phone silhouette, as an RGBA image
    with a transparent background."""
    from PIL import Image, ImageDraw

    screen = screen.convert("RGB")
    w, h = screen.size
    # A status bar on top, over the screenshot's own top colour, and the
    # gesture handle under its navigation bar, over its bottom colour.
    band = status_band(w)
    nav = nav_band(w)
    banded = Image.new("RGB", (w, h + band + nav))
    banded.paste(_status_bar(w, screen.getpixel((w // 2, 0)), frame_dir), (0, 0))
    banded.paste(screen, (0, band))
    banded.paste(_gesture_band(w, screen.getpixel((w // 2, h - 1))), (0, band + h))
    screen = banded
    h += band + nav
    bezel, button = margins(w)
    out_w, out_h = frame_size((w, h - band - nav))
    ss = _SUPERSAMPLE
    radius = round(w * 0.13)
    inner_radius = max(4, radius - bezel)
    rim = max(2, round(w * 0.005))
    line = max(1, round(w * 0.004))

    def big(*box):
        return [round(v * ss) for v in box]

    body_left = button
    body_right = button + w + 2 * bezel
    art = Image.new("RGBA", (out_w * ss, out_h * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(art)
    # Side buttons first, the body over their roots: the power key and two
    # volume keys, on the right and the left.
    key = max(2, round(h * 0.004))
    for side, top, length in (
        ("right", 0.22, 0.075),
        ("right", 0.33, 0.075),
        ("left", 0.26, 0.10),
    ):
        y0 = out_h * top
        y1 = y0 + h * length
        if side == "right":
            box = big(body_right - rim, y0, body_right + button, y1)
        else:
            box = big(0, y0, body_left + rim, y1)
        d.rounded_rectangle(box, radius=key * ss, fill=RIM)
        d.rounded_rectangle(
            [box[0] + (rim * ss if side == "right" else 0), box[1] + rim * ss // 2,
             box[2] - (0 if side == "right" else rim * ss), box[3] - rim * ss // 2],
            radius=key * ss,
            fill=BODY,
        )
    d.rounded_rectangle(
        big(body_left, 0, body_right - 1, out_h - 1), radius=radius * ss, fill=RIM
    )
    d.rounded_rectangle(
        big(body_left + rim, rim, body_right - 1 - rim, out_h - 1 - rim),
        radius=(radius - rim) * ss,
        fill=BODY,
    )
    # The screen's edge, a dark line just outside the picture.
    d.rounded_rectangle(
        big(
            body_left + bezel - line,
            bezel - line,
            body_left + bezel + w + line - 1,
            bezel + h + line - 1,
        ),
        radius=(inner_radius + line) * ss,
        fill=EDGE,
    )
    art = art.resize((out_w, out_h), Image.Resampling.LANCZOS)

    # The screen, with rounded corners.
    mask = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, w * ss - 1, h * ss - 1], radius=inner_radius * ss, fill=255
    )
    mask = mask.resize((w, h), Image.Resampling.LANCZOS)
    art.paste(screen, (body_left + bezel, bezel), mask)

    # The camera: a dot at the top of the screen, on a thin ring.
    dot = max(3, round(w * 0.022))
    cx = body_left + bezel + w / 2
    cy = bezel + band / 2
    layer = Image.new("RGBA", (out_w * ss, out_h * ss), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ring = dot + max(1, round(dot * 0.3))
    ld.ellipse(big(cx - ring, cy - ring, cx + ring, cy + ring), fill=CAMERA_RING)
    ld.ellipse(big(cx - dot, cy - dot, cx + dot, cy + dot), fill=CAMERA)
    layer = layer.resize((out_w, out_h), Image.Resampling.LANCZOS)
    art.alpha_composite(layer)
    return art


def to_palette(image, colors: int = 256):
    """[image] (RGBA) as a palette image that keeps its transparency."""
    from PIL import Image

    return image.quantize(colors=colors, method=Image.Quantize.FASTOCTREE)


def png_bytes(image, colors: int = 256) -> bytes:
    out = io.BytesIO()
    to_palette(image, colors).save(out, format="PNG", optimize=True)
    return out.getvalue()


def write_framed_png(
    source: Path, out: Path, *, width: int = 0, max_bytes: int = 400_000
) -> tuple[int, int]:
    """Writes [source] framed to [out]; returns its size in bytes and its
    width in pixels. The screenshot is scaled to [width] first if given, and
    made narrower (down to 360 px) and with fewer colours until the PNG fits
    [max_bytes]."""
    from PIL import Image

    screen = Image.open(source).convert("RGB")
    if width and screen.width != width:
        height = round(screen.height * width / screen.width)
        screen = screen.resize((width, height), Image.Resampling.LANCZOS)
    colors = 256
    while True:
        data = png_bytes(frame_phone(screen), colors)
        if len(data) <= max_bytes:
            break
        if colors > 128:
            colors = 128
        elif screen.width > 360:
            width = max(360, round(screen.width * 0.9))
            height = round(screen.height * width / screen.width)
            screen = screen.resize((width, height), Image.Resampling.LANCZOS)
        else:
            break
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    return len(data), frame_size(screen.size)[0]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("screenshot", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--width", type=int, default=0, help="scale the screen to this width first")
    parser.add_argument("--max-bytes", type=int, default=400_000)
    args = parser.parse_args(argv)
    size, width = write_framed_png(
        args.screenshot, args.out, width=args.width, max_bytes=args.max_bytes
    )
    print(f"{args.out}: {size / 1e3:.0f} KB, {width} px wide")
    if size > args.max_bytes:
        print("over --max-bytes even at the smallest settings", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
