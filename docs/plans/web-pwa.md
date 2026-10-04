# Plan: Fluenough on the web, as a PWA on GitHub Pages

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
   - Flutter's service worker caches the app and the bundled decks, so it
     opens offline after the first visit.
   - iOS installs it from Safari's Share menu, "Add to Home Screen". The
     app should say how, once, on iOS Safari.
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
   | Speaking drill | `speech_to_text` works in Chrome and only partly in Safari. Where it can't hear, the drill says so, as it does for a phone without a recogniser. |
   | Phone volume | `flutter_volume_controller` has no web support, and its code reads `dart:io`'s `Platform`, which throws on the web. `SystemVolumeMonitor` must not start on the web (`kIsWeb`). |
   | Updates | The OTA update check and installer are Android-only. On the web, the service worker brings the new version. |
   | Deck import and log export | `file_picker` works on the web: downloads and uploads instead of the file system. |
   | Bug reports | Mail links work. Screenshots in reports need checking. |

5. **Storage that lasts on iOS.**
   - Safari may clear a website's storage after seven days without a visit,
     unless the site is added to the Home Screen. The app should ask for
     persistent storage (`navigator.storage.persist()`) where the browser
     allows it, and suggest installing it.
   - It should also point to Settings > Export log as the backup.

## To decide

- The URL: the default `aaronified.github.io/fluenough/` or a custom domain.
- Whether the web build carries every language's decks, about the size of
  the APK's, or loads them as they are chosen.
- Whether the web app may check for updates itself, or only through the
  service worker.

## Estimate

About 4–6 hours, most of it the drift web setup and checking each plugin in
Safari and Chrome. Confidence: low, until the web build is tried. No iPhone
is available here, so the owner or a tester has to try it on one.
