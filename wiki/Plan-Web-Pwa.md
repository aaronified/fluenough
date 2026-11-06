# Plan: Fluenough on the web, as a PWA on GitHub Pages

Source of truth: this wiki page.


For next week (2026-10-04).

## What the owner asked

> For next week, also add a plan for a github pages PWA with webstorage to
> save sessions in cache, this will be useful to get ios people to check it
> out.

There is no iOS build. A web build that installs as an app, a PWA, lets
iPhone users try Fluenough from Safari, with progress kept on the phone.

## What it takes

1. **Build and publish.**
   - A workflow, `.github/workflows/pages.yml`, runs on every push to
     `main`: `flutter create . --platforms=web` (as CI already does for
     Android), then `flutter build web --release --base-href /fluenough/`.
   - It publishes `build/web` to GitHub Pages, at
     `https://aaronified.github.io/fluenough/`.
   - `web/` is generated like `android/`, so it is not committed (AGENTS.md
     rule 4). A `tools/brand_web.py` sets the manifest's name, colours and
     icons, as `tools/brand_android.py` does for Android.
2. **Installable (the PWA part).**
   - `web/manifest.json`: name, short name, `display: standalone`, theme
     colour, and icons at 192 and 512 px, with a maskable one.
   - Offline (built, #1038): Flutter 3.47's generated service worker caches
     nothing and unregisters itself, so `tools/brand_web.py` writes
     `flutter_bootstrap.js` without Flutter's service worker settings and the
     app ships its own worker, `tools/web/sw.js`. It is network-first with
     the cache as fallback and a 5 s wait, revalidates each fetch, and keeps
     a versioned cache (old caches are deleted on activate). It never touches
     `decks/` or cross-origin requests, and only caches ok basic responses; a
     failing cache write still serves the response. `tools/check_web_sw.py`
     runs in `pages.yml` after the build and fails if Flutter's worker stops
     being a stub.
   - Install hint (built, #1038): a card on Today, web only. On iPhone and
     iPad it says how to add the app from Safari; in Chrome an Install button
     uses `beforeinstallprompt`. "Got it" hides it for good, "Later" for 7
     days, and it is hidden once the app is installed. Its state is kept in
     `localStorage`.
   - iOS installs it from Safari's Share menu, "Add to Home Screen".
3. **Sessions saved in the browser's storage.**
   - Progress is a drift database (ADR-0005). drift runs on the web on
     SQLite compiled to WebAssembly, stored in the browser's origin-private
     file system where there is one, and in IndexedDB where not.
   - `drift_flutter` takes `DriftWebOptions` naming `sqlite3.wasm` and
     `drift_worker.js`, which the workflow copies into `web/`.
   - The review log, settings and profiles then persist like on Android.
   - Settings stored outside drift need the same check.
4. **What the web cannot do, and what to do instead.**

   | Feature | On the web |
   |---|---|
   | Speech | `flutter_tts` uses the browser's Web Speech API, which Safari has. Its voices differ from Android's, so the Voices page must show what the browser offers. |
   | Speaking drill | Built, #1039: `WebSpeechEngine` runs over the browser's Web Speech API. It is online-only, and it asks the learner before audio leaves the device (also in Find my level and placement). Chrome, Edge and Safari have a recogniser, partly in Safari; Firefox has none, so Say is not tested there and the drill says so. |
   | Phone volume | `flutter_volume_controller` has no web support, and its code reads `dart:io`'s `Platform`, which throws on the web. `SystemVolumeMonitor` must not start on the web (`kIsWeb`). The sound check runs on the web (#1039). |
   | Reminders | Hidden on the web through `FeatureRegistry.web()` (#1039). |
   | Updates | The OTA update check and installer are Android-only, so the Updates and What's new rows are hidden on the web (`FeatureRegistry.web()`, #1039). The service worker brings the new version. |
   | Deck import and log export | `file_picker` works on the web: downloads and uploads instead of the file system. |
   | Bug reports | Reports open by `mailto:` in the learner's mail app (#1039). Screenshots in reports need checking. |

5. **Storage that lasts on iOS.**
   - Safari may clear a website's storage after seven days without a visit,
     unless the site is added to the Home Screen. The app should ask for
     persistent storage (`navigator.storage.persist()`) where the browser
     allows it, and suggest installing it.
   - It should also point to Settings > Export log as the backup.
   - Built (#1038): a Storage group at the top of Your data, web only. It
     shows whether the browser keeps the progress (`navigator.storage.persisted()`),
     offers a button to ask for it (`navigator.storage.persist()`), and warns
     that clearing the site's data deletes progress.
6. **Checks.**
   - Built (#1039): the Playwright smoke test job "Web: smoke test" in
     `pages.yml` opens the built app in headless Chromium (`tools/web_smoke.cjs`),
     on ubuntu-24.04 with Playwright 1.56.1, because Playwright's Chromium does
     not yet support ubuntu-latest. It skips deck- and doc-only changes. It is
     not a required check.

## Known gaps (2026-11-06)

- Private and local decks added from a file are kept in memory only on the
  web, so they are lost on reload. They need their own storage; this matters
  for [Plan-Private-Languages](Plan-Private-Languages) (0.9.0).
- `flutter_tts`'s web plugin ignores a second `speak()` while one plays.
- Untested on web: real Safari, Firefox and physical microphones; file import
  and export; deep links; share; haptics.
- GitHub Pages caches for up to 10 minutes, so a new build can take that long
  to reach a visitor.

## To decide

- The URL: the default `aaronified.github.io/fluenough/` or a custom domain.
- (Settled by ADR-0037: it downloads decks like the app.) Whether the web build carries every language's decks, about the size of
  the APK's, or loads them as they are chosen.
- Whether the web app may check for updates itself, or only through the
  service worker.

## Estimate

About 4–6 hours, most of it the drift web setup and checking each plugin in
Safari and Chrome. Confidence: low, until the web build is tried. No iPhone
is available here, so the owner or a tester has to try it on one.

See also: [Roadmap](Roadmap) · [Plans-Index](Plans-Index) · [Home](Home)
