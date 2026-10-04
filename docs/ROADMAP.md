# Roadmap

Every item below has an issue. The issues carry the detail — files to touch,
acceptance criteria, and what to read first.

## Beta — 0.9.0

The first release for learners, tracked in #55: a signed APK that a learner
uses daily for a month without losing progress. F-Droid and the deck authoring
guide wait for 1.0.

- **Decks** are all taught from English: Hindi, Bengali and Telugu, plus the
  existing Spanish. Japanese is kept in the repository but not bundled for
  now. Deck ids name both languages (#51).
- **Vocabulary is taught by theme**, one deck per theme, in 18 shared themes
  aimed at minimal fluency: first words, questions, numbers, market,
  groceries, transport, directions and so on (#52).
- **Numbers**: two number decks, and a generator for 4-digit numbers and
  years built from them (#54).
- **Grammar**: the pattern expander and grammar drill, with grammar decks for
  Hindi, Bengali and Telugu (#2, #14).
- **Spoken languages**, ranked, set on first launch from English, Bengali and
  Hindi. Daily facts come in each of them, with contrasts against each (#53,
  #48).
- **Progress is saved**, with stats, leeches and a review-log export (#3, #5,
  #6, #18, #19, #20).
- **Telugu is written without a Telugu speaker's review**, and says so (#39).
- **Not in the beta:** the Hindi and Bengali interface, profiles and PIN, the
  daily reminder. Deck imports from a file and transliterated answers came
  after it (#156, #166).

## v0.1 — Core loop
- [x] `flutter create` the platform folders, wire up CI
- [x] Models, deck parser
- [ ] Pattern expander
- [ ] drift schema and migrations
- [x] SM-2 scheduler, with tests
- [ ] Review log
- [x] `AnswerGrader`, with tests
- [x] Recognition drill
- [ ] Production drill
- [ ] Deck browser and per-deck drill launch
- [ ] Two complete starter decks

## v0.2 — Audio and grammar
- [ ] `SystemTtsEngine`, voice availability detection
- [ ] Listening drill, shown disabled with "Set up" when no voice is installed
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

- [ ] Bengali (#36) · Hindi (#37) · Gujarati (#38) · Telugu (#39) · Urdu (#40)

Hindi is the one to start with: Devanagari is already a valid script value, so
it is not blocked on #27.

## Later
- [ ] iOS build (requires an Apple Developer account — see [ADR-0001](adr/0001-flutter.md))
- [ ] Optional Kokoro TTS backend, if the Flutter bindings mature — see [ADR-0002](adr/0002-system-tts.md)
- [ ] FSRS scheduler, replaying existing history through it
- [ ] Sentence mining from imported text
