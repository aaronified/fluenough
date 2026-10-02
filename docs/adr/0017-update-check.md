# ADR-0017: The app checks GitHub for updates and installs them itself

- **Status:** Accepted
- **Date:** 2026-10-03

## Context

Fluenough ships as an APK attached to a GitHub release. The release
workflow builds `app-release.apk` for every version tag. No store tells
anyone that a new version is out, so until now a learner had to go and look.

The maintainer asked, on 2 October 2026:
- "create a settings to check for updates and download the latest one from
  Github releases (direct download from the latest path)";
- then: "can it start the update process after the download? ... and after
  successful update, it will delete the download (it will be in app storage,
  so no storage permission needed). also add a placeholder for a backup
  feature with backup to Dropbox, box, google drive, onedrive, and nextcloud
  options. this will be another "feature incoming" thing."

Two things pull against this. The app is offline by design: the Settings
footer says "Works fully offline", and the market research counts "offline,
with no account" among its few leads. A check is a request to GitHub. And
the project keeps few dependencies (AGENTS.md rule 6). Until now the app's
links were copied rather than opened, because opening one needs
url_launcher.

## Decision

- **The check.** It asks
  `https://api.github.com/repos/aaronified/fluenough/releases/latest`, with
  dart:io's own `HttpClient`, a `User-Agent` of `fluenough/<version>`, and a
  15-second timeout. No account is used. That endpoint returns the newest
  release that is not a draft or a pre-release.
  - Its `tag_name`, such as `v0.2.0`, is read as dotted numbers and compared
    with `AppInfo.version` number by number. A missing number counts as 0.
  - 403 and 429 are GitHub's rate limits. Any other error, or a reply
    without a readable tag, is a bad reply. No network, or no answer in time,
    is offline. Each has its own message, with Try again.
  - It sits behind `ReleaseCheckEngine`, in `lib/core/updates`. Only
    `main.dart` names `GitHubReleaseCheck`; tests and the gallery use
    `FixedReleaseCheck`, so no test reaches the network.
- **When it checks.** When the learner taps "Check for updates". And at
  launch if they have switched on "Check automatically", at most once in 24
  hours. A check that reached GitHub counts, whatever it answered. One that
  could not reach it does not, so the next launch tries again. **Automatic
  checks are off by default**: each one is a request to a third party, and
  the app should not make one until the learner chooses it.
- **What it remembers.** The switch, the last check and the newest version
  found are settings (`auto_update_check`, `last_update_check`,
  `latest_release`). So a newer version stays marked after a restart without
  asking again: a dot on the Settings tab, which a screen reader hears as
  "Update available", and Download in the row. No dialog interrupts.
- **The install.** Download fetches
  `https://github.com/aaronified/fluenough/releases/latest/download/app-release.apk`
  with ota_update, into `files/ota_update/fluenough-update.apk` in the app's
  own storage. That needs no storage permission. The row shows the
  download's progress, then opens Android's installer on the file.
  - If this launch's check saw a `sha256:` digest on the release's
    `app-release.apk` asset, it is passed as ota_update's checksum, and a
    download that does not match is not installed. Without one, it downloads
    unchecked.
  - Each ota_update error has its own message. When the learner has not
    allowed Fluenough to install apps, it names the setting: Install unknown
    apps. Try again checks again, for the newest version and its checksum,
    then downloads again.
  - When the install fails, "Open download page" opens
    `https://github.com/aaronified/fluenough/releases/latest` in the browser,
    so the learner can still update by hand.
  - It sits behind `ApkInstaller`, as the check does: `OtaApkInstaller` in
    `lib/app` wraps the plugin, and `FixedApkInstaller` stands in for it.
- **The download is deleted after the update.** The version being
  installed is recorded (`pending_update`). At each launch, if that version
  is this build's or an earlier one, the update has happened: the file is
  deleted and the record cleared. The name never changes, and ota_update
  deletes a file of that name before it downloads, so a newer download
  replaces an older one. A cancelled install keeps the file until then.
- **The app's other links open.** The issues page and HeliBoard now open in
  the browser, or F-Droid, through url_launcher in external-application
  mode. When nothing on the phone can open a link, it is copied and a
  SnackBar says so, as before. `LinkOpener` puts this behind an interface
  too.
