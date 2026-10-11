# Plan: full app backup and restore

Written 2026-10-11. **Priority for the next release (0.4.3/0.5).**

## What the owner asked

> There isn't an app backup, right? That is needed for easier testing, I
> feel. Make that a priority plan for next release.

(owner, 2026-10-11)

Right: there is none. There is a log export and import, and nothing else.

## What exists

- **Review-log export/import (#20).** `LogJsonl` (`lib/core/data/log_jsonl.dart`,
  `docs/LOG-FORMAT.md`) writes JSON Lines: a header (`format`, `version: 1`),
  every review and leech action, then the fitted FSRS parameters. Plain
  text. An import rebuilds every schedule from the log by replay. Exposed by
  `MemoryProgress.exportJsonl()` and an import in
  `lib/features/settings/settings_page.dart`.
- **Settings** live in the drift database as key/value rows
  (`SettingsNotifier.toStored()` / `restore()`, saved by `StoredSettings`),
  so they are not in the log export. Language choice, scripts read, review
  pairs, collapsed levels and the rest are lost on a new install.
- **Drift database** (`lib/core/data/database.dart`, `schemaVersion` 7):
  tables for reviews, card states, leech actions, FSRS parameters, settings,
  decks and cards.
- **Downloaded decks** (`DownloadedDecks`, `FileDownloadedDecks`): files on
  disk with a `files.json` manifest. They re-download.
- **Reviewer data**: reviewer mode and proposal answers
  (`lib/app/reviewing.dart`).

So today a fresh APK install means: log import only, then re-pick
languages, re-set every option, re-download decks, re-enter reviewer state.
That is slow for testing.

## What goes in

| Part | Source | Notes |
|---|---|---|
| Review log | reviews table | as `LogJsonl` today |
| Leech actions | leech_actions | as `LogJsonl` today |
| Schedules / FSRS state | rebuilt by replay; fitted parameters stored | same rule as #20: only what replay cannot recover is stored |
| Settings, every key | settings table | language choice, scripts read, review pairs, collapsed levels, skills, theme, reminder, 18+ and the rest; written as the raw key/value map |
| Reviewer mode, code and proposal answers | reviewing state | included, with the access code (owner, 2026-10-11); see Privacy |
| Downloaded languages | `files.json` manifest | the list only, never deck files; after restore they re-download |
| Profiles | profile store, once #204 exists | one section per profile; see Profiles |
| App version and schema version | `app_info`, `schemaVersion` | for the compatibility check |

Not in: deck files, caches, the app log, update APKs, TTS voices.

## Format

One file, `fluenough-backup-<date>.fnbackup` (a zip, so it is one file to
share). Inside:

- `manifest.json`: `format: "fluenough-backup"`, `version` (backup format),
  `appVersion`, `schemaVersion`, `createdAt`, and the list of parts;
- `log.jsonl`: the existing #20 file unchanged, so a backup's log can still
  be read by the old importer and by `docs/LOG-FORMAT.md` tools;
- `settings.json`: the key/value map;
- `reviewer.json`, `downloads.json`: small JSON files;
- `profiles/<id>/...` later, same layout per profile.

A plain zip of text files, so a backup outlives the app, like the log.

**Forward compatibility.** The manifest `version` is checked first.

- Same or older version: read it; missing parts or keys take their defaults
  (as `restore()` already does for settings).
