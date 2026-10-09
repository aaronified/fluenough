# ADR-0037: Decks download from main, by an index, and update when asked

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

Until now every deck shipped inside the APK, as Flutter assets, one
`pubspec.yaml` entry per language. A fixed card, or a new language, reached
learners only with a new release.

The owner asked (#210, `docs/plans/decks-from-github.md`):

> add another feature so that the app will not get installed with any
> language decks, but download them from github itself on demand (start
> with the deck that the user has chosen, app ready to start once the
> first 5 decks have been downloaded). … the app should also list any
> language deck added in github … deck selections will be based on target
> and native language.

and settled the questions with it: the latest decks on `main`, not the
release's; ready after five decks; English decks where the learner's own
language has none, saying so; updates asked about, with "Not now" leaving
them in Settings; any connection, not only Wi-Fi; removing a language
deletes its files; `themes.yaml` and the spoken-languages list stay in the
app; no token, ever.

Three things constrain it. The app works offline (the welcome screen and
the Settings footer said so), so it may go online only for something the
learner wants; the app update check (ADR-0017) asks GitHub by itself only
once the learner switches that on. A learner's
progress is keyed by card id (AGENTS.md rule 1) and must never be lost,
whatever happens to the files. And the project adds no dependency without
agreement (rule 6): there is no HTTP or hashing package.

## Decision

- **The index.** `decks/index.json`, written by `tools/deck_index.py`,
  lists every language not hidden: its name, own name, icon and script,
  whether it has script decks, the native languages it is taught from, its
  path order, each unit's planned words and the words its decks have per
  native language, and every file with its path, size, SHA-256, schema,
  kind, native language and core id. One file is one line. It lists only
  languages; `decks/themes.yaml` stays bundled, and `index.json` says so.
- **Kept current by CI.** `tools/validate_decks.py decks/` fails while the
  index is not what the tool writes now. It replaces the check that every
  language folder was bundled. `.gitattributes` keeps deck files LF, so the
  hash computed on any checkout is the one GitHub serves.
- **Where from.** `https://raw.githubusercontent.com/aaronified/fluenough/main/`,
  the index first, then each file by its path, through dart:io's own
  `HttpClient`, as the update check reaches GitHub (ADR-0017). No account,
  no token. GitHub learns the phone's address, the files asked for and the
  user agent, `fluenough/<version>`.
- **Where kept.** `downloaded/` in the app's own storage, each file under
  its repository path, so that the catalog reads a downloaded deck as it
  read a bundled one; beside them, what the index said of each file, the
  last index read, and when GitHub was last asked.
- **Checked before use.** Each file must match the index's size and SHA-256
  (computed by a SHA-256 in `lib/core/decks/`, not a package), and must then
  parse as the app reads it. A file that does not match may have changed on
  `main` since the index was read, days ago perhaps: the index is read
  again, once, and the download or update tried again with it, so Try again
  is not stuck on an old index. A batch is written beside its place and
  moved in only when every file is written; a part-file left by a crash is
  deleted at launch. A batch with any file that fails is not used at all:
  the decks already on the phone stay.
- **What a learner gets.** For a language, its own files (path, facts,
  romanisation, sounds, numbers, script guide), its cores, and its decks
  and layers for the native languages the learner speaks; where it has
  none in them, English, and the language list says "Taught from English".
  A file of a newer schema than the app reads is skipped, and Settings
  says the app needs updating; an index of a newer format asks for the
  update outright.
- **Ready after five.** A language can be learned once its own files and
  the first five decks of its path are in (a core alone does not count).
  The rest download behind it, ten decks to a write, each deck's core with
  its layers, and are finished at the next launch if cut short.
- **First launch** lists the index's languages, so a language added on
  GitHub appears without a release. With no connection it says so and
  offers Try again; nothing is bundled to fall back on. An install that
  updates from a version that bundled its decks downloads the languages it
  learns before it opens, the same way.
- **Updates.** At most once a day, at launch, the app reads the index and
  compares it with its files. When a downloaded language has new or changed
  files it asks once; "Not now" leaves the update on Settings > Deck
  downloads and is remembered until the update changes. Card ids are
  permanent, so an update keeps every card's progress. Try again on a
  language whose update failed tries the update again, not only the files
  still missing.
- **The daily check has its own switch, on by default.** "Check
  automatically", on Settings > Deck downloads, kept beside the files
  (`state.json`), not among the settings. Off, the app asks GitHub at
  launch only to finish a download the learner started; "Check for deck
  updates" still works. This differs from ADR-0017, whose automatic check is
  off until switched on, on purpose: the owner asked that the app check for
  deck updates and ask (#210, plan item 5), and the learner chose to get
  decks from GitHub when choosing a language. The request carries what a
  download does: the address, the index's path and the user agent.
- **What the app says.** The welcome screen says "Works offline once your
  language is downloaded", and the Settings footer "Works offline once
  decks are downloaded", not "Works fully offline".
- **Removed upstream.** A file GitHub no longer lists stays on the phone,
  so a learner's cards do not vanish, unless a new file takes its role: a
  deck's core and layer replacing its single file, or a language's new path
  replacing its old one. A language GitHub no longer offers stays, marked
  so.
- **Removing a language** in Settings deletes its files and takes it off
  the languages learned. Progress, in the review log, stays and returns if
  it is downloaded again.

## Consequences

- A fix to a deck reaches learners the next day, without a release, and
  a new language the moment its index line is merged.
- The first launch needs a connection. The app is offline only once its
  decks are in. A learner offline at first launch cannot start, and is
  told why. The welcome screen, the footer and the README no longer say
  the app is fully offline.
- With the daily check on, as it is unless turned off, the app asks GitHub
  for the index once a day at launch: GitHub learns the phone's address
  daily. The README says so, and where to turn it off.
- `main` is now what learners run. A broken deck merged to `main` reaches
  phones, although each file must still parse before it replaces a working
  one. CI's validator is the gate that protects learners now, not the
  release.
- Two merged pull requests that each change decks can leave the index on
  `main` stale if neither was rebased on the other. The validator fails on
  `main` then, and phones refuse the files whose hashes no longer match
  until someone writes the index again. Branch protection that requires a
  branch to be up to date before merging closes this.
- Raw GitHub limits requests per address. A first download of a language
  is about 60 requests; a classroom on one network could meet the limit,
  and is told to try again in a few minutes.
- Tests no longer read bundled assets. `RepositoryDeckSource` reads the
  checkout's `decks/` through its index, so the tests see what a phone that
  downloaded every language has.
- The APK is only a little smaller: the decks were about 2 MB of YAML.

## Alternatives considered

- **Decks from the release tag.** Matches the app exactly, but a fix waits
  for a release, which is what the owner wanted to avoid. The schema field
  carries the compatibility instead.
- **The GitHub contents API.** Lists files without an index, but counts
  against 60 requests an hour from one address, which one language's
  download would nearly spend, and gives no word counts for the picker.
- **A zip per language.** One request, but no per-file update, and an
  unzip dependency or code; a language's files are small and few.
- **Bundling the decks as a fallback.** Keeps the first launch offline, but
  ships stale decks that an update then replaces, and the owner chose a
  smaller install that lists what is on GitHub.
- **The daily check off until switched on, like ADR-0017's.** Kinder to
  privacy, but a learner who never finds the switch would never get a
  fixed deck, which is what the owner asked this for. Reusing ADR-0017's
  switch has the same cost, and mixes two checks the learner may want
  apart.
- **A hashing package (`crypto`).** A new dependency for one function
  (rule 6); SHA-256 is short, and tested against the standard's examples.
