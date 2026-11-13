# App backup format, version 1

Source of truth: this wiki page.


Settings → Your data → Back up now saves the whole app as one file,
`fluenough-backup-<yyyy-mm-dd>.fnbackup` (#470). Restore from a file reads
such a file back.

The file is a plain zip of small UTF-8 text files, so a backup outlives the
app the way the review log does: any unzip tool opens it. The app writes its
entries stored, not compressed, and reads stored or deflated entries, so a
backup unzipped and zipped again by hand still restores. No encryption, no
zip64, no multi-disk archives.

A backup never holds deck files, nor anything that restricts a profile,
**except the learner's own private language packages** (#1017), which exist
nowhere else. After a restore the languages it lists download again, and the
private packages it holds are installed again.

## Parts

| File | What it holds |
|---|---|
| `manifest.json` | What the file is; read first. Required. |
| `log.jsonl` | The review log, leech actions and fitted parameters, byte for byte the file Export review log writes ([Log-Format](Log-Format)). |
| `settings.json` | Every setting, as a JSON object of string keys to string values, except the reviewer's. |
| `reviewer.json` | The reviewer's settings, the same way: `review_decks`, `rater_code` (the access code; owner, 2026-10-11), `review_intro_shown`, `reviews`. |
| `downloads.json` | `{"languages": ["bn", "hi"]}`: the languages whose decks were on the phone. |
| `own-decks.json` | Only when the learner has private language packages, or removed some: `{"packages": [{"id": "fnpd-qaa", "name": "Tiny", "revision": 2, "kind": "new-language", "active": true, "retired": ["fnpd-qaa-0003"], "file": "own-decks/fnpd-qaa.fnzip"}], "tombstones": {"fnpd-qab": ["fnpd-qab-0001"]}}`. `retired` are the card ids an update dropped; `tombstones` are those of packages the learner removed. Both keep a later revision from reusing an id. |
| `own-decks/<package id>.fnzip` | Each private package as the learner imported it ([Private-Language-Package](Private-Language-Package)). Already compressed, so the backup stores it as it is. |

A part that is missing reads as empty, and a setting that is not there
takes its default. A file or key the app does not know is ignored: an older
app restores the log and settings of a backup that has `own-decks`, and leaves
the packages out. The format `version` stays `1`.

A package entry whose id is not `fnpd-<code>`, or whose file is not in the zip,
is skipped. A restore installs each package through the same checks as an
import, so one that no longer passes them (or whose manifest is another
package than the index says) is left out and logged, and the others come back. A
restore adds to the packages on the phone, never removes one, and installs a
package off when turning it on would make a fourth active.

## `manifest.json`

```json
{"format":"fluenough-backup","version":1,"appVersion":"0.5.0","schemaVersion":7,"createdAt":"2026-09-28T13:10:00.000Z","kind":"you","reviews":6,"parts":["log.jsonl","settings.json","reviewer.json","downloads.json"]}
```

| Field | Notes |
|---|---|
| `format` | Always `fluenough-backup`. A file without it is not a backup. |
| `version` | The backup format, `1`. An app refuses a file whose version is newer than it reads, names the app that made it, and changes nothing. |
| `appVersion` | The app version that made it. |
| `schemaVersion` | The database schema then. Informational only: every part is read by its own format, never as table rows, so a backup survives migrations. |
| `createdAt` | ISO 8601, in UTC. |
| `kind` | What made it: `you` (Back up now), `update` (an app update began to download), `restore` (the copy of what a restore replaced), `file` (a file restored from, kept as it was read), `delete` (the copy made before a language's data was deleted from its sheet, #861). Unknown reads as `you`. |
| `forVersion` | For an `update` backup, the version being downloaded. |
| `reviews` | How many reviews `log.jsonl` holds, so Recent backups can say without reading the log. |
| `privateLanguages` | When there are private packages: their names, so the restore screen can say what comes back. |
| `parts` | The other files in the zip (the `.fnzip` files are listed in `own-decks.json`). |

## Kept on the phone

The app keeps backups in its own storage, which an update leaves alone: the
five newest of any kind, of which at most the three newest made by an
update. Each can be downloaded or restored from Recent backups.

## Restore

A restore reads and checks the whole file, and shows what it holds, before
anything changes. It replaces the progress and settings the learner has,
after asking, and keeps a copy of them first. Replacing the append-only
review log is the one logged exception to AGENTS.md rule 9 (owner,
2026-10-17: "Logged exception"): in one transaction, the database empties
`reviews` and `leech_actions`, writes the backup's, and appends to
`restores` when it happened, which backup it was and the name of the copy
kept first. A failure leaves the app as it was.

See also: [Contributing](Contributing) · [Home](Home)
