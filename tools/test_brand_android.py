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
ANDROID = "{http://schemas.android.com/apk/res/android}"
NAME = f"{ANDROID}name"
SCHEME = f"{ANDROID}scheme"
NODE = "{http://schemas.android.com/tools}node"

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

# The app's Gradle file, cut down to what the script looks for: written for
# this test, in the shape flutter create's Kotlin DSL file has.
GRADLE = """\
plugins {
    id("com.android.application")
}

android {
    namespace = "app.fluenough"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

flutter {
    source = "../.."
}
"""


# MainActivity.kt as flutter create writes it for app.fluenough.
ACTIVITY = """\
package app.fluenough

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
"""


def granted(root: ET.Element) -> list[str]:
    """The permissions [root], a manifest, asks for, in order."""
    return [
        e.get(NAME) for e in root.findall("uses-permission") if e.get(NODE) != "remove"
    ]


def removed(root: ET.Element) -> list[str]:
    """The permissions [root] removes from what plugins ask for."""
    return [
        e.get(NAME) for e in root.findall("uses-permission") if e.get(NODE) == "remove"
    ]


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
        self.gradle = self.root / brand_android.GRADLE
        self.gradle.write_text(GRADLE, encoding="utf-8")
        self.activity = self.root / brand_android.ACTIVITY
        self.activity.parent.mkdir(parents=True)
        self.activity.write_text(ACTIVITY, encoding="utf-8")

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
        files = (
            self.manifest,
            self.gradle,
            self.root / brand_android.OTA_PATHS,
            self.activity,
        )
        once = [f.read_text(encoding="utf-8") for f in files]
        brand_android.apply(self.root)
        self.assertEqual([f.read_text(encoding="utf-8") for f in files], once)

    def test_a_name_is_escaped_for_xml(self) -> None:
        (self.root / brand_android.ARB).write_text(
            json.dumps({"appTitle": 'A & "B"'}), encoding="utf-8"
        )
        brand_android.apply(self.root)
        self.assertIn(
            'android:label="A &amp; &quot;B&quot;"',
            self.manifest.read_text(encoding="utf-8"),
        )

    def test_the_microphone_and_the_recogniser_are_declared(self) -> None:
        brand_android.apply(self.root)
        text = self.manifest.read_text(encoding="utf-8")
        root = ET.fromstring(text)
        self.assertEqual(
            granted(root),
            ["android.permission.RECORD_AUDIO", "android.permission.INTERNET"],
        )
        actions = [e.get(NAME) for e in root.findall("queries/intent/action")]
        self.assertIn("android.speech.RecognitionService", actions)

    def test_the_text_to_speech_engine_is_declared(self) -> None:
        # Android 11+ shows the app no TTS engine without the query, so
        # nothing is ever spoken.
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        actions = [e.get(NAME) for e in root.findall("queries/intent/action")]
        self.assertEqual(actions.count("android.intent.action.TTS_SERVICE"), 1)

    def test_the_internet_and_https_links_are_declared(self) -> None:
        # A release build has no internet unless the main manifest asks, and
        # url_launcher finds no browser on Android 11+ without the query.
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        self.assertIn("android.permission.INTERNET", granted(root))
        views = [
            intent
            for intent in root.findall("queries/intent")
            if [a.get(NAME) for a in intent.findall("action")]
            == ["android.intent.action.VIEW"]
        ]
        self.assertEqual(len(views), 1)
        self.assertEqual(
            [d.get(SCHEME) for d in views[0].findall("data")], ["https"]
        )

    def test_what_the_manifest_already_declares_is_not_added_again(self) -> None:
        # Written by hand, laid out differently from what the script writes.
        self.manifest.write_text(
            MANIFEST.replace(
                "<application",
                '<uses-permission android:name="android.permission.INTERNET" />\n'
                "    <application",
            ).replace(
                "</manifest>",
                "    <queries>\n"
                "        <intent><action android:name=\"android.intent.action.VIEW\" />"
                '<data android:scheme="https" /></intent>\n'
                "    </queries>\n</manifest>",
            ),
            encoding="utf-8",
        )
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            sorted(granted(root)),
            ["android.permission.INTERNET", "android.permission.RECORD_AUDIO"],
        )
        self.assertEqual(
            sorted(e.get(NAME) for e in root.findall("queries/intent/action")),
            [
                "android.intent.action.TTS_SERVICE",
                "android.intent.action.VIEW",
                "android.speech.RecognitionService",
                "android.speech.tts.engine.INSTALL_TTS_DATA",
                "com.android.settings.TTS_SETTINGS",
            ],
        )

    def test_a_view_query_for_another_scheme_does_not_count(self) -> None:
        self.manifest.write_text(
            MANIFEST.replace(
                "</manifest>",
                "    <queries>\n        <intent>\n"
                '            <action android:name="android.intent.action.VIEW"/>\n'
                '            <data android:scheme="geo"/>\n'
                "        </intent>\n    </queries>\n</manifest>",
            ),
            encoding="utf-8",
        )
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            sorted(d.get(SCHEME) for d in root.findall("queries/intent/data")),
            ["geo", "https"],
        )

    def test_an_existing_queries_block_keeps_what_it_had(self) -> None:
        self.manifest.write_text(
            MANIFEST.replace(
                "</manifest>",
                "    <queries>\n        <intent>\n"
                '            <action android:name="android.intent.action.PROCESS_TEXT"/>\n'
                "        </intent>\n    </queries>\n</manifest>",
            ),
            encoding="utf-8",
        )
        brand_android.apply(self.root)
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        self.assertEqual(len(root.findall("queries")), 1)
        self.assertEqual(
            sorted(e.get(NAME) for e in root.findall("queries/intent/action")),
            [
                "android.intent.action.PROCESS_TEXT",
                "android.intent.action.TTS_SERVICE",
                "android.intent.action.VIEW",
                "android.speech.RecognitionService",
                "android.speech.tts.engine.INSTALL_TTS_DATA",
                "com.android.settings.TTS_SETTINGS",
            ],
        )
        self.assertEqual(len(granted(root)), 2)

    def test_ota_update_gets_its_file_provider(self) -> None:
        # Android's installer reads the download through it; ota_update's
        # own manifest does not declare one.
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        providers = root.findall("application/provider")
        self.assertEqual(len(providers), 1)
        provider = providers[0]
        self.assertEqual(provider.get(NAME), "sk.fourq.otaupdate.OtaUpdateFileProvider")
        self.assertEqual(
            provider.get(f"{ANDROID}authorities"),
            "${applicationId}.ota_update_provider",
        )
        self.assertEqual(provider.get(f"{ANDROID}exported"), "false")
        self.assertEqual(provider.get(f"{ANDROID}grantUriPermissions"), "true")
        meta = provider.findall("meta-data")
        self.assertEqual(
            [(m.get(NAME), m.get(f"{ANDROID}resource")) for m in meta],
            [("android.support.FILE_PROVIDER_PATHS", "@xml/ota_update_paths")],
        )
        # The activity is still there, and the provider is beside it.
        self.assertEqual(len(root.findall("application/activity")), 1)

    def test_the_provider_shares_only_the_download_folder(self) -> None:
        brand_android.apply(self.root)
        paths = self.root / brand_android.OTA_PATHS
        self.assertEqual(
            paths.relative_to(self.root / brand_android.RES).as_posix(),
            "xml/ota_update_paths.xml",
        )
        root = ET.parse(paths).getroot()
        self.assertEqual(root.tag, "paths")
        # FileProvider reads these attributes without a namespace.
        shared = [(e.tag, e.get("name"), e.get("path")) for e in root]
        self.assertEqual(
            shared, [("files-path", "internal_apk_storage", "ota_update/")]
        )

    def test_external_storage_is_removed_from_the_merged_manifest(self) -> None:
        # ota_update asks to write it, which implies reading it, and has used
        # neither since 7.0.1: the download goes to the app's own storage.
        brand_android.apply(self.root)
        text = self.manifest.read_text(encoding="utf-8")
        self.assertEqual(text.count('xmlns:tools="http://schemas.android.com/tools"'), 1)
        root = ET.fromstring(text)
        self.assertEqual(
            removed(root),
            [
                "android.permission.WRITE_EXTERNAL_STORAGE",
                "android.permission.READ_EXTERNAL_STORAGE",
            ],
        )
        self.assertFalse([p for p in granted(root) if "STORAGE" in p])

    def test_core_library_desugaring_is_switched_on(self) -> None:
        # ota_update's build requires it of the app.
        brand_android.apply(self.root)
        text = self.gradle.read_text(encoding="utf-8")
        start = text.index("compileOptions {")
        options = text[start : text.index("}", start)]
        self.assertIn("isCoreLibraryDesugaringEnabled = true", options)
        self.assertEqual(text.count("isCoreLibraryDesugaringEnabled"), 1)
        self.assertIn(
            "dependencies {\n"
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
            "}",
            text,
        )
        self.assertIn("sourceCompatibility = JavaVersion.VERSION_17", text)

    def test_desugaring_already_on_is_left_alone(self) -> None:
        self.gradle.write_text(
            GRADLE.replace(
                "compileOptions {",
                "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            )
            + "dependencies {\n"
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n'
            "}\n",
            encoding="utf-8",
        )
        before = self.gradle.read_text(encoding="utf-8")
        brand_android.apply(self.root)
        self.assertEqual(self.gradle.read_text(encoding="utf-8"), before)

    def test_a_gradle_file_of_another_shape_is_an_error_and_nothing_changes(
        self,
    ) -> None:
        self.gradle.write_text(
            GRADLE.replace("compileOptions {", "java {"), encoding="utf-8"
        )
        with self.assertRaisesRegex(brand_android.BrandError, "compileOptions"):
            brand_android.apply(self.root)
        self.assertEqual(self.manifest.read_text(encoding="utf-8"), MANIFEST)
        png = self.root / brand_android.RES / "mipmap-mdpi/ic_launcher.png"
        self.assertEqual(png.read_text(encoding="utf-8"), "flutter")

    def test_no_gradle_file_is_an_error(self) -> None:
        self.gradle.unlink()
        with self.assertRaisesRegex(brand_android.BrandError, "flutter create"):
            brand_android.apply(self.root)

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

    def test_the_voice_settings_pages_are_queried(self) -> None:
        # Android 11+ resolves neither for the app without a query, and the
        # channel opens only what resolves.
        brand_android.apply(self.root)
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        actions = [e.get(NAME) for e in root.findall("queries/intent/action")]
        self.assertEqual(actions.count("com.android.settings.TTS_SETTINGS"), 1)
        self.assertEqual(
            actions.count("android.speech.tts.engine.INSTALL_TTS_DATA"), 1
        )
        self.assertEqual(len(root.findall("queries")), 1)

    # MainActivity's platform channel, for Settings > Voices. Nothing here
    # has an Android SDK, so the Kotlin is checked by shape, not compiled.

    def kotlin(self) -> str:
        return self.activity.read_text(encoding="utf-8")

    def test_activity_gets_the_channel_once(self) -> None:
        brand_android.apply(self.root)
        text = self.kotlin()
        self.assertTrue(text.startswith("package app.fluenough\n"))
        self.assertEqual(text.count('"app.fluenough/system"'), 1)
        self.assertEqual(text.count('"openVoiceSettings" ->'), 1)
        self.assertEqual(text.count("override fun configureFlutterEngine("), 1)
        self.assertIn("super.configureFlutterEngine(flutterEngine)", text)
        self.assertEqual(text.count("class MainActivity : FlutterActivity() {"), 1)
        self.assertEqual(text.count("{"), text.count("}"))
        self.assertEqual(text.count("("), text.count(")"))
        # Tries the settings, then the default engine's voice data, then
        # any engine's, each only if something handles it.
        order = [
            text.index('Intent("com.android.settings.TTS_SETTINGS")'),
            text.index("ACTION_INSTALL_TTS_DATA).setPackage(engine)"),
            text.rindex("Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA))"),
        ]
        self.assertEqual(order, sorted(order))
        self.assertIn("intent.resolveActivity(packageManager) == null", text)
        self.assertIn("Intent.FLAG_ACTIVITY_NEW_TASK", text)
        for page in ('"textToSpeech"', '"installVoices"', '"none"'):
            self.assertIn(f"return {page}", text)

    def test_activity_imports_what_it_uses_once_each(self) -> None:
        brand_android.apply(self.root)
        text = self.kotlin()
        imports = re.findall(r"^import (\S+)$", text, re.M)
        self.assertEqual(sorted(imports), sorted(brand_android.KOTLIN_IMPORTS))
        # Imports come before the class.
        self.assertLess(
            text.rindex("\nimport "), text.index("class MainActivity")
        )
        for name in brand_android.KOTLIN_IMPORTS:
            used = name.rsplit(".", 1)[1]
            self.assertGreater(text.count(used), 1, used)

    def test_activity_written_once_is_left_alone(self) -> None:
        brand_android.apply(self.root)
        once = self.kotlin()
        self.assertEqual(brand_android.channel(once), once)
        brand_android.apply(self.root)
        self.assertEqual(self.kotlin(), once)

    def test_activity_keeps_what_it_had(self) -> None:
        self.activity.write_text(
            "package app.fluenough\n\n"
            "import android.os.Bundle\n"
            "import android.content.Intent\n"
            "import io.flutter.embedding.android.FlutterActivity\n\n"
            "// Someone's own.\n"
            "class MainActivity : FlutterActivity() {\n"
            "    private val mine = 1\n"
            "}\n",
            encoding="utf-8",
        )
        brand_android.apply(self.root)
        text = self.kotlin()
        self.assertIn("import android.os.Bundle\n", text)
        self.assertEqual(text.count("import android.content.Intent\n"), 1)
        self.assertIn("// Someone's own.\nclass MainActivity", text)
        self.assertIn("    private val mine = 1\n}\n", text)
        self.assertEqual(text.count('"app.fluenough/system"'), 1)
        self.assertEqual(text.count("{"), text.count("}"))
        once = text
        brand_android.apply(self.root)
        self.assertEqual(self.kotlin(), once)

    def test_activity_with_its_own_engine_setup_is_an_error_and_nothing_changes(
        self,
    ) -> None:
        own = ACTIVITY.replace(
            "FlutterActivity()",
            "FlutterActivity() {\n"
            "    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {\n"
            "        super.configureFlutterEngine(flutterEngine)\n"
            "    }\n"
            "}",
        )
        self.activity.write_text(own, encoding="utf-8")
        with self.assertRaisesRegex(brand_android.BrandError, "configureFlutterEngine"):
            brand_android.apply(self.root)
        self.assertEqual(self.kotlin(), own)
        self.assertEqual(self.manifest.read_text(encoding="utf-8"), MANIFEST)

    def test_activity_of_another_shape_is_an_error(self) -> None:
        for text in (
            ACTIVITY.replace("FlutterActivity()", "FlutterFragmentActivity()"),
            ACTIVITY.replace("FlutterActivity()", "FlutterActivity(), Other"),
        ):
            with self.subTest(text=text):
                self.activity.write_text(text, encoding="utf-8")
                with self.assertRaisesRegex(
                    brand_android.BrandError, "flutter create"
                ):
                    brand_android.apply(self.root)
                self.assertEqual(self.kotlin(), text)
                self.assertEqual(
                    self.manifest.read_text(encoding="utf-8"), MANIFEST
                )

    def test_activity_missing_is_an_error(self) -> None:
        self.activity.unlink()
        with self.assertRaisesRegex(brand_android.BrandError, "MainActivity.kt"):
            brand_android.apply(self.root)


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
