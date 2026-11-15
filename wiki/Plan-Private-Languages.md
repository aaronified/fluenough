# Plan: build entire languages as private decks (Your decks)

Source of truth: this wiki page.


Written 2026-11-04. Tracker: #1017. Builds on #495 (Your decks) and #475
(Add deck moved into Settings). Nothing here is built.

## What the owner asked

> I need a way to build entire languages as private decks. This will be through the existing your decks entry in settings. Create a plan for this. (owner, 2026-11-04)

## Goal and non-goals

**Goal.** A learner can bring a whole language the app does not teach, as a
private package, through Settings, Your decks, and use it like any course:
path, Today, reviews, drills, search. It lives only in the app's data and
in backups.

**Non-goals.**

- Uploading, publishing or sharing through us. "Send it to us" stays #495's
  optional step, after the deck is added.
- Making the content. The app validates and fixes; authoring is outside
  the app (a text editor, a spreadsheet, an AI tool the learner uses).
- Anything for the repository's languages. Private content never enters
  `decks/`, `decks/index.json` or the released-app check.
- Changing the deck schema (still `schema: 1`), or card ids already
  built. AGENTS.md says an agent must not decide either alone.
- A new dependency. The zip reader and writer already exist
  (`lib/core/backup/zip_files.dart`), and so does the YAML reader.

## What exists today

| Piece | Where | State |
|---|---|---|
| Your decks page: Upload a deck (opens the import page), Get a template (`Feature.deckTemplates`, incoming), list grouped by language then native, Open, Send it to us (`Feature.deckSend`, incoming), Remove | `lib/features/settings/your_decks_page.dart`, `lib/app/features.dart` | Upload and Remove built; the rest incoming |
| Import page and check | `lib/features/decks/import_page.dart`, `lib/app/deck_import.dart` (`checkAddedDeck`) | Parses one file with `DeckParser`; refuses a bundled deck id and a card id another deck has; shows file, line, message. No fixes, no warnings list |
| Storage | `lib/app/added_decks.dart` (`DeckStore`, `FileDeckStore`) | One `<deck id>.yaml` per deck, read under the `added/` prefix, marked not bundled (ADR-0020). Ids are kept as written; the user series of #495 is not built |
| Template | `assets/deck-template.yaml` | Hindi from English, `hi-my-NNNN` ids; to be replaced by #495 |
| Paths | ADR-0020 wildcards | An added deck goes at the bottom of its theme's unit, else the end of the course's path |
| Backup | [Backup-Format](Backup-Format) | "A backup never holds deck files". Private decks have no place in it yet |
| Catalog load | `lib/app/deck_catalog.dart` | `DeckSource`s read as one; parse on an isolate; snapshot by SHA-256 (ADR-0048) |
| Language list | `assets/languages.yaml`, `lib/features/languages/add_language_page.dart`, `LanguageInfo` in `lib/core/models/deck.dart` | The picker lists the official languages; a language is otherwise read from a deck's `language` block |
| Validator | `tools/validate_decks.py` (about 7,200 lines, 187 functions, per-file and cross-file checks) | Python only. The app's `DeckParser` (`lib/core/data/deck_parser.dart`, about 3,400 lines) is a separate reader |
| Fonts | ADR-0042, `lib/core/decks/script_fonts.dart` | Noto fonts per script, downloaded with a course, listed in the index. Unknown scripts are accepted with a warning (ADR-0009) and fall back to the phone's font |

