# DELETE THIS FILE BEFORE THE PR OPENS (work-in-progress status, owner 2026-11-04)

Branch feat/web-service-worker, off main 2895c65. Job J1 of #1012 (refs, do not close). Depends on: #1018 and #1019 (both unmerged when written). Nothing here touches their files except tools/brand_web.py (two small additions) and .github/workflows/pages.yml (one step).

## Done (committed, never run in a browser or in CI)
- tools/web/sw.js: network-first service worker, versioned cache `fluenough-shell-v1`, deletes older `fluenough-shell-*` caches on activate, same-origin GET only, skips Range, skips `decks/` paths and every cross-origin request (deck downloads are raw.githubusercontent.com, owned by #1018's IndexedDB store), 5 s wait before using a cached copy, offline navigation falls back to index.html, 'cache-loaded' message fills the cache on the first visit.
- tools/web/register_sw.js: registers `sw.js` (relative, so it follows the base href), posts loaded resource URLs to the worker after ready, first frame and load.
- tools/brand_web.py: `brand_service_worker(web)` copies sw.js and writes web/flutter_bootstrap.js (template tags + register_sw.js + `_flutter.loader.load();`), called at the end of main().
- tools/check_web_sw.py: asserts the built output has sw.js with a fetch handler, index.html loads flutter_bootstrap.js, the built bootstrap registers sw.js, starts with no serviceWorkerSettings, has no unfilled `{{`.
- pages.yml: runs the check after the drift files are fetched (before the upload).
- tools/test_web_service_worker.py: 10 tests, all passed locally (node 22 harness runs the real sw.js; skipped if node is missing).
- CHANGELOG line under [Unreleased].

## Evidence (Flutter 3.47.6 SDK read in a scratchpad, not built)
- packages/flutter_tools/lib/src/web/file_generators/js/flutter_service_worker.js is 31 lines: on install `skipWaiting`, on activate it UNREGISTERS itself and navigates every client. It caches nothing. So Flutter 3.47.6 has no offline shell (finding 3 of the check: confirmed absent).
- `--pwa-strategy` is deprecated (flutter/flutter#156910, warns). Default offlineFirst writes `serviceWorkerSettings` into the default flutter_bootstrap.js, so the page registers flutter_service_worker.js?v=<random>. That would REPLACE sw.js at the same scope, hence the custom flutter_bootstrap.js written by brand_web.py (no flag needed). The index template loads `flutter_bootstrap.js` (templates/app/web/index.html.tmpl line 44).
- flutter.js loadServiceWorker with no settings only registers Flutter's worker if a registration already exists AND settings are given; with `load()` and no args it returns at once.

## Could not verify
- A real `flutter build web` (templates substitution of my bootstrap, e.g. `{{flutter_build_config}}`), a browser run, the offline reload, iOS Safari behaviour, whether `flutter-first-frame` fires, SW scope on Pages (/fluenough/).
- Old visitors may have Flutter's stub registered; it unregisters itself, so sw.js takes over on the next visit.

## Next steps
1. After #1018/#1019 land: `git merge origin/main` (never rebase or force-push). Expect a conflict in tools/brand_web.py: #1019 turns main() into `brand(ROOT)`; call `brand_service_worker(root / "web")` at the end of `brand()` and keep ROOT/SW_SOURCE constants. #1019 also adds pages.yml steps and tools/check_web_page.py: place my step after the build, keep theirs.
2. Run `python3 -m unittest tools/test_web_service_worker.py` style (cd tools) once; CI runs the rest.
3. Optionally fold check_web_sw.py into check_web_page.py once it is on main.
4. Delete this file and WEB-JOBS-PENDING.md, open the PR to main (body ends with the Claude Code line and the session link), comment on #1012.
