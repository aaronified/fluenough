#!/usr/bin/env python3
"""Put the brand into the generated web/ folder.

Usage:
    python3 tools/brand_web.py        # after flutter create; 0 ok, 1 error

flutter create writes web/ with Flutter's name, colours and description.
web/ is never committed (AGENTS.md rule 4), so this runs after every flutter
create for the Pages build (.github/workflows/pages.yml). It sets the name,
which has one source, `appTitle` in lib/l10n/app_en.arb, and the colours and
description in the manifest and the page. The icons are Flutter's own until
the brand's are sized for the web.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESCRIPTION = "Learn the basics of a new language with drills that come back just before you'd forget them."
THEME = "#2A6C4A"
BACKGROUND = "#F6FBF4"


def main() -> int:
    name = json.loads((ROOT / "lib/l10n/app_en.arb").read_text())["appTitle"]
    manifest_path = ROOT / "web/manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest.update(
        name=name,
        short_name=name,
        description=DESCRIPTION,
        theme_color=THEME,
        background_color=BACKGROUND,
    )
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

    page_path = ROOT / "web/index.html"
    page = page_path.read_text()
    page = page.replace('content="A new Flutter project."', f'content="{DESCRIPTION}"')
    page = page.replace('name="apple-mobile-web-app-title" content="fluenough"',
                        f'name="apple-mobile-web-app-title" content="{name}"')
    page = page.replace("<title>fluenough</title>", f"<title>{name}</title>")
    page_path.write_text(page)
    return 0


if __name__ == "__main__":
    sys.exit(main())
