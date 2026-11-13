---
name: changelog
description: Use before adding or editing a CHANGELOG.md line in a pull request. Rules for what earns a line (only what a learner can see or feel), how to word it, and what never does (CI, workflows, tools, tests, refactors, deck content, docs). Docs-only commits and pushes need no line.
---

The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

# Writing the CHANGELOG line

Owner, 2026-11-13: "the last changelog for the app (the one that shows up at
the start after an update) was very weird. a lot of the entries were simply CI
(nothing else). the changelog writer needs to be wary of these mistakes, maybe
add a skill for writing changelogs in each PR commit. pure doc commits do not
need update in the changelog as they do not alter the app".

## Who reads it

An app user, after an update. The app shows the headline of each entry of the
installed version as a bullet in a sheet on the first launch (#944;
`whatsNewHeadlines` in `lib/core/updates/whats_new.dart`), and the release
workflow publishes the same section as the release notes
(`tools/prepare_release.py --notes`). Write for a learner who has never seen
the repository.

## What the app does with a line

- A line that starts with a bold phrase shows that phrase: `- **Headline.** detail`.
- A line that starts with a backtick is hidden in the app's sheet, but it is
  still in the release notes on GitHub. So a backtick does not make a line
  harmless; it only keeps it out of the sheet.
- Any other line is shown, cut at the first ` (#123)`, colon, full stop and
  space, or spaced dash. `- CI: test shard weights refreshed ...` therefore
  shows as the bullet "CI". That is the mistake of 0.10.0.
- The Release workflow refuses to run if a line breaks this rule
  (`unreleased_problems` in `tools/prepare_release.py`).

## What earns a line

A change a learner can see or feel in the app: a new screen, button or
setting, a behaviour that now works differently, a bug they could hit that is
fixed. Form:

- One line: `- **Plain headline.** One plain sentence of what changes for the learner.`
- The headline is a few words, bold, ending in a full stop, and makes sense on
  its own as a bullet.
- No issue numbers, no file paths, no jargon (no "ONNX", "CTC", "shard",
  "pipeline", "refactor").

## What never earns a line

CI, workflows, `.github/`, `tools/`, tests, refactors, internal plumbing that
no screen shows yet, deck content (new or filled decks, paths: it is content,
not a release), and docs. If unsure whether a learner could notice it, it is
developer-only: leave it out of the CHANGELOG. (Only if the owner asks for a
developer note, start it with a backtick, which hides it from the app's sheet
but not from the release notes.)

**Pure doc commits and docs-only pushes need no CHANGELOG line**, since they do
not alter the app. A change that touches code, a deck, `decks/index.json` or
the CHANGELOG itself is not docs only.

A pull request with nothing a learner can notice adds no line. The release
workflow refuses an empty Unreleased section, so the owner is told when a
release has nothing in it.

## Structure

One heading of each kind per section: `### Added`, `### Changed`, `### Fixed`.
Add the line under the existing heading in `## [Unreleased]`; never open a
second `### Fixed` (0.10.0 has two identical ones, with the same two lines in
both). A merge conflict in the CHANGELOG is resolved by keeping both sides'
lines under one heading, not by repeating the block.

## Examples, from the 0.10.0 section

Good:

- `- **Find my level shows its result card at once, and the result is simpler.** The "See my result" pause is gone ...`
- `- **Search results by type, and topic pages.** The Decks tab's search shows a tab for each kind of result ...`

Bad, with the fix:

- `- CI: test shard weights refreshed so the 8 shards finish together.` Shown as the bullet "CI". Omit.
- `- CI: the heavy placement suites run only when placement changes ...` Omit.
- `- tools/asr: Telugu on-device listener reference tools (#1004).` A path, a tool. Omit.
- `- .github/workflows/asr-export.yml: manual workflow that exports ...` A workflow. Omit.
- `- On-device listener: pure-Dart log-mel front end (#1004).` Jargon, an internal piece no screen shows. Omit until the feature lands; then one line: `- **Telugu on-device listening.** Install a Telugu listener from the Voices page and Say works offline.`
- `- Say works again: recording no longer runs ...; #1107.` No bold headline and an issue number. Better: `- **Say works again.** Recording no longer clashes with online recognition, so your voice is heard as before.`
- `- CI: the web smoke test no longer fails when the runner ...` CI again. Omit.
- A second `### Fixed` block repeating the first. Keep one.

Do not rewrite a released section: it is history.

## Self-check before committing

1. Is the change docs only? Then no line.
2. Could a learner notice it in the app? If not, no line.
3. Does the line start with `- **Headline.**` in plain words?
4. No issue number, no file path, no jargon, no "CI", "tools", "workflow", "test"?
5. One sentence of detail, saying what the learner now sees or can do?
6. Is it under the one existing `###` heading in `## [Unreleased]`, not a new duplicate heading?
7. Does it say nothing about deck content?
