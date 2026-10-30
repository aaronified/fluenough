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


    def _running_twice_is_the_same_as_once(self) -> None:
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


    def _the_microphone_and_the_recogniser_are_declared(self) -> None:
        brand_android.apply(self.root)
        text = self.manifest.read_text(encoding="utf-8")
        root = ET.fromstring(text)
        self.assertEqual(
            granted(root),
            [
                "android.permission.RECORD_AUDIO",
                "android.permission.INTERNET",
                "android.permission.POST_NOTIFICATIONS",
                "android.permission.RECEIVE_BOOT_COMPLETED",
            ],
        )
        actions = [e.get(NAME) for e in root.findall("queries/intent/action")]
        self.assertIn("android.speech.RecognitionService", actions)

    def _the_reminder_can_be_shown_and_survives_a_reboot(self) -> None:
        # The plugin's own manifest has POST_NOTIFICATIONS but not the boot
        # permission or the receivers: without them a scheduled reminder
        # never shows, or is lost at a reboot (#90). And inexact scheduling
        # means no exact-alarm permission.
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        permissions = granted(root)
        self.assertIn("android.permission.POST_NOTIFICATIONS", permissions)
        self.assertIn("android.permission.RECEIVE_BOOT_COMPLETED", permissions)
        for exact in ("SCHEDULE_EXACT_ALARM", "USE_EXACT_ALARM"):
            self.assertNotIn(f"android.permission.{exact}", permissions)
        receivers = {
            e.get(NAME): e for e in root.findall("application/receiver")
        }
        plugin = "com.dexterous.flutterlocalnotifications."
        self.assertEqual(
            sorted(receivers),
            [
                plugin + "ScheduledNotificationBootReceiver",
                plugin + "ScheduledNotificationReceiver",
            ],
        )
        for receiver in receivers.values():
            self.assertEqual(
                receiver.get(f"{ANDROID}exported"), "false", "never exported"
            )
        boot = receivers[plugin + "ScheduledNotificationBootReceiver"]
        actions = [a.get(NAME) for a in boot.findall("intent-filter/action")]
        self.assertIn("android.intent.action.BOOT_COMPLETED", actions)
        self.assertIn("android.intent.action.MY_PACKAGE_REPLACED", actions)

    def _the_text_to_speech_engine_is_declared(self) -> None:
        # Android 11+ shows the app no TTS engine without the query, so
        # nothing is ever spoken.
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        actions = [e.get(NAME) for e in root.findall("queries/intent/action")]
        self.assertEqual(actions.count("android.intent.action.TTS_SERVICE"), 1)

    def _the_internet_and_https_links_are_declared(self) -> None:
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
        self.assertEqual(
            sorted(d.get(SCHEME) for v in views for d in v.findall("data")),
            ["https", "upi"],
        )


    def _a_gradle_file_of_another_shape_is_an_error_and_nothing_changes(
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


    def _a_manifest_of_another_shape_is_an_error_and_nothing_changes(
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


    # MainActivity's platform channel, for Settings > Voices. Nothing here
    # has an Android SDK, so the Kotlin is checked by shape, not compiled.

    def kotlin(self) -> str:
        return self.activity.read_text(encoding="utf-8")


    # Sharing a mail with files: a report's app log (ADR-0021), and later
    # the review files. Checked by shape, as nothing here can compile it.


    def _the_files_are_lent_through_the_apps_own_provider(self) -> None:
        brand_android.apply(self.root)
        brand_android.apply(self.root)
        root = ET.fromstring(self.manifest.read_text(encoding="utf-8"))
        shares = [
            p
            for p in root.findall("application/provider")
            if p.get(NAME) == "app.fluenough.ShareFileProvider"
        ]
        self.assertEqual(len(shares), 1)
        provider = shares[0]
        authority = provider.get(f"{ANDROID}authorities")
        self.assertEqual(authority, "${applicationId}.share")
        self.assertEqual(provider.get(f"{ANDROID}exported"), "false")
        self.assertEqual(provider.get(f"{ANDROID}grantUriPermissions"), "true")
        self.assertEqual(
            [
                (m.get(NAME), m.get(f"{ANDROID}resource"))
                for m in provider.findall("meta-data")
            ],
            [("android.support.FILE_PROVIDER_PATHS", "@xml/share_paths")],
        )
        # The activity asks for the same authority: the app's id, ".share".
        self.assertIn('"$packageName.share"', self.kotlin())
        # ota_update's is still there, beside it.
        self.assertEqual(len(root.findall("application/provider")), 2)


    def _a_kept_update_reopens_the_installer_through_the_ota_provider(self) -> None:
        # #487: Install after a cancelled install opens the same file again.
        brand_android.apply(self.root)
        self.assertIn(
            '"installApk" -> result.success(installApk(call))', self.kotlin()
        )
        self.assertIn('"$packageName.ota_update_provider"', self.kotlin())
        # An activity written before installApk gets it, once.
        self.activity.write_text(self.earlier_activity(), encoding="utf-8")
        brand_android.apply(self.root)
        brand_android.apply(self.root)
        self.assertEqual(self.kotlin().count("private fun installApk"), 1)

    def earlier_activity(self) -> str:
        """MainActivity as the version before shareFiles wrote it."""
        old_imports = [
            "android.content.ActivityNotFoundException",
            "android.content.Intent",
            "android.provider.Settings",
            "android.speech.tts.TextToSpeech",
            "io.flutter.embedding.android.FlutterActivity",
            "io.flutter.embedding.engine.FlutterEngine",
            "io.flutter.plugin.common.MethodChannel",
        ]
        return (
            "package app.fluenough\n\n"
            + "".join(f"import {name}\n" for name in old_imports)
            + "\nclass MainActivity : FlutterActivity() {"
            + brand_android.VOICE_MEMBERS
            + "}\n"
        )


    def test_running_twice_is_running_once_and_another_shape_changes_nothing(self) -> None:
        cases = (
            self._running_twice_is_the_same_as_once,
            self._a_manifest_of_another_shape_is_an_error_and_nothing_changes,
            self._a_gradle_file_of_another_shape_is_an_error_and_nothing_changes,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()

    def test_the_microphone_speech_internet_and_share_provider_are_declared(self) -> None:
        cases = (
            self._the_microphone_and_the_recogniser_are_declared,
            self._the_reminder_can_be_shown_and_survives_a_reboot,
            self._the_text_to_speech_engine_is_declared,
            self._the_internet_and_https_links_are_declared,
            self._the_files_are_lent_through_the_apps_own_provider,
            self._a_kept_update_reopens_the_installer_through_the_ota_provider,
        )
        for case in cases:
            with self.subTest(case.__name__.lstrip("_")):
                # Each case on a test of its own: its own setUp, cleanups.
                fresh = type(self)(case.__name__)
                fresh.setUp()
                try:
                    getattr(fresh, case.__name__)()
                finally:
                    fresh.doCleanups()


if __name__ == "__main__":
    unittest.main()
