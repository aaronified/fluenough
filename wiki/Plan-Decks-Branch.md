# Plan: decks in a branch of their own

Source of truth: this wiki page.

Status: audit written, migration started in stages (2026-11-06). Owner's idea, quoted:
"Can we instead keep all decks in a separate decks branch and the app will then
pull the decks from there? The branch can have deck CI. While the app portion
(main) will have app CI along with checking that it can read the decks from a
sample deck which the deck CI will use as standard?" On old apps: "Old apps:
not a big risk, not many are using the app. This way I will know who even is
using it, lol". So no mirror of the decks stays on main: an app that is not
updated simply stops getting deck updates.

## Owner decisions (2026-11-06), which replace the recommended defaults below

"First create decks and the sample deck. And let the app read the sample deck. Make app ready to read from the decks branch only. Release. Copy the decks to the decks branch, but do not delete anything in main. New deck works will merge into the decks branch. Those on old app still gets the decks they had, those who updated get the new ones."

So: main keeps its decks, frozen (old apps keep reading them); the branch is created from main, so it starts with a copy; the app then reads the branch only. Stages: (1) create the branch; (2) deck CI and the index, min_app and README jobs live on the branch and write there; main's deck-index job stops writing, the `Validate decks` gate stays as a cheap always-reporting job; (3) one main PR: sample deck, tests switched to it, "Released app reads the decks" on the sample, downloader and web read the branch only, CHANGELOG line; (4) the owner releases. Step 7 of the plan below (removing `decks/` from main) is **not** done. The branch is named `decks`, not `decks-live`: see the first finding, which needs the `decks/*` branches renamed or deleted first.

## Decision recorded

| Option | What | Verdict |
|---|---|---|
| **A. A long-lived branch in this repo** | Deck PRs target it; main keeps app, tools, `assets/` and a sample deck. | **Owner's pick.** Same repo: tags, releases, issues, wiki, Pages and the `ADMIN_TOKEN` stay as they are; the app changes one base URL. |
| B. A second repository | `fluenough-decks`. | Cleaner permissions, but a second set of issues, tokens, rulesets and Pages, and the validator needs the app repo's tags and `assets/languages.yaml` anyway. Rejected: more to run for one owner. |
| C. Path filters on main | Keep one branch, skip app jobs on deck PRs. | Already done (`Which parts changed`, 2026-11-02). It saves runners but does not decouple: a deck still reaches main only after the 8 test shards read it, and main still holds 103 MB of decks (66 MB of it fonts). Rejected: does not give the owner's separation. |

## Two findings that shape option A

1. **The branch cannot be called `decks`.** Git cannot hold a branch `decks`
   and branches `decks/...` together (a ref cannot be both a file and a
   folder). 20+ remote branches are named `decks/...` (`decks/ja-b1`,
   `decks/fr-b1`, `decks/ta-a1`, ...). Name it `decks-live` (recommended;
   `decks-next` already exists with the same style), or rename every
   `decks/*` branch first. This page says `decks-live` from here on.
2. **About 45 test files read the real decks without saying so.**
   `AppState.test(...)` with no `decks:` argument, and the shared harness
   (`test/support/harness.dart`), default to `RepositoryDeckSource()`
   (`lib/app/app_state.dart:371`), which reads the checkout's
   `decks/index.json` and every file it lists. That is the hard part (below).

## Audit 1: everything that reads decks or assumes `decks/` is in the checkout

### The app and the web build

