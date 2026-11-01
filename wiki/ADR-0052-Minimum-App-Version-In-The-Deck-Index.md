# ADR-0052: The deck index says which app version a language or deck needs

Source of truth: this wiki page.

- **Status:** Proposed (the owner asked for the arrangement on 2026-11-01:
  "Not everyone updates to a new app as soon as we release them. Make some
  arrangement so users know that they need to update the app.")
- **Date:** 2026-11-01
- **Builds on:** [ADR-0037](ADR-0037-Decks-Download-From-Main) (decks download
  from main by an index; a file of a newer schema is skipped; an index of a
  newer version asks for an update), [ADR-0017](ADR-0017-Update-Check)
  (the app's own update check).

## Context

Decks are fetched from `main`, so a deck, or a whole language, reaches every
phone at once, whatever app version the phone runs. The app knows two ways to
refuse what it cannot read: an index of a newer `version` stops all downloads
and asks for an update, and a file of a newer `schema` is skipped. Neither
fits "this language is for the next app": the first blocks every download of
every language, and the second says nothing where a learner has not yet
downloaded the language (the row that says "Some decks need a newer version"
exists only for a language already on the phone).

About 41 new languages will be published after 0.7.1. Phones on 0.7.0 cannot
be changed, so nothing decided here teaches them anything. What can be
decided is how every later app treats what is newer than itself.

## Decision

- **A new optional key, `min_app`,** a version like `"0.7.1"` (three numbers),
  in the index, on a language and on a file of `files`, `script_guides` or
  `situations`. A language's holds for all its files and recordings. It is
  not a new index `version`: an app that does not know the key ignores it,
  as it ignores every key it does not know, so `supportedIndexVersion` stays
  1 and nobody is asked to update by the index itself.
- **Written from one checked-in file,** `decks/min_app.json`:
  `{"languages": {"pt": "0.7.1"}, "files": {"decks/es/es-en-x.yaml": "0.7.2"}}`.
  `tools/deck_index.py` writes the key from it, and fails (so
  `validate_decks.py decks/` fails) when the file is not JSON of that shape,
  a value is not `major.minor.patch`, a language is not in the index (no
  decks, or hidden), or a file is not listed. JSON, not YAML, because every
  scanner of `decks/**/*.yaml` would otherwise read it as a deck. Empty maps
  write nothing, so the index does not change until an entry is added. The
  `deck-index.yml` workflow already runs on any change under `decks/`.
- **The app (0.7.1 and later) compares it with its own version**
  (`AppInfo.version`) when it reads the index (`DeckIndex.parse(text,
  appVersion:)`, `lib/core/decks/app_version.dart`). A language or file whose
  `min_app` is newer is marked `appTooOld`, which makes it not `readable`,
  exactly as a newer schema does: it is not downloaded, not counted in the
  size, and never an update. A value that is not a version is ignored, never
  thrown at: one bad entry must not block every download (it does today for
  a malformed file entry).
- **What the learner sees,** calm and with one way out: on Add a language
  and in the language picker, a language the app is too old for is greyed,
  reads "Needs app 0.7.1" and Update, and a tap opens the newest release's
  page (`AppLinks.latestRelease`, through `LinkOpener`; the link is copied
  if nothing can open it). It cannot be added. On a language already on the
  phone some of whose decks need a newer app, its row gets the same Update
  beside the existing line. Under the deck update button (Languages) a line
  says "N new decks need an app update" with Update. Downloading such a
  language returns `DeckDownloadFailure.appTooOld`, whose text already says
  to update the app.
- **A `min_app` is never set for a language the released app already ships,**
  and never above a version that is not yet released.

## What this does not do

A 0.7.0 phone knows nothing of `min_app`, so it downloads and lists whatever
the index lists. See "The 41 languages and 0.7.0" below.

## The 41 languages and 0.7.0

Under **HIDDEN** (left out of the index) a 0.7.0 phone never learns the
language exists: it is not on the Download, picker or placement lists, and
nothing is downloaded. The index is the only source those lists read. Nothing
tells the learner to update, because nothing tells them anything.

**Listed** (in the index, no `min_app` helps 0.7.0): the language is partly
visible. It appears with its name, icon, size and courses in the first-run
and "learn languages" picker, the placement picker and the Download page,
and can be chosen and downloaded. It does not appear on the Languages page
or Add a language (they list `assets/languages.yaml`, which 0.7.0 holds
without it), so it has no own-name row there, no family or script question,
and its skills cannot be managed from them. What else a half-known language
does in 0.7.0 is untested; test it on a 0.7.0 build against a staging index
before listing anything. Every listed entry must also match the strict
shapes 0.7.0 checks (a file path `decks/<2 or 3 letters>/...yaml`, a 64-digit
hash, a size): one malformed file entry throws in `IndexLanguage._parse`, the
index read fails, and no download works for anyone on 0.7.0.

**Recommendation:** keep the 41 hidden until 0.7.1 is out and most users have
updated, then unhide them together with their `min_app` entries and the
`assets/languages.yaml` rows in the same release cycle, so that 0.7.1 and
later show them properly and a later app can tell an older one to update.
Hiding costs nothing for 0.7.0 and surprises nobody.

**The schema option** (give the new decks a `schema` newer than 0.7.0
reads, so 0.7.0 skips the files while 0.7.1 reads them) is not
recommended:

- It is not silent in the useful way. A 0.7.0 phone still lists the
  language, with size 0 (its files are skipped), and a learner who chooses it
  gets "ready" with no deck, with no message: the row that says a newer app
  is needed exists only for a language already on the phone. A visible,
  empty language is worse than a hidden one.
- It is not small. `schema: 1` is hard-wired: the Dart deck parser fails
  anything but 1 (`lib/core/data/deck_parser.dart`), the validator checks
  `SCHEMA` at eight or more sites, and the index tool reads the number from
  each file's header. 0.7.1 would need a parser and validator that accept 2
  for these decks and 1 for the rest, `supportedDeckSchema = 2`, and tests;
  existing decks and phones are not touched, so it is feasible without
  breaking them, but it is a deck-format change with its own ADR, to buy
  a behaviour `min_app` and HIDDEN already cover better.
- Inflating the index's `schema` without the file's header would make the
  index lie about the file.

## Consequences

- Old phones stay on what they have; from 0.7.1 on, a language that needs the
  next app is shown as such and not downloaded.
- One more file to keep, `decks/min_app.json`, which the validator checks.
- A phone can show "needs app X" only if X is a real release: the owner sets
  `min_app` when the release exists.
