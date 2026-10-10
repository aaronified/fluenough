"""Tests for make_gif.py and readme_fonts.py, the README screenshot tools.

make_gif.py needs Pillow, which CI does not install: its tests are skipped
without it.
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_gif  # noqa: E402
import readme_fonts  # noqa: E402

try:
    from PIL import Image
except ImportError:  # pragma: no cover - depends on the machine
    Image = None


@unittest.skipIf(Image is None, "needs Pillow")
class MakeGifTest(unittest.TestCase):
    def frames(self, directory: Path, count: int) -> None:
        for i in range(count):
            image = Image.new("RGB", (80, 160), (240, 248, 240))
            # A bar that moves down, as a scrolled page does.
            for y in range(i * 10, i * 10 + 20):
                for x in range(10, 70):
                    image.putpixel((x, y), (40, 110, 70))
            image.save(directory / f"frame_{i:03d}.png")

    def test_frames_play_in_name_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            for name in ("frame_010.png", "frame_002.png", "other.png"):
                (d / name).write_bytes(b"")
            self.assertEqual(
                [p.name for p in make_gif.frame_paths(d)],
                ["frame_002.png", "frame_010.png"],
            )

    def test_makes_a_looping_scaled_gif(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            self.frames(d, 6)
            out = d / "out" / "x.gif"
            size, width, _ = make_gif.make_gif(d, out, width=40, fps=10)
            self.assertEqual(size, out.stat().st_size)
            self.assertEqual(width, 40)
            with Image.open(out) as gif:
                self.assertEqual(gif.size, (40, 80))
                self.assertEqual(gif.n_frames, 6)
                self.assertEqual(gif.info["loop"], 0)
                self.assertEqual(gif.info["duration"], 100)

    def test_shrinks_to_fit(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            self.frames(d, 6)
            _, width, colors = make_gif.make_gif(
                d, d / "x.gif", width=360, colors=128, max_bytes=1
            )
            # Nothing fits in a byte: it stops at the smallest it makes.
            self.assertEqual((width, colors), (240, 64))

    def test_no_frames_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(SystemExit):
                make_gif.make_gif(Path(tmp), Path(tmp) / "x.gif")


class ReadmeFontsTest(unittest.TestCase):
    def test_nearest_weight_prefers_the_heavier_on_a_tie(self):
        regular, semibold = Path("r.ttf"), Path("s.ttf")
        weights = {regular: 400, semibold: 600}
        self.assertEqual(readme_fonts.nearest(weights, 300), regular)
        self.assertEqual(readme_fonts.nearest(weights, 400), regular)
        self.assertEqual(readme_fonts.nearest(weights, 500), semibold)
        self.assertEqual(readme_fonts.nearest(weights, 900), semibold)


if __name__ == "__main__":
    unittest.main()
