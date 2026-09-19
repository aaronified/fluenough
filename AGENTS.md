# Working on Fluenough

Guidance for contributors and the coding agents they work with.

Several people are building this at once, most of them with an agent. That
changes what good contribution looks like: work has to be claimable, diffs have
to stay small, and a confident wrong change has to be hard to make by accident.
This document exists to make those things true.

[CONTRIBUTING.md](CONTRIBUTING.md) covers licensing and how to submit a deck.
This file covers how to work in the repository without colliding with everyone
else.

---

## Start here

**What this is.** A language-agnostic drilling app for basic language skills —
vocabulary, production, listening and grammar — scheduled by spaced repetition,
running offline. Flutter, Android first. A language is *data*, never code:
adding one means adding deck files.

**What state it is in.** The domain layer, deck format, tooling and docs are
written. **The UI is not built.** See [docs/ROADMAP.md](docs/ROADMAP.md).

**One thing you must know before running anything:** the Dart code has never
been compiled. It was written without a Flutter SDK available. The Python
tooling is tested and working; the Dart is not. The first person to run
`flutter analyze` will find real errors. **Fix them; do not conclude the design
is wrong and start over.** If you are that person, say so in your PR so nobody
repeats the work.

---

## Commands

```sh
# Decks — no Flutter toolchain needed, just Python 3.11+ and PyYAML
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
flutter pub get
```

Full toolchain setup, including containers for immutable Linux distributions
and why Waydroid cannot test audio, is in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

---

## Repo map

| Path | What it is | Conflict risk |
|---|---|---|
| `lib/core/models/` | Card, Deck, DrillMode | medium |
| `lib/core/scheduling/` | SM-2. Pure functions | low |
| `lib/core/grading/` | Answer comparison | low |
| `lib/core/tts/` | `TtsEngine` + system implementation | low |
| `lib/core/data/` | drift database, repositories | **high — coordinate** |
| `lib/features/` | UI, one directory per screen area | low if you stay in yours |
| `decks/<lang>/` | Content, one YAML file per deck | very low |
| `tools/` | Python deck validator and importer | low |
| `docs/adr/` | Architecture decision records | low |
| `pubspec.yaml` | Dependencies | **high — coordinate** |

---

## Nine rules

These are ordered by how much damage breaking them does.

### 1. Card ids are permanent. Never renumber, reuse or tidy them.

Every card id keys the review history of every user who has ever studied that
card. Change one and you orphan their progress. Reuse one and you silently
attach old history to new content.

Ids will look inconsistent — `es-core-0001` then `es-core-0010`, gaps
everywhere, `ja-test-no` next to `ja-bare-0001`. **This is not a mess to clean
up.** Making them sequential is the single most destructive change anyone can
make to this repository, it will pass every test, and no reviewer will
necessarily catch it.

To retire a card, delete it. Never repurpose it.

### 2. Quote YAML values that are not obviously prose.

YAML resolves bare `no`, `yes`, `on`, `off`, `true` and `false` to booleans,
and `007` or `1.0` to numbers. The hiragana `の` romanises to `no`, so this is
not hypothetical — it was a real bug in the first draft of `ja-hiragana.yaml`.

```yaml
native: no        # WRONG — the boolean false
native: "no"      # correct
```

`tools/validate_decks.py` catches it and names the cause. Run it.

### 3. `lib/core/models`, `core/scheduling` and `core/grading` import nothing
from Flutter.

That is what keeps them testable in milliseconds with no device or emulator.
`lib/core/tts` is exempt — it wraps a platform plugin by definition.

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

GPL-3.0 with an App Store Distribution Exception, reasoned out in
[ADR-0003](docs/adr/0003-licence.md). It cannot be changed now without the
agreement of every contributor. Do not remove the exception, "simplify" to MIT,
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
it. See [ADR-0005](docs/adr/0005-scheduling.md).

---

## Working alongside other agents

**Claim work before starting.** Comment on the issue saying what you are doing
*and which files you expect to touch*. That second half is what prevents the
collisions, and it is the part people skip.

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

### Files where you should expect contention

`pubspec.yaml`, `lib/core/data/*`, `docs/ROADMAP.md`, `lib/core/models/card.dart`.
Touch them in their own small PR, merged quickly, rather than as part of a
large feature branch that sits open for a week.

---

## Branches, commits, pull requests

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

Agents must not merge their own pull requests. Every change gets human review.

Superseding an existing ADR is a decision, not a refactor. If your change
contradicts one, that is a conversation first — and if agreed, a **new** ADR
marking the old one `Superseded`. Do not edit the reasoning in an accepted ADR.

---

## Failure modes to watch for

Specific to this repository, roughly in order of likelihood:

| The tempting change | Why it is wrong |
|---|---|
| Making card ids sequential and tidy | Destroys every user's review history. Rule 1. |
| "Fixing" `native: "no"` to `native: no` | Reintroduces the YAML boolean bug. Rule 2. |
| Adding a package for something small | Dependencies are a shared cost. Rule 6. |
| Regenerating a deck to change one card | 46-line diff for a 1-line fix. Rule 8. |
| Running `flutter create` and committing the result | Rule 4. |
| Putting scheduling logic in a widget | Makes it untestable without a device. Rule 3. |
| Treating `flutter analyze` errors as a broken design | The Dart was never compiled. Fix the errors. |
| Making the grader stricter so tests look cleaner | Typo tolerance is deliberate — see `docs/DECK-FORMAT.md`. |
| Bundling a neural TTS model | Covers ~10 languages against a language-agnostic goal. [ADR-0002](docs/adr/0002-system-tts.md). |

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

The existing five are worth reading before your first substantial change — they
explain most of what is otherwise surprising about this codebase.

---

## Definition of done

- [ ] `python3 tools/validate_decks.py decks/` passes, if decks changed
- [ ] `flutter analyze` and `flutter test` pass, if code changed — or the PR
      says plainly that they were not run
- [ ] `dart format lib test` applied, and nothing else reformatted
- [ ] No card id renumbered, reused, or removed-and-replaced
- [ ] Tests added for anything touching scheduling or grading
- [ ] An ADR added if an architectural decision was made
- [ ] The PR describes what was verified and what was not
