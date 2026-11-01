# Releasing

Source of truth: this wiki page.

## The release workflow

The owner's rules, as written in [CLAUDE.md](https://github.com/aaronified/fluenough/blob/main/CLAUDE.md):

- **Releases** (owner, 2026-10-20: "Can the release workflow not
  automatically take care of the release commit? So that I can cut releases
  just from the UI?"). Each pull request adds its own CHANGELOG.md line under
  `## [Unreleased]`; deck content (new or filled decks, paths) is not part of
  a release and stays out of it (owner, 2026-10-19: "This has nothing to do
  with the release. It is content."). The owner releases by running the
  Release workflow from the Actions tab, from main, with the version (like
  `0.5.3`): it bumps `pubspec.yaml` and `lib/app/app_info.dart`, dates the
  changelog, commits, tags and builds (`tools/prepare_release.py`). There is
  no release pull request.

## Decks that need a newer app

Not every phone updates as soon as a release is out, and decks are fetched
from `main` whatever the phone runs. When new decks or a new language need
what a release added, list them in `decks/min_app.json` (language code, or a
deck file's path, to the version, such as `"0.7.1"`) in the same pull request
that adds them, once that version is released or will be before the decks
merge. The index then carries `min_app`, and apps from the first one that
knows it show "Needs app X, Update" instead of downloading (ADR-0052). A phone
on a release before that cannot be told anything: keep a new language hidden
(`HIDDEN` in `tools/deck_index.py`) until most phones have the app that reads
`min_app`, then unhide it together with its `min_app` entry. Never set
`min_app` for a language a released app already ships.

## Changelog entries and "What's new"

Each pull request adds its own line under `## [Unreleased]` in
`CHANGELOG.md`, and from 2026-10-31 (owner, #944) the line starts with a
short, plain, user-facing headline in bold, ending in a full stop, then the
detail and the issue number:

```
- **Situations on Today.** Six buttons open sheets of key phrases (#724).
```

The first launch after an update shows a sheet, once per version, listing
the headline of each entry of the installed version as a bullet, with the
version and one "Got it" button. It is not shown on a fresh install, and not
when the version's dated section has no entry to list. The release workflow
dates the section and commits before it builds, and `CHANGELOG.md` is bundled
in the app as an asset, so the sheet reads it offline and asks GitHub for
nothing (ADR-0017). The last version seen is the `last_seen_version` setting,
kept per profile. Settings > Updates > What's new still shows the full notes.

How a headline is found, in `headlineOf` (`lib/core/updates/whats_new.dart`):

1. A bold lead, `**Headline.** detail`, is the headline.
2. Otherwise, for entries written before the rule, the text up to the first
   ` (#123)`, colon-and-space, full-stop-and-space, or spaced dash.
3. Otherwise the whole entry. Marks (backticks, bold, link addresses) are
   removed, and a headline over 90 characters is cut at a word.

An entry that starts with a backtick (a tool, file or command) is for
developers and is left out. Entries are read from every `###` heading of the
version's section; `## [Unreleased]` is never shown.

## Version check

The release workflow runs the version check in [tools/README.md](https://github.com/aaronified/fluenough/blob/main/tools/README.md) before it builds.

## `check_release_version.py`

Fails when a release tag and `pubspec.yaml`'s version differ (#141). The
release workflow runs it before building, because the APK's versionName is
the tag while the app reports `AppInfo.version`, which follows
`pubspec.yaml`. Only the version name is compared; the `+build` part is
ignored. Standard library only.

```sh
python3 tools/check_release_version.py v0.3.4             # reads ./pubspec.yaml
python3 tools/check_release_version.py v0.3.4 pubspec.yaml
```

Exit status is 0 when they match, 1 when they differ or `pubspec.yaml` has no
`version:` line, and 2 if the arguments are wrong or the file cannot be read.

## Changelog and plan

The changelog is [CHANGELOG.md](https://github.com/aaronified/fluenough/blob/main/CHANGELOG.md). The signing and first-release plan is [Plan-Release-Signing](Plan-Release-Signing).

See also: [Contributing](Contributing) · [Home](Home)
