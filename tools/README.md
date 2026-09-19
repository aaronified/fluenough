# Deck tools

Python, not Dart, so that deck contributors need no Flutter toolchain.
Requires Python 3.11+ and PyYAML (`pip install pyyaml`).

## `validate_decks.py`

Checks decks against schema 1. CI runs this on every pull request.

```sh
python3 tools/validate_decks.py decks/
python3 tools/validate_decks.py decks/es/es-core-100.yaml
```

Errors fail the build; warnings do not. Exit status is 0 when every deck is
valid, 1 on any error, 2 if the arguments are wrong.

It checks structure and field types, that the deck id matches the filename,
that card ids are unique, that a grammar deck supplies every slot for every
entry — and that no value has been silently eaten by YAML's type resolution.
That last one is the reason this exists: `native: no` on the hiragana `の`
parses as the boolean `false`, and no reviewer reliably catches that by eye.

## `import_csv.py`

Turns a CSV wordlist into a deck. `target` and `native` columns are required;
`reading`, `tags`, `pos`, `gender`, `notes`, `alt_target` and `alt_native` are
used when present. `front`/`back` work as aliases. List columns split on `|`.

```sh
python3 tools/import_csv.py words.csv \
    --id es-food --name "Spanish food" \
    --language es --language-name Spanish --tts es-ES \
    --license CC0-1.0 > decks/es/es-food.yaml

python3 tools/validate_decks.py decks/es/es-food.yaml
```

It quotes any value YAML would misread, and derives card ids from the target,
falling back to the reading and then to the row number when the target has no
usable ASCII. **Check the generated ids before committing** — they are
permanent once published, because they key every user's review history.
