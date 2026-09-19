# Contributing to Fluenough

## Licensing of contributions

Fluenough is **GPL-3.0 with an App Store Distribution Exception** (see
[LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md)). By opening a pull request you
license your contribution under those same terms.

**There is no CLA.** The exception is part of the project licence rather than
something maintainers grant separately, so contributors keep their copyright
and nothing needs signing.

## Contributing a deck

The most useful thing you can contribute, and it needs no Flutter toolchain.

1. Read [docs/DECK-FORMAT.md](docs/DECK-FORMAT.md).
2. Add `decks/<language-code>/<deck-id>.yaml`.
3. Run `python3 tools/validate_decks.py decks/`.
4. Open a pull request.

Please make sure that:

- **The content is legally yours to give.** Wordlists lifted from textbooks or
  commercial courses are not acceptable, even reworded. Public-domain frequency
  lists, Wiktionary (CC-BY-SA-4.0), Tatoeba (CC-BY-2.0-FR) and your own work
  are all fine. Declare the licence in the deck's `license` field.
- **`language.tts` is set** when the language has significant regional variation
  (`pt-BR` vs `pt-PT`, `es-ES` vs `es-MX`). Without it, learners get whatever
  accent the device defaults to.
- **`reading` is provided** for non-Latin scripts.
- **Card ids are never reused or renumbered.** They key users' review history;
  changing one silently orphans their progress. To retire a card, delete it.

Small, focused decks beat one enormous one. A hundred good cards with example
sentences are worth more than a thousand bare word pairs.

## Contributing code

Please open an issue before starting anything substantial.

- Keep `lib/core/models`, `core/scheduling` and `core/grading` free of Flutter
  imports — that is what keeps them fast to test.
- Anything touching scheduling or grading needs tests.
- Run the pre-PR checks in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
- Architectural decisions belong in `docs/adr/` as a new numbered record.

## Reporting bugs

Include the device and Android/iOS version, the deck and drill mode, and
whether a TTS voice for the language is installed. For audio problems, say
whether you were on a physical device, an emulator or Waydroid — Waydroid has
no Google TTS voices and this is the most common cause of silent audio.
