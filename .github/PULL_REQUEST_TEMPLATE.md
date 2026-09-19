## What this changes

<!-- One or two sentences. -->

## What I verified

<!-- Say what you actually ran, and what you did not. "Validator passes,
     flutter test not run - no SDK available" is a useful answer. -->

## Checklist

- [ ] `python3 tools/validate_decks.py decks/` passes (if decks changed)
- [ ] `flutter analyze` and `flutter test` pass (if code changed)
- [ ] `dart format lib test` applied
- [ ] Architectural decisions recorded in `docs/adr/` (if any were made)

### For deck changes

- [ ] I have the right to contribute this content, and `license` says so
- [ ] No existing card id was renumbered, reused or removed-and-replaced
- [ ] Romanisations and other bare values are quoted (`"no"`, not `no`)
- [ ] `language.tts` is set if the language has regional variation

- [ ] One concern only; rebased on `main`
- [ ] Agent assistance disclosed with a `Co-Authored-By:` trailer, if any

New here? See [CONTRIBUTING.md](../CONTRIBUTING.md) and [AGENTS.md](../AGENTS.md).

By opening this pull request you agree to license your contribution under
GPL-3.0 with the App Store Distribution Exception. No CLA is required.