Decisions already recorded in #495 (owner, 2026-10-12) that this plan keeps:
a custom deck is **one file** with no core and layer split; the app assigns
every deck id (`user-<target>-<native>-NNNN`) and card id
(`<target>-user-NNNNNN`) from a series course decks never use, the counter
stored and never reused; two-letter ISO 639-1 codes where one exists; the
same file again is recognised by content (Replace keeps progress on
unchanged cards, or Keep both); "Send it to us" only after the deck is in
Your decks; the Settings mockup (`docs/mockups/settings.html`, #496) is
the approved spec. On 2026-11-04 the owner set #495 aside ("remove blocked
and keep it aside"), so stage 2 below is where its core gets built.

## What "an entire language as a private deck" means

A language today is spread over a few hundred files. For scale, from
`decks/index.json`: Bengali is 464 files, 5.2 MB, 173 path units; Spanish
441 files, 3.4 MB. A private language is the same set, in the shape #495
chose: **single-file decks**, with the native text inside each deck.

| Part | Official course | Private language package | Needed? |
|---|---|---|---|
| Manifest: package id, revision, name, format, `min_app` | none (the index does it) | `manifest.yaml` | Required |
| Language entry: code, ISO 639-3, names, scripts, `tts`, `rtl`, icon, family | `assets/languages.yaml` plus every deck's `language` block | One `language` block in the manifest, copied into each deck on import | Required |
| Decks: vocab, grammar, reading, sets, phrasebook | core in `decks/<lang>/`, layer in `decks/<lang>/<native>/` | One file per deck, one native each; several natives allowed as separate decks | At least one deck |
| Path and the B1 plan | `<lang>-path.yaml` | Optional `path.yaml`; without it the decks are a list in file order | Optional |
| Themes | `decks/themes.yaml` | The official ids, or own themes in the package | Optional |
| Facts | `<lang>-facts.yaml` (30 or more) | Optional, no minimum | Optional |
| Readings and romanisation | `<lang>-romanisation.yaml`, a `reading` on each card | The `reading` on each card; a romanisation file is optional | Readings required for non-Latin scripts (a warning, not an error) |
| Sounds, script guides, numbers, situations, resources | `<lang>-sounds.yaml` and the others | Optional, same format | Optional |
| Fonts | `decks/fonts/<script>/` (ADR-0042) | The phone's font, an official Noto font where the script has one, or a font in the package (open question 9) | Optional |
| Audio and images | per card `audio`, `image` | Optional, small files only (open question 11) | Optional |
| Version | the index and `min_app` (ADR-0052) | `format`, `revision`, `min_app` in the manifest | Required |

Stage 1 includes an audit of what each feature needs of a language beyond
its decks (Today, placement, number drills, search, question engine, the
sound check), so each missing optional part degrades quietly and none
crashes. That audit is not done here.

## The user journey

1. **Settings, Your decks.** Rows: Upload a deck (as now), Get a template
   (standalone deck or full language, as #495 says), and the list. A
   private language shows as a group in the list.
2. **Get a template.** Saved to Downloads through the system file dialog
   (`DeckFiles.save`). "Full language" is a starter package: manifest,
   one example deck per kind, an example path, and a short `README` that
   says the app numbers the cards. A guide page in the wiki says how to
   fill it, by hand or with an AI tool.
3. **Author outside the app.** The learner edits files on a computer or
   phone.
4. **Upload.** The system picker takes a `.yaml` (one deck, as now) or a
   package (a zip, see open question 1).
5. **The fix-up review screen** (#495, extended). It lists findings:
   file, line, card id, field, the problem. Errors block. Warnings do not.
   A minor problem has a fix button ("Add quotes", "Use 'bn'", "Add the
   missing reading later"), or the field can be edited in place. "Add to my
   decks" is enabled when no errors remain. The learner sees the counts
   first: decks, cards, files skipped.
6. **Use it.** The language appears in Languages and in the picker as
   "Yours". It has a path, Today lessons, reviews, drills and search, like
   any course.
7. **Update or replace.** Upload the package again. The app recognises it
   by its package id (or by content, as #495 says), shows what changed (new,
   changed and removed cards), and replaces it. Progress on the cards that
   stay is kept.
8. **Export.** Settings, Your decks, a language, Export: writes the package
   as it is now, with the assigned ids as keys, so a re-import on another
   phone matches.
9. **Delete.** Remove asks first, in the error colour. The files go; the
   review history stays and returns if the same package is added again
   (as ADR-0020 does for added decks).
10. **Share privately, file to file.** The exported package is a file the
    learner sends however they like. Nothing is uploaded by the app.

## Data model and storage

- **A separate namespace.** Private decks live under their own directory
  in app storage, beside `added/` (which stays for single decks), never in
  `downloaded/`. The catalog reads them as another `DeckSource` marked
  private, so no official deck or index entry can overwrite one.
- **Ids, as #495 decided.** The app gives each deck `user-<code>-<native>-NNNN`
  and each card `<code>-user-NNNNNN`. Course decks never use these, and the
  validator will refuse them under `decks/`.
- **Language code collision.** The package's language code must not be one
  in `assets/languages.yaml`, official or planned. A real ISO code the app
  does not list is allowed (two letters where one exists, else three). A
  language with no ISO code takes a private-use code, `qaa` to `qtz`, the
  way English Braille uses `qbe`. A clash with an official language is
  refused with a plain message, unless the owner allows private decks inside
  official languages (open question 2). Two private languages cannot share
  a code on one phone; the second is offered Replace or Rename.
- **Card-id permanence on re-import.** The one thing that must hold:
  once an id is assigned it is never reused or changed. The app keeps a map
  `package id + author key -> card id` and the next-number counter, in
  its own file, so no database migration is needed (AGENTS.md rule 9). On
  update, each card in the file is matched in order by author key, then by
  its target and native text. A match keeps its id. A new card takes the
  next number. A card gone from the file is retired: its id is never
  reused, as for a repository card. **This goes beyond #495**, which says
  the file's own ids are replaced; the plan keeps them as keys so that an
  author can edit a word and keep the learner's progress (open question 6).
- **Reviews.** `reviews` stays append-only and keyed by card id, unchanged.
  Removal and retirement leave history, as ADR-0020 says.
- **Backup.** Add a part to the backup zip: `own-decks.json` (package ids,
  key map, counters) and `own-decks/` (the package files). The format
  version stays 1, because a part the app does not know is ignored; the cost
  is that an older app restoring such a file silently drops private
  decks, so the manifest lists the part and the restore screen of the new
  app names the languages it holds. [Backup-Format](Backup-Format) must change its line "A
  backup never holds deck files" to "except the learner's own decks".
  The backup writes entries stored, not compressed, so a 5 MB language adds
  about 5 MB; compress this part (the reader already accepts deflated
  entries) or leave it, an open choice for stage 3.
- **Not shared, not indexed.** A private deck is not in `decks/index.json`,
  not in the deck update check, not in the reviewer's mail, not in an
  in-app report, and not in a log export except as card ids. Stage 2 checks
  each of those paths.

## Validation: one rule set, four levels

The released app and the Python validator are two readers. The in-app
check cannot copy 7,200 lines of Python, and need not: a private deck must
be **readable by the app**, not meet the repository's content rules.

| Level | What it checks | Where it runs | Blocks? |
|---|---|---|---|
| 0 Safe to open | Size, UTF-8, archive entry names and sizes, file types, YAML depth, no aliases | New Dart code | Error |
| 1 Readable | The same `DeckParser`, path, themes and facts parsers the app uses to play a deck | Existing Dart | Error |
| 2 Consistent | Language code rules, scripts, every path unit names a deck, refs exist, no card twice, readings on cards of non-Latin scripts | New Dart, over the parsed objects | Error or warning |
| 3 Quality | A subset of the validator's checks that help a learner: quoted YAML scalars, script in prose with its reading, stem notes, wrong script letters | Dart port, one rule at a time | Warning |
| 4 Repository grade | The whole `tools/validate_decks.py` | CI, when a sent deck is split and added | Not in the app |

**What must be identical.** Level 1 is the released app's own reader, so a
deck that passes it is valid for the released app by construction; no
second parser may exist. Levels 2 and 3 must give the same finding as the
Python tool for the same input.

**Keeping the rules in one place.** Three options:

| Option | Meaning | Main downside |
|---|---|---|
| A. Shared fixtures (recommended) | Python stays the source of truth. Each Dart rule has a rule id and a fixture folder of input plus expected finding, run by both tools in CI | Two code bases still; a rule can drift until a fixture catches it |
| B. Generate | Write rules as data (a JSON table) that both tools read | Most rules are code, not data; a big rewrite of the validator |
| C. Dart runs the Python | Not possible on a phone without a runtime | Rules out offline use |

Stage 5 follows option A and ports only the rules a learner benefits
from. The validator's "custom deck" mode that Deck-Format already calls for
("Adding your own deck") is built with it: it accepts the user id series
and refuses them under `decks/`.

## Scripts, fonts and speech for languages the app does not know

| Need | What the package gives | What the app does | Gap |
|---|---|---|---|
| Script | `script` and `scripts` in the language block, any lowercase name | Accepts unknown names with a warning (ADR-0009); every script but Latin, Cyrillic and Greek expects a `reading` | None |
| Right to left | `rtl: true` | `LanguageInfo.rightToLeft` and the existing drawing rules | Scripts not in `rtlScripts` need `rtl` set |
| Font | Nothing, or a font file | Official Noto font where ADR-0042 has one; else the phone's font | An unknown script may draw as boxes; warn on import by drawing a sample (the existing `font_check`) |
| Speech out | `tts` tag | System TTS (ADR-0002) | The phone may lack the voice |
| Speech in | none | System recogniser | May lack the language |
| Romanisation | `reading` per card, optional romanisation file | Typed-reading answers (ADR-0022) | The scheme is the author's own; the app calls it "reading", never ISO 15919 |
| IPA | `ipa` per card | As for official cards | Narrow `phonetic` is written by repository tools only |
| Kanji-like second scripts | `scripts`, `target_scripts` (ADR-0053) | As official | None |

The import checks the voice, the recogniser and a font sample and shows
what the language will lack (no sound, no speaking drill) before it is
added. Drills that need a missing capability are hidden for it, or say why they
cannot run (compare [Plan Speech Offline Alert](Plan-Speech-Offline-Alert)).

## Limits (proposed; stage 2 sets them from measurements)

| Limit | Proposed | Why |
|---|---|---|
| Package size | 30 MB | The largest official course is 5.2 MB; audio is the reason for room |
| One file | 2 MB | A catalog parse reads one file at a time |
| Files per package | 1,000 | Bengali is 464 |
| Cards per language | 20,000 | Memory; the card index and Fts5 search (ADR-0049) |
| Private languages | 5 | Catalog load time on every launch |
| YAML depth | 32 | Stack safety |

Import runs on an isolate, as the catalog does (#875), with progress. The
catalog snapshot (ADR-0048) is keyed by file SHA-256, so a private
language costs a full parse once, then loads from the snapshot. The
performance budget of ADR-0047 applies: stage 2 measures a 5 MB language on
a low-end phone before the limits are fixed.

## Security

Packages are untrusted input.

- **YAML.** Dart's `yaml` package only builds data. Refuse aliases, custom
  tags and any depth beyond the limit. No file is ever run.
- **Archives.** Read in memory. Refuse an entry name that is absolute,
  has `..`, a backslash or a drive letter, a duplicate name, a symlink,
  encryption or zip64 (the backup reader refuses the last two). Check the
  declared size against the bytes read, and the total against the limit,
  before parsing (a zip bomb). Never write a file under the name the
  archive gives: the app picks its own names.
- **Allowed types.** `.yaml`, `.json`, and later fonts and audio by
  extension and by content. Anything else is skipped and listed.
- **Binary files** (fonts, audio, images) are the riskiest parts, decoded by
  the engine. They are a later stage and may be left out (open
  questions 9 and 11).
- **Privacy.** Nothing about private content leaves the phone: see
  "Not shared, not indexed".

## Screens needing a mockup (`docs/mockups/README.md`; none are drawn here)

1. Your decks, with private languages as groups, and Get a template with its
   two choices (extends the approved Settings mockup).
2. The review screen with findings, fixes, in-place editing and counts
   (the #495 screen, widened to a package).
3. The language page for a private language: what it has and lacks (sound,
   speaking, font), Update, Export, Remove.
4. The update summary: new, changed and removed cards.
5. A "language you bring" entry in Add a language, if the owner wants one
   (open question 2).

Each is built to the approved spec only.

## Accessibility and l10n

- Findings are text with a severity word, never colour alone. Order on
  screen is the order a screen reader reads: file, then card, then field.
- Every control is 48dp or more and works at 1.4x text (the app's cap).
  Fix buttons have clear labels. Icon-only buttons have one-word tooltips.
- Remove and other destructive actions are in the error colour and ask
  first.
- No user-visible string is a literal (AGENTS.md rule 10). Findings are
  tokens with placeholders: "Card {id}: '{field}' is missing". The deck's
  own text is not translated. Package keywords are not interface text.
- The review screen uses directional paddings and isolates quoted deck text
  so right-to-left words do not reorder the sentence around them.

## Testing strategy

Tests check behaviour and run only in CI (AGENTS.md). Few, and
meaningful:

- **Fixtures.** A tiny package of an invented language in a Latin, a
  right-to-left and an Indic-like script, and a broken variant of each
  finding: bad code, missing reading, unquoted scalar, traversal entry,
  duplicate name, oversize file, alias.
- **Shared rule fixtures** run by both `tools/` and Dart (option A).
- **Round trip.** Import, export, import on a fresh phone: the same
  cards, the same ids, the same path. A property test over generated
  packages.
- **Permanence.** Import, review, edit a word, update: its progress stays;
  retire a card and add one: the id is not reused; restore a backup:
  counters and keys survive.
- **Backup.** A backup with private decks restores them; an older reader
  ignores the part.
- **Performance.** A 5 MB package imports within budget and loads from the
  snapshot.

## Staged pull requests

Sizes: S under 200 changed lines, M up to 600, L up to 1,500. One concern
per pull request; docs go straight to main.

| # | Stage | Size | Blocked by |
|---|---|---|---|
| 0 | Owner answers the open questions below | n/a | none |
| 1 | Decision record, wiki format page "Private language package", validator custom mode spec, audit of what features need of a language (docs only) | M | 0 |
| 2 | Private store: separate directory, user id series, key map and counter, replace by key, retire; catalog source; limits measured | L | 1 |
| 3 | Backup part `own-decks` and restore, with Backup-Format change | M | 2 |
| 4 | Package reader: manifest, archive and folder safety, staging in memory | M | 1 |
| 5 | Validation engine in Dart: findings, levels 0 to 3, shared fixtures; validator custom mode in Python | L | 4 |
| 6 | Language entry, scripts, `rtl`, font sample and capability check (voice, recogniser) | M | 2 |
| 7 | Review screen: findings, fixes, in-place edit, update summary (needs mockup) | L | 5, 6 |
| 8 | Templates and starter package, the guide page (wiki), `Feature.deckTemplates` on | M | 1, 4 |
| 9 | Export, update, replace, remove for a language; Your decks list groups (needs mockup) | M | 2, 7 |
| 10 | Optional: fonts and audio in a package | M | 4, open questions 9 and 11 |
| 11 | Optional: "Send it to us" for a language (#495's own part) | M | 9, #495 |

Stages 4 and 8 can start with 2. Stage 7 is the first the learner sees.

**Risks.**

- Two readers drift (mitigated by shared fixtures, and by Level 1 being
  the app's own parser).
- A parse of 5 MB on a low-end phone is slow (measured in stage 2, then
  the snapshot and isolate).
- Private-use language codes may clash with official ones later: the
  official `languages.yaml` wins and a private language is offered Rename.
  The risk is small and handled at import.
- Scope: this can grow into a content editor. The plan stays at import,
  fix and use.

## Milestone

0.8.0 exists, and its only issue is Handwriting. **0.9.0 does not exist
yet.** Suggest: the docs stage (1) with 0.8.0; the build (2 to 9) in a new
0.9.0, which the owner creates. The milestone's description holds the order
(CLAUDE.md). This is the owner's call; no milestone is set on the
issues until he says.

## Dependencies

- #495 is the base: stage 2 builds its custom-deck core. It is set aside
  (owner, 2026-11-04), so the owner decides whether it is built first,
  folded into this plan, or built as stage 2 here (question 13).
- #475 is closed; the Add deck row is already in Settings.
- Nothing else blocks it. Record each child issue's "blocked by" link and
  the `blocked` label as the table says (CLAUDE.md).

## Open questions for the owner

| # | Question | Options | Main downside |
|---|---|---|---|
| 1 | Package form | (a) one zip, `.fnlang`, like the backup; (b) a folder the learner picks; (c) many single files picked one by one | (a) needs a zip tool for authors; (b) system pickers on phones handle folders badly; (c) cannot carry a path or manifest |
| 2 | Can private languages add decks to an official language, or only bring new ones? | (a) new languages only; (b) both, kept apart | (b) doubles the id and path rules and the "which course is this" question |
| 3 | Sharing between users | (a) file to file only; (b) also a link; (c) via "Send it to us" | (b) needs a host and moderation; (c) turns private content public and needs the licence below |
| 4 | Built-in AI authoring helper | (a) none, a prompt guide on the wiki; (b) a Copy prompt button; (c) an in-app AI call | (c) needs the network and an account, against "offline"; (b) can tempt wrong content |
| 5 | A language with no voice or no speech recognition | (a) hide speaking and sound drills for it; (b) let the package carry audio; (c) refuse it | (a) a thinner course; (b) large files and a binary stage |
| 6 | Card keys on update | (a) the author gives a `key` per card; the app maps it to its id (this plan); (b) as #495: replace all ids, match by content | (a) beyond #495's words, one more field; (b) an edited word loses its progress |
| 7 | Core and layer for a private language | (a) single-file decks only, as #495 chose; (b) allow core and layers for authors who want them | (b) a second code path for the parser and the review screen |
| 8 | Language codes | (a) ISO two letters, three where none, `qaa` to `qtz` for no ISO code; (b) the learner types anything | (b) clashes with official codes later |
| 9 | Fonts in a package | (a) never, phone font or Noto only; (b) allowed, one font up to 2 MB | (a) some scripts draw as boxes; (b) an untrusted binary and a licence to check |
| 10 | Licence field of a private deck | (a) any SPDX id or `private`; (b) `CC-BY-SA-4.0` as in the repository (ADR-0040) | (a) a sent deck needs its licence cleared first; (b) forces a licence on private work |
| 11 | Audio and images in a package | (a) not now; (b) small clips and pictures, with limits | (b) larger packages and binary decoding risk |
| 12 | The numbers: 30 MB, 2 MB a file, 20,000 cards, 5 languages | accept, or change | Too low blocks a real language; too high risks memory on a low-end phone |
| 13 | #495 | (a) build it as stage 2 here; (b) build it alone first, then this plan; (c) fold it into this plan | (b) the full-language work waits; (c) #495's mockup spec must be re-read |
| 14 | Milestone | (a) 0.8.0; (b) a new 0.9.0 | (a) crowds 0.8.0; (b) the owner creates it and sets its order |

See also: [Plans-Index](Plans-Index) · [Deck-Format](Deck-Format) · [Backup-Format](Backup-Format) · [ADR-0020](ADR-0020-Added-Decks) · [ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course) · [ADR-0052](ADR-0052-Minimum-App-Version-In-The-Deck-Index) · [Roadmap](Roadmap) · [Home](Home)
