# Contributing to Fluenough

Thank you for considering it. Fluenough is a language-agnostic drilling app —
the whole premise is that a language is *data*, not code, so the most valuable
contributions are often content rather than software.

## Which document do I need?

| You want to | Read |
|---|---|
| Add or fix deck content | This file, then [docs/DECK-FORMAT.md](docs/DECK-FORMAT.md) |
| Write code | This file, then [AGENTS.md](AGENTS.md) |
| Work with a coding agent | [AGENTS.md](AGENTS.md) — the rules that keep parallel work from colliding |
| Understand why something is the way it is | [docs/adr/](docs/adr/) |
| Set up the toolchain | [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) |

**[AGENTS.md](AGENTS.md) is required reading before your first code change**,
whether or not you use an agent. It carries the constraints that are easy to
break and expensive to undo.

---

## Licensing of contributions

Fluenough is **GPL-3.0 with an App Store Distribution Exception** (see
[LICENSE](LICENSE) and [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md)). By
opening a pull request you license your contribution under those same terms.

**There is no CLA.** The exception is part of the project licence from the
first commit rather than something maintainers grant separately, so you keep
your copyright and there is nothing to sign. The reasoning is in
[ADR-0003](docs/adr/0003-licence.md).

A consequence worth understanding: the licence cannot be changed later without
the agreement of every contributor. That is deliberate. It means no one —
including the maintainers — can take this closed-source.

---

## Ways to contribute

Roughly in order of how much they help right now.

### 1. Decks

The most useful thing you can contribute, and it needs **no Flutter toolchain
at all** — just a text editor and Python.

The app ships with three starter decks. It needs many more, in many more
languages, and the people best placed to write a good Hungarian deck are not
necessarily Flutter developers. That asymmetry is the whole reason the deck
format is plain text validated by a standalone Python script.

### 2. The app itself

The domain layer exists; the UI does not. [docs/ROADMAP.md](docs/ROADMAP.md)
lists what is wanted, in order. See *Contributing code* below — and note that
the Dart has never been compiled, which is the first thing to know.

### 3. Bug reports

Especially about text-to-speech, which varies enormously by device and is the
hardest thing for us to test. Use the issue template.

### 4. Documentation

If something here was confusing, that is a bug in this file.

---

## Contributing a deck

### Setup

```sh
git clone <your fork>
cd fluenough
pip install pyyaml        # the only dependency
```

### Write it

1. Read [docs/DECK-FORMAT.md](docs/DECK-FORMAT.md). It is short.
2. Create `decks/<language-code>/<deck-id>.yaml`. The deck id must equal the
   filename stem.
3. Start from an existing deck — [`decks/es/es-core-100.yaml`](decks/es/es-core-100.yaml)
   for vocabulary, [`decks/es/es-grammar-present-ar.yaml`](decks/es/es-grammar-present-ar.yaml)
   for a grammar pattern, [`decks/ja/ja-hiragana.yaml`](decks/ja/ja-hiragana.yaml)
   for a non-Latin script.

Converting an existing wordlist:

```sh
python3 tools/import_csv.py words.csv \
    --id fr-core-100 --name "French Core" \
    --language fr --language-name French --tts fr-FR \
    --license CC0-1.0 > decks/fr/fr-core-100.yaml
```

Then **read the generated card ids before committing.** They are permanent.

### Validate it

```sh
python3 tools/validate_decks.py decks/
```

CI runs exactly this. Errors fail the build; warnings do not, but are usually
worth fixing.

### The four things reviewers check

**You have the right to contribute the content.** Wordlists taken from
textbooks or commercial courses are not acceptable, *even reworded* — a
translated derivative of a copyrighted list is still a derivative. Public
domain frequency lists, Wiktionary (CC-BY-SA-4.0), Tatoeba (CC-BY-2.0-FR) and
your own work are all fine. Declare it in the deck's `license` field.

**Bare values are quoted.** YAML turns `no`, `yes`, `on` and `off` into
booleans. The hiragana `の` romanises to `no`. The validator catches this.

