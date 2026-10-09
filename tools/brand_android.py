#!/usr/bin/env python3
"""Put the brand into the generated android/ folder.

Usage:
    python3 tools/brand_android.py        # after flutter create; 0 ok, 1 error

flutter create writes android/ with Flutter's launcher icon, a plain launch
screen and the project name, "fluenough", as the launcher label. android/ is
never committed (AGENTS.md rule 4), so this runs after every flutter create:
in CI, in the release workflow and on a first checkout. It

- copies fluenough-brand/android/ over android/app/src/main/res/: the
  launcher icon, and a launch screen in the app's own background, light or
  dark, with the mark;
- sets the launcher label to the app's name, `appTitle` in
  lib/l10n/app_en.arb, so the name has one source;
- declares what the app asks Android for: the microphone, for the speaking
  drill (ADR-0014), and a query for the speech recogniser, which Android 11
  and later hide from an app that does not declare one. The speech_to_text
  plugin's own manifest declares neither. Likewise a query for the
  text-to-speech engine: without it, Android 11 and later let the app find
  no voice to speak with, and flutter_tts's manifest does not declare one;
- declares the internet, for the update check (ADR-0017): flutter create
  grants it to debug and profile builds only, so a release build could not
  reach GitHub without it. And a query for apps that open https links,
  which url_launcher needs on Android 11 and later to find the browser;
- sets up ota_update, which installs updates (ADR-0017). Its own manifest
  asks to install packages but declares no FileProvider, which Android's
  installer needs to read the download, so this adds one, and the file
  naming the folder it shares. It asks for external storage too, which it
  no longer uses: the download goes to the app's own storage. So this
  removes both storage permissions from the merged manifest. And its build
  requires core library desugaring of the app, which this switches on in
  android/app/build.gradle.kts;
- gives MainActivity a platform channel, app.fluenough/system, whose
  openVoiceSettings opens Android's text-to-speech settings for Settings >
  Voices, or failing that the default engine's page for installing voice
  data, and says which opened. No plugin is needed for it, and a channel
  is no dependency (AGENTS.md rule 6). The manifest gets a query for each
  page, which Android 11 and later need before the app can see that one
  opens.

Each is added only if it is not there already, so running this twice is
the same as running it once.

It fails rather than quietly doing nothing when the manifest does not have
the one android:label and one <application> it expects, the Gradle file
not the one compileOptions block, or MainActivity.kt not the one
`class MainActivity : FlutterActivity()`, or a configureFlutterEngine of
its own, as it would after a flutter create that changed shape. Then it
changes nothing.

Requires only Python 3.11+, like the other tools.
"""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent

BRAND = Path("fluenough-brand/android")
RES = Path("android/app/src/main/res")
MANIFEST = Path("android/app/src/main/AndroidManifest.xml")
GRADLE = Path("android/app/build.gradle.kts")
ACTIVITY = Path("android/app/src/main/kotlin/app/fluenough/MainActivity.kt")
ARB = Path("lib/l10n/app_en.arb")

LABEL = re.compile(r'android:label="[^"]*"')
MANIFEST_OPEN = re.compile(r"<manifest\b[^>]*>")
PERMISSION = re.compile(r'<uses-permission\s[^>]*?android:name="([^"]+)"[^>]*>')
QUERIES = re.compile(r"<queries>.*?</queries>", re.S)
INTENT = re.compile(r"<intent>.*?</intent>", re.S)
RECORD_AUDIO = "android.permission.RECORD_AUDIO"
INTERNET = "android.permission.INTERNET"
RECOGNITION_SERVICE = "android.speech.RecognitionService"
TTS_SERVICE = "android.intent.action.TTS_SERVICE"
VIEW = "android.intent.action.VIEW"
# What MainActivity's openVoiceSettings opens: Android's text-to-speech
# settings, or an engine's page for installing voice data
# (TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA).
TTS_SETTINGS = "com.android.settings.TTS_SETTINGS"
INSTALL_TTS_DATA = "android.speech.tts.engine.INSTALL_TTS_DATA"
# ota_update asks to write external storage, and the merge then adds the
# read permission that implies. It has used neither since 7.0.1.
STORAGE = (
    "android.permission.WRITE_EXTERNAL_STORAGE",
    "android.permission.READ_EXTERNAL_STORAGE",
)
TOOLS = 'xmlns:tools="http://schemas.android.com/tools"'