| Where | What it does | Change |
|---|---|---|
| `lib/core/decks/deck_fetch.dart` `GitHubDeckFetcher.defaultBase` | `https://raw.githubusercontent.com/aaronified/fluenough/main/`; paths like `decks/index.json` are resolved against it. | One constant to `.../decks-live/`. Keep the `decks/` folder inside the branch so every path in the index and in the app stays the same. Needs an app release. |
| `lib/app/web_deck_fetcher.dart`, `lib/core/network/network_probe.dart` | Both use `defaultBase`. | Follow the constant. The web app is built from main, so it follows on the next Pages deploy (no old web clients to worry about, the site is replaced). |
| `tools/web/sw.js` | Never caches `<scope>/decks/` (same origin only); decks come from `raw.githubusercontent.com`. | None. |
| `pubspec.yaml` assets | Bundles `decks/themes.yaml` (and `assets/languages.yaml`, `assets/pictures/`, `assets/synonyms/en.yaml`). The app bundles no deck. | `themes.yaml` is the one deck-folder file the app compiles in: move it to `assets/themes.yaml` on main (`index.json` `bundled` lists it; the validator reads it back from there). |
| `lib/app/repository_decks.dart`, `lib/features/downloads/download_fixtures.dart`, `lib/features/placement/picker_fixtures.dart`, `lib/core/data/course_path.dart` | Test and fixture code in `lib/` that names `decks/` paths. | Point `RepositoryDeckSource` at a root from `FLUENOUGH_DECKS_ROOT` (default: the sample deck). |
| `test/live/github_downloads_test.dart` + CI job `App: live downloads` | Downloads from real GitHub through the app's fetcher. | Follows `defaultBase`; reads whatever `decks-live` has. Keep it on main CI (it is the check that the real branch is reachable), but see "Coupling" below. |

### Workflows

| Workflow | Today | Change |
|---|---|---|
| `ci.yml` `changes` ("Which parts changed") | A PR touching only `decks/` skips analyse, live downloads and the APK. | On main: no deck PRs exist, so the job can go; the app jobs always run on a PR. On `decks-live`: its own ci.yml (below). |
| `ci.yml` `decks-index`, `decks-validate`, `decks-tools-*`, `decks` ("Validate decks") | Validator, index, tools' tests (4 of them read real decks: ~20 to 25 minutes each), synonyms. | Split: the deck jobs move to `decks-live`'s CI; main keeps only the tools' tests that use `tools/fixtures` plus a sample-deck validation. |
| `ci.yml` `release-reader` ("Released app reads the decks") | Checks out the latest `v*` tag, replaces its `decks/` with the PR's, runs `tools/release_reader/release_reader_test.dart` there. | Moves to `decks-live`'s CI unchanged in spirit: check out the tag (app code) and overlay the branch's `decks/`. This is the only check that protects installed apps, so it must stay required. |
| `ci.yml` `app-tests` (8 shards) | Downloads the `decks-index` artifact into `decks/`; tests read real decks. | Download nothing; tests read the sample deck. |
| `ci.yml` `app-live` | See above. | Stays. |
| `deck-index.yml` | On push to main touching `decks/`: runs `deck_index.py` and `readme_languages.py`, pushes `decks/index.json` **and README.md** to main with `ADMIN_TOKEN`. | Moves to `decks-live` (index only). The README list needs `index.json` and `assets/languages.yaml`: a small workflow on main (schedule plus `workflow_dispatch`, and `repository_dispatch` from `decks-live`) fetches the index from `decks-live` and regenerates the README. |
| `pages.yml` | Builds web from main; its smoke job skips on `decks/` or docs only PRs. | Drop `decks/` from the filters (harmless to leave). Smoke test uses no deck (check `tools/web_smoke.cjs` against the sample). |
| `release.yml` | Runs the 8 test shards (read committed `decks/index.json`) and `validate_decks.py decks/` before building. | Shards use the sample deck; drop the full validation or point it at the sample (`decks-live` has its own). No release artifact contains decks, so nothing else changes. |
| `feedback-mail.yml` + `tools/review_bot.py` | Triggers on push to main under `decks/**`; the bot builds its PR branches from `origin/main`, opens PRs with `"base": "main"`, validates `decks/<lang>/`, and reads the required-check names for main. | Run against `decks-live`: trigger, `fresh()` base, PR base and compare calls. The bot needs the tools: use the overlay checkout (below). Medium work, tested by `tools/test_review_bot.py`. |
| `roadmap.yml`, `wiki-sync.yml` | Wiki and milestones only. | None. |

