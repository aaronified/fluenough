# Decks

Deck content, one YAML file per deck, organised by language code.

```
decks/
  es/  es-core-100.yaml
       es-grammar-present-ar.yaml
  ja/  ja-hiragana.yaml
```

- Format specification: [../docs/DECK-FORMAT.md](../docs/DECK-FORMAT.md)
- How to contribute one: [../CONTRIBUTING.md](../CONTRIBUTING.md)

**Adding a language means adding its directory to `pubspec.yaml`.** A Flutter
asset entry bundles only the files directly inside the directory it names, so
`flutter.assets` needs one `- decks/<lang>/` line per language. Validating the
whole of `decks/` — which is what CI does — fails if a directory holding decks
has no entry, because the alternative is an app that builds and ships without
that language in it. Validating a single deck or one language directory only
checks what you pointed it at.

Validate before committing — CI runs exactly this:

```sh
python3 tools/validate_decks.py decks/
```

## Two rules that matter more than the rest

**Quote your romanisations.** YAML turns bare `no`, `yes`, `on` and `off` into
booleans. The hiragana `の` romanises to `no`, so this is not hypothetical.

**Never reuse or renumber a card id.** Ids key every user's review history.
Changing one orphans their progress on that card; reusing one attaches old
history to new content. To retire a card, delete it.

## Deck licences

Each deck declares its own `license`, separate from the app's GPL-3.0. The
decks here are CC0-1.0 (public domain). Contributed decks may use any licence
permitting redistribution, declared in the file.