**`language.tts` is set** where the language has meaningful regional variation
— `pt-BR` versus `pt-PT`, `es-ES` versus `es-MX`. Without it, learners get
whatever accent the device defaults to.

**Card ids are new.** Never renumber, reuse, or remove-and-replace an existing
one; they key every user's review history. To retire a card, delete it.

Non-Latin scripts also need `reading` on every card.

### What makes a deck good

Small and focused beats enormous. A hundred well-chosen cards with example
sentences are worth more than a thousand bare word pairs.

Prefer words a beginner will actually meet in their first months. Add `notes`
where a word has a trap in it — grammatical gender that contradicts the
ending, a false friend, a form that only exists in one region. Add `examples`
for anything whose meaning depends on context.

Frequency order is a good default when you are unsure what to include.

---

## Contributing code

### Before you start

**The Dart has never been compiled.** It was written without a Flutter SDK
available. The Python tooling is tested and working; the Dart is not. Expect
`flutter analyze` to report real errors on a fresh checkout — fix them, and say
so in your PR, rather than concluding the design is broken.

**Open an issue before anything substantial**, and say which files you expect
to touch. Several people are working on this in parallel, frequently with
agents, and that one sentence prevents most collisions. See
[AGENTS.md](AGENTS.md#working-alongside-other-agents).

### Setup

```sh
flutter create . --org app --project-name fluenough --platforms=android,ios
rm -f test/widget_test.dart   # generated boilerplate; references MyApp, not ours
flutter pub get
flutter test
```

`android/` and `ios/` are generated, not committed. Full setup — including
containers for immutable Linux distributions, and why Waydroid cannot test
audio — is in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

### While you work

The constraints that matter are in [AGENTS.md](AGENTS.md#nine-rules). The three
that catch people most often:

- `lib/core/models`, `core/scheduling` and `core/grading` import nothing from
  Flutter. That is what keeps them testable without a device.
- Anything touching scheduling or grading needs tests.
- Do not reformat files you are not changing.

Architectural decisions are recorded in `docs/adr/`. **Read the relevant one
before changing something that looks wrong** — much of what appears accidental
in this codebase was decided, and the reasoning is written down.

### Before opening the pull request

```sh
python3 tools/validate_decks.py decks/   # if decks changed
dart format lib test
flutter analyze
flutter test
```

---

## Pull requests

`main` is protected: every change needs a pull request, one approving review,
and green CI. Branch before you start.

**One concern per pull request.** A change that adds a feature, refactors
something and fixes formatting cannot be reviewed properly and conflicts with
every other open branch.

**Explain why in the description**, not what — the diff already shows what.

**Say what you actually verified.** "Validator passes; `flutter test` not run,
no SDK available" is genuinely useful. Claiming tests pass when they were never
run costs a reviewer their afternoon.

**Disclose agent assistance** with a `Co-Authored-By:` trailer where an agent
wrote a substantial part of the change. This is review context, not a
judgement — a reviewer reads uncompiled agent-written code differently, and
should know which they have.

**Rebase on `main`** rather than merging it into your branch repeatedly.

The checklist in the pull request template is the definition of done.

---

## Review

Every change gets human review, including agent-authored ones. Nobody merges
their own pull request.

Expect review to be about *why* as much as *what*. If a change contradicts an
ADR, that is a conversation before it is a diff — and if the decision does
change, it needs a new ADR marking the old one superseded, not an edit to the
reasoning of an accepted one.

Reviews should be specific and about the code. Everyone here is working on
something they care about, usually in their own time.

---

## Reporting bugs

Use the issue template, and include the device and OS version, the app version,
the deck, and the drill mode.

**For silent audio, say whether you were on a physical device, an emulator, or
Waydroid.** Waydroid ships without Google Play Services, which is what provides
the TTS voices, so listening drills are silent there. It is the most common
cause of "audio is broken" reports and is not a bug in Fluenough. Also check
that a voice for the language is installed: on Android, Settings →
Accessibility → Text-to-speech output → install voice data.

---

## Questions

Open an issue. A question that turns out to be a gap in these documents is a
useful contribution in itself.
