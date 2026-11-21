# Plan: decks-live moves to a separate public repository

Source of truth: this wiki page.

Status: planned, not scheduled (owner: "soon", 2026-11-21). Tracked in [#1677](https://github.com/aaronified/fluenough/issues/1677). Nothing here is built.

**ADR-0003 is not amended yet.** The amendment (code stays GPL-3.0; decks may be CC BY-SA 4.0 or, for whole languages, CC BY-NC) waits until the owner approves this plan. `CLAUDE.md` is not edited either; its `decks-live` rules change in work package 8.

## What the owner decided

2026-11-21: "Ok. Leave out nc for now. We will move decks-live to a separate public repo, fluenough decks, soon. The NC decks will be there as complete NC decks. Like this language is SA, this is NC." Earlier that day the owner argued that decks and fonts are never behind a payment ("Only payments will be about cosmetics and donations") and that NC content would be in downloads, not in the app. See [Owner-Decisions-History](Owner-Decisions-History#nc-content-is-out-for-now-and-decks-live-moves-to-its-own-repository-2026-11-21).

So two things: (1) NC is out today; (2) the move to a repo of its own is the way NC may come back, as whole NC languages only. This reverses the 2026-11-06 choice of option A (a branch, not a second repository) in [Plan-Decks-Branch](Plan-Decks-Branch); that page rejected a second repository as "more to run for one owner", and the licence question is the new reason.

## Why a separate repository helps with NC

- The app (GPL-3.0) and the decks are already separate works: the app bundles no deck and downloads them. F-Droid and forks are weaker objections when NC content is downloaded data kept apart from the app. The F-Droid policy pages could not be read (f-droid.org was not reachable from the agent session), so **nothing is claimed here about F-Droid anti-features**. That check is open.
- A repo root licence can say "CC BY-SA 4.0, except the languages that declare CC BY-NC", which a branch of the code repo cannot say without muddying the repo's own licence.

Constraints that remain:

- No mixed licences inside a deck file. A language is CC BY-SA or CC BY-NC as a whole, core, layers, path, audio and images alike.
- The Play build with paid cosmetics ([#1103](https://github.com/aaronified/fluenough/issues/1103)) is a grey area: NC forbids commercial use of the content, and a paid app that offers NC courses may count. Unresolved; owner decision later.
- The validator must allow NC only on whole NC languages.
- Forks of the code repo no longer inherit deck data.

## What moves and what stays

| Moves to the new repo | Stays on main |
|---|---|
| `decks/` (languages, `index.json`, `min_app.json`, `themes.yaml`, `review-queue.json`), fonts (`decks/fonts/`), audio, images | `lib/`, `test/`, `android/`, web, `pubspec.yaml`, l10n |
| `.gitattributes` rules for decks | `tools/` (validator, index tool, bots) and their tests |
| Deck CI (`ci.yml`), `deck-index.yml`, `review-queue.yml`, the composite action `main-tools` (changes, see work package 4) | `assets/` (languages.yaml, synonyms, pictures, bundled `themes.yaml`), the sample deck `test/fixtures/sample-decks` |
| `docs/review-queue/` (read by `review-queue.yml`) | Release, Pages, roadmap, wiki-sync, readme workflows; `wiki/`, `docs/`, CHANGELOG, `CLAUDE.md`, `AGENTS.md` |

`feedback-mail.yml`, `reviewer-revocation.yml` and the review bot run on main today and fetch `decks-live`; they stay on main or move (work package 5, to decide).

## How the app gets decks

Today `GitHubDeckFetcher.defaultBase` (`lib/core/decks/deck_fetch.dart`) is `https://raw.githubusercontent.com/aaronified/fluenough/decks-live/`; every path in the index (`decks/index.json`, `decks/<lang>/...`) resolves against it. The web build and the network probe use the same constant. The index has `version` (the app supports `supportedIndexVersion = 1`), `schema`, `bundled`, `shared`, `shared_media`, `languages` and per-file `min_app` (ADR-0052).

- **New base**: one constant, to the new repo's raw URL (plus its default branch, for example `.../fluenough-decks/main/`). Keep the `decks/` folder inside the repo so every index path is unchanged. Better: make the base a field the app can be told, so a later move needs no release (see below).
- **Installed apps keep the old base.** The base is compiled in. An app that has not been updated reads `.../fluenough/decks-live/` forever. Installed apps from before `decks-live` still read main's frozen `decks/`.
- **Mirror period (owner decision).** `decks-live` must keep being updated until the installed base has moved. Options: (a) keep it updated for a fixed period after the release that reads the new repo (suggest three months), then freeze it with a last index and a note; (b) mirror: a workflow in the new repo pushes every merge to `decks-live`, so the mirror is automatic; (c) never mirror, as the owner did for main on 2026-11-06 ("not many are using the app"). Cost of (b): the old branch stays a second copy, and NC languages must **not** be mirrored there (they belong in the new repo only, so old apps simply never see them). The index `min_app` gates keep working in the mirror.
- **Avoid this next time.** The release that reads the new repo should read a small pointer first: the old location's `decks/index.json` gains a field naming the new base, so a later move needs only a pointer update. The index schema stays at 1 if the field is additive and optional; apps that do not know it ignore it. Check `parseDeckIndex` for unknown-key handling before relying on this.

## CI across two repositories

Today the decks-live CI lays main's `tools/`, `assets/`, `test/` and the sample deck over the checkout (`.github/actions/main-tools`, 'main' ref, fetched at run time) so deck PRs are held to main's current validator. Options:

| Option | What | Verdict |
|---|---|---|
| A. Check out main at a pinned ref | The action does `actions/checkout` of `aaronified/fluenough` at a ref in a `TOOLS_REF` file (default `main`; a release tag while a format rolls out), as the branch does today, but across repositories. Public repos, so no token. | Recommended: the least change; the sync PRs of lib files never exist. |
| B. Tools as a git submodule at a pinned commit | Reproducible, but the pin needs a bump PR for every validator change. | Rejected for friction. |
| C. Tools as a published package | A versioned `fluenough-tools` artifact. | Heavy; revisit if CI minutes bite. |

Consequences of A: the "sync PRs of lib files" (if any are planned) disappear; "Released app reads the decks" checks out the latest `v*` tag of the code repo and overlays the new repo's `decks/`; `deck_index.py --strict-released` needs the code repo's tags, so the checkout of main uses `fetch-depth: 0`. The two required checks keep their names (`Validate decks`, `Released app reads the decks`). Main's CI must not depend on the decks repo's health: only `app-live` reads it, and it stays informational.

## Automations to retarget

| Piece | Change |
|---|---|
| `deck-index.yml`, `review-queue.yml` | Move; push to the new repo with a token that may bypass its ruleset (`ADMIN_TOKEN` is a secret of the code repo: copy it, scoped to the new repo). |
| Review bot (`tools/review_bot.py`, `DECKS_BRANCH`) | It opens PRs to `decks-live` from `review-bot/*` branches. Point it at the new repo: the GitHub App or token needs `contents` and `pull_requests` write on the new repo; the secrets (`docs/review-bot-setup.md`) move or are duplicated. |
| `feedback-mail.yml`, `reviewer-revocation.yml` | Mail bot and revocation job (opens PRs on `review-bot/*` branches): workflow_run triggers do not cross repositories, so the "after Deck CI" trigger becomes a dispatch from the decks repo's CI, or the bot polls. Needs a design step. |
| Release workflow | Runs shards on the sample deck already; check it names nothing in `decks-live`. |
| README language list (`readme-languages.yml`) | Fetches the new repo's index. |
| Wiki and docs links | Search `decks-live` in `wiki/`, `docs/`, `README.md`, `CONTRIBUTING.md`; update. |
| Issue and PR templates | Add templates to the new repo (the deck PR template and the bug template exist on `decks-live`); keep deck issues in the code repo's tracker (one tracker) unless the owner prefers otherwise. |
| `CLAUDE.md` and `AGENTS.md` | Rules naming `decks-live` and its branches (`decks/*`, `review-bot/*`): update after the move (not now). |

## History

Keep it: `git filter-repo --path decks --path .gitattributes --path .github/...` on a clone of `decks-live`, or a plain push of the `decks-live` branch as the new repo's `main` (keeps main's unrelated history for the first commits). Recommended: plain push of the branch, because the commits are already deck-only and the index and review-queue bot commits stay; run `filter-repo` only if the clone size (fonts, 66 MB) matters. Open PR branches (`decks/ja-b1` and others) are rebased onto the new repo's main; their PRs are re-opened there.

## Licences in the new repo

- **Root `LICENSE`**: CC BY-SA 4.0, covering every language unless it declares otherwise. A `LICENCES.md` explains the rule.
- **Per-language declaration (proposal)**: a file `decks/<lang>/LICENCE` (one SPDX identifier on the first line, then the attribution text) **and** the existing `license` key in every deck file's header (already required by the validator: `"CC-BY-SA-4.0"` today). The validator checks that every file of a language carries the same identifier as that language's `LICENCE` file; the index carries it per language (`license`, additive). Mixed licences inside a language fail validation.
- **NC allow-list**: `CC-BY-NC-4.0` and `CC-BY-NC-SA-4.0`; never ND, unless the owner says. Open decision: only those two, or older versions too.
- **Validator rule**: NC is accepted ONLY for a whole language flagged NC. Today `MEDIA_LICENSE_RE` and `IMAGE_LICENCES` refuse NC for audio and images; the NC language's media may use NC licences, other languages' may not. Shared files (themes, fonts, shared sections, creators) stay BY-SA and may not be NC.
- **Credit rules for NC media**: same shape as today (`source`, `license`, `credit`), with the NC licence named in full; the app shows it on the card's credit line.
- **In the app**: Settings > Sources and the course page show the licence per course. Before downloading an NC course the app asks consent ("This course is licensed CC BY-NC: free for non-commercial use only") and remembers it per course. NC courses are never bundled, never mirrored to `decks-live`, and never part of the sample deck.

## Play and F-Droid

Unresolved; the owner decides later. The Play build with paid cosmetics (#1103) may need to hide NC courses, or the Play build may not offer them at all. F-Droid: the policy pages could not be read from here; someone must read them before any claim. GitHub forks: a fork of the code repo no longer carries decks; forks point their base to the decks repo (or their own).

## Work packages, in order

| # | Package | Blocked by | Risk |
|---|---|---|---|
| 0 | Owner decisions (below); approve this plan | none | None |
| 1 | App: configurable deck base, index carries a licence per language, optional pointer field | 0 | An old reader rejecting a new index key (check `parseDeckIndex`); the "Released app reads the decks" check catches it |
| 2 | Validator: per-language licence, NC allow-list, NC only on whole NC languages; tests | 0 | A mixed-licence language slipping through; fixtures for both cases |
| 3 | Create the repo; push the history; licence files; ruleset (required checks, review, bypass for the index bot); secrets; Pages if used | 0 | Wrong owner or name (renaming later breaks raw URLs; GitHub redirects renames for git but not always for raw URLs) |
| 4 | Deck CI, `deck-index.yml`, `review-queue.yml` in the new repo; `main-tools` checks out the code repo at `TOOLS_REF`; freeze deck merges meanwhile | 3 | Two copies of the decks drift; freeze merges to `decks-live` during the cut-over |
| 5 | Retarget the review bot, mail bot, revocation job, README job; Release workflow check | 3, 4 | Bot App permissions; the cross-repo `workflow_run` gap |
| 6 | App release with the new base, licence display and NC consent (an NC course needs a first NC language to test; use a fixture) | 1, 4 | Phones lose decks if main or `decks-live` stops serving before the release; keep the old location updated until the mirror period ends |
| 7 | Mirror period, then freeze `decks-live` with a last index | 6 | Stale decks for old apps; the owner decides the length |
| 8 | Docs: `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, wiki links, templates; ADR-0003 amendment | plan approval | Rules naming `decks-live` stay wrong until edited |
| 9 | Rebase open deck branches and PRs onto the new repo | 4 | PR history lost; list branches left for the owner to delete (agents cannot delete remote branches) |

## Owner decisions needed

1. **Name and owner of the new repository.** "fluenough decks" suggests `aaronified/fluenough-decks`; a GitHub organisation would give separate permissions for deck contributors.
2. **Mirror period**: how long `decks-live` keeps being updated for installed apps (suggested: three months after the release that reads the new repo, or no mirror, as in 2026-11-06).
3. **NC licence list**: `CC-BY-NC-4.0` and `CC-BY-NC-SA-4.0` (proposed); never ND unless the owner says.
4. **Whether the Play build offers NC courses**, and who reads F-Droid's policy.
5. **Where deck issues live** (the code repo's tracker, as now, or the new repo's).

See also: [Plan-Decks-Branch](Plan-Decks-Branch) · [Plan-Deck-Owned-Data](Plan-Deck-Owned-Data) · [Licence](Licence) · [ADR-0003](ADR-0003-Licence) · [Deck-Licences-and-Quoted-Books](Deck-Licences-and-Quoted-Books) · [Owner-Decisions-History](Owner-Decisions-History) · [Plans Index](Plans-Index)
