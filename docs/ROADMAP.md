# Roadmap

Every item below has an issue. The issues carry the detail — files to touch,
acceptance criteria, and what to read first.

## v0.1 — Core loop
- [ ] `flutter create` the platform folders, wire up CI
- [ ] Models, deck parser, pattern expander
- [ ] drift schema and migrations
- [ ] SM-2 scheduler + review log, with tests
- [ ] `AnswerGrader`, with tests
- [ ] Recognition and production drills
- [ ] Deck browser and per-deck drill launch
- [ ] Two complete starter decks

## v0.2 — Audio and grammar
- [ ] `SystemTtsEngine`, voice availability detection
- [ ] Listening drill, hidden when no voice is installed
- [ ] Grammar drill over expanded patterns
- [ ] Settings: daily new-card cap, drill modes, TTS rate

## v0.3 — Progress
- [ ] Statistics from the review log: accuracy per tag, retention, streaks
- [ ] "Leeches" — cards failed repeatedly
- [ ] Review log export/import as JSONL
- [ ] Daily reminder notification

## v0.4 — Content
- [ ] Import decks from file and URL
- [ ] CSV importer in-app
- [ ] Anki `.apkg` importer
- [ ] More starter decks

## v1.0 — Release
- [ ] Signed APK via GitHub Releases
- [ ] F-Droid metadata and submission
- [ ] Accessibility pass: screen reader, font scaling, contrast
- [ ] Deck authoring guide

## Scripts and pronunciation

Runs alongside the milestones above rather than after them, because the
starter languages need it.

Learning a language written in an unfamiliar script means learning the script
and its pronunciation first, not as an afterthought. Four of the five starter
languages are abugidas — a consonant carries an inherent vowel, vowel signs
attach around it and may be drawn before the letter they are pronounced after,
and conjuncts have shapes not predictable from their parts. The fifth, Urdu,
is right to left, gives every letter four positional forms, and does not write
short vowels at all.

None of that is expressible today, and some of it is actively broken:

- [ ] Extend the `script` enum — Bengali, Gujarati and Telugu cannot currently
      be declared (#27)
- [ ] Unicode normalisation in the grader — without it, correct Indic and Urdu
      answers are marked wrong (#28)
- [ ] An `ipa` field distinct from romanisation (#29)
- [ ] Conventions for script decks: abugidas and positional forms (#30)
- [ ] Minimal-pair drill for aspiration and retroflexion (#31)
- [ ] Grapheme-level TTS fallback (#32)
- [ ] Right-to-left layout (#33)
- [ ] Nastaliq, conjunct and matra rendering (#34)

## Starter languages

Tracked in #35. Each needs a script deck, a core vocabulary deck, and
pronunciation.

- [ ] Bengali (#36)
- [x] Hindi (#37) — script deck and core vocabulary; see `decks/hi/`
- [ ] Gujarati (#38)
- [ ] Telugu (#39)
- [ ] Urdu (#40)

Hindi was the one to start with: Devanagari was already a valid script value,
so it was not blocked on #27.

## Later
- [ ] iOS build (requires an Apple Developer account — see [ADR-0001](adr/0001-flutter.md))
- [ ] Optional Kokoro TTS backend, if the Flutter bindings mature — see [ADR-0002](adr/0002-system-tts.md)
- [ ] FSRS scheduler, replaying existing history through it
- [ ] Sentence mining from imported text
