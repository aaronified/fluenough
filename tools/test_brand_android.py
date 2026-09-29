#!/usr/bin/env python3
"""Tests for brand_android.py, and for the brand's Android resources.

Nothing here has an Android SDK, so the resources are checked the way aapt
would first fail on them: every file must be well-formed XML, and every
@color, @drawable and @mipmap it names must be one the brand defines or
flutter create writes.
"""

from __future__ import annotations

import json
import re
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

import brand_android

REPO = Path(__file__).resolve().parent.parent
BRAND = REPO / brand_android.BRAND

# A manifest shaped like the one flutter create writes, cut down.
MANIFEST = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="fluenough"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity android:name=".MainActivity" android:theme="@style/LaunchTheme"/>
    </application>
</manifest>
"""

# What flutter create puts in res/ that the brand replaces or relies on.
GENERATED = {
    "drawable/launch_background.xml": "<layer-list/>",
    "drawable-v21/launch_background.xml": "<layer-list/>",
    "mipmap-mdpi/ic_launcher.png": "flutter",
    "values/styles.xml": "<resources/>",
    "values-night/styles.xml": "<resources/>",
}


class ApplyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        shutil.copytree(BRAND, self.root / brand_android.BRAND)
        arb = self.root / brand_android.ARB
        arb.parent.mkdir(parents=True)
        arb.write_text(json.dumps({"appTitle": "Fluenough"}), encoding="utf-8")
        res = self.root / brand_android.RES
        for path, text in GENERATED.items():
            (res / path).parent.mkdir(parents=True, exist_ok=True)
            (res / path).write_text(text, encoding="utf-8")
        self.manifest = self.root / brand_android.MANIFEST
        self.manifest.write_text(MANIFEST, encoding="utf-8")

    def test_the_label_is_the_app_title(self) -> None:
        self.assertEqual(brand_android.apply(self.root), "Fluenough")
        text = self.manifest.read_text(encoding="utf-8")
        self.assertIn('android:label="Fluenough"', text)
        self.assertNotIn('android:label="fluenough"', text)
        self.assertIn('android:icon="@mipmap/ic_launcher"', text)

    def test_the_brand_replaces_what_flutter_create_wrote(self) -> None:
        brand_android.apply(self.root)
        res = self.root / brand_android.RES
        for source in BRAND.rglob("*"):
            if source.is_file():
                copied = res / source.relative_to(BRAND)
                self.assertEqual(copied.read_bytes(), source.read_bytes(), copied)
        # Left alone: files the brand does not have.
        self.assertEqual(
            (res / "values/styles.xml").read_text(encoding="utf-8"), "<resources/>"
        )

    def test_running_twice_is_the_same_as_once(self) -> None:
        brand_android.apply(self.root)
        once = self.manifest.read_text(encoding="utf-8")
        brand_android.apply(self.root)
        self.assertEqual(self.manifest.read_text(encoding="utf-8"), once)

    def test_a_name_is_escaped_for_xml(self) -> None:
        (self.root / brand_android.ARB).write_text(
            json.dumps({"appTitle": 'A & "B"'}), encoding="utf-8"
        )
        brand_android.apply(self.root)
        self.assertIn(
            'android:label="A &amp; &quot;B&quot;"',
            self.manifest.read_text(encoding="utf-8"),
        )

    def test_no_android_folder_is_an_error(self) -> None:
        self.manifest.unlink()
        with self.assertRaisesRegex(brand_android.BrandError, "flutter create"):
            brand_android.apply(self.root)

    def test_a_manifest_of_another_shape_is_an_error_and_nothing_changes(
        self,
    ) -> None:
        self.manifest.write_text(
            MANIFEST.replace(
                "<activity", '<activity android:label="Other"'
            ),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(brand_android.BrandError, "2 android:label"):
            brand_android.apply(self.root)
        png = self.root / brand_android.RES / "mipmap-mdpi/ic_launcher.png"
        self.assertEqual(png.read_text(encoding="utf-8"), "flutter")


class ResourcesTest(unittest.TestCase):
    """The brand's resources, as aapt would first check them."""

    REFERENCE = re.compile(r"@(color|drawable|mipmap)/([a-z0-9_]+)")

    def xml_files(self) -> list[Path]:
        return sorted(BRAND.rglob("*.xml"))

    def defined(self) -> dict[str, set[str]]:
        names: dict[str, set[str]] = {"color": set(), "drawable": set(), "mipmap": set()}
        for path in BRAND.rglob("*"):
            if not path.is_file():
                continue
            kind = path.parent.name.split("-")[0]
            if kind in ("drawable", "mipmap"):
                names[kind].add(path.stem)
            elif kind == "values":
                for color in ET.parse(path).getroot().iter("color"):
                    names["color"].add(color.attrib["name"])
        return names

    def test_every_file_is_well_formed(self) -> None:
        self.assertTrue(self.xml_files())
        for path in self.xml_files():
            with self.subTest(path=path.relative_to(BRAND)):
                ET.parse(path)

    def test_every_reference_resolves(self) -> None:
        defined = self.defined()
        for path in self.xml_files():
            for kind, name in self.REFERENCE.findall(path.read_text(encoding="utf-8")):
                with self.subTest(path=path.relative_to(BRAND), ref=f"@{kind}/{name}"):
                    self.assertIn(name, defined[kind])

    def test_dark_mode_has_every_launch_colour(self) -> None:
        def colors(folder: str) -> dict[str, str]:
            root = ET.parse(BRAND / folder / "launch_colors.xml").getroot()
            return {c.attrib["name"]: c.text or "" for c in root.iter("color")}

        light, dark = colors("values"), colors("values-night")
        self.assertEqual(light.keys(), dark.keys())
        # A soft black, not true black.
        self.assertNotEqual(dark["launch_background"].upper(), "#000000")

    def test_the_launch_screen_is_themed_on_every_android(self) -> None:
        for folder in ("values-v31", "values-night-v31"):
            with self.subTest(folder=folder):
                root = ET.parse(BRAND / folder / "styles.xml").getroot()
                items = {
                    i.attrib["name"]: i.text
                    for style in root.iter("style")
                    if style.attrib["name"] == "LaunchTheme"
                    for i in style.iter("item")
                }
                self.assertEqual(
                    items["android:windowSplashScreenBackground"],
                    "@color/launch_background",
                )


if __name__ == "__main__":
    unittest.main()
