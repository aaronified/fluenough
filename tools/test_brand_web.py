#!/usr/bin/env python3
"""Tests for brand_web.py: what the branded web/ folder must carry for the
app to install on an iPhone's home screen and behave in standalone mode.

There is no Flutter SDK here, so a web/ folder shaped like the one
`flutter create` writes is made in a temporary copy of the repo's brand
files, branded, and read back.
"""

from __future__ import annotations

import json
import re
import shutil
import struct
import tempfile
import unittest
from pathlib import Path

import brand_web

REPO = Path(__file__).resolve().parent.parent

# index.html as flutter create writes it, cut down.
INDEX = """\
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="A new Flutter project.">
  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="fluenough">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png"/>
  <title>fluenough</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
"""

MANIFEST = {
    "name": "fluenough",
    "short_name": "fluenough",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#0175C2",
    "theme_color": "#0175C2",
    "description": "A new Flutter project.",
    "orientation": "portrait-primary",
    "prefer_related_applications": False,
    "icons": [
        {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"}
    ],
}


def tag(page: str, pattern: str) -> list[str]:
    return re.findall(pattern, page)


class BrandedPage(unittest.TestCase):
    def setUp(self):
        self.name = json.loads((REPO / "lib/l10n/app_en.arb").read_text())["appTitle"]
        self.page = brand_web.brand_page(INDEX, self.name)

    def test_installable_on_the_ios_home_screen(self):
        page = self.page
        for name in ("apple-mobile-web-app-capable", "mobile-web-app-capable"):
            self.assertEqual(
                tag(page, rf'<meta name="{name}" content="(\w+)"'), ["yes"], name
            )
        self.assertEqual(
            tag(page, r'<meta name="apple-mobile-web-app-title" content="([^"]+)"'),
            [self.name],
        )
        self.assertEqual(
            tag(page, r'<meta name="apple-mobile-web-app-status-bar-style" content="(\w+)"'),
            ["default"],
            "black-translucent would draw white status text on the light theme",
        )
        self.assertEqual(
            tag(page, r'<link rel="apple-touch-icon"[^>]*href="([^"]+)"'),
            ["icons/apple-touch-icon.png"],
            "one icon, relative to the base href, not Flutter's 192 one",
        )

    def test_theme_colour_follows_light_and_dark(self):
        got = dict(
            (media, colour)
            for colour, media in tag(
                self.page, r'<meta name="theme-color" content="(#\w+)" media="([^"]+)"'
            )
        )
        self.assertEqual(
            got,
            {
                "(prefers-color-scheme: light)": brand_web.BACKGROUND,
                "(prefers-color-scheme: dark)": brand_web.BACKGROUND_DARK,
            },
        )

    def test_viewport_covers_the_notch_and_does_not_zoom_the_layout(self):
        views = tag(self.page, r'<meta name="viewport" content="([^"]+)"')
        self.assertEqual(len(views), 1)
        self.assertIn("viewport-fit=cover", views[0])
        self.assertIn("width=device-width", views[0])

    def test_ios_touch_and_scroll_quirks_are_switched_off(self):
        css = re.search(r"<style>(.*?)</style>", self.page, re.S).group(1)
        for rule in (
            "touch-action: manipulation",
            "overscroll-behavior: none",
            "-webkit-text-size-adjust: none",
            "height: 100dvh",
        ):
            self.assertIn(rule, css)
        self.assertNotIn("vh;", css.replace("dvh;", ""), "100vh is too tall on iOS")

    def test_branding_stays_and_head_tags_are_not_doubled(self):
        page = self.page
        self.assertIn(f"<title>{self.name}</title>", page)
        self.assertIn(brand_web.DESCRIPTION, page)
        self.assertIn('<link rel="manifest" href="manifest.json">', page)
        self.assertIn('<base href="$FLUTTER_BASE_HREF">', page)
        self.assertEqual(page.count("</head>"), 1)

    def test_branding_twice_gives_the_same_page(self):
        self.assertEqual(brand_web.brand_page(self.page, self.name), self.page)

    def test_a_template_with_a_viewport_of_its_own_gets_just_ours(self):
        old = INDEX.replace(
            "<title>",
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n  <title>',
        )
        page = brand_web.brand_page(old, self.name)
        self.assertEqual(len(tag(page, r'<meta name="viewport"')), 1)
        self.assertIn("viewport-fit=cover", page)

    def test_a_page_without_a_head_is_an_error(self):
        with self.assertRaises(ValueError):
            brand_web.brand_page("<html></html>", self.name)


class BrandedManifest(unittest.TestCase):
    def setUp(self):
        self.manifest = brand_web.brand_manifest(json.loads(json.dumps(MANIFEST)), "Fluenough")

    def test_the_app_is_one_standalone_app_at_the_base_href(self):
        m = self.manifest
        self.assertEqual(m["display"], "standalone")
        # Relative, so they resolve against the manifest's own folder: the
        # base href's, /fluenough/ on GitHub Pages, "/" anywhere else.
        for key in ("id", "start_url", "scope"):
            self.assertEqual(m[key], "./", key)
        self.assertEqual(m["lang"], "en")

    def test_names_and_colours_are_the_brands(self):
        m = self.manifest
        self.assertEqual((m["name"], m["short_name"]), ("Fluenough", "Fluenough"))
        self.assertEqual(m["theme_color"], brand_web.THEME)
        self.assertEqual(m["background_color"], brand_web.BACKGROUND)
        self.assertEqual(m["description"], brand_web.DESCRIPTION)


class BrandedFolder(unittest.TestCase):
    """The whole script, on a copy of what it reads, and the icons it ships."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "lib/l10n").mkdir(parents=True)
        shutil.copy(REPO / "lib/l10n/app_en.arb", self.root / "lib/l10n/app_en.arb")
        shutil.copytree(REPO / "fluenough-brand/web", self.root / "fluenough-brand/web")
        web = self.root / "web"
        web.mkdir()
        (web / "index.html").write_text(INDEX)
        (web / "manifest.json").write_text(json.dumps(MANIFEST))
        brand_web.brand(self.root)

    def test_every_file_the_page_and_manifest_name_is_there(self):
        web = self.root / "web"
        page = (web / "index.html").read_text()
        manifest = json.loads((web / "manifest.json").read_text())
        named = [m for m in re.findall(r'(?:href|src)="(icons/[^"]+|favicon\.png)"', page)]
        named += [i["src"] for i in manifest["icons"]]
        self.assertIn("icons/apple-touch-icon.png", named)
        for path in named:
            self.assertTrue((web / path).is_file(), path)

    def test_the_192_512_and_maskable_icons_ship(self):
        for f in ("Icon-192.png", "Icon-512.png", "Icon-maskable-192.png", "Icon-maskable-512.png"):
            self.assertTrue((self.root / "web/icons" / f).is_file(), f)

    def test_apple_touch_icon_is_a_180_square_opaque_png(self):
        data = (self.root / "web/icons/apple-touch-icon.png").read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        width, height, depth, colour = struct.unpack(">IIBB", data[16:26])
        self.assertEqual((width, height), (180, 180))
        # Colour type 2 is RGB and 3 is a palette: neither has alpha. iOS
        # fills transparency with black.
        self.assertIn(colour, (2, 3))
        self.assertNotIn(b"tRNS", data)


if __name__ == "__main__":
    unittest.main()
