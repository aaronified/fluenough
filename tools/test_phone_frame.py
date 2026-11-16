"""Tests for phone_frame.py: the silhouette around a screenshot."""

import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None

import phone_frame

SCREEN = (180, 390)


def _screen(colour=(200, 40, 40)):
    return Image.new("RGB", SCREEN, colour)


@unittest.skipIf(Image is None, "Pillow is not installed")
class PhoneFrameTest(unittest.TestCase):
    def test_the_frame_is_bigger_than_the_screen_by_its_bezel(self):
        framed = phone_frame.frame_phone(_screen())
        self.assertEqual(framed.size, phone_frame.frame_size(SCREEN))
        self.assertGreater(framed.width, SCREEN[0])
        self.assertGreater(framed.height, SCREEN[1])
        self.assertEqual(framed.mode, "RGBA")

    def test_the_screen_shows_unchanged_in_the_middle(self):
        framed = phone_frame.frame_phone(_screen())
        bezel, button = phone_frame.margins(SCREEN[0])
        self.assertEqual(
            framed.getpixel((framed.width // 2, framed.height // 2)),
            (200, 40, 40, 255),
        )
        # And at the screen's own corner region just inside its rounding.
        self.assertEqual(
            framed.getpixel((button + bezel + SCREEN[0] // 2, bezel + 100)),
            (200, 40, 40, 255),
        )

    def test_outside_the_phone_is_transparent(self):
        framed = phone_frame.frame_phone(_screen())
        for corner in (
            (0, 0),
            (framed.width - 1, 0),
            (0, framed.height - 1),
            (framed.width - 1, framed.height - 1),
        ):
            self.assertEqual(framed.getpixel(corner)[3], 0)

    def test_the_bezel_is_opaque_and_light(self):
        framed = phone_frame.frame_phone(_screen())
        bezel, button = phone_frame.margins(SCREEN[0])
        # Midway down the left bezel, between the rim and the screen's edge.
        x = button + bezel // 2
        r, g, b, a = framed.getpixel((x, framed.height // 2))
        self.assertEqual(a, 255)
        self.assertGreater(min(r, g, b), 100)

    def test_the_camera_dot_is_dark_at_the_top_centre(self):
        framed = phone_frame.frame_phone(_screen((255, 255, 255)))
        bezel, _ = phone_frame.margins(SCREEN[0])
        dark = [
            framed.getpixel((framed.width // 2, y))
            for y in range(bezel, bezel + 40)
        ]
        self.assertTrue(any(max(p[:3]) < 60 for p in dark))

    def test_the_screen_has_rounded_corners(self):
        framed = phone_frame.frame_phone(_screen((255, 255, 255)))
        bezel, button = phone_frame.margins(SCREEN[0])
        corner = framed.getpixel((button + bezel, bezel))
        # The screen's own corner is cut away: not the screen's white.
        self.assertNotEqual(corner[:3], (255, 255, 255))

    def test_the_png_is_a_small_palette_image_with_transparency(self):
        framed = phone_frame.frame_phone(_screen())
        data = phone_frame.png_bytes(framed)
        back = Image.open(io.BytesIO(data))
        self.assertEqual(back.mode, "P")
        self.assertEqual(back.size, framed.size)
        self.assertEqual(back.convert("RGBA").getpixel((0, 0))[3], 0)

    def test_the_command_writes_a_framed_png(self):
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "in.png"
            out = Path(tmp) / "out" / "framed.png"
            _screen().save(src)
            self.assertEqual(phone_frame.main([str(src), str(out)]), 0)
            with Image.open(out) as back:
                self.assertEqual(back.size, phone_frame.frame_size(SCREEN))

    def test_a_phone_gif_is_transparent_outside_the_phone(self):
        import make_gif

        with tempfile.TemporaryDirectory() as tmp:
            frames = Path(tmp) / "frames"
            frames.mkdir()
            for i in range(3):
                _screen((40 * i, 80, 120)).save(frames / f"frame_{i:03d}.png")
            out = Path(tmp) / "out.gif"
            make_gif.make_gif(frames, out, phone=True, width=120)
            with Image.open(out) as gif:
                self.assertEqual(gif.n_frames, 3)
                rgba = gif.convert("RGBA")
                self.assertEqual(rgba.getpixel((0, 0))[3], 0)
                self.assertEqual(
                    rgba.getpixel((rgba.width // 2, rgba.height // 2))[3], 255
                )


if __name__ == "__main__":
    unittest.main()
