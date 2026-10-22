# Contributing to Fluenough

Source of truth: this wiki page.


Thank you for considering it. Fluenough is a language-agnostic drilling app —
the whole premise is that a language is *data*, not code, so the most valuable
contributions are often content rather than software.

## Which document do I need?

| You want to | Read |
|---|---|
| Add or fix deck content | [Deck-Format](Deck-Format) (and the licensing rule in [Deck Building Guide](Deck-Building-Guide#contributing-a-deck)) |
| Write code | This file, then [Agentic-Coding](Agentic-Coding) |
| Work with a coding agent | [Agentic-Coding](Agentic-Coding) — the rules that keep parallel work from colliding |
| Understand why something is the way it is | [ADR-Index](ADR-Index) |
| Set up the toolchain | [Development-Setup](Development-Setup) |

**Start with an issue labelled `direct-code`.** It is fully decided: the
owner's answers are in it and any mockup is approved, so you can build it as
written without asking anything. For any other issue, ask first.

**[Agentic-Coding](Agentic-Coding) is required reading before your first code change**,
whether or not you use an agent. It carries the constraints that are easy to
break and expensive to undo.

---

## Licensing of contributions

Fluenough's code is **GPL-3.0 with an App Store Distribution Exception** (see
[LICENSE](https://github.com/aaronified/fluenough/blob/main/LICENSE) and [LICENSE-EXCEPTION.md](https://github.com/aaronified/fluenough/blob/main/LICENSE-EXCEPTION.md)). Its
decks are **CC BY-SA 4.0**, with attribution. By opening a pull request you
license code under the first and deck content under the second
([ADR-0040](ADR-0040-Decks-Are-Cc-By-Sa)). Content once given as
CC0 stays usable, because CC0 allows it.

**There is no CLA.** The exception is part of the project licence from the
first commit rather than something maintainers grant separately, so you keep
your copyright and there is nothing to sign. The reasoning is in
[ADR-0003](ADR-0003-Licence), carried over by ADR-0040.

A consequence worth understanding: the licence cannot be changed later without
the agreement of every contributor. That is deliberate. It means no one —
including the maintainers — can take this closed-source.

---

## Ways to contribute

Roughly in order of how much they help right now.

### 1. Decks

The most useful thing you can contribute, and it needs **no Flutter toolchain
at all** — just a text editor and Python.

The app offers the courses listed in `decks/index.json` (Assamese, Bengali,
Gujarati, Hindustani, Kannada, Marathi, Spanish, Telugu, Japanese, Korean,
Mandarin Chinese, and the IPA and English Braille courses), downloaded from
this repository when a learner chooses one. It needs many more, in many more
languages, and the people best placed to write a good Hungarian deck are not
necessarily Flutter developers. That asymmetry is the whole reason the deck
format is plain text validated by a standalone Python script.

### 2. Translating the interface

Also **no Flutter toolchain** — one JSON file and a text editor.

Every word the app puts on screen is a token rather than a literal, decided in
[ADR-0006](ADR-0006-Interface-Text-Is-Tokens) precisely so that this is
possible. English lives in [`lib/l10n/app_en.arb`](https://github.com/aaronified/fluenough/blob/main/lib/l10n/app_en.arb). To add
a language, copy it to `app_<code>.arb`, change `@@locale`, and translate the
values:

```json
{
  "@@locale": "hi",
  "appTitle": "Fluenough",
  "scaffoldingTagline": "पर्याप्त रूप से धाराप्रवाह।"
}
```

Leave the `@`-prefixed entries out of your copy — they are descriptions for
translators, not text to translate, and they stay in the English file. Anything
you omit falls back to English, so a partial translation is welcome and useful.

If you are translating into a language the app has no deck for yet, that is
still worth doing, and the reverse is true too: the person best placed to write
a good Telugu deck is usually the person best placed to translate the interface
into Telugu.

### 3. The app itself

The app is built and saves progress. [Roadmap](Roadmap)
lists what is wanted, in order, with the plan for each. See *Contributing
code* below.

### 4. Bug reports

Especially about text-to-speech, which varies enormously by device and is the
hardest thing for us to test. Use the issue template.

### 5. Documentation

If something here was confusing, that is a bug in this file.

---

## Contributing a deck

The steps, the licensing rule and the tools to run are in
[Deck Building Guide](Deck-Building-Guide#contributing-a-deck). The format is in
[Deck Format](Deck-Format).

---

## Contributing code

### Before you start

**The Dart compiles, as of 2026-09-21** — on Flutter 3.47.1, `flutter analyze`
is clean and `flutter test` passes. It was written without an SDK available and
went unrun for a while, so that is worth knowing rather than assuming. If
`flutter analyze` reports an error on a fresh checkout, it is most likely your
change rather than the design.

It has since been built and run on Android phones for every release. Nobody
has built it on macOS or Windows, or generated the iOS folder.

**Open an issue before anything substantial**, and say which files you expect
to touch. Several people are working on this in parallel, frequently with
agents, and that one sentence prevents most collisions. See
[AGENTS.md](Agentic-Coding#working-alongside-other-agents).

### Setup

```sh
flutter create . --org app --project-name fluenough --platforms=android,ios
rm -f test/widget_test.dart   # generated boilerplate; references MyApp, not ours
python3 tools/brand_android.py
flutter pub get
flutter test
```

`android/` and `ios/` are generated, not committed. Full setup — including
containers for immutable Linux distributions, and why Waydroid cannot test
audio — is in [Development-Setup](Development-Setup).

### While you work

The constraints that matter are in [AGENTS.md](Agentic-Coding#ten-rules). The four
that catch people most often:

- `lib/core/models`, `core/scheduling` and `core/grading` import nothing from
  Flutter. That is what keeps them testable without a device.
- No user-visible string is a literal in a widget — it is a token in
  `lib/l10n/app_en.arb`. CI checks this.
- Anything touching scheduling or grading needs tests.
- Do not reformat files you are not changing.

Architectural decisions are recorded in `docs/adr/`. **Read the relevant one
before changing something that looks wrong** — much of what appears accidental
in this codebase was decided, and the reasoning is written down.

### Before opening the pull request

```sh
python3 tools/deck_index.py              # if decks changed
python3 tools/validate_decks.py decks/   # if decks changed
python3 tools/check_ui_strings.py lib/   # if you added a widget
dart format lib test
flutter analyze
flutter test
```

---

## Pull requests

`main` is protected: every change from a contributor needs a pull request,
one approving review, and green CI. Branch before you start. A change to
decks only needs the "Validate decks" and "Released app reads the decks"
jobs green: the second reads your decks with the latest release's code, since
phones download decks from main (#524). (Work done for the owner
uses pull requests too, except documentation only, which goes straight to
main; see [Agentic-Coding](Agentic-Coding). Contributors never create
or push tags.)

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

Every contributor's change gets human review, including agent-authored ones.
Nobody merges their own pull request.

Reviewing decks in the app has its own rules: reviewers are bilingual, the
meaning of a card never changes, and a new theme comes only by pull request.
See [Reviewing-Guide](Reviewing-Guide).

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


## Templates

- [Pull request template](https://github.com/aaronified/fluenough/blob/main/.github/PULL_REQUEST_TEMPLATE.md)
- [Bug report template](https://github.com/aaronified/fluenough/blob/main/.github/ISSUE_TEMPLATE/bug_report.md)

See also: [Home](Home)
