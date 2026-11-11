# Plan: deck-owned data on decks-live

Owner order, 2026-11-11: "Move themes to decks-live. And not just themes,
anything that is entirely about decks and will change with the decks. Build
whatever you need to for the app to accommodate that."

Before this, `decks/themes.yaml` was bundled in the app (pubspec asset), so a
new theme, a new situations theme for example, needed an edit on main and an
app release. Now every file that is entirely about decks and changes with them
lives on `decks-live` and reaches installed apps through the deck download.
The bundled copy stays only as the fallback for an offline first start and for
apps that cannot read the new file. Main's `decks/` stays frozen for old apps.

## The rule

A file is **deck-owned data** when it is entirely about decks, changes when
decks change, and is not one language's file (a language's own files already
download with that language). Deck-owned data lives on decks-live, is listed
in `decks/index.json` under `shared`, and is downloaded by the app with the
decks. App-level data (languages, fonts, voice apps, synonym sets, emoji
pictures, the placement profiles) stays bundled.

## Audit

Every file the app bundles or reads from main that has to do with decks.

| File | Read by | If it changes under an installed app | Safe to download? | Decision |
|---|---|---|---|---|
| `decks/themes.yaml` | `DeckCatalog.parseAll` kind `themes` (`lib/app/deck_catalog.dart:825`, `parseThemes` in `lib/core/data/themes.dart`), through the asset source (`AssetDeckSource`, pubspec asset) | The catalog reads again after a download; the theme order and names change. A deck naming a theme the bundled copy lacks went to the end of the course until a release. | Yes: schema 1 (a newer schema is refused), `min_app` gating, a hash and size in the index, full parse before use, small | **Move.** Built: index `shared`, `DeckDownloads`, `SharedDeckSource` before the bundled asset. |
| `decks/min_app.json` | `tools/deck_index.py` only (`load_min_app`), written into the index as `min_app` | Nothing in the app reads the file; it already reaches the app through the index | Not needed | **Keep.** It is an input of the index tool, and its effect already travels with the index. Its entries for shared files are written to their `shared` entry. |
| `decks/review-queue.json` | `DeckDownloads.refreshReviewQueue` (`lib/app/deck_downloads.dart`), fetched from decks-live once a day | Already deck-owned: read from decks-live, kept as a note, offline copy used | Already is | **Already moved.** No change. |
| `decks/<lang>/<lang>-resources.yaml` (#832) | `DeckDownloads.resourcesFor` (`lib/app/deck_downloads.dart`), listed per language in the index | Already deck-owned: fetched on demand, hash checked, kept | Already is | **Already moved.** No change. |
| Per-language files: path, facts, romanisation, sounds, script guides, situations, number rules, phonology (`kind` of each) | `DeckCatalog.parseAll` (`lib/app/deck_catalog.dart:780-870`), listed in the index per language | Already download with their language and update with it | Already is | **Already moved.** No change. |
| Fonts per script (`decks/fonts/`) and recordings and images (`decks/<lang>/audio`, `images`) | `DeckDownloads` | Already downloaded by the index | Already is | **Already moved.** No change. |
| `assets/placement_profiles.json` | `loadPlacementProfiles` (`lib/app/placement_profiles.dart:19`), once per launch | Placement calibration and a kill switch; changing it changes how Find my level scores | It parses safely to the built-in default | **Keep for now.** It is about the placement algorithm (and holds a kill switch), not about deck content. If the owner wants per-language calibration to move with the decks, it is one line in `SHARED` and one loader (the layer below is generic). |
| `assets/languages.yaml` | Language lists, pickers, fonts (`lib/app/language_offer.dart`, `lib/features/profiles/spoken_languages_picker.dart`), the validator and `deck_index.py` (scripts) | A new language needs fonts, speech engines and a path generator, which are code | No: app-level, ties to app code | **Keep** (owner: languages stay bundled unless a deck-only part shows). No deck-only part: its fields are the language's script, family, aliases and speech, all read by app code. |
| `assets/pictures/` (86 emoji PNGs) | `card.dart:978` maps a card's emoji to its picture | A deck using a new emoji shows no picture until the app has the PNG | Binary files; needs a media-style download | **Keep, flagged.** This is the one remaining deck-driven gap: new emoji need an app release. Moving it means serving the PNGs from decks-live like card images. Separate task. |
| `assets/synonyms/en.yaml` | `lib/app/synonym_loader.dart:10` | English grading synonyms, not tied to a deck | Yes, but it is not about decks | **Keep.** App-level grading data. |
| `assets/voice_apps.yaml` | `lib/features/settings/voices_page.dart:67` | Android text-to-speech apps | Not about decks | **Keep.** |
| `assets/deck-template.yaml` | `lib/features/decks/import_page.dart:53` | A learner's template, with the theme ids in a comment | A comment, not data | **Keep.** The comment's list is advice, never read; a theme missing from it costs nothing. |
| Deck kinds, tag lists, deck-format fields | `DeckParser`, `DeckCatalog.checkFile` | Parsers are code: a new kind needs an app release, whatever the file | No | **Keep.** Gated by `min_app` and `schema` already. |
| `lib/l10n/app_en.arb` theme names | none: theme names come from `themes.yaml` | n/a | n/a | Nothing to move. No theme is hard-coded in `lib/`. |

## How it works

### decks-live side

- `decks/themes.yaml` is edited on decks-live. The validator
  (`tools/validate_decks.py`, kind `themes`) already validates it on every
  decks-live pull request; no new rule was needed.
- `tools/deck_index.py` writes the index's new `shared` list, one file to a
  line: `path`, `size`, `sha256`, `content_sha256`, `schema`, `kind`, and
  `min_app` when `decks/min_app.json` lists the path under `files`.
  `SHARED` in the tool names the files. The index stays version 1: an older
  app ignores the key. `bundled` stays, for the apps before this one and for
  the tests' repository source.
- The index on decks-live gains `shared` at the next merge that touches
  `decks/` (the deck-index workflow), or by running that workflow by hand.
- CI check: decks-live's CI lays main's tools over the checkout and runs
  `tools/check_themes_in_sync.py`: decks-live's themes may be ahead of main's
  bundled copy, but must keep every theme id of it (ids are permanent).

### App side

- `lib/core/decks/shared_data.dart`: the files the app can read from the
  downloads (`sharedKinds`), the newest schema of each, the size limit
  (512 KB), the parse of the index's `shared` list (a bad entry costs its
  file and never the index), and the content check (`checkSharedText`, the
  same parser the catalog reads it with).