There is **no `review-queue.yml`** and no `decks/review-queue.json` or
`docs/review-queue/` in the tree. Review proposals live inside the deck files
(ADR-0038, `proposed:` entries), so they move with `decks/`.

### Tools

| Tool | Reads | Note |
|---|---|---|
| `tools/validate_decks.py` | `decks/**`, `decks/themes.yaml`, `assets/pictures/`, `assets/languages.yaml` (via `deck_index`), `tools/` siblings | Takes `ROOT = parent.parent`; deck root is `ROOT/decks`. |
| `tools/deck_index.py` | `decks/`, `decks/min_app.json`, `assets/languages.yaml`, **`git tag --list 'v*'` and `git show <tag>:assets/languages.yaml`** | `--strict-released` needs the repo's tags: a plus for option A. After the move, a tag's tree has no `decks/`: check that `released_app()` copes with "the tag holds no deck paths". |
| `tools/validate_synonyms.py` | `assets/synonyms/en.yaml` and `decks/` | The synonym sets stay in the app (bundled). |
| `tools/readme_languages.py` | `decks/index.json`, `assets/languages.yaml`, README.md | See `deck-index.yml`. |
| `tools/review_bot.py`, `proposals.py`, `question_answers.py`, `derive_phonetic.py`, `import_*.py`, `split_deck.py`, `set_script_pos.py`, `gen_planned_paths.py`, `snapshot_ask_pin.py` | `decks/` | Deck-side tools: they run in the overlay (below), so they can stay on main. |
| `tools/release_reader/` | `decks/index.json` | Used by the deck CI only. |
| `.gitattributes` | `decks/** text eol=lf`, binary rules for audio, images and fonts | Must move with the decks: the index hashes the bytes GitHub serves. |

### Flutter tests that read real decks (the hard part)

Counted from `grep`, 2026-11-06 (132 files in `test/`):

