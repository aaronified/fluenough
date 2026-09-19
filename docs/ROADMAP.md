# Roadmap

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

## Later
- [ ] iOS build (requires an Apple Developer account — see [ADR-0001](adr/0001-flutter.md))
- [ ] Optional Kokoro TTS backend, if the Flutter bindings mature — see [ADR-0002](adr/0002-system-tts.md)
- [ ] FSRS scheduler, replaying existing history through it
- [ ] Sentence mining from imported text