- **Android.** `android/` is generated, so `tools/brand_android.py` sets up
  what these need, and the result is checked by building it:
  - the internet permission: `flutter create` grants it only to debug and
    profile builds;
  - a query for apps that open https links, which url_launcher needs on
    Android 11 and later;
  - ota_update's FileProvider and the file naming the folder it shares. Its
    own manifest asks to install packages but declares no provider, and
    Android's installer reads the download through one;
  - both external-storage permissions removed from the merged manifest.
    ota_update asks to write external storage, which implies reading it, and
    has used neither since 7.0.1;
  - core library desugaring in `android/app/build.gradle.kts`. ota_update's
    own build switches it on, and the app's then fails AGP's AAR metadata
    check ("Dependency ':ota_update' requires core library desugaring to be
    enabled for :app") until it is on too.
- **Two dependencies, both agreed.** The maintainer agreed to both on 2
  October 2026, under AGENTS.md rule 6:
  - **url_launcher**, so that a link opens rather than being copied for the
    learner to paste. It was first added to open the APK in the browser, and
    stays for the other links and the download page;
  - **ota_update**, so that the app downloads the APK into its own storage,
    where it can delete it again, and hands it to Android's installer itself.
- **A placeholder for cloud backup.** Settings has "Back up to the cloud",
  under Your data, with Dropbox, Box, Google Drive, OneDrive and Nextcloud.
  Each is drawn disabled with the "Feature incoming" badge, behind
  `Feature.cloudBackup` (ADR-0008). Under them a line says that progress
  stays on the phone, and that Export keeps a copy, after the market
  research's model of export and import. No code reaches those services
  yet. [#139](https://github.com/aaronified/fluenough/issues/139) decides
  how each signs in and what it stores; it is related to #112, backup to a
  folder.

## Consequences

- **What GitHub learns.** A check tells GitHub the phone's address, that it
  asked, and the app's version. A download tells it the same. Nothing about
  the learner or their progress is sent. Nothing is asked at all unless the
  learner taps, or switches automatic checks on. The app still works with
  no network, so the footer's "Works fully offline" still holds.
- **The app does not see the install finish.** ota_update's report ends as
  Android's installer opens. The row says to finish there, with Try again in
  case it was closed. Only the next launch knows, from the version.
- **The version must be right.** The check and the deletion both trust
  `AppInfo.version`, which is kept in step with `pubspec.yaml` by hand, while
  the release's own versionName comes from the tag. A release tagged without
  bumping both would keep offering itself, and never delete its download.
  [#141](https://github.com/aaronified/fluenough/issues/141) asks the release
  workflow to refuse such a tag.
- **More permissions, and a bigger APK.** The manifest now asks for the
  internet and to request installs. ota_update also merges three it does not
  use: `INSTALL_PACKAGES`, which Android grants only to system apps, and the
  network and Wi-Fi state. They are left as they are. The release APK grew
  by about 3 MB.
- **A plugin with rough edges.** ota_update 7.1.0's Dart and Java lists of
  statuses disagree on two values, so "already running" and "installation
  error" cannot be told apart. Both read "Android didn't start installing
  it". The app guards against starting two installs itself. A plugin
  instance also hands its first stream back to every later call, so each
  install makes a new one.
- **The script now edits a Gradle file.** Like the manifest, it fails, and
  changes nothing, when `flutter create` writes a file of another shape.
- **Android only.** ota_update only opens Safari on iOS, and the release is
  an APK. iOS is not built yet (ROADMAP, "Later"); when it is, the Updates
  rows should be hidden there.
- **The rate limit.** Without an account GitHub allows 60 requests an hour
  from one address. A school or office network shares that, and its message
  says to try again in an hour.

## Alternatives considered

- **Downloading in the browser.** This PR's first version opened the
  latest-download path in the browser, with url_launcher alone. The learner
  had to find the file and open it, the browser needed leave to install,
  and the file stayed in Downloads where the app cannot delete it. Rejected
  once the maintainer asked for the install to start from the app. The
  browser stays as the fallback, through "Open download page".
- **An installer written for this app.** A PackageInstaller session over a
  platform channel needs no dependency, but needs Kotlin in `android/`, which
  is generated and never committed (AGENTS.md rule 4).
- **`package:http` for the check.** Another dependency, where dart:io's
  client does the one request needed.
- **Checking at every launch, or by default.** More requests to a third
  party than the question needs, from an app that is offline by design.
- **The release's own download address.** The reply names each asset's
  address, which would tie the download to the version and checksum exactly.
  But the maintainer asked for the latest-download path. The gap is a release
  published between the check and the download: at worst a checksum error,
  which Try again settles by checking again.
- **GitHub's Atom feed of releases.** No account either, but no checksum,
  and a feed to parse instead of one JSON field.