| Group | Files | What breaks | Fix |
|---|---|---|---|
| Default `AppState.test(...)` without `decks:` (and `test/support/harness.dart`, `paced_learner`, `profiles`, `progress_shared`, `lesson_and_review_shared`, `accessibility_shared`, `nav_bar_walk`, `backup_fixture`) | ~45 | They get real Spanish, Telugu, Bengali, Hindustani and so on. Many of the 24 files that name real card ids (`es-0001`, `te-1034` ...) assert on real cards. | Default to the sample deck; rewrite the assertions that name real ids/counts to sample ids. Mechanical but wide: the largest cost of the whole plan (L). |
| `test/deck_format_catalog_test.dart`, `catalog_snapshot_test.dart`, `catalog_isolate_test.dart`, `deck_format_cards_test.dart` (reads `decks/es/*`), `deck_search_core_test.dart` (reads `decks/themes.yaml`) | 5 | "Main's code parses every real deck" (#524), snapshot of the whole catalog. | These are real-deck tests by nature. Tag them `real-decks`, remove them from main's shards, run them in `decks-live` CI with app code overlaid (see below). |
| `test/deck_downloads_test.dart`, `stored_downloaded_decks_test.dart`, `min_app_test.dart`, `situations_test.dart`, `language_resources_test.dart` and the `support/*_course.dart` builders | ~10 | Use `FakeDeckRemote.repo()` (the committed index as served) or inline YAML. | `FakeDeckRemote.repo()` reads the sample; the inline ones are untouched. |
| `grading_test.dart`, `ipa_switch_everywhere_test.dart`, `progress_decks_test.dart` | 3 | Already use the frozen copy `test/fixtures/ask_pin/decks` (es, te, ipa, with its own `index.json` and `themes.yaml`, refreshed by `tools/snapshot_ask_pin.py`). | Already the pattern. |
| Python tools' tests that read real decks | 4 tests | `test_validate_b1.py::PathAcrossDecks`, `::Compatibility::test_todays_decks...`, `test_validate_card_ids.py` (2) | Move to `decks-live` CI; they are what makes "Decks: tools' tests" slow. |

So the sample deck is **not new**: `test/fixtures/ask_pin/decks` is a frozen
real subset made for one test. The plan promotes it.

## Audit 2: the contract between app and decks

What the app needs from a deck set, all checked today by the validator and
read by `lib/core/decks/deck_index.dart`:

| Part | Contract |
|---|---|
| `decks/index.json` | `version` (app supports `supportedIndexVersion = 1`; a higher one stops all downloads and asks for an update), `schema` (1), `bundled` (list: `decks/themes.yaml`), `languages` (a list; per language: name, own name, icon, script, scripts, native languages, path order, unit plans, `files`, `script_guides`, `media`, `fonts`, `resources`, `size`, optional `min_app`). Per file: `path`, `size`, `sha256`, `content_sha256`, `schema`, `kind`, native language, core id, `part`, `proposed`. Unknown keys are ignored by apps that do not know them. |
| `decks/min_app.json` | `{"languages": {code: "x.y.z"}, "files": {path: "x.y.z"}}`; written into the index (ADR-0052). Never set for what the latest release already reads. |
| File layout | `decks/<lang>/<lang>-<name>.yaml` cores, `decks/<lang>/<native>/<lang>-<native>-<name>.yaml` layers, `<lang>-path.yaml`, `audio/`, `images/`, `decks/fonts/<script>/`. |
| Kinds | `vocab, grammar, facts, situations, themes, numbers, path, sounds, script, reading, rules, layer, resources, phonetics`; each file has `schema: 1`. |
| Rules that keep installed apps working | Card ids permanent; keys the latest release rejects (`warning`, `not_synonyms`, ...) only after a release that reads them ("Released app reads the decks"). |

### The sample deck

Promote `test/fixtures/ask_pin/decks` to **`assets/sample-decks/`** on main
(under `assets/` so it is not a "test" detail, and not in `pubspec.yaml`: it is
not bundled). Contents: today's es, te and ipa, plus a few small additions so
that one place exercises everything: one file of each `kind` above, a layer in
two native languages, a script guide, a resources file, a media file of each
type, a font entry, a `min_app` entry, a `proposed:` card, and an index with
`script_guides`, `media`, `fonts`, `resources`, `bundled`. It is generated by
`tools/snapshot_ask_pin.py` (renamed `snapshot_sample_deck.py`) from the real
decks, so the sample stays real; a generator test checks that every kind in
`KINDS` appears. Size: small (the existing copy is 1.9 MB with the b1 and
fsrs fixtures; the sample alone is less).

| CI | Use of the sample |
|---|---|
| Main (app CI) | `flutter test` reads it (default `FLUENOUGH_DECKS_ROOT`); `validate_decks.py assets/sample-decks/` must pass (the format and the app can never drift apart on main); `release-reader`-style check of the latest release against it is optional. |
| `decks-live` (deck CI) | The validator also validates the sample (standard). It also compares **contract versions**: `index.json` `version`/`schema` and `KINDS` of the real decks against the sample's, so a deck PR that uses a newer format than main's sample knows about fails. The real decks are read by the `real-decks` tests with main's app code (overlay). |

### How the two stay in sync

Do **not** make `decks-live` a full copy of main that merges main regularly:
the commit on main that deletes `decks/` would, when merged, delete the decks
on `decks-live`. Instead:

| Piece | Mechanism |
|---|---|
| `decks-live` content | Only `decks/` (with `.gitattributes`), its own `.github/workflows/`, a short README and `CLAUDE.md`-style pointer. |
| Tools and app code in deck CI | **Overlay**: deck CI does `actions/checkout` of main (full history and tags, at `path: app`) and of `decks-live` into `app/decks`, then runs `app/tools/validate_decks.py` and the app tests from `app/`. No merge, no sync, always main's current validator. |
| Pinning when a format changes | A file `TOOLS_REF` on `decks-live` (default `main`) names the main ref the overlay uses; set to the last release tag while a new format rolls out. |
| Sample | Lives on main; the overlay brings it. `decks-live` never copies it. |
| Format change rollout | (1) PR on main: new format + sample updated + `min_app.json` entry design; deck CI (overlay at main) still passes on old decks. (2) App release with the new reader. (3) Only then deck PRs on `decks-live` use the new format; `min_app` gates languages that need it for apps not yet updated (ADR-0052). |

## Plan: migration steps, in order

| # | Step | Risk | Effort | Who |
|---|---|---|---|---|
| 0 | **Name the branch** (`decks-live`, not `decks`; see finding 1) and answer the open questions below. | None | S | Owner |
| 1 | **Decouple tests on main first, nothing moved.** Add `FLUENOUGH_DECKS_ROOT` (default `decks/`), promote the sample to `assets/sample-decks/`, run the shards with `FLUENOUGH_DECKS_ROOT=assets/sample-decks`, tag the 5 real-deck test files `real-decks` and move them out of the shards; rewrite assertions that name real ids. Ship in 3 to 5 PRs by test group. | A test passes against the sample for the wrong reason; a shard weight file (`test/shard_weights.json`) gets stale | L | Sonnet (reviews: one Sonnet each) |
| 2 | **Create `decks-live`** from main: `decks/` and `.gitattributes` and workflows. Do **not** delete `decks/` on main yet. Both carry the same decks for a day. | Two copies drift if PRs land in between: freeze deck merges during steps 2 to 5 | S | Sonnet |
| 3 | **Deck CI on `decks-live`**: `ci.yml` with the overlay: validate, index, tools' tests, `release-reader`, `real-decks` tests, synonyms, sample-contract check. `deck-index.yml` moves; README job on main fetches the index. Same job names (`Validate decks`, `Released app reads the decks`). | The overlay checkout of a PR needs fork handling (decks PRs from forks cannot use secrets: not needed here); CI minutes: the 8 shards no longer run per deck PR (a saving) | M | Sonnet; owner for tokens (step 6) |
| 4 | **Ruleset for `decks-live`**: required checks `Validate decks` and `Released app reads the decks`, 1 approving review, strict up-to-date as on main, deletion and non-fast-forward blocked; bypass for the `ADMIN_TOKEN` owner so the index workflow can push. Exempt from the delete-branch-on-merge cleanup (it is permanent, like `decks-next`). | A required check that never runs blocks every PR: create the workflow first, the rule second | S | **Owner** (repo settings) |
| 5 | **App release that follows the branch**: change `defaultBase`, `CHANGELOG` line, bump. Test: `app-live` reads `decks-live` from raw. Web follows on deploy. | The release must go out **before** main stops serving decks, or phones lose decks; old apps keep reading main's last `decks/` (frozen) and then stop updating: accepted | S (code), M (waiting for the release) | Sonnet code; **owner** runs the Release workflow |
| 6 | **Retarget automations**: `feedback-mail.yml` and `review_bot.py` to `decks-live` (trigger, base, compare, required-check names, `fresh()`); `ADMIN_TOKEN` may push to `decks-live` (ruleset bypass); update `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md` ("deck PRs target `decks-live`", "no stray branches" exemption), wiki pages (Deck-Format "How the app gets decks", ADR-0037 amendment, Deck-Tools, Deck-Building-Guide), and the PR template. | The bot is the most intricate consumer; its tests use a fake git, so a real dry run is needed | M | Sonnet; docs by Haiku or Sonnet |
| 7 | **Remove `decks/` from main** (`git rm`, keep `assets/themes.yaml`), drop deck jobs and filters from `ci.yml`, `pages.yml`, `release.yml`; `tools/` deck-only tests go. Main's clone shrinks by about 100 MB. | The commit on main must never be merged into `decks-live` (no merges in that direction exist by design) | M | Sonnet |
| 8 | **Open deck branches and PRs.** Branches `decks/ja-b1`, `decks/zh-b1`, `decks/fr-b1`, `decks/ta-a1`, `deck/*`: before step 7, rebase each onto `decks-live` (all touch only `decks/`, so `git rebase --onto decks-live main <branch>` is clean unless it also touches tools); change each open PR's base with `gh pr edit --base`. `decks-next`: merge into `decks-live` and retire it (its role, decks waiting for a release, is now `min_app`). | `decks-next` may hold decks that need a newer app: check `min_app.json` first; `index.json` conflicts: take `decks-live`'s | M | Sonnet; **owner** deletes retired remote branches (agents cannot) |

Order of the whole: 0, 1 (long, safe, on main), 2 to 4 (in parallel with the end of 1), 5, 6, 7, 8 (8 before 7).
Step 1 is useful on its own: it speeds main CI whether or not the move happens.

## What stays on main and what moves

| Item | Where after |
|---|---|
| `lib/`, `test/`, `pubspec.yaml`, `android/`, web, `l10n` | main |
| `assets/` (languages.yaml, synonyms, pictures, fonts, voice_apps, deck-template) | main |
| `assets/themes.yaml` (from `decks/themes.yaml`) | main (bundled) |
| `assets/sample-decks/` (new) and its generator | main |
| `tools/` (validator, index, bots, release tools) and their tests that use `tools/fixtures` | main |
| `decks/**` (languages, audio, images, fonts, `index.json`, `min_app.json`, `README.md`) | `decks-live` |
| `.gitattributes` decks rules | `decks-live` (main keeps none) |
| The 4 slow real-deck tools' tests, `release-reader`, `real-decks` Flutter tests | run in `decks-live` CI (code from main) |
| `deck-index.yml` | `decks-live`; README job on main |
| `wiki/`, `docs/`, `CHANGELOG.md`, `README.md`, `CLAUDE.md`, `AGENTS.md` | main (docs still go straight to main) |
| `tools/test_*` for deck tools using `decks/` | split as above |

## Coupling to watch

| Concern | Note |
|---|---|
| Main CI must not depend on `decks-live`'s health | Only the `app-live` job reads `decks-live`; make it non-required or retried so a bad deck merge cannot block an app PR. |
| The "Released app reads the decks" check | Compares the latest release's code with the PR's decks: the guarantee for installed apps. After step 5 the latest release has the new base, so the check also covers the path to `decks-live`. |
| A format change | Never lands in decks first (rollout above). The sample is the contract: its generator test and the `KINDS` comparison make a drift visible. |
| Tags | Releases are tagged on main; `deck_index.py --strict-released` needs `fetch-depth: 0` on the overlay's main checkout. |
| Fonts | 66 MB; `decks-live` clones stay large. Keep as is (a shallow clone in CI). |

## Open questions for the owner

| # | Question | Recommended default |
|---|---|---|
| 1 | Branch name | `decks-live` (`decks` is impossible while `decks/*` branches exist). |
| 2 | `decks-live` holds only `decks/` (overlay in CI), or a full tree merged from main? | Only `decks/` + overlay: no sync merges, no deletion trap. |
| 3 | Real-deck Flutter tests in deck CI with main's app code (overlay), or drop them? | Keep: they are the "main's code parses the PR's decks" check (#524), now in deck CI. |
| 4 | Is `decks-next` retired once `decks-live` exists? | Yes: `min_app` (ADR-0052) replaced its purpose; merge its content first. |
| 5 | Is the app-live job required on main? | No; informational. |
| 6 | Freeze deck merges while steps 2 to 5 run (about a week of waiting for the app release)? | Yes. Deck work is already paused this week by the owner. |
| 7 | README language list refresh: nightly job, or on dispatch from `decks-live`? | Dispatch plus a nightly fallback. |
| 8 | Permissions: who may merge to `decks-live`? | As main: the owner approves; `ADMIN_TOKEN` bypass for the index bot only. |

See also: [ADR-0037](ADR-0037-Decks-Download-From-Main) · [ADR-0052](ADR-0052-Minimum-App-Version-In-The-Deck-Index) · [Deck Format](Deck-Format) · [Plans Index](Plans-Index)
