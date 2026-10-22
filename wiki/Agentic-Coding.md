# Agentic coding

Source of truth: this wiki page.

## Working on Fluenough

Guidance for contributors and the coding agents they work with.

Several people are building this at once, most of them with an agent. That
changes what good contribution looks like: work has to be claimable, diffs have
to stay small, and a confident wrong change has to be hard to make by accident.
This document exists to make those things true.

[Contributing](Contributing) covers licensing and how to submit a deck.
This file covers how to work in the repository without colliding with everyone
else. [Agentic-Coding](Agentic-Coding) adds what the owner has asked of agents working
for them: which model does what, and pushing to main directly. Where it
differs from this file, it wins for the owner's work.

---

## Start here

**What this is.** A language-agnostic drilling app for basic language skills —
vocabulary, production, listening and grammar — scheduled by spaced repetition,
running offline. Flutter, Android first. A language is *data*, never code:
adding one means adding deck files.

**What state it is in.** The domain layer, deck format, tooling and docs are
written. **The UI is built from the design** and progress is saved in a
database; what the backend lacks is shown disabled, marked "Feature incoming"
([ADR-0008](ADR-0008-Unbuilt-Features-Are-Shown-Disabled)). See
[Roadmap](Roadmap).

**The Dart now compiles, as of 2026-09-21.** It was written without a Flutter
SDK available, and for a while nobody had run it. That has been done: on
Flutter 3.47.1, from a clean checkout following the sequence below with
`--platforms=android`,
`flutter analyze` reports no issues, `flutter test` passes (35 tests then;
about 380 now, each checking a behaviour: docs/plans/test-cut.md),
`dart format lib test` changes nothing, and `dart run build_runner build`
succeeds. The Python tooling is tested and working too.

Since then the app has been built and run on Android phones for every
release, which closed #17. What this does **not** tell you: nobody has built
it on macOS or Windows, or generated the iOS folder.

---

## Commands

```sh
# Decks — no Flutter toolchain needed, just Python 3.11+ and PyYAML
python3 tools/deck_index.py                     # after any change to decks/
python3 tools/validate_decks.py decks/          # 0 ok, 1 errors, 2 bad args

# Code — needs the Flutter SDK (3.47+)
flutter analyze
flutter test
dart format lib test
```

First checkout, because `android/` and `ios/` are generated rather than
committed:

```sh
flutter create . --org app --project-name fluenough --platforms=android,ios
rm -f test/widget_test.dart   # generated boilerplate; references MyApp, not ours
python3 tools/brand_android.py   # icon, label, launch screen, permissions, updater, voice settings
flutter pub get
```

Full toolchain setup, including containers for immutable Linux distributions
and why Waydroid cannot test audio, is in
[Development-Setup](Development-Setup).

---

## Repo map

| Path | What it is | Conflict risk |
|---|---|---|
| `lib/core/models/` | Card, Deck, DrillMode | medium |
| `lib/core/scheduling/` | FSRS. Pure functions | low |
| `lib/core/grading/` | Answer comparison | low |
| `lib/core/tts/` | `TtsEngine` + system implementation | low |
| `lib/core/speech/`, `lib/core/sound/` | `SpeechEngine`, `SoundCheckEngine` + system implementations | low |
| `lib/core/data/` | drift database, repositories | **high — coordinate** |
| `lib/features/` | UI, one directory per screen area | low if you stay in yours |
| `lib/l10n/` | Interface strings, one ARB file per locale | low |
| `decks/<lang>/` | Content, one YAML file per deck, or a core and its layers (`decks/<lang>/<native>/`); the language's path, `<lang>-path.yaml`, shared by every native language. The app downloads them from `main` (ADR-0037) | very low |
| `decks/index.json` | What the app downloads, written by `tools/deck_index.py`; CI fails while it is stale | low — regenerate, never hand-edit |
| `tools/` | Python deck validator and importer | low |
| `docs/adr/` | Architecture decision records | low |
| `pubspec.yaml` | Dependencies | **high — coordinate** |

State reaches widgets through AppScope (ADR-0007). No state-management package.

---

## Ten rules

These are ordered by how much damage breaking them does.

