# Fluenough

*Fluent enough.*

A language-agnostic drilling app for basic language skills — vocabulary,
production, listening and grammar — scheduled by spaced repetition, running
entirely offline on your phone.

> **Status: design complete, implementation not started.** This repository
> currently contains the architecture, the deck format, example decks, the
> deck validator and the project scaffolding. The Flutter app itself is not
> yet built. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Why "language-agnostic"

Most drilling apps are built around one language and then stretched to fit
others. Fluenough inverts that: **a language is just data.** A deck is a text
file, the card model is a superset that accommodates Latin, syllabic and
logographic scripts alike, and grammar is described by pattern tables rather
than hard-coded rules. Adding a language means adding files, never code.

## What it does

| Drill | Direction | Graded by |
|---|---|---|
| **Recognition** | see target → recall meaning | you (self-assessed) |
| **Production** | see meaning → type target | the app, with diacritic and typo tolerance |
| **Listening** | hear target → answer | the app |
| **Grammar** | prompt + slot → inflected form | the app |

All four share one card model and one scheduler, so a card's difficulty is
tracked per *skill* — you can recognise a word long before you can produce it,
and Fluenough schedules those separately.

### Spaced repetition, with a real audit trail

Scheduling is SM-2. The part that matters more is that **every review is
written to an append-only log** — not just the current interval. That means
your statistics are recomputable, and the scheduling algorithm can be replaced
later without throwing away your history. Most apps store only current state
and can never go back.

### Text to speech

Listening drills use the **operating system's own TTS** — `android.speech.tts`
on Android, `AVSpeechSynthesizer` on iOS — through a pluggable `TtsEngine`
interface. This adds nothing to the download size, needs no network, and
covers far more languages than any bundled model could. Users install voices
through system settings.

A neural backend (Kokoro) is a candidate for a later release; see
[ADR-0002](docs/adr/0002-system-tts.md) for why it is not in v1.

## Decks

Decks are YAML files under [`decks/`](decks/), versioned in git like any other
source. They are diffable, reviewable, and contributed as pull requests.

```yaml
schema: 1
id: es-core-100
name: Spanish Core 100
language: { code: es, name: Spanish, script: latin, tts: es-ES }
native:   { code: en, name: English }
license: CC-BY-SA-4.0
cards:
  - id: es-core-0001
    target: la casa
    native: the house
    tags: [noun, home]
```

The full specification is in [docs/DECK-FORMAT.md](docs/DECK-FORMAT.md).
Validate any deck before opening a pull request:

```sh
python3 tools/validate_decks.py decks/
```

The validator needs only Python 3.11+ and PyYAML — no Flutter toolchain.

## Building

You need the Flutter SDK (3.47+) and, for Android, a JDK and the Android SDK.
The platform folders are **not** committed; generate them on first checkout:

```sh
flutter create . --org app --project-name fluenough --platforms=android,ios
flutter pub get
dart run build_runner build
flutter run
```

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for toolchain setup, including
notes for immutable Linux distributions and a warning about Waydroid and TTS.

## Licence

**GPL-3.0, with an App Store Distribution Exception.**

Fluenough is free software and every fork must stay free software. The
exception exists solely so the app can be distributed through stores whose
terms would otherwise conflict with the GPL; it grants no permission to close
the source. See [LICENSE](LICENSE) and
[LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md), and
[ADR-0003](docs/adr/0003-licence.md) for the reasoning.

Deck content carries its own licence, declared per file.