- Newer version than this app knows: refuse with a clear message ("made by a
  newer Fluenough, update first"), change nothing.
- Unknown extra files or keys inside a known version are ignored, not
  errors.
- `schemaVersion` is informational: parts are read by their own format, not
  by raw table rows, so a backup survives database migrations.

## Flow

- **Export.** Settings, Backup and restore, Back up now. Writes the file and
  opens the Android share/save sheet (system file picker, `ACTION_CREATE_DOCUMENT`
  or share intent). No network permission used.
- **Import.** Same page, Restore from a file. System file picker. The app
  reads the manifest and shows a summary (date, app version, number of
  reviews, languages) before anything changes.
- **Replace, by default** (decided: the purpose is testing, where the same
  state must come back exactly). A confirmation names what will be erased
  ("This replaces your current progress and settings"). Merge is not in the
  first version: merging two logs needs de-duplication and conflicting
  settings rules, and testing does not need it. The existing log-only
  import keeps its current behaviour.
- The restore runs in one database transaction, so a failed or corrupt file
  leaves the app as it was. Afterwards the app queues the downloads in
  `downloads.json` and shows the usual progress.
- **Download-failure escape screens: not offered.** Those screens exist to
  get a stuck user going (retry, update); a restore there is a different
  decision and needs the confirmation. Keep one place, Settings.

## Testing value

Install a new APK, restore, same state: languages, settings, progress,
reviewer status. A tester backs up before a risky build and restores after.
Not planned (YAGNI): an automatic or on-crash export, scheduled backups,
cloud sync.

## Privacy

The file stays on the phone unless the user shares it. No upload, no
network call. A backup holds a full learning history, so the share sheet
copy says so. The reviewer access code is included (owner, 2026-10-11:
"Yes"), so a restore brings reviewing back as it was; because the file then
holds a secret, the share sheet copy also says it contains the reviewer
code. Reviewer proposals and answers are kept.

## Profiles and child profiles (compatible with `profiles.md`)

- Before profiles, the backup holds the one learner. Once #204 lands, a
  backup holds every profile, and a restore into a phone with profiles
  replaces all of them (after the confirmation).
- `profiles.md` has a grown-up child move history with Export and Import
  into a new adult profile. That is the single-profile export: the same
  file format with one profile in it, importable as a new profile.
- **Restrictions are never carried.** A single-profile export holds
  learning history and learner settings only: no child flag, no admin
  or profile PIN, no held-off languages, no hidden courses, no locked
  actions. An import into a new adult profile starts unrestricted.
- In a child profile, Backup and restore is a locked action (admin PIN),
  like the log export.
- A full-device backup holds the admin's supervision rules and PIN hashes
  so a restore returns a family set-up as it was; it is only offered to the
  admin profile.

## Tests

- `test/core/` (no Flutter imports, per AGENTS.md): backup encode/decode
  round trip; manifest version check (older reads, newer refuses, unknown
  keys ignored); log part byte-identical to `LogJsonl.encode`; a backup
  never contains deck files or restriction fields.
- Settings: every key in `toStored()` survives export and restore; a key
  added later reads as its default from an older backup.
- Restore is atomic: a corrupt zip, a truncated `log.jsonl` or a failing
  part leaves the database unchanged.
- Replace: existing progress is gone after restore, and schedules equal the
  originals (replay equals stored).
- Downloaded languages: list restored, no deck files written.
- Widget tests: Settings entry, confirmation text, summary shown before
  restore, cancel changes nothing.
- Profiles (when they exist): single-profile export imports as a new adult
  profile without restrictions.
- Docs: extend `docs/LOG-FORMAT.md` or add `docs/BACKUP-FORMAT.md`.

## Estimate

About 4 to 6 working days: format and codec 1 day, export/import and
transactional restore 1.5 days, Settings UI and Android share/picker 1 day,
reviewer and downloads parts 0.5 day, tests and docs 1 to 1.5 days.
Confidence: medium-high (about 70%) for the single-learner version, since
most parts already exist; the Android file picker and share on a real
device are the main risk. Profile support adds about 1 day later and
depends on #204.

## Open questions

- Zip dependency versus a single JSON file with the log embedded as lines.
  A zip is cleaner; a JSON file avoids a package. Decide at build time by
  what is already in `pubspec.yaml`.
- ~~Whether the reviewer code is exported.~~ Decided (owner, 2026-10-11):
  yes, it is included.
