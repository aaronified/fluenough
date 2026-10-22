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
