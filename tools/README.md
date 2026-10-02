# Deck tools

Python, not Dart, so that deck contributors need no Flutter toolchain.
Requires Python 3.11+ and PyYAML (`pip install pyyaml`).

## `validate_decks.py`

Checks decks against schema 1. CI runs this on every pull request.

```sh
python3 tools/validate_decks.py decks/
python3 tools/validate_decks.py decks/es/es-en-core-100.yaml
```

Errors fail the build; warnings do not. Exit status is 0 when every deck is
valid, 1 on any error, 2 if the arguments are wrong.

It checks structure and field types, that the deck id matches the filename,
that each card id names the deck's language and is written once in it, that
every `ref` names a card another deck writes (ADR-0018), that a grammar deck
supplies every slot for every entry — and that no value has been silently eaten by YAML's type resolution.
That last one is the reason this exists: `native: no` on the hiragana `の`
parses as the boolean `false`, and no reviewer reliably catches that by eye.

## `import_csv.py`

Turns a CSV wordlist into a deck. `target` and `native` columns are required;
`reading`, `tags`, `pos`, `gender`, `notes`, `alt_target` and `alt_native` are
used when present. `front`/`back` work as aliases. List columns split on `|`.

```sh
python3 tools/import_csv.py words.csv \
    --id es-en-food --name "Spanish food" \
    --language es --language-name Spanish --iso639-3 spa --tts es-ES \
    --license CC0-1.0 > decks/es/es-en-food.yaml

python3 tools/validate_decks.py decks/es/es-en-food.yaml
```

It quotes any value YAML would misread, and numbers the cards from the
language's next free id (`validate_decks.py --next-id`). **Check the generated
ids before committing** — they are permanent once published, because they key
every user's review history. A word another deck already teaches should be
listed there by `ref` instead.

## `brand_android.py`

Run after every `flutter create`. It copies `fluenough-brand/android/` into
the generated `android/app/src/main/res/`, for the launcher icon and the
launch screen, and sets the launcher label to `appTitle` from
`lib/l10n/app_en.arb`. It declares in the manifest what the app asks Android
for: the microphone, the internet for the update check, and queries for the
speech recogniser and for apps that open https links. And it sets up
ota_update, which installs updates: its FileProvider and the folder that
shares, external storage removed, and core library desugaring switched on
in `android/app/build.gradle.kts`. Each is added once, so running it again
changes nothing. CI and the release workflow run it.

```sh
python3 tools/brand_android.py
```

Exit status is 0 on success, and 1 when `android/` is missing or its manifest
or Gradle file is not the shape `flutter create` writes.
