#!/usr/bin/env python3
"""Check a built web/ folder contains the service worker and registers it.

Usage:
    python3 tools/check_web_sw.py [build/web]   # 0 ok, 1 something is missing

Run by .github/workflows/pages.yml after `flutter build web` (#1012). Flutter
3.47's own flutter_service_worker.js caches nothing and removes itself, so the
offline app shell depends on tools/web/sw.js reaching the build and on the
built flutter_bootstrap.js registering it, not Flutter's. Prints every
problem.
"""

import re
import sys
from pathlib import Path


def check(web: Path) -> list[str]:
    problems: list[str] = []
    sw = web / "sw.js"
    if not sw.is_file():
        problems.append(f"{sw} is missing: the service worker did not reach the build")
    elif "addEventListener('fetch'" not in sw.read_text():
        problems.append("sw.js has no fetch handler, so it caches nothing")

    index = web / "index.html"
    if not index.is_file():
        problems.append(f"{index} is missing")
    elif not re.search(r'<script[^>]+src="flutter_bootstrap\.js"', index.read_text()):
        problems.append("index.html does not load flutter_bootstrap.js, which registers sw.js")

    bootstrap = web / "flutter_bootstrap.js"
    if not bootstrap.is_file():
        problems.append(f"{bootstrap} is missing")
    else:
        text = bootstrap.read_text()
        if "serviceWorker.register('sw.js')" not in text:
            problems.append("flutter_bootstrap.js does not register sw.js")
        if not re.search(r"_flutter\.loader\.load\(\s*\)", text):
            problems.append(
                "flutter_bootstrap.js starts the app with service worker settings: "
                "Flutter's own worker would replace sw.js"
            )
        if "{{" in text:
            problems.append("flutter_bootstrap.js still holds an unfilled {{template}} tag")
    return problems


def main() -> int:
    web = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    problems = check(web)
    for p in problems:
        print(f"::error::service worker check: {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
