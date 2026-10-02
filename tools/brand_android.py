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
  plugin's own manifest declares neither.

It fails rather than quietly doing nothing when the manifest does not have
the one android:label it expects, as it would after a flutter create that
changed shape.

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
ARB = Path("lib/l10n/app_en.arb")

LABEL = re.compile(r'android:label="[^"]*"')
MANIFEST_OPEN = re.compile(r"<manifest\b[^>]*>")
RECORD_AUDIO = "android.permission.RECORD_AUDIO"
RECOGNITION_SERVICE = "android.speech.RecognitionService"


class BrandError(Exception):
    """Why the brand could not be applied."""


def app_name(root: Path) -> str:
    """The app's name, as the interface has it."""
    name = json.loads((root / ARB).read_text(encoding="utf-8")).get("appTitle")
    if not isinstance(name, str) or not name.strip():
        raise BrandError(f"{ARB} has no appTitle")
    return name


def declare(text: str) -> str:
    """[text], a manifest, with the microphone permission and the speech
    recogniser query added if they are not there already."""
    if len(MANIFEST_OPEN.findall(text)) != 1 or text.count("</manifest>") != 1:
        raise BrandError(
            f"{MANIFEST} does not have one <manifest> element; "
            "flutter create has changed what it writes"
        )
    if RECORD_AUDIO not in text:
        text = MANIFEST_OPEN.sub(
            lambda m: f'{m.group(0)}\n    <uses-permission android:name="{RECORD_AUDIO}"/>',
            text,
            count=1,
        )
    if RECOGNITION_SERVICE not in text:
        intent = (
            f'<intent>\n            <action android:name="{RECOGNITION_SERVICE}"/>'
            "\n        </intent>"
        )
        if "<queries>" in text:
            text = text.replace("<queries>", f"<queries>\n        {intent}", 1)
        else:
            text = text.replace(
                "</manifest>", f"    <queries>\n        {intent}\n    </queries>\n</manifest>", 1
            )
    return text


def apply(root: Path) -> str:
    """Copies the brand's resources into [root]'s android/ and sets the
    launcher label. Returns the label."""
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

    name = app_name(root)
    shutil.copytree(root / BRAND, root / RES, dirs_exist_ok=True)
    label = f'android:label="{escape(name, {chr(34): "&quot;"})}"'
    manifest.write_text(declare(LABEL.sub(lambda _: label, text)), encoding="utf-8")
    return name


def main() -> int:
    try:
        name = apply(ROOT)
    except BrandError as e:
        print(f"brand_android: {e}", file=sys.stderr)
        return 1
    print(f"Brand applied to {RES}; launcher label {name!r}; microphone and "
          "speech recogniser declared.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