### 1. Card ids are permanent. Never renumber, reuse or tidy them.

Every card id keys the review history of every user who has ever studied that
card. Change one and you orphan their progress. Reuse one and you silently
attach old history to new content.

Ids will look inconsistent — `bn-0012` then `bn-0040` in one deck, gaps
everywhere, a deck listing another deck's card by `ref`. **This is not a mess
to clean up.** Making them sequential is the single most destructive change anyone can
make to this repository, it will pass every test, and no reviewer will
necessarily catch it.

To retire a card, delete it. Never repurpose it.

There have been two exceptions, both made before anyone but the maintainer had
progress to lose. #51 renamed every deck and card id once so that an id names
the language a deck is taught from (`es-core-0001` became `es-en-core-0001`).
#143 renamed every card once more, so that an id names only the language
learned (`es-en-core-0001` became `es-0001`), and a word repeated across decks
or courses is one card (ADR-0018). Neither will be repeated. A new card takes
`python3 tools/validate_decks.py --next-id <language>`.

### 2. Quote YAML values that are not obviously prose.

A bare `true` or `false` is a boolean, and `007` or `1.0` a number, however
the field is meant. The validator and the app read plain values as YAML 1.2
does, so a bare `no`, `yes`, `on` or `off` is text to both (the table is
"YAML values" in [Deck-Format](Deck-Format)). Quote it all
the same: YAML 1.1, which PyYAML and many editors still read, makes those
four booleans. The hiragana `の` romanises to `no`, so this is not
hypothetical — it was a real bug in the first draft of the hiragana deck.

```yaml
native: true      # WRONG — the boolean true
native: no        # text here, but the boolean false to YAML 1.1 tools
native: "no"      # correct
```

`tools/validate_decks.py` refuses a boolean or a number where text is
wanted, and for a boolean names the cause. Run it.

### 3. `lib/core/models`, `core/scheduling` and `core/grading` import nothing
from Flutter.

That is what keeps them testable in milliseconds with no device or emulator.
`lib/core/tts`, `lib/core/speech` and `lib/core/sound` are exempt — they
wrap platform plugins by definition.

If you find yourself wanting `BuildContext` in the scheduler, the logic belongs
in the feature layer instead.

### 4. Never commit `android/`, `ios/`, or anything they generate.

They are recreated by `flutter create`. CI does this on every run. Committing
them produces enormous diffs that conflict with everyone.

Never commit a keystore, `key.properties`, or any signing material. The release
workflow restores them from secrets and deletes them afterwards.

### 5. The application id is `app.fluenough`. Do not change it.

Changing it after release breaks upgrades for every existing installation, and
Android offers no recovery.

### 6. Do not add a dependency without agreement first.

Open an issue. Dependencies are a shared cost and this project deliberately has
few. The deck tools are stdlib + PyYAML **on purpose**, so that deck
contributors need no Flutter toolchain — do not add a Python package to them.

### 7. Do not touch the licence.

GPL-3.0 with an App Store Distribution Exception for the code, reasoned out
in [ADR-0003](ADR-0003-Licence); CC BY-SA 4.0 for the decks
([ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa)). It cannot be changed now
without the agreement of every contributor. Do not remove the exception, "simplify" to MIT,
or add a CLA — there is deliberately no CLA.

### 8. Do not reformat or rewrite files you are not changing.

A whole-file reformat hides the three lines that matter and conflicts with
every open branch. Run `dart format lib test`, which is what CI checks, and
nothing more.

Equally: patch generated content, do not regenerate it. Rerunning the hiragana
generator to fix one card rewrites all 46 and produces an unreviewable diff.

### 9. Database migrations are additive, numbered, and coordinated.

`lib/core/data/` is the highest-contention area in the repository. Two agents
writing migration 3 at the same time is a bad afternoon. Claim it in an issue
before you start.

`reviews` is an **append-only log** — never update or delete a row in it. It is
the only table whose loss is irreparable; everything else can be rebuilt from
it. See [ADR-0005](ADR-0005-Scheduling). `leech_actions` is
append-only in the same way.

