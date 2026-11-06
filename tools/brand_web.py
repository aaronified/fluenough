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

It also makes the page installable on an iPhone's home screen (#1012, wiki:
Plan-Web-Pwa): the apple-touch-icon, the standalone-mode and theme-colour
tags, the viewport with `viewport-fit=cover`, a few lines of CSS that stop
iOS Safari's double-tap zoom, rubber-band scroll and text inflation, and a
manifest whose `id`, `scope` and `start_url` are relative, so they follow
whatever `--base-href` the build uses (/fluenough/ on GitHub Pages).
tools/test_brand_web.py asserts all of it, so it cannot silently regress.

Last it adds the offline service worker (brand_service_worker, below).
"""

import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SW_SOURCE = ROOT / "tools/web"
DESCRIPTION = "Learn the basics of a new language with drills that come back just before you'd forget them."
THEME = "#2A6C4A"
BACKGROUND = "#F6FBF4"
# The app's dark background (the launch screen's, fluenough-brand/android).
BACKGROUND_DARK = "#0F1511"
LANG = "en"

# Tags this script owns in <head>: any the template already has are removed
# first, so running it twice, or on a template that gains one, gives one.
_OWNED = re.compile(
    r"[ \t]*<(?:meta\s+name=\"(?:viewport|theme-color|mobile-web-app-capable"
    r"|apple-mobile-web-app-capable|apple-mobile-web-app-title"
    r"|apple-mobile-web-app-status-bar-style|format-detection)\""
    r"|link\s+rel=\"apple-touch-icon\")[^>]*>[ \t]*\n?"
)
_MARK = "<!-- brand_web.py: iOS home screen, viewport -->"

# iOS Safari: `touch-action: manipulation` ends double-tap zoom and the old
# 300ms click delay; `overscroll-behavior: none` ends the rubber band;
# `text-size-adjust: none` stops it inflating text; 100dvh is the visible
# height as the address bar comes and goes (100vh is the tallest it gets).
# The page's own background shows before Flutter paints, and behind the
# frame's edges, in the app's two themes.
_STYLE = f"""<style>
    html, body {{
      margin: 0;
      height: 100%;
      height: 100dvh;
      overflow: hidden;
      overscroll-behavior: none;
      touch-action: manipulation;
      -webkit-text-size-adjust: none;
      text-size-adjust: none;
      -webkit-tap-highlight-color: transparent;
      background: {BACKGROUND};
    }}
    @media (prefers-color-scheme: dark) {{
      html, body {{ background: {BACKGROUND_DARK}; }}
    }}
  </style>"""


def head_tags(name: str) -> str:
    """The tags for <head>, in the order they are written."""
    return "\n".join(
        f"  {line}"
        for line in (
            _MARK,
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">',
            '<meta name="mobile-web-app-capable" content="yes">',
            '<meta name="apple-mobile-web-app-capable" content="yes">',
            f'<meta name="apple-mobile-web-app-title" content="{name}">',
            '<meta name="apple-mobile-web-app-status-bar-style" content="default">',
            '<meta name="format-detection" content="telephone=no">',
            f'<meta name="theme-color" content="{BACKGROUND}" media="(prefers-color-scheme: light)">',
            f'<meta name="theme-color" content="{BACKGROUND_DARK}" media="(prefers-color-scheme: dark)">',
            '<link rel="apple-touch-icon" sizes="180x180" href="icons/apple-touch-icon.png">',
            _STYLE,
        )
    )


def brand_page(page: str, name: str) -> str:
    """Flutter's index.html, branded and made installable on iOS."""
    page = page.replace('content="A new Flutter project."', f'content="{DESCRIPTION}"')
    page = re.sub(r"[ \t]*" + re.escape(_MARK) + r".*?</style>\n?", "", page, flags=re.S)
    page = _OWNED.sub("", page)
    page = re.sub(r"<title>.*?</title>", f"<title>{name}</title>", page)
    if "</head>" not in page:
        raise ValueError("index.html has no </head>")
    return page.replace("</head>", head_tags(name) + "\n</head>", 1)


def brand_manifest(manifest: dict, name: str) -> dict:
    """Flutter's manifest.json, branded. `id`, `scope` and `start_url` are
    relative to the manifest, so they are the base href's folder."""
    manifest.update(
        id="./",
        name=name,
        short_name=name,
        description=DESCRIPTION,
        lang=LANG,
        start_url="./",
        scope="./",
        display="standalone",
        theme_color=THEME,
        background_color=BACKGROUND,
    )
    return manifest


def brand_service_worker(web: Path, source: Path = SW_SOURCE) -> None:
    """Add the hand-written service worker to web/ (#1012).

    Flutter 3.47's own flutter_service_worker.js unregisters itself and caches
    nothing, so sw.js (tools/web/sw.js) is copied beside the page, and
    flutter_bootstrap.js is written without Flutter's service worker settings
    (Flutter's worker would replace ours at the same scope) but with
    tools/web/register_sw.js, which registers sw.js and holds the browser's
    install prompt for the app. The {{...}} lines are Flutter's bootstrap
    template, filled in at build time.
    """
    shutil.copyfile(source / "sw.js", web / "sw.js")
    (web / "flutter_bootstrap.js").write_text(
        "{{flutter_js}}\n{{flutter_build_config}}\n"
        + (source / "register_sw.js").read_text()
        + "\n_flutter.loader.load();\n"
    )


def brand(root: Path) -> None:
    """Brands `root`/web, which flutter create wrote, from `root`'s brand."""
    name = json.loads((root / "lib/l10n/app_en.arb").read_text())["appTitle"]
    shutil.copytree(root / "fluenough-brand/web", root / "web", dirs_exist_ok=True)
    manifest_path = root / "web/manifest.json"
    manifest = brand_manifest(json.loads(manifest_path.read_text()), name)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

    page_path = root / "web/index.html"
    page_path.write_text(brand_page(page_path.read_text(), name))
    brand_service_worker(root / "web")


def main() -> int:
    brand(ROOT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
