# Plan: build entire languages as private decks (Your decks)

> **Build ordered** (owner, 2026-11-11): the "user language decks" part is to be built now, after the placement release. This page was revised on 2026-11-11 to the owner's answers of 2026-11-06 (issue #1017). Earlier text that these answers replace is kept in the issue's history.

Source of truth: this wiki page.

Tracker: #1017 (milestone 0.9.0). Builds on #495 (Your decks, set aside 2026-11-04) and #475 (closed).

## What the owner asked

> I need a way to build entire languages as private decks. This will be through the existing your decks entry in settings. Create a plan for this. (owner, 2026-11-04)

## Decisions already made (owner, 2026-11-06, #1017 comments)

| Topic | Decision |
|---|---|
| Package file | One zip renamed `.fnzip`. No gzip or 7zip. |
| New or existing language | A private deck set is either a **new language** or an **update of an existing one**. For an existing language an updated **path file** is required; the units named in it come from the existing decks or from the upload. The path file carries a **"privately modified" marker**, shown in the app wherever the course or path is shown (a small tag). |
| Ids | Every private serial starts with **`fnpd-<iso lang_code>`**. With no ISO code, a `qaa` to `qtz` code that is aligned with the app's own `q` series. Serials never collide with built-in ids. |
| Download to modify | The private decks page lets the learner **download the decks of any existing language** to modify. |
| Core and layer | Allowed (the repository's own shape), as zips are used anyway. |
| Sharing | File to file, offline. Nothing to build. No "Send it to us", no AI helper. |
| No voice or recogniser | Hide the speaking and sound drills for that language. |
| Licence | `CC-BY-SA-4.0` on private decks, as the repository. |
| Fonts | Check font packages for malicious code; **if that cannot be airtight, remove the feature** (phone fonts only). Also: a per-language font upload on the Languages page (switch in the info-dot screen), under the same rule. |
| Audio and images | Not now (pictures come first in curated decks). |
| Limits | **10 MB per language, measured on the `.fnzip` itself** (fonts count inside it; one font at most 2 MB). No limit on the total number of languages; **at most 3 private languages active** at a time; a fourth asks the learner to deactivate one. Unpacked ceiling 30 MB with a compression-ratio check; per file 2 MB; 20,000 cards. |
| Mockup | A fresh one, to be drawn (`docs/mockups/README.md`). |

## Open questions answered (orchestrator, 2026-11-11)

The owner said not to stop for confirmation (CLAUDE.md, 2026-11-07), so the orchestrator took these defaults for the open questions of section 4. They stand until the owner says otherwise.

| # | Question | Decision |
|---|---|---|
| 1 | Progress when a built-in card is edited | An unchanged built-in card stays in the private unit by `ref`; an edited card gets a new `fnpd-` id plus `replaces` |
| 2 | Fonts, audio, images in packages | None in v1: phone fonts and the official Noto set only |
| 3 | Who writes card ids | The author, with the enforced prefix `fnpd-<code>-`; the app never renumbers (replaces #495's app-numbered series) |
| 4 | Packages per language, and the path | One package per language code; a modified private path replaces the built-in path while the package is active |
| 5 | A code later becoming official | The package is flagged "shadowed" (2.10) |

## Decisions taken building the last slice (tasks 19 to 24)

The orchestrator took these defaults (CLAUDE.md, 2026-11-07: do not stop for confirmation); they stand until the owner says otherwise.

| # | Question | Decision |
|---|---|---|
| 1 | What "download a course to change" writes | Copies of the course's **vocab and grammar** cores and their layers, every id rewritten to `fnpd-<code>-`, plus the course's path file **as it is**. The path still names the built-in decks, so an unchanged export teaches what the course did and keeps every card's progress; a learner who edits a copy puts its `fnpd-` id in the path (an edited card is a new card and starts fresh, owner default 5 of 2026-11-13). Facts, sounds, scripts, romanisation, themes, **rules decks and reading decks** are not copied (the path keeps naming them): the first group belongs to the app, and for the rules and reading decks no rewrite that is checked to import has been written |
| 2 | `replaces` | A card of a package may carry `replaces: "<built-in card id>"`. The deck parser accepts the field in a core or single-file card (and nowhere else); nothing else reads it. The import review counts the cards that carry it, and the cards that are only a `ref`, in the note "N cards replace built-in cards. M stay as they are, by reference". The repository's validator refuses the field. The export does not write it: an unchanged copy replaces nothing |
| 3 | A course file that uses YAML aliases | Some of the course's own files do (written by a tool); an import refuses an alias. The export writes such a file out in full, as JSON (valid YAML), so what is exported always imports. A deck that still has an id of the language without the prefix after the rewrite is left out with its layers and counted |
| 4 | A restore and the packages on the phone | It **adds**: each package of the backup is installed through the import's own checks (a lower revision is allowed, a restore replaces), turned off when it would be a fourth active one; a package on the phone that the backup lacks stays, and a backup with no private part changes none. The retired ids a backup carries, and the tombstones of removed packages, are kept |
| 5 | Backup size | Every backup (the learner's, the update's, the restore copy, the delete copy) carries the packages, stored as the `.fnzip` already is. Up to three packages: at most their own sizes (10 MB each) |
| 6 | Starter package and template | The starter is the tiny `qaa` fixture with a comment on every part, written as Dart text (`private_starter.dart`) and zipped when saved, so a test keeps it importing clean. Get a template saves the existing single-deck template |
| 7 | The `deckSend` row | Removed with its feature flag and string; the line under Your decks now says nothing is sent |
| 8 | The Python `--private` check | `tools/validate_private.py` checks the package (level 0 and 2 mirrored from the app) and then each deck and layer with the validator's own rules, ids rewritten from `fnpd-<code>-` to `<code>-`; the validator, outside `--private`, refuses a `fnpd-` id or a private manifest |
| 9 | Limits | Unchanged: the measured numbers below leave room under every limit |

## Goal and non-goals

**Goal.** A learner brings a whole language, or a modified path of one the app teaches, as a private package through Settings, Your decks, and uses it like any course: path, Today, reviews, placement, drills, search. It lives only on the phone and in backups.

**Non-goals.** Uploading or publishing (no "Send it to us", no host). Authoring inside the app. Anything under `decks/`, `decks/index.json` or the released-app check. A deck schema change (`schema: 1` stays). Any change to a built-in card id. A new dependency.

## 1. What exists today

| Piece | Where | Supports | Missing for a whole private language |
|---|---|---|---|
| Added decks store | `lib/app/added_decks.dart` (`DeckStore`, `FileDeckStore`, `MemoryDeckStore`); prefix `added/` | One `<deck id>.yaml` per deck in app storage, read as a `DeckSource` by `DeckCatalog` and marked `bundled: false` | Flat, single files only; no folders, manifest, path, facts or layers; no package id, revision, limits or active flag |
| Catalog | `lib/app/deck_catalog.dart` (`DeckCatalog._load`, `Catalog.parseAll`, `isAdded`) | Pure `parseAll(files)` gives decks plus a `broken` list; isolate parse; SHA-256 snapshot (ADR-0048) | `parseAll` treats every `added/` path as a single-file deck (`isCore`, `isLayer`, `isGuide` are all `!isAdded`), so a language with cores, layers and a path cannot be added today |
| Import check | `lib/app/deck_import.dart` (`checkAddedDeck`), `lib/features/decks/import_page.dart` | Parses one file with `DeckParser`; refuses a bundled deck id or a card id another deck has | One file only; no archive, no findings list beyond the parser's, no id-prefix rule |
| Your decks page | `lib/features/settings/your_decks_page.dart`, `lib/app/features.dart` (`deckTemplates`, `deckSend` incoming) | Upload, list grouped by language, Remove | Language groups, export, update, activate or deactivate, download-to-modify |
| Zip | `lib/core/backup/zip_files.dart` | Reads stored and deflated, refuses encryption, zip64 and bad names; writes **stored only**; `maxEntryBytes` 256 MB | Per-package limits, compression-ratio guard, duplicate-name and traversal checks to confirm, a deflate writer |
| Backup | `lib/core/backup/app_backup.dart`, [Backup-Format](Backup-Format) | Parts listed in the manifest, unknown parts ignored | "A backup never holds deck files"; no `own-decks` part |
| Paths | `lib/core/data/course_path.dart`, ADR-0020 wildcards | `*` places decks a path does not list; a path is per language, shared by natives | A private path that **replaces** the built-in one for an existing language, and a marker |
| Languages | `assets/languages.yaml`, `lib/core/decks/language_catalog.dart`, `lib/features/languages/*` (`LanguageView`), `lib/core/models/deck.dart` (`LanguageInfo`) | A language not in the asset is read from a deck's `language` block | About 12 screens read `languages.yaml` directly (picker, spoken languages, facts, placement); none merges a private language in |
| Validator | `tools/validate_decks.py`, Dart `DeckParser` | The id pattern `^[a-z0-9]+(-[a-z0-9]+)*$`; core ids must start with the language | No `fnpd-` rule or custom mode; core-id rule assumes `<lang>-` |
| Fonts | ADR-0042, `lib/core/decks/script_fonts.dart`, `lib/app/font_check.dart` | Noto per script, phone fallback, a sample-drawing check | Nothing for private scripts beyond the fallback |
| Reviews | `lib/core/data/review_log.dart`, drift `reviews` | Append-only, keyed by a plain card id string, no foreign key to decks | Nothing needed: ids that never change keep progress |
| Placement, Today, drills | `lib/app/placement*.dart`, `daily_plan.dart`, `language_skills.dart` | Work from the catalog's courses | Audit of what each needs of a language (voice, recogniser, facts, numbers, a card minimum) |

Read of the code on 2026-11-11: the main blocker is that the catalog treats everything under `added/` as a single-file deck. Everything else is addition.

## 2. Architecture

### 2.1 The package: `.fnzip`

A zip whose layout is the repository's own, so the app's existing readers parse it unchanged:

```
manifest.yaml                  required: format, package, revision, min_app, language block, licence
<code>-path.yaml               required when modifying an existing language; optional for a new one
<code>/<deck>.yaml             cores, as decks/<lang>/
<code>/<native>/<deck>.yaml    layers
<code>/<code>-facts.yaml, -sounds, -romanisation, ...   optional, same formats
themes.yaml                    optional own themes (official theme ids also allowed)
```

`manifest.yaml`: `format: fluenough-private`, `package: fnpd-<code>` (one package per language code), `revision` (integer, rising, never reused), `kind: new-language | modified-language`, `language:` (code, iso639_3, name, own name, script, scripts, tts, rtl), `min_app`, `license: CC-BY-SA-4.0` (fixed), `based_on` (the course revision, for a modified language). No fonts, audio or images in v1.

### 2.2 Id namespace

| Thing | Rule | Notes |
|---|---|---|
| Package id | `fnpd-<code>` | One package per language code on a phone |
| Deck id | `fnpd-<code>-<slug>` (a layer: the core id plus its native, as the repository does) | Matches the existing id pattern; the `<lang>-` core rule becomes `fnpd-<code>-` for private files |
| Card id | `fnpd-<code>-<NNNN or slug>` | **Written by the author, prefix enforced**; the app does not renumber (replaces #495's app-assigned `user-` series) |
| Code | ISO 639-1, else 639-3, else `qaa` to `qtz` | `q` codes are never official, so no later clash. A same-code package is an Update, never a merge |
| Rule | A file whose ids lack the prefix is an **error** | Built-in ids are therefore unreachable by a private file |

**Permanence.** An id the author wrote is theirs and never changes; the app checks that none repeats inside the package and that the prefix holds. The app keeps a **retired list** per package (ids that vanished in an update) and blocks a later revision that gives a retired id to a different card. That is the whole key map: no counter, no renumbering, no database change (AGENTS.md rule 9).

**Modifying an existing language.** The download-to-modify export (the course's decks are already on the phone) writes a `.fnzip` of the course's files with every id rewritten to `fnpd-<code>-...` and a `replaces: <built-in id>` field on each changed card. Open (question 1): a new id does not carry the built-in card's progress. Proposed: an **unchanged** card stays in the unit by a `ref:` to its built-in id (the catalog supports `ref`), so its history stays; an **edited** card gets a new `fnpd-` id and `replaces` hides the original in this learner's path only. The private path file lists the units; a unit may name built-in decks (`te-home`) or the package's own.

### 2.3 On-device storage

```
<app support>/private/index.json         packages: id, revision, active, kind, sha256, size, imported_at, retired ids
<app support>/private/<package id>/...   unpacked files, written under names the app picks
<app support>/private/staging/           one import in progress; deleted on cancel or after commit
```

A new `PrivateStore` (an interface like `DeckStore`, with memory and file implementations). The catalog reads each **active** package as a `DeckSource` under the prefix `private/<package id>/`, `bundled: false`, with a new `private` flag on `DeckEntry`. Inactive packages are not read at all (launch time). Files never go to `downloaded/`, `added/`, `decks/index.json` or the update check. Commit is atomic: unpack to staging, validate, rename the directory, then write `index.json`.

### 2.4 Import and validation

Reuse the app's own readers; do not write a second parser. Staging means `Catalog.parseAll` over the package files (with the built-in files too when `kind` is modified); its `broken` list is level 1.

| Level | Check | Blocks |
|---|---|---|
| 0 Safe | Archive at most 10 MB; entry names (no absolute path, `..`, backslash, drive, duplicates, symlinks, encryption, zip64); per file 2 MB; unpacked 30 MB; compression ratio; 1,000 files; `.yaml` and `.json` only; UTF-8; YAML depth 32, no aliases or custom tags | Error |
| 1 Readable | `parseAll` on the staged files: every deck, path, theme and facts file parses | Error |
| 2 Consistent | Manifest valid; every id has the prefix and is unique; language code rules; every path unit names a deck that exists (package or built-in); at most 20,000 cards; readings on cards of non-Latin scripts (warning); `min_app` | Error or warning |
| 3 Quality | A small Dart subset of the validator's learner-useful checks (quoted scalars, stem notes), one rule per fixture; the Python tool gets a `--private` mode that runs the same fixtures | Warning |

The full `tools/validate_decks.py` stays CI-only. Shared rule fixtures keep Dart and Python in step.

### 2.5 Registering the language

A `PrivateLanguages` service turns each active manifest into a `LanguageInfo` and a `SpokenLanguage`, merged into one **language directory** that the Languages page, the pickers, facts and placement read instead of loading `assets/languages.yaml` directly (about 12 call sites). Shown as "Yours" with a tag. At import and on activation the app checks voice, recogniser and a font sample; a language lacking a voice or recogniser hides its speaking and sound drills (decision 5); boxes in the sample give a warning and the phone-font fallback.

Path and units: a new language's path is used as is; without one, the decks are one unit in file order. A modified language's private path **replaces** the built-in path for that code while the package is active (a private `LanguagePath` wins over the bundled one), and carries `privately_modified: true`, shown as a tag on the course, path and Today. Wildcards (ADR-0020) still work. Placement for a private language builds from its path; the audit of `placement_bank.dart` finds its minimum card count.

### 2.6 FSRS and reviews

Unchanged: `reviews` is keyed by card id, append-only. Remove, deactivate and update never touch it. Re-adding the package, or a later revision that keeps ids, picks the progress up. A card dropped by an update keeps its history and its retired id.

### 2.7 Backup, export, delete

| Action | Behaviour |
|---|---|
| Backup | New parts `own-decks.json` (index) and `own-decks/<package>.fnzip` (as imported, deflated); format `version` stays 1, manifest `parts` names it, the restore screen names the private languages it holds; the Backup-Format line "never holds deck files" becomes "except the learner's own packages". Needs a deflate writer; three packages are at most 30 MB |
| Export | Writes the package's current `.fnzip` through the system file dialog; the same file re-imports on another phone |
| Update | A newer `.fnzip` with the same package id; summary (new, changed, removed cards, retired ids) before commit; a lower revision needs a confirm |
| Remove | Asks first, error colour; deletes files and index entry; review history stays for good (ADR-0020) |
| Deactivate | Keeps files, drops the package from the catalog; needed for the 3-active cap |

### 2.8 Privacy

Private files are not in `decks/index.json`, the update check, reviewer mail, in-app reports or log exports (ids only; the `fnpd-` prefix shows that private cards exist, which is acceptable); no network call mentions a package. `deckSend` is retired (decision 3). A test fails if any outbound path reads the private store.

### 2.9 Fonts (decision 9)

Assessment: a font is an untrusted binary decoded by the platform text engine; the app cannot make a check "airtight" without vetting that engine's parser. Per the owner's rule, **v1 has no fonts in packages and no font upload**: phone fonts, the official Noto set (ADR-0042) and the sample check. The per-language font picker offers only installed or official fonts. Owner to confirm (question 2).

### 2.10 When the language later gains a built-in course

A `q` code never clashes. A real ISO code later added to `languages.yaml`: the package is flagged **shadowed** on the next launch; both courses stay; a one-time notice asks which to use (default: the private course stays active, tagged). Ids never collide by construction, so no progress is lost either way; nothing merges automatically.

### 2.11 Limits

10 MB `.fnzip`; 30 MB unpacked; ratio guard; 2 MB per file; 1,000 files; 20,000 cards; depth 32; 3 active languages (a fourth asks which to deactivate); no cap on installed packages (disk use is shown on the page). Import runs on an isolate with progress. Measure a 5 MB language on a low-end phone before fixing the numbers (ADR-0047).

### Measured limits (task 24)

Measured on 2026-11-13 with the app's own pure-Dart code (`PrivateExport`, `ZipFiles`, `PrivateCheck`, the `yaml` package) run on the Dart VM 3.13 of a desktop machine, on the real courses of this repository exported with "Download a course to change". **These are desktop numbers, not a phone's.**

| Course | Files | Cards | Text | `.fnzip` | Text / file |
|---|---|---|---|---|---|
| Chinese (`zh`) | 572 | 4,379 | 5.34 MB | 1,315,285 B (1.3 MB) | 4.1 |
| Bengali (`bn`) | 396 | 4,054 | 4.11 MB | 959,898 B (0.9 MB) | 4.3 |
| Hindustani (`hi`) | 316 | 2,586 | 4.51 MB | 881,190 B (0.8 MB) | 5.1 |
| Spanish (`es`) | 328 | 2,536 | 3.13 MB | 699,805 B (0.7 MB) | 4.5 |
| Telugu (`te`) | 270 | 3,625 | 3.51 MB | 734,156 B (0.7 MB) | 4.8 |

- **What binds first.** Against the limits, the largest course (Chinese) uses 57% of the 1,000 files, 22% of the 20,000 cards (cards in cores, not the cells of grammar decks), 18% of the 30 MB unpacked, 13% of the 10 MB file. The largest single file in all the decks is 648,090 bytes (bn-grammar-noun-forms), 32% of the 2 MB limit. No built-in course has more than 571 files. At the observed text-to-file ratio of 4.1 to 5.1 the 30 MB unpacked ceiling is reached at a 6 to 7 MB file, so it binds before the 10 MB file limit would. The 100 times ratio guard was not measured per entry.
- **Time, desktop VM, one isolate, for Chinese (5.3 MB of text):** copying the course into a package 1.7 to 2.5 s; writing the `.fnzip` 0.35 to 0.4 s; opening it with the limits about 0.05 s (Telugu); level 0 1.1 to 1.2 s; counting 0.7 s; level 2 1.5 s; reading all its YAML once 0.3 s (Telugu). Level 0, counting and level 2 each read the YAML again, and the catalog reads it a fourth time, so an import costs about four reads of the package: about 3.4 s of CPU on the desktop before the catalog parses it.
- **Not measured:** a phone (the numbers above would be several times higher on a low-end one: ADR-0047's "the app must not lag" has not been checked for an import), the catalog's own parse of a package (it needs Flutter), and a package of 5 MB packed: no real package here is above 1.3 MB, and a synthetic one made by repeating cards compresses unrealistically (ratio 7 to 8), so none is quoted.
- **Finding.** The import runs the checks on the UI isolate (`stagePrivateArchive`), and the review page waits on them. For a course-sized package that is seconds of work on a desktop and more on a phone. The plan (2.11) said "import runs on an isolate with progress": **this is not built**, and is left as a follow-up. The pure checks (`ZipFiles.decode`, level 0, counts, level 2) take only plain data, so they can move into an isolate without touching the store.
- **Numbers adjusted:** none. Every limit has room for the app's largest course, and a language of 20,000 cards would need about 4 to 5 MB packed.

## 3. Byte-sized tasks, in dependency order

H = Haiku-suitable; S = Sonnet only. One pull request each; CI only (no local test runs). Never touch: `decks/`, the drift schema (no migration), built-in ids, `assets/languages.yaml`.

**Status (2026-11-13):** tasks 1 to 24 are built (slices 1 to 4). What is left is the follow-up noted under "Measured limits": the checks on an isolate.

**Slice 1: import one tiny private language folder and see its first unit (tasks 1 to 6).**

| # | Task | Files | Behaviour and tests | Not touch | Model |
|---|---|---|---|---|---|
| 1 | Tiny fixture language | `test/fixtures/private/qaa-tiny/` (manifest, path, core, `en` layer, 2 units, 6 cards, ids `fnpd-qaa-0001`...) | Parses with `DeckParser`; every later test uses it | `decks/` | H |
| 2 | Id rules | new `lib/core/private/private_ids.dart` (pure Dart) | `hasPrivatePrefix(id, code)`, `packageCode(id)`; table tests: accepts `fnpd-qaa-0001`, refuses `qaa-0001`, `fnpd-QAA`, empty | all else | H |
| 3 | Manifest model | new `lib/core/private/private_manifest.dart` | `PrivateManifest.parse(text)` returns fields or a `FormatException` naming the field; tests: valid, missing package, package differs from `fnpd-<code>`, bad `q` code, wrong licence | deck parser | S |
| 4 | Catalog reads `private/` | `lib/app/deck_catalog.dart`: `private/` paths take the bundled route for core, layer, guide and path (not the `isAdded` route), `DeckEntry.private = true`, `bundled = false`; an id without the prefix goes to `broken` | `parseAll` over the fixture gives its decks and path; a built-in-shaped id is a `BrokenDeck` | `added/` behaviour | S |
| 5 | `PrivateStore` | new `lib/app/private_store.dart`; `DeckCatalog(privateStore:)` | `list`/`read` active packages only; atomic `install(packageId, files)`; memory and file versions; test with the fixture | `added_decks.dart` | S |
| 6 | Dev import and first unit | `lib/app/private_import.dart` (staging, level 1), a widget test | Install the fixture, load the catalog, the course route for `qaa` shows unit 1 and its cards; `LanguageInfo` from the manifest registered minimally | UI beyond a debug entry | S |

**Reading the package (no UI).**

| # | Task | Files | Behaviour and tests | Model |
|---|---|---|---|---|
| 7 | Safe zip reading | `zip_files.dart` `decode(bytes, limits:)`, new `ZipLimits` | Refuses absolute, `..`, backslash, drive, duplicate, symlink, ratio over 100, unpacked over 30 MB, over 1,000 files; hand-built zips | S |
| 8 | Language directory merge | new `lib/core/decks/language_directory.dart`; swap direct `languages.yaml` reads in the Languages, picker, spoken-languages, facts, review-languages and onboarding files | Directory returns assets plus active private ("Yours"); existing tests unchanged; one `qaa` test | S for the directory, H for the mechanical call-site swaps |
| 9 | Level 0 and 2 checks | new `lib/core/private/private_check.dart` | Findings (`severity`, `file`, `line`, token, params) per rule of 2.4; a fixture per rule | S |
| 10 | `.fnzip` to staging | `private_import.dart` | Bytes to files, manifest, levels 0 to 2, counts; refuses over 10 MB and a lower revision of the same package | S |
| 11 | Private path replaces built-in | `deck_catalog.dart` `_coursePaths`; `CoursePath.privatelyModified` | A modified `te` path wins while active, marker true; inactive falls back | S |
| 12 | Retired ids | `private_store.dart`, `private_check.dart` | An update that drops an id records it; a later revision reusing it for another card is an error | S |

**Learner-facing.**

| # | Task | Files | Behaviour | Model |
|---|---|---|---|---|
| 13 | Active cap and activate or deactivate | `private_store.dart`, `private_import.dart` | A fourth install returns `NeedsDeactivation`; tests | S |
| 14 | Capability check | new `lib/app/private_capabilities.dart`, `language_skills.dart` | Voice, recogniser, font sample at import and activation; speaking and sound drills hidden for the language | S |
| 15 | Strings and the "privately modified" tag | `lib/l10n/app_en.arb`, course, path and Today headers | A small tag; no literal strings (`tools/check_ui_strings.py`) | H after 11 |
| 16 | Your decks: package groups | `your_decks_page.dart` | Per language: size, revision, Activate, Update, Export, Remove; **needs the fresh mockup** | S |
| 17 | Import review screen | `lib/features/decks/` | Findings (file, line, card, field), counts, Add disabled while errors; severity as a word; 48 dp; 1.4x text; **needs mockup** | S |
| 18 | Update summary | same | New, changed, removed, retired | S |
| 19 | Export and download-to-modify | new `private_export.dart` | Fixture round trip is stable; a built-in course export rewrites ids to `fnpd-`, adds `replaces` and `ref`s, marks the path | S |
| 20 | Backup part and restore | `app_backup.dart`, `zip_files.dart` (deflate writer), Backup-Format | Round trip; an old reader ignores the part | S (the wiki line: H) |
| 21 | Template, starter package, wiki guide | assets, `Feature.deckTemplates` on, a wiki page "Private language package" | The starter imports clean | H |
| 22 | Validator `--private` mode | `tools/validate_decks.py` and its tests | Accepts `fnpd-` ids, refuses them under `decks/`, shares the fixtures with Dart | S |
| 23 | Retire `deckSend` and #495 leftovers | `features.dart`, `your_decks_page.dart`, Deck-Format "Adding your own deck" | Row gone; section rewritten to this plan | H |
| 24 | Measure limits | a note in this page | A 5 MB package within the ADR-0047 budget; numbers adjusted | S |

Order: 1, 2, 3, 4, 5, 6 (slice 1); 7, 8, 9, 10; 11, 12; 13, 14; 15; mockup; 16 to 19; 20; 21, 22; 23, 24.

## 4. Risks and open questions

| # | Risk or question | Proposed default |
|---|---|---|
| 1 | **Progress when a learner edits a built-in card.** A new `fnpd-` id is a new card, so FSRS state does not carry. | Unchanged cards stay by `ref`; edited ones get a new id plus `replaces`. Owner to confirm, or allow "inherit history from <id>" |
| 2 | **Fonts and the per-language font upload.** A font cannot be vetted airtight. | No fonts in packages; picker limited to installed and official fonts; confirm dropping the upload |
| 3 | Authors write ids themselves (differs from #495's app-assigned series). | Prefix enforced, app never renumbers; confirm |
| 4 | One package per language code; a second package for `te` replaces the first. | Yes |
| 5 | A modified private path replaces the built-in one for that language. | Yes, tagged; built-in one tap away |
| 6 | A real ISO code later becomes official. | "Shadowed" notice, private stays (2.10) |
| 7 | Launch time with three 10 MB languages; placement needs enough cards. | Measure (task 24); inactive packages are not read |
| 8 | Backup grows by up to 30 MB. | Deflate this part |
| 9 | Does `DeckParser` also require `<lang>-` on core ids? | Audit before task 4; allow `fnpd-<code>-` in both |
| 10 | Download-to-modify needs the language downloaded. | Offer only downloaded languages |
| 11 | Scope grows into an editor. | Stays at import, fix and use |

## Staged issues

The staged children in #1017 (stages 0 to 11) are superseded by tasks 1 to 24 above. Each child issue records its `blocked by` links and the `blocked` label (CLAUDE.md).

See also: [Plans-Index](Plans-Index) · [Deck-Format](Deck-Format) · [Backup-Format](Backup-Format) · [ADR-0020](ADR-0020-Added-Decks) · [ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course) · [ADR-0052](ADR-0052-Minimum-App-Version-In-The-Deck-Index) · [Roadmap](Roadmap) · [Home](Home)

See also [Plan-Deck-Kinds-And-Topics](Plan-Deck-Kinds-And-Topics) (D14): a package may carry deck genres, levels, hidden decks, creators, topics and recommendations. The importer must reuse the app's readers and `sections.yaml`, never a list of kinds of its own.