# ota_update's FileProvider, under the authority it asks for by default, and
# the folder it shares: files/ota_update, where it downloads.
OTA_PROVIDER = "sk.fourq.otaupdate.OtaUpdateFileProvider"
OTA_PATHS = RES / "xml/ota_update_paths.xml"
PROVIDER = '''        <provider
            android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
            android:authorities="${applicationId}.ota_update_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/ota_update_paths"/>
        </provider>
'''
PATHS = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tools/brand_android.py: the folder ota_update downloads
     updates into, which Android's installer may read (ADR-0017). -->
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
'''

# MainActivity's platform channel, which lib/app/system_settings.dart calls.
CHANNEL = "app.fluenough/system"
ACTIVITY_CLASS = re.compile(r"class\s+MainActivity\s*:\s*FlutterActivity\(\)")
IMPORT = re.compile(r"^import\s+\S+[ \t]*$", re.M)
PACKAGE = re.compile(r"^package\s+\S+[ \t]*$", re.M)
KOTLIN_IMPORTS = (
    "android.content.ActivityNotFoundException",
    "android.content.Intent",
    "android.provider.Settings",
    "android.speech.tts.TextToSpeech",
    "io.flutter.embedding.android.FlutterActivity",
    "io.flutter.embedding.engine.FlutterEngine",
    "io.flutter.plugin.common.MethodChannel",
)
# What goes in MainActivity. openVoiceSettings answers with the name of the
# page that opened, which the Dart side reads as a VoiceSettingsPage:
# textToSpeech, installVoices or none.
CHANNEL_MEMBERS = """
    // Written by tools/brand_android.py: Settings > Voices opens the phone's
    // text-to-speech settings through this, from lib/app/system_settings.dart.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.fluenough/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openVoiceSettings" -> result.success(openVoiceSettings())
                    else -> result.notImplemented()
                }
            }
    }

    // Android's text-to-speech settings; failing that, the default engine's
    // page for installing voice data; failing that, any engine's. Answers
    // with the name of the one that opened, or "none".
    private fun openVoiceSettings(): String {
        if (startIfHandled(Intent("com.android.settings.TTS_SETTINGS"))) {
            return "textToSpeech"
        }
        val engine = defaultTtsEngine()
        if (engine != null &&
            startIfHandled(
                Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA).setPackage(engine)
            )
        ) {
            return "installVoices"
        }
        if (startIfHandled(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA))) {
            return "installVoices"
        }
        return "none"
    }

    // Starts intent if an activity on the phone handles it. False if none
    // does, or it would not start.
    private fun startIfHandled(intent: Intent): Boolean {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (intent.resolveActivity(packageManager) == null) return false
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    // The package of the phone's preferred text-to-speech engine, or null.
    private fun defaultTtsEngine(): String? =
        try {
            Settings.Secure.getString(contentResolver, Settings.Secure.TTS_DEFAULT_SYNTH)
                ?.takeIf { it.isNotBlank() }
        } catch (e: SecurityException) {
            null
        }
"""

# The version ota_update 7.1.0's own build uses.
DESUGAR_LIBS = "com.android.tools:desugar_jdk_libs:2.1.4"


class BrandError(Exception):
    """Why the brand could not be applied."""


def app_name(root: Path) -> str:
    """The app's name, as the interface has it."""
    name = json.loads((root / ARB).read_text(encoding="utf-8")).get("appTitle")
    if not isinstance(name, str) or not name.strip():
        raise BrandError(f"{ARB} has no appTitle")
    return name


def permit(text: str, permission: str) -> str:
    """[text], a manifest, with a <uses-permission> for [permission] after
    any it has already, unless it has that one."""
    found = list(PERMISSION.finditer(text))
    if any(m.group(1) == permission for m in found):
        return text
    at = found[-1].end() if found else MANIFEST_OPEN.search(text).end()
    line = f'\n    <uses-permission android:name="{permission}"/>'
    return text[:at] + line + text[at:]


def refuse(text: str, permission: str) -> str:
    """[text], a manifest, removing [permission], which a plugin asks for,
    from the manifest the build merges, unless it removes it already."""
    found = list(PERMISSION.finditer(text))
    if any(
        m.group(1) == permission and 'tools:node="remove"' in m.group(0)
        for m in found
    ):
        return text
    if TOOLS not in text:
        opening = MANIFEST_OPEN.search(text)
        text = (
            text[: opening.end() - 1].rstrip()
            + f" {TOOLS}"
            + text[opening.end() - 1 :]
        )
        found = list(PERMISSION.finditer(text))
    at = found[-1].end() if found else MANIFEST_OPEN.search(text).end()
    line = f'\n    <uses-permission android:name="{permission}" tools:node="remove"/>'
    return text[:at] + line + text[at:]


def provide(text: str) -> str:
    """[text], a manifest, with ota_update's FileProvider last in its
    <application>, unless it has it."""
    if OTA_PROVIDER in text:
        return text
    return text.replace("    </application>", f"{PROVIDER}    </application>", 1)


def desugar(text: str) -> str:
    """[text], the app's build.gradle.kts, with core library desugaring
    switched on and its library added, each unless it is there already."""
    if "isCoreLibraryDesugaringEnabled" not in text:
        text = text.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            1,
        )
    if "coreLibraryDesugaring(" not in text:
        text = (
            text.rstrip("\n")
            + f'\n\ndependencies {{\n    coreLibraryDesugaring("{DESUGAR_LIBS}")\n}}\n'
        )
    return text


def channel(text: str) -> str:
    """[text], MainActivity.kt, with the app.fluenough/system channel and
    the imports it needs, unless it has the channel already. Everything
    else in the file is kept."""
    if CHANNEL in text:
        return text
    if len(ACTIVITY_CLASS.findall(text)) != 1:
        raise BrandError(
            f"{ACTIVITY} does not have one "
            "`class MainActivity : FlutterActivity()`; "
            "flutter create has changed what it writes"
        )
    if "configureFlutterEngine" in text:
        raise BrandError(
            f"{ACTIVITY} has a configureFlutterEngine of its own; "
            f"add the {CHANNEL} channel to it by hand"
        )
    missing = [
        f"import {name}"
        for name in KOTLIN_IMPORTS
        if not re.search(rf"^import\s+{re.escape(name)}[ \t]*$", text, re.M)
    ]
    if missing:
        imports = list(IMPORT.finditer(text))
        lines = "".join(f"\n{line}" for line in missing)
        if imports:
            at = imports[-1].end()
        elif package := PACKAGE.search(text):
            at, lines = package.end(), "\n" + lines
        else:
            at, lines = 0, lines.lstrip("\n") + "\n\n"
        text = text[:at] + lines + text[at:]
    found = ACTIVITY_CLASS.search(text)
    rest = text[found.end() :]
    body = re.match(r"\s*\{", rest)
    if body:
        at = found.end() + body.end()
        return text[:at] + CHANNEL_MEMBERS + text[at:]
    if not re.match(r"[ \t]*(\n|$)", rest):
        raise BrandError(
            f"{ACTIVITY} declares MainActivity in a shape this does not know; "
            "flutter create has changed what it writes"
        )
    return text[: found.end()] + " {" + CHANNEL_MEMBERS + "}" + rest


def queries(text: str, action: str, scheme: str | None = None) -> bool:
    """Whether [text]'s <queries> has an intent for [action], and, if
    [scheme] is given, for data in that scheme."""
    return any(
        f'android:name="{action}"' in intent
        and (scheme is None or f'android:scheme="{scheme}"' in intent)
        for block in QUERIES.findall(text)
        for intent in INTENT.findall(block)
    )


def query(text: str, *lines: str) -> str:
    """[text] with an <intent> of [lines] first in its <queries>, which is
    added if it has none."""
    body = "".join(f"\n            {line}" for line in lines)
    intent = f"<intent>{body}\n        </intent>"
    if "<queries>" in text:
        return text.replace("<queries>", f"<queries>\n        {intent}", 1)
    return text.replace(
        "</manifest>", f"    <queries>\n        {intent}\n    </queries>\n</manifest>", 1
    )


def declare(text: str) -> str:
    """[text], a manifest, with the microphone and internet permissions, the
    queries for the speech recogniser, the text-to-speech engine, its
    settings and its voice data, and for opening https links, and
    ota_update's FileProvider, each added if it is not there already, and
    external storage removed."""
    if len(MANIFEST_OPEN.findall(text)) != 1 or text.count("</manifest>") != 1:
        raise BrandError(
            f"{MANIFEST} does not have one <manifest> element; "
            "flutter create has changed what it writes"
        )
    if text.count("    </application>") != 1:
        raise BrandError(
            f"{MANIFEST} does not have one <application> element; "
            "flutter create has changed what it writes"
        )
    for permission in (RECORD_AUDIO, INTERNET):
        text = permit(text, permission)
    for permission in STORAGE:
        text = refuse(text, permission)
    text = provide(text)
    for action in (RECOGNITION_SERVICE, TTS_SERVICE, TTS_SETTINGS, INSTALL_TTS_DATA):
        if not queries(text, action):
            text = query(text, f'<action android:name="{action}"/>')
    if not queries(text, VIEW, scheme="https"):
        text = query(
            text,
            f'<action android:name="{VIEW}"/>',
            '<data android:scheme="https"/>',
        )
    return text


def apply(root: Path) -> str:
    """Copies the brand's resources into [root]'s android/, sets the
    launcher label, declares what the app needs, sets up ota_update and
    gives MainActivity its channel. Returns the label."""
    manifest = root / MANIFEST
    if not manifest.is_file():
        raise BrandError(f"{MANIFEST} is missing; run flutter create first")
    text = manifest.read_text(encoding="utf-8")
    found = LABEL.findall(text)
    if len(found) != 1:
        raise BrandError(
            f"{MANIFEST} has {len(found)} android:label attributes, expected 1; "
            "flutter create has changed what it writes"
        )
    gradle = root / GRADLE
    if not gradle.is_file():
        raise BrandError(f"{GRADLE} is missing; run flutter create first")
    build = gradle.read_text(encoding="utf-8")
    if (
        "isCoreLibraryDesugaringEnabled" not in build
        and build.count("compileOptions {") != 1
    ):
        raise BrandError(
            f"{GRADLE} does not have one compileOptions block; "
            "flutter create has changed what it writes"
        )

    activity = root / ACTIVITY
    if not activity.is_file():
        raise BrandError(f"{ACTIVITY} is missing; run flutter create first")
    kotlin = activity.read_text(encoding="utf-8")
    channelled = channel(kotlin)

    name = app_name(root)
    label = f'android:label="{escape(name, {chr(34): "&quot;"})}"'
    # Everything is worked out before anything is written.
    declared = declare(LABEL.sub(lambda _: label, text))
    shutil.copytree(root / BRAND, root / RES, dirs_exist_ok=True)
    (root / OTA_PATHS).parent.mkdir(parents=True, exist_ok=True)
    (root / OTA_PATHS).write_text(PATHS, encoding="utf-8")
    manifest.write_text(declared, encoding="utf-8")
    gradle.write_text(desugar(build), encoding="utf-8")
    if channelled != kotlin:
        activity.write_text(channelled, encoding="utf-8")
    return name


def main() -> int:
    try:
        name = apply(ROOT)
    except BrandError as e:
        print(f"brand_android: {e}", file=sys.stderr)
        return 1
    print(f"Brand applied to {RES}; launcher label {name!r}; microphone, "
          "internet, speech recogniser, text-to-speech settings and https links "
          "declared; ota_update set up; MainActivity's channel written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
