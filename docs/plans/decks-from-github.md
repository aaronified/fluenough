# Plan: download decks from GitHub, not bundle them

Written 2026-10-05. **After the B1 plans** (`b1-plans.md`), which the index
is designed around, and before the settings redesign (owner's order:
the skill model (done), `b1-plans.md`, this plan, then the settings redesign).

## What the owner asked

> add another feature so that the app will not get installed with any
> language decks, but download them from github itself on demand (start
> with the deck that the user has chosen, app ready to start once the
> first 5 decks have been downloaded). this is to be the first item on the
> list. and the app should also list any language deck added in github
> (language specific settings will also appear based on the selected
> languages). deck selections will be based on target and native language.

Decided with the owner:

- **Source:** the latest decks on `main`, not the app's release tag. A deck
  in a newer format than the app understands is skipped, and the app says
  to update.
- **Ready:** once the first five decks of the chosen language are in. The
  rest follow in the background.
- **Native language:** decks are chosen by target and native language. Where
  a language has none for the learner's native language, its English decks
  are offered, and the app says so.
- **Updates:** the app checks, then asks whether to update. If the learner
  says no, the update waits on a deck downloads page in Settings.
- **Network:** downloads and updates use any connection, not only Wi-Fi.
- **Removing a language** deletes its files.
- **`themes.yaml` and the spoken-languages list** stay in the app.

## What exists

- Every deck ships in the APK. `pubspec.yaml` lists `decks/themes.yaml` and
  one folder per language. `AssetDeckSource` reads them, behind a
  `DeckSource` interface whose comment already expects "the deck
  repository" to replace it, with "nothing above it" changing.
- The decks are 2.1 MB of YAML in all, about 0.3 MB per language, so the
  APK gets only a little smaller. The gain is that languages and fixes
  reach learners without an app release.
- A language's folder holds more than decks: its path, romanisation, sounds,
  number rules, facts and script guide. All of it would download with the
  language.
- Every deck today teaches from English (`hi-en-…`, `bn-en-…`).
- Decks a learner adds (#22) are kept as files by `FileDeckStore`, under
  `added/`. Downloaded decks can be kept the same way.
- The app already reaches GitHub, for the update check
  (`api.github.com`, releases). It holds no token, and must not (owner's
  rule).
- The Settings pages list `state.languages`, the languages in the catalog.
  With only chosen languages downloaded, their language settings show only
  those, as asked.
- The tests read the bundled decks. They would read `decks/` from the
  repository instead, through a file source.

## What it takes

1. **An index on `main`:** `decks/index.json`, written by a tool
   (`tools/deck_index.py`). It lists every language with:
   - its name, code and icon;
   - the native languages it is taught from;
   - its path order;
   - each file's path, size, SHA-256 and schema;
   - for the language picker that follows (`language-picker.md`): its own
     name, script, whether it has script decks, and the words each path
     unit has and plans, counted by the tool, so the app can calculate
     completeness toward B1 without downloading the decks.

   The validator fails when the index is out of date, so CI keeps it
   current. The app reads it from `raw.githubusercontent.com`, with no
   token.
2. **A download source** beside `AssetDeckSource`:
   - it keeps files under `downloaded/` in the app's storage;
   - it checks each file's SHA-256 before using it;
   - it replaces a file only once the new one is complete.
3. **First launch:**
   - the learner picks languages from the index, so any language added on
     GitHub is listed;
   - the downloads start with the chosen deck;
   - the app opens once the first five decks on that language's path are
     in, and the rest download in the background.

   With no connection, it says so and offers Try again. Nothing is bundled
   to fall back on.
4. **Adding a language later** downloads it the same way. Removing one
   deletes its files but keeps the learner's progress, which is in the
   review log, so downloading it again restores it.
5. **Updates:**
   - the app compares the index with its files, at most once a day;
   - when decks have changed, it asks whether to update;
   - "Not now" leaves the update waiting on **Settings > Deck downloads**.

   That page lists each language, its size and state, and an Update
   button. Card ids are permanent (AGENTS.md), so an update keeps every
   card's progress.
6. **A deck removed from GitHub** stays on the phone, so a learner's cards
   do not vanish.
7. **Remove the language folders from `pubspec.yaml`.** `decks/themes.yaml`
   and `assets/languages.yaml` stay bundled. The tests then read `decks/`
   through a file source. The deck format docs and the README say where
   decks come from.
8. **Privacy:** downloads tell GitHub the phone's IP address, as the update
   check already does. The README says so.
9. **An ADR** for decks from `main`, the index and the update rule.

This also settles the web plan's question (`web-pwa.md`) of whether the web
build carries every language: it downloads them like the app.

## To decide

Nothing left: the owner answered every question above.

## Estimate

About 10–14 hours: 2 for the index and its check, 3 for the source and the
store, 3 for the first launch, 3 for updates and the Settings page, 2 for
moving the tests off bundled decks. Complexity: high, since it changes the
first launch and how every deck is loaded. Confidence: medium-low.
