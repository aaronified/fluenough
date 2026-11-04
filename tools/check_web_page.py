#!/usr/bin/env python3
"""Check the branded web/ folder has what iOS needs to install the app.

Usage:
    python3 tools/check_web_page.py [web-folder]   # 0 ok, 1 something is missing

Run by .github/workflows/pages.yml right after tools/brand_web.py, on the
real output of flutter create, so a Flutter upgrade that changes its
template cannot silently drop the iOS tags (#1012). Prints every problem.
"""

import json
import re
import sys
from pathlib import Path

REQUIRED_METAS = (
    "apple-mobile-web-app-capable",
    "apple-mobile-web-app-title",
    "apple-mobile-web-app-status-bar-style",
    "mobile-web-app-capable",
)
REQUIRED_MANIFEST = ("id", "scope", "start_url", "lang")


def check(web: Path) -> list[str]:
    problems: list[str] = []
    page = (web / "index.html").read_text()
    manifest = json.loads((web / "manifest.json").read_text())

    views = re.findall(r'<meta\s+name="viewport"[^>]*>', page)
    if len(views) != 1 or "viewport-fit=cover" not in views[0]:
        problems.append(f"want exactly one viewport meta with viewport-fit=cover, found {views}")
    for name in REQUIRED_METAS:
        if len(re.findall(rf'<meta\s+name="{name}"', page)) != 1:
            problems.append(f"want exactly one <meta name=\"{name}\">")
    links = re.findall(r'<link\s+rel="apple-touch-icon"[^>]*>', page)
    if len(links) != 1:
        problems.append(f"want exactly one apple-touch-icon link, found {len(links)}")
    for href in re.findall(r'href="([^"]+)"', links[0] if links else ""):
        if not (web / href).is_file():
            problems.append(f"apple-touch-icon file {href} is not in {web}")
    for key in REQUIRED_MANIFEST:
        if not manifest.get(key):
            problems.append(f"manifest.json has no {key}")
    if manifest.get("display") != "standalone":
        problems.append("manifest.json display is not standalone")
    return problems


def main() -> int:
    web = Path(sys.argv[1] if len(sys.argv) > 1 else "web")
    problems = check(web)
    for p in problems:
        print(f"::error::iOS web check: {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
