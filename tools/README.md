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
It reads plain YAML values as the app does (YAML 1.2: a bare `no` is the text
"no", only `true` and `false` are booleans), so the two never disagree.

It also checks the B1 format (ADR-0036): cores (`part: "core"`) and their
layers (`kind: "layer"`, in `decks/<lang>/<native>/`), rules decks, the
phrasebook, typed notes, `bases`, `wiktionary`, and the language's path,
one per language learnt (`<lang>-path.yaml`), by core id, with its B1 plan
and its regions. Some of
these read the language's other files from disk, so a file validated alone is
checked against them. Lines marked `info` (a layer's coverage of its core, a
plan's sizes) never fail the build. `tools/fixtures/b1/zz/` is a valid set in
a made-up language, used by `test_validate_b1.py`.

## `deck_index.py`

Writes `decks/index.json`, the list the app downloads decks from (#210,
ADR-0037). Run it after changing anything under `decks/`, and commit the
result with your change.

```sh
python3 tools/deck_index.py            # write it
python3 tools/deck_index.py --check    # exit 1 if it is out of date
```

For each language it lists its name, own name, icon and script, whether it
has script decks, the native languages it is taught from, its path's order,
each unit's planned words and the words its decks have (counted as the
validator counts them, for completeness toward B1), and every file with its
path, size, SHA-256, schema, kind, and the native language and core id of a
deck. Languages in `HIDDEN` are left out; `decks/themes.yaml` stays bundled
in the app. One file is one line, so a changed deck is a one-line diff.

`validate_decks.py decks/` fails while the index is out of date, so CI keeps
it current.

## `pictures.py`

Copies the pictures the decks name (a card's `picture`, one emoji) from a
Noto Emoji checkout into `assets/pictures/`, and removes any no deck names,
so that only what is used ships. Run it after adding or changing a picture.

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/googlefonts/noto-emoji
git -C noto-emoji sparse-checkout set 2D/png/128
python3 tools/pictures.py noto-emoji
```

## `mail_to_issues.py`

Turns the report mails the app sends to the Fluenough Gmail into GitHub
issues (#160, ADR-0021). `.github/workflows/feedback-mail.yml` runs it hourly.
Stdlib only.

It reads the inbox over IMAP and takes only mails whose subject starts with
`[Fluenough]`, as the app writes it. Each bug report and each piece of
feedback not filed before becomes one issue, text only, and the mail gets
the Gmail label `fluenough-filed` so that it is never filed twice. The
sender's address is never written to the issue, `@mentions` are broken, and a
screenshot or the app log stays in the mail, which the issue says it had.
**Support mails are never made public:** one is skipped and left untouched in
the inbox when its subject or its `Kind:` line says Support, read loosely
(any case, with or without the colon).

It needs two repository secrets, `FEEDBACK_GMAIL_ADDRESS` and
`FEEDBACK_GMAIL_APP_PASSWORD` (a Gmail app password), and uses the
workflow's own `GITHUB_TOKEN` for the issues. Without the two secrets it does
nothing and says so. `python3 -m unittest discover -s tools -p test_mail_to_issues.py` tests
it without a network.

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