- `DeckDownloads`: after every index read (`refreshIndex`, the same trigger
  as the decks update), each shared file the index lists, that this app can
  read, whose hash is not the kept one, is downloaded with the usual size and
  SHA-256 check, read with its parser, and only then kept as a note
  (`shared-themes.yaml`). The catalog is read again. A kept file is checked
  again when read at startup (`open`), so an app update that changed the
  parser never uses a stale file.
- `SharedDeckSource` is listed before the bundled assets in `DeckSources`
  (`lib/main.dart`), so a path it lists is read from the download and any
  other from the bundle. No download: the bundled copy.
- Adding a shared file later is: a path in `SHARED` (`deck_index.py`), a kind
  and schema in `shared_data.dart`, a parser call in `checkSharedText`, and a
  reader of `DeckDownloads.sharedTexts`.

### What happens when

| Situation | Result |
|---|---|
| App released before this change | Ignores `shared`; uses its bundled `decks/themes.yaml`. Main's copy is frozen except for the sync rule below. |
| Offline first start | No index, no download; the bundled copy. |
| Online first start, index read | Theme list downloaded and used from then on, offline too. |
| Index lists a newer `schema`, or a `min_app` newer than the app | Not downloaded; the kept or bundled copy stays; a line in the app log. |
| Hash or size differs from the index | Thrown away; the kept or bundled copy stays; logged. |
| File passes the hash but does not parse | Not kept; logged. |
| A kept file no longer parses after an app update | Ignored at startup; the bundled copy is used; logged. |
| Phone full, note cannot be written | Not used this run; logged. |

Every one of those paths writes a line to the app log; none is silent.

## Rules after this change

- `decks/themes.yaml` is edited on decks-live (owner, 2026-11-11), with the
  decks. It is no longer edited only on main.
- Main's `decks/themes.yaml` is the bundled fallback. It is brought up to date
  at the next app release when convenient, never required for a new theme.
- A new shared file follows the five steps above, and the audit table is
  updated.

## Not verified

- The tests (`test/deck_shared_data_test.dart`, `tools/test_deck_index.py`,
  `tools/test_check_themes_in_sync.py`) run only in CI.
- The app was not run on a device with this change.
- decks-live's real `decks/index.json` gets `shared` only after its workflow
  next runs.
