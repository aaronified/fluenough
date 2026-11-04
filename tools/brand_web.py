#!/usr/bin/env python3
"""Put the brand into the generated web/ folder.

Usage:
    python3 tools/brand_web.py        # after flutter create; 0 ok, 1 error

flutter create writes web/ with Flutter's name, colours and description.
web/ is never committed (AGENTS.md rule 4), so this runs after every flutter
create for the Pages build (.github/workflows/pages.yml). It sets the name,
which has one source, `appTitle` in lib/l10n/app_en.arb, and the colours and
description in the manifest and the page, and copies fluenough-brand/web/
over web/: the favicon and the manifest's icons, rendered from
fluenough-app-icon.svg (the maskable ones are the same square, whose mark
sits inside the safe zone).
"""

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SW_SOURCE = ROOT / "tools/web"
DESCRIPTION = "Learn the basics of a new language with drills that come back just before you'd forget them."
THEME = "#2A6C4A"
BACKGROUND = "#F6FBF4"


def brand_service_worker(web: Path, source: Path = SW_SOURCE) -> None:
    """Add the hand-written service worker to web/ (#1012).

    Flutter 3.47's own flutter_service_worker.js unregisters itself and caches
    nothing, so sw.js (tools/web/sw.js) is copied beside the page, and
    flutter_bootstrap.js is written without Flutter's service worker settings
    (Flutter's worker would replace ours at the same scope) but with
    tools/web/register_sw.js, which registers sw.js. The {{...}} lines are
    Flutter's bootstrap template, filled in at build time.
    """
    shutil.copyfile(source / "sw.js", web / "sw.js")
    (web / "flutter_bootstrap.js").write_text(
        "{{flutter_js}}\n{{flutter_build_config}}\n"
        + (source / "register_sw.js").read_text()
        + "\n_flutter.loader.load();\n"
    )


def main() -> int:
    name = json.loads((ROOT / "lib/l10n/app_en.arb").read_text())["appTitle"]
    shutil.copytree(ROOT / "fluenough-brand/web", ROOT / "web", dirs_exist_ok=True)
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
    brand_service_worker(ROOT / "web")
    return 0


if __name__ == "__main__":
    sys.exit(main())
