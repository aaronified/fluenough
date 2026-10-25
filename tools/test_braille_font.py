"""The braille shadow-dot font (#835, ADR-0043): every cell of the block is
there with all its positions drawn, raised dots solid and unraised ones
rings, and the committed file is what the generator builds."""
import tempfile
import unittest
from pathlib import Path

try:
    from fontTools.ttLib import TTFont
except ImportError:  # the generator is a developer tool: skip without it
    TTFont = None

import make_braille_font as gen

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets" / "fonts" / "BrailleShadow.ttf"


@unittest.skipIf(TTFont is None, "fonttools is not installed")
class BrailleShadowFont(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.font = TTFont(FONT)
        cls.glyf = cls.font["glyf"]
        cls.cmap = cls.font.getBestCmap()

    def _contours(self, code: int) -> int:
        return self.glyf[self.cmap[0x2800 + code]].numberOfContours

    def test_every_cell_is_drawn_with_all_its_positions(self):
        for code in range(256):
            self.assertIn(0x2800 + code, self.cmap, f"U+{0x2800 + code:04X}")
            raised = bin(code & 0x3F).count("1")
            positions = 8 if code & 0xC0 else 6
            raised += bin(code & 0xC0).count("1")
            # A raised dot is one filled contour, an unraised one a ring:
            # an outside and a hole.
            self.assertEqual(self._contours(code),
                             raised + 2 * (positions - raised),
                             f"cell {code:#04x}")

    def test_a_lone_dots_column_and_row_can_be_read(self):
        # Each of the six single-dot cells looks different, and every one
        # shows six positions: the shadow dots around the raised one are
        # what tell its place.
        lone = [1 << d for d in range(6)]
        drawn = {tuple(self.glyf[self.cmap[0x2800 + c]].coordinates)
                 for c in lone}
        self.assertEqual(len(drawn), 6)
        self.assertEqual({self._contours(c) for c in lone}, {1 + 2 * 5})

    def test_the_cell_has_the_standard_proportions(self):
        # Dots 2.5 mm apart, cells 6 mm: the gap between cells is wider
        # than the one inside a cell.
        self.assertEqual(gen.PITCH, 250)
        self.assertEqual(gen.ADVANCE, 600)
        self.assertGreater(gen.ADVANCE - gen.PITCH, gen.PITCH)
        self.assertEqual(self.font["hmtx"][self.cmap[0x2801]][0], gen.ADVANCE)

    def test_the_rings_are_thin_and_the_font_small(self):
        self.assertLess(gen.RING_OUTER - gen.RING_INNER, gen.RAISED)
        self.assertLess(FONT.stat().st_size, 100_000)

    def test_it_is_licensed_openly(self):
        names = {n.nameID: n.toUnicode() for n in self.font["name"].names}
        self.assertIn("SIL Open Font License", names[13])
        text = (FONT.parent / "OFL.txt").read_text(encoding="utf-8")
        self.assertIn("SIL OPEN FONT LICENSE Version 1.1", text)

    def test_the_committed_file_is_what_the_generator_builds(self):
        with tempfile.TemporaryDirectory() as tmp:
            built = TTFont(gen.build(Path(tmp) / "b.ttf"))
            self.assertEqual(built.getBestCmap(), self.cmap)
            for name in self.font.getGlyphOrder():
                a, b = self.glyf[name], built["glyf"][name]
                self.assertEqual(
                    (list(a.coordinates), list(a.endPtsOfContours))
                    if a.numberOfContours else None,
                    (list(b.coordinates), list(b.endPtsOfContours))
                    if b.numberOfContours else None,
                    name)


if __name__ == "__main__":
    unittest.main()