There is **one exception**, and only one (owner, 2026-10-17: "Logged
exception"): a restore from a backup that the learner has confirmed, after
the app has kept a copy of what it replaces, empties `reviews` and
`leech_actions` and writes the backup's in their place. It goes only
through `AppDatabase.replaceLog`, in one transaction with the import, and
appends a row to the append-only `restores` table saying when, from which
backup, and where the kept copy is. Nothing else may call it, and no other
code path may delete from or update these tables.

### 10. No user-visible string is a literal in a widget.

Every label, title, button, hint, error and piece of interface prose is a token
in `lib/l10n/app_en.arb`, reached through the generated `AppLocalizations`.
English is the base locale and ships built in — it is a translation like any
other, not a default hardcoded into the screens.

```dart
Text('Due today')                  // WRONG
Text(AppLocalizations.of(context)!.dueToday)   // correct
```

Deck content — `target`, `native`, `reading`, `notes` — is not interface text
and stays exactly as it is. So do log messages, exception text, and ids.

Readings are *based on* ISO 15919; never write that they strictly follow it.
Within deck content, a word in a script other than Latin is never left without
its reading: a note says లేదు (lēdu), not లేదు. The validator rejects it; see
"Script in prose" in [Deck-Format](Deck-Format).

The half that gets skipped is not the strings, it is the layout around them.
Use `EdgeInsetsDirectional`, `AlignmentDirectional` and `TextAlign.start`, never
`left` or `right`. Build sentences with placeholders rather than concatenation,
so a translator controls word order. Use ICU `plural`, not `if (n == 1)`. Do not
size a widget to the length of the English string.

This is not anticipating a need. Four of the five starter languages are read by
people whose interface language is not English, and one of them — Urdu — is
right to left (#33). See [ADR-0006](ADR-0006-Interface-Text-Is-Tokens).

---

## Working alongside other agents

**Claim work before starting.** The open issues are the backlog — start there
rather than inventing scope. Comment on the issue saying what you are doing
*and which files you expect to touch*. That second half is what prevents the
collisions, and it is the part people skip.

**Read the plan before the issue.** Most issues are parts of a tracker
labelled `plan`, which links its plan in `docs/plans/`. Read that plan on
`main`, and the plans it names: the issue is a summary, and where the two
differ, the plan is current. A plan that a later one changes says so at its
top. An issue waits for its own "Blocked by" links and for whatever its
tracker or parent waits for, and the milestones give the order
([Roadmap](Roadmap)).

**Check for open PRs touching your files before you begin.** An agent that
reads only the main branch will cheerfully rewrite something already under
review.

**One concern per pull request.** A PR that adds the production drill *and*
refactors the scheduler *and* fixes some formatting cannot be reviewed, and
conflicts with three other branches instead of one.

**Prefer new files to edits in shared ones.** This is why decks are one file
each: two people adding decks never conflict. Apply the same instinct
elsewhere — a new widget file rather than a new method in a shared one.

**Rebase on `main` before opening a PR.** Do not merge `main` into your branch
repeatedly; the history becomes unreadable. Never force-push a branch someone
else is working on.

**If you are blocked on someone else's work, say so in the issue** rather than
implementing your own version of it in parallel. Two implementations of the
same repository interface is the most expensive outcome available here.

### How agents should run work

Two rules, both about where effort is spent.

**Fan out on the cheap tier.** Establishing what this repository already does —
its conventions, its layout, which files a rule reaches, what a document says on
page four — is searching, and searching is mechanical. It goes to a cheap-tier
subagent, every time. Reading the tree into a flagship model's context to answer
one question is the most expensive way to work here, and it is the default
people fall into under time pressure.

| Tier | Work | Model |
| --- | --- | --- |
| cheap | Searching, extraction, parsing, grouping, transcribing | Haiku |
| standard | Writing, synthesis and review with judgement | Sonnet |

For work done for the owner, the table in [Agentic-Coding](Agentic-Coding) decides
instead, along with how many agents may run at once. Opus is used only when
the owner asks (CLAUDE.md, owner, 2026-10-22).

**One review before calling it done** (owner, 2026-10-12: the independent
8/10 rating is dropped; "the review is enough"). A change gets one
independent Sonnet review, which reports only blocking defects it has
confirmed. Fix those, then finish. No rating, no extra verification pass; a
second review runs only if the first caught a breaking bug (CLAUDE.md, owner,
2026-10-22). The work-rating skill (`.claude/skills/work-rating/SKILL.md`) runs only
when the owner asks for a score.

**Tests run only in CI.** No agent runs the tests or the validator locally,
and none is launched just to run them. Push code and deck changes, then read
CI's result, ignoring checks irrelevant to the change (CLAUDE.md, "How the
owner works"). A docs-only push to main needs no CI check (owner, 2026-10-22:
"Doc pushes do not need CI.").

### Tests check behaviour

The owner, 2026-10-20: "there is no need for 4000+ tests. That can easily be
cut down to about 100-500. You are testing every code change. No point in
that at all. You should only check behaviour." A test says what a learner or
a deck author sees happen, not how the code does it. A change adds a test
only for a behaviour no test covers yet, never one per code change, and not
for coverage, for every branch or for every case of a loop. The suite is
already cut down ([Plan-Test-Cut](Plan-Test-Cut)). Other
documents point here.

### Files where you should expect contention

`pubspec.yaml`, `lib/core/data/*`, `docs/ROADMAP.md`, `lib/core/models/card.dart`,
`lib/l10n/app_en.arb`.
Touch them in their own small PR, merged quickly, rather than as part of a
large feature branch that sits open for a week.

---

## Branches, commits, pull requests

`main` is protected. As a contributor you cannot push to it directly: every
change goes through a pull request that needs one approving review, all four
CI jobs green, and every review conversation resolved. Force pushes and branch
deletion are refused. Work on a branch from the start. (An agent's work for
the owner goes through a pull request too, except a change to documentation
only, which the owner has pushed straight to main: see [Agentic-Coding](Agentic-Coding).
A change to decks only needs "Validate decks" and "Released app reads the
decks" green.)

Never create or push git tags; the owner tags releases.

Branch names: `<area>/<short-description>` — `deck/fr-core-100`,
`feat/production-drill`, `fix/grader-article-stripping`, `docs/adr-tts-update`.

Commit subjects in the imperative, under ~70 characters. Explain **why** in the
body; the diff already shows what. If a commit is hard to summarise in one
line, it is probably two commits.

**Disclose agent assistance.** Where an agent wrote a substantial part of a
change, add a trailer:

```
Co-Authored-By: <Agent name> <noreply@example.com>
```

This is not a judgement on agent-written code — it is review context. A
reviewer reads uncompiled agent-written Dart differently from hand-tested code,
and should be told which one they have.

**Say what you actually verified.** "Validator passes, `flutter test` not run —
no SDK available" is a genuinely useful PR description. Claiming tests pass
when they were never run wastes a reviewer's afternoon and is the fastest way
to lose trust in this workflow.

---

## What an agent must not decide alone

Open an issue and get a human answer before:

- changing the licence, or anything in `LICENSE-EXCEPTION.md`
- adding, removing or major-version-bumping a dependency
- changing the deck format schema, or anything that alters card ids
- replacing the scheduling algorithm
- changing the database schema in a non-additive way
- changing the application id or anything about signing

Agents must not merge their own pull requests. Every contributor's change gets
human review.

Superseding an existing ADR is a decision, not a refactor. If your change
contradicts one, that is a conversation first — and if agreed, a **new** ADR
marking the old one `Superseded`. Do not edit the reasoning in an accepted ADR.

---

## Failure modes to watch for

Specific to this repository, roughly in order of likelihood:

| The tempting change | Why it is wrong |
|---|---|
| Making card ids sequential and tidy | Destroys every user's review history. Rule 1. |
| "Fixing" `native: "no"` to `native: no` | Text to the app and the validator, but the boolean false to any YAML 1.1 tool. Rule 2. |
| Adding a package for something small | Dependencies are a shared cost. Rule 6. |
| Regenerating a deck to change one card | 46-line diff for a 1-line fix. Rule 8. |
| Running `flutter create` and committing the result | Rule 4. |
| Putting scheduling logic in a widget | Makes it untestable without a device. Rule 3. |
| Treating a `flutter analyze` error as a broken design | It analysed clean on 3.47.1; an error means your change. Fix it. |
| Typing an English label straight into a widget | Every screen has to be re-laid-out later, not just re-strung. Rule 10. |
| Fanning out repository reading on a pricier model than Haiku | Searching is cheap-tier work. See *How agents should run work*. |
| Making the grader stricter so tests look cleaner | Typo tolerance is deliberate — see `docs/DECK-FORMAT.md`. |
| Bundling a neural TTS model | Covers ~10 languages against a language-agnostic goal. [ADR-0002](ADR-0002-System-Tts). |

When something in this codebase looks inconsistent, check `docs/adr/` before
correcting it. Much of what looks accidental is decided.

---

## Adding an ADR

Architectural decisions go in `docs/adr/NNNN-short-name.md`, numbered
sequentially:

```markdown
# ADR-000N: <the decision, as a statement>

- **Status:** Accepted
- **Date:** YYYY-MM-DD

## Context
What made a decision necessary.

## Decision
What was decided.

## Consequences
What this costs, not only what it buys. Be honest about the downsides.

## Alternatives considered
What was rejected, and why.
```

The ADRs are worth reading before your first substantial change — they
explain most of what is otherwise surprising about this codebase.

---

## Definition of done

- [ ] `python3 tools/validate_decks.py decks/` passes, if decks changed
- [ ] `flutter analyze` and `flutter test` pass, if code changed — or the PR
      says plainly that they were not run
- [ ] `dart format lib test` applied, and nothing else reformatted
- [ ] No card id renumbered, reused, or removed-and-replaced
- [ ] Every card whose base changes its stem (రావడం (rāvaḍam) to వచ్చింది
      (vaccindi)) says so in its notes
- [ ] A new language has `iso639_3` on every language block, and a
      `<code>-facts.yaml` with 30+ facts or an issue for one
- [ ] A test added only if the change adds a behaviour no test covers yet (*Tests check behaviour*)
- [ ] An ADR added if an architectural decision was made
- [ ] No user-visible string is a literal in a widget; new tokens are in
      `lib/l10n/app_en.arb`
- [ ] One independent review found nothing blocking, or its findings are fixed
- [ ] The PR describes what was verified and what was not

---

## CLAUDE.md

The project instructions that agents read, copied from CLAUDE.md:

See [Agentic-Coding](Agentic-Coding) for how to work in this repository.

Read it before making changes. It is short, and three of its rules — card ids
are permanent, YAML scalars must be quoted, and `lib/core` stays free of
Flutter imports — protect against mistakes that pass every test.

## Which model does what (owner, 2026-10-22)

The main session only orchestrates agents; it does not write code or decks
itself. Pick the model by the job:

| Job | Model |
|---|---|
| All coding, small or multi-file, and bug fixes | Sonnet |
| UI mockups | Sonnet |
| Building decks | Haiku |
| Reviews (one per PR, decks included) | Sonnet |
| Docs and audits | Sonnet |
| Fan-outs and large reads | Haiku |

At most **three agents run at the same time, and never more than two
Sonnet** (owner, 2026-10-22). This replaces the earlier Opus rules
(2026-10-09, 2026-10-12, 2026-10-16, 2026-10-17).

**Opus only when the owner explicitly asks**, reviews included (owner,
2026-10-22). Nothing defaults to Opus.

**Reviews** (owner, 2026-10-22): one Sonnet review per pull request. A second
review runs only if the first caught a breaking bug, and it is also Sonnet.
Ratings are opt in (`.claude/skills/work-rating/SKILL.md`).

**Bug fixes are only for decks and reviews** (owner, 2026-10-16: "Don't do
bugfixes that are not relevant to decks and reviews"). Others wait for a
contributor.

## How the owner works (owner, 2026-10-11)

- **Docs straight to main** (owner, 2026-10-17: "Docs go straight to main,
  no PR"). A change to documentation only (Markdown such as `docs/`,
  `CLAUDE.md`, `AGENTS.md`, the READMEs and the skills) is pushed straight to
  main, with no pull request and no review. A change that touches code, a
  deck, `decks/index.json` or the CHANGELOG is not docs only.
- **Pull requests for everything else** (owner, 2026-10-16: "Do use PRs for
  everything", replacing "Push straight to main" of 2026-10-11). Every other
  change goes through a pull request to main
  (or to `decks-next`). Before it merges, CI's checks pass (`flutter
  analyze`, the full `flutter test`, the deck validator and the tools'
  tests) and one review finds nothing blocking (see "Which model does what").
  The owner approves it in review; then merge it
  once CI is green (owner, 2026-10-16, on #529: "I have approved it in
  review. So you should be able to merge").
- **Commit and push often** (owner, 2026-10-15: "Keep committing and pushing
  to a branch frequently"). Long work is committed in small steps and pushed
  to a work branch (`wip/<topic>`) as it goes, so nothing is lost if a
  session ends. Only checked, approved work reaches main or `decks-next`.
- **Releases** (owner, 2026-10-20: "Can the release workflow not
  automatically take care of the release commit? So that I can cut releases
  just from the UI?"). Each pull request adds its own CHANGELOG.md line under
  `## [Unreleased]`; deck content (new or filled decks, paths) is not part of
  a release and stays out of it (owner, 2026-10-19: "This has nothing to do
  with the release. It is content."). The owner releases by running the
  Release workflow from the Actions tab, from main, with the version (like
  `0.5.3`): it bumps `pubspec.yaml` and `lib/app/app_info.dart`, dates the
  changelog, commits, tags and builds (`tools/prepare_release.py`). There is
  no release pull request.
- **Questions.** Ask them as soon as they come up. Record the owner's
  answers, quoted and dated, in the plan and the issue they belong to.
- **Readings.** Readings are *based on* ISO 15919. Never say they strictly
  follow it.
- **Milestones are releases** (0.4.4, 0.5.0, 0.6.0, 0.7.0). The milestone's
  description holds its order. Until the roadmap is generated from them
  (#484), update `docs/ROADMAP.md` by hand to match. Tidy issues and plans
  after work lands, and close issues when done. Tag new issues to a
  milestone only as the owner says.
- **Mockups** follow `docs/mockups/README.md`: build the approved specs
  exactly, never rewrite one without approval, and adapt the older ones.
  Each uses the app's real theme, light and dark, 1.4x text (the app's
  cap, #505), a contrast self-check, and Hindi and Bengali examples, and
  is checked in Chromium. Remove a mockup once its feature is built
  (owner, 2026-10-16: "Remove when built").
  The page holds only the screens and their tweak controls, with what
  changed highlighted (not for a complete overhaul, where everything is
  new); the self-checks and the notes go in a Markdown file of the same
  name beside it, such as `progress-mastery.md` for `progress-mastery.html`
  (owner, 2026-10-22: "keep the self checks and notes separate in an md
  file with the same name as the mockup. Always. Keep the mockup clean").
- **Text size: 1.4x only** (owner, 2026-10-17: "We are now only building
  for 1.4x text"). The app caps text at 1.4x (#505), so layouts, layout
  tests and bug reports go up to 1.4x; a phone set to 2x is drawn at 1.4x.
- **Content.** Keep transliteration in deck prose, and say in a card's notes
  when its base word changes its stem (`docs/DECK-FORMAT.md`).
  Telugu readings write a word-final anusvara (ం) as `ṁ`, course-wide
  (owner, 2026-10-19).
- **Reviewers** are bilingual and the meaning of a card never changes; new
  themes come only by pull request (`docs/plans/reviewing-scope.md`).
- **Tests check behaviour** (owner, 2026-10-20). The rule is in
  [Agentic-Coding](Agentic-Coding), "Tests check behaviour".
- **Tests run only in CI** (owner, 2026-10-17: "You should not run tests
  locally at all"; on the validator: "Why not let ci do it?"; 2026-10-22: "Doc
  pushes do not need CI.").
  No agent runs the tests or the deck validator locally, and none is launched
  just to run tests. CI runs them for free. Code and deck commits are checked
  by CI: after pushing, read CI's result. A docs-only push to main needs no CI
  check.
- **Irrelevant checks** (owner, 2026-10-22). When reading CI for a change,
  ignore failing checks that are irrelevant to it. A deck-only change needs
  only "Validate decks" and "Released app reads the decks" green (#524, owner,
  2026-10-17). An irrelevant failure is fixed in its own pull request, never
  by widening the current change or pushing a fix straight to main.
- **Budget.** Tokens are limited: one review per change (see "Which model
  does what"), no extra verification passes, and no new work unless the owner asks for it.

## Decks before 0.6.0 (owner, 2026-10-18)

"Do not start work on 0.6.0 at all before the full deck work, across all
languages." No 0.6.0 issue is started, planned in code, or built until the
deck work is done.

## Repositories off limits (owner, 2026-10-12)

`homelab-stacks` is not part of this work. Never clone or download it, never
modify it, and never push to it, even if it appears in a session's
repositories.

## Tags (owner, 2026-10-12)

Never create or push git tags. Only the owner tags releases.

## The `direct-code` label (owner, 2026-10-12)

Label an issue `direct-code` once every decision on it is made: the owner's
answers are in the issue, and any mockup it needs is approved. A
contributor can then build it as written, without asking anything. Remove
the label if a new question comes up, and add it when the last one is
answered.

Keep some simple `direct-code` issues for contributors (owner, 2026-10-17:
"You can keep some simple direct-code issues for the contributor as
well"). Leave them the small, self-contained ones, such as a UI bug or a
one-screen tweak. The deck and review work, and anything a deck build
waits on, is built here.

Every language's path and decks are built here (owner, 2026-10-18: "We
will build the paths for every language that we want here. This is to be
a repository of world's languages. The tower of babel, is to rise
again."). This replaces the 2026-10-17 rule that only Telugu and Bengali
were built here; the other courses' decks (#420) and the new courses'
paths are no longer left to contributors.

**Deck priority** (owner, 2026-10-18). Decks are built to B1 in this order:
1. Telugu, 2. Bengali, 3. Spanish, 4. Marathi, 5. Kannada, 6. Assamese,
7. Chinese, 8. Hindustani, 9. Japanese, 10. Korean, 11. Toki Pona (owner,
2026-10-20: "Make it high priority (11th language)"; built next week). "Once these decks are
done till B1 and we have added the movies songs books parts, we can
finally start advertising the app." Other languages' paths and decks
follow.

**Hindustani** is one course (owner, 2026-10-18: "Hindi and Urdu should be
combined as we should not care about socipolitics over linguistics"; chose
"One course, two scripts"). The `hi` course and its card ids stay; it is
renamed Hindustani, teaches the shared colloquial vocabulary, and offers
Devanagari or the Perso-Arabic (Urdu)
script as the learner's script, as Punjabi offers
Gurmukhi or Shahmukhi. Sanskrit- and Persian-leaning synonyms go on the
card. The Urdu path (#602) is folded into it.

## Dependencies are marked, never assumed (owner, 2026-10-12)

When one issue needs another done first, record it on GitHub: set "blocked
by" between the issues and add the `blocked` label. Never rely on both
landing in the same milestone, or on any other timing.

## Contributor DhyanendraSinghSikarwar (2026-10-13)

When the session's GitHub user is `DhyanendraSinghSikarwar`, these rules
replace "Push straight to main" above:

- **Author.** Before the first commit, run:
  `git config user.name "DhyanendraSinghSikarwar"` and
  `git config user.email "87273551+DhyanendraSinghSikarwar@users.noreply.github.com"`.
- **Trailer.** End each commit message with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No
  `Claude-Session` line.
- **Branches and PRs.** One branch and one PR per issue, named
  `issue-<n>-<slug>`. Work without an issue uses a branch name without a
  number. Never push to main.
- **Commits.** One commit per fix, even within a PR. Push each one as soon
  as it is made.
- **Skills.** Use the repo's skills in `.claude/skills/`.
- **Decisions.** Ask whenever in doubt. Never decide alone.

## Skills and agents

The repo's skills and the work-rater agent are listed in [Mockups-and-Skills](Mockups-and-Skills).

See also: [Contributing](Contributing) · [Home](Home)
