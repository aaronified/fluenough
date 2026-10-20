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

A card's `proposed` changes (ADR-0038) are taken out before any other
check, so their text is never held to deck content's rules, and checked on
their own: one line each, an id that is its facts' hash, a field the entry
may give, a good rater code and date, and acceptances by other codes. An
outdated proposal gets an `info` line. A card's `checked_by` (#449) is
taken out the same way and checked to be a non-empty list of rater codes,
none twice.

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
deck, how many proposals a file holds (`proposed`), and `content_sha256`,
the file's hash without its proposals and `checked_by`, which a learner's
phone compares (#444, #449). Languages in
`HIDDEN` are left out; `decks/themes.yaml` stays bundled
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

A review mail's issue names the rater code and the languages, counts the
changes suggested and the proposals accepted and rejected, and lists each
rejected proposal by id and card, labelled `proposal rejected`: never the
text. Once the review bot is set up, the job then runs it (below). The
rater code check is in `rater_codes.py`, shared with the validator.

## `review_bot.py` and `proposals.py`

The review bot (ADR-0038, #441), run by `mail_to_issues.py`. A filed review
mail whose sender passed the check becomes one pull request that adds its
suggestions as `proposed` lines on their cards and records its acceptances;
a proposal accepted by `REVIEW_AGREEMENTS_NEEDED` other rater codes (a
repository variable, 1 when unset) gets a pull request that writes it into
the field and closes the other proposals on that field; proposals whose
field has changed are closed as outdated. The review mail's PR also adds
the reviewer's code to the `checked_by` of each card marked "Looks right",
never twice, and tags a deck file `reviewed` once all its cards are
checked (#449). Each PR is merged as soon as its
checks pass. The mail gets the Gmail label `fluenough-proposed` once its PR
is merged or closed.

Every branch, `review-bot/…`, starts afresh from `main`, finds the card by
id across the language, writes only if the field still says what the
proposer saw, rewrites the index and validates the language before it is
pushed. Branches are named after their mail or proposals, so a rerun finds
its PR rather than opening another; a PR closed by the owner stays closed,
and one whose checks fail stays open, labelled `review-bot: checks failed`.
It logs rater codes, ids and counts, never an address or a suggestion.

`proposals.py` makes every edit to a deck, one line at a time, and saves it
only if the file then reads back as meant: a field written over several
lines, or a card in flow style, is left for the owner.

It needs a GitHub App's token (the secrets `FLUENOUGH_BOT_APP_ID` and
`FLUENOUGH_BOT_PRIVATE_KEY`); without them it does nothing and says so.
Setting it up: [docs/review-bot-setup.md](../docs/review-bot-setup.md).
`test_review_bot.py` and `test_proposals.py` test it with fakes, without a
network.

## `import_csv.py`

Turns a CSV wordlist into a deck. `target` and `native` columns are required;
`reading`, `tags`, `pos`, `gender`, `notes`, `alt_target` and `alt_native` are
used when present. `front`/`back` work as aliases. List columns split on `|`.

```sh
python3 tools/import_csv.py words.csv \
    --id es-en-food --name "Spanish food" \
    --language es --language-name Spanish --iso639-3 spa --tts es-ES \
    --license CC-BY-SA-4.0 > decks/es/es-en-food.yaml

python3 tools/validate_decks.py decks/es/es-en-food.yaml
```

It quotes any value YAML would misread, and numbers the cards from the
language's next free id (`validate_decks.py --next-id`). **Check the generated
ids before committing** — they are permanent once published, because they key
every user's review history. A word another deck already teaches should be
listed there by `ref` instead.

## `split_deck.py`

Splits a single-file deck into a core and an English layer, as
`docs/DECK-FORMAT.md`, "Splitting a deck", describes (#397, #498). It
keeps every card id, entry key and slot, deletes the old file, and refuses a
split that, merged back, would not give the old deck. A language's script
guide and sounds file split the same way: the core keeps the path, the
English text goes to `en/<lang>-en-script.yaml`.

```sh
python3 tools/split_deck.py decks/te/te-en-home.yaml     # te-home + en/te-en-home
python3 tools/split_deck.py --check decks/te/te-en-*.yaml  # try, write nothing
python3 tools/deck_index.py
```

Reading decks stay single-file, and so do paths, facts, numbers and
romanisation files. `test_split_deck.py` tests it.

## `import_wiktionary.py`

Fills a language's core cards from Wiktionary (#518, #523), through
kaikki.org's Wiktextract extract: the language's "all word senses" JSON
lines from `https://kaikki.org/dictionary/<Language>/`, such as
`Hindi.jsonl`. It fills **only empty fields** and never a card's meaning:
`ipa`, `gender` (in the path's classes), `bases: "self"` or a base by
`ref`, `synonyms` and `antonyms`, `examples` with their translations in the
English layer (only of words the course teaches), `forms`, `senses`, and
`wiktionary: true` in the layer. Every item names its `source`, the
Wiktionary page only, `https://en.wiktionary.org/wiki/<word>` (owner,
2026-10-16, #518: "Link only"); the dump's date and checksum are in the
report alone. The validator checks this shape: a `source` naming
wiktionary.org must be exactly that page (owner, 2026-10-17). The decks stay `unreviewed`: what it adds is semi-verified,
for reviewers to check (#508).

```sh
# The report alone, writing nothing: what it would fill, and what is
# still missing card by card.
python3 tools/import_wiktionary.py hi Hindi.jsonl --dump-date 2026-10-13
# Fill the decks, and keep the report.
python3 tools/import_wiktionary.py hi Hindi.jsonl --dump-date 2026-10-13 --write --report hi-report.md
# A dry run on a copy of the decks.
cp -r decks /tmp/decks-copy
python3 tools/import_wiktionary.py hi Hindi.jsonl --dump-date 2026-10-13 --write --decks /tmp/decks-copy
# Recordings and images too: needs ffmpeg and the network.
python3 tools/import_wiktionary.py hi Hindi.jsonl --dump-date 2026-10-13 --write --audio --images
# The image proposals a reviewer approved, by card id.
python3 tools/import_wiktionary.py hi Hindi.jsonl --dump-date 2026-10-13 --write --images --approve hi-0419,hi-0420
python3 tools/deck_index.py
python3 tools/validate_decks.py decks/
```

- **`--audio`**: the recording Wiktionary links for exactly the card's text
  (never joined from other recordings; sentences stay text-to-speech),
  downloaded from Wikimedia Commons and converted to Opus at
  `decks/<lang>/audio/<card id>.opus`, with its `audio_credit`.
- **`--images`**: for a card with a `picture`, the one picture in the
  language's section of its Wiktionary page, from Wikimedia Commons, else
  OpenMoji's drawing of its `picture`, shrunk to 256 pixels and converted
  to WebP at `decks/<lang>/images/<card id>.webp`, with its
  `image_credit`. With none, the card keeps its Noto picture. Images come
  from Wiktionary only, never Wikidata (owner, 2026-10-16, #523:
  "Wiktionary only").
- **Image proposals**: a noun, verb or adjective card without a `picture` gets no image from
  `--images`. Where its Wiktionary section has one picture that can ship,
  the report's "Image proposals" table lists it: the card, word, Commons
  file, licence, credit, Commons page and Wiktionary page (owner,
  2026-10-16, #523: "Also mark concrete", "Importer proposes"). Only the
  lookups run, so this works without `--write` too, and no file is
  downloaded. A reviewer approves each; then `--images --write --approve
  <card id>=<File name>` (repeated, or items separated by commas) writes
  those cards' images. The approval pins the file (owner, 2026-10-16:
  "Pin the file"): the table shows each proposal's file so it can be copied
  as `hi-0419=File.jpg`, and it lands only if that is still the proposal's
  file. A mismatch is listed in the report as not imported, naming both
  files; a bare id is refused with an error. An approved id that is not
  such a card is listed too. Approvals by mail come with #519.
- A file whose licence cannot ship in a CC BY-SA 4.0 deck, or that names
  no one to credit, is skipped and listed in the report. Without `ffmpeg`
  on the PATH, `--audio` and `--images` stop with an error before anything
  is written. A card written in flow style, `- { id: ... }`, is left alone
  and listed.

`test_import_wiktionary.py` tests it on `fixtures/wiktionary`, with the
network and ffmpeg replaced.

## `wikipedia_frequency.py`

Counts how often each word is used in a language's Wikipedia, and gives
each card whose target is one word its `frequency: { rank, source }` (#516;
owner: "Count from Wikipedia instead"). The text is a pages-articles dump,
`<lang>wiki-<date>-pages-articles.xml.bz2` from
`https://dumps.wikimedia.org/<lang>wiki/`, or a file or folder of plain
text extracted from one. A card that has a `frequency` keeps it; a phrase
gets none.

```sh
# The report alone: the source, and the cards Wikipedia never uses.
python3 tools/wikipedia_frequency.py hi hiwiki-20261001-pages-articles.xml.bz2
# Write the ranks, and save the count for later runs.
python3 tools/wikipedia_frequency.py hi hiwiki-20261001-pages-articles.xml.bz2 --write --counts hi-counts.tsv
# Rank again from the saved count, without the dump.
python3 tools/wikipedia_frequency.py hi --from-counts hi-counts.tsv --month 2026-10 --write
```

The source is `"<lang>.wikipedia.org, <month>"`, the month taken from the
dump's name or given with `--month YYYY-MM`. `test_wikipedia_frequency.py`
tests it on a dump of four pages in `fixtures/wikipedia`.

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

## `check_release_version.py`

Fails when a release tag and `pubspec.yaml`'s version differ (#141). The
release workflow runs it before building, because the APK's versionName is
the tag while the app reports `AppInfo.version`, which follows
`pubspec.yaml`. Only the version name is compared; the `+build` part is
ignored. Standard library only.

```sh
python3 tools/check_release_version.py v0.3.4             # reads ./pubspec.yaml
python3 tools/check_release_version.py v0.3.4 pubspec.yaml
```

Exit status is 0 when they match, 1 when they differ or `pubspec.yaml` has no
`version:` line, and 2 if the arguments are wrong or the file cannot be read.

## `readme_fonts.py` and `make_gif.py`

Remake the README's screenshots, `docs/screenshots/*.gif`: a slow scroll
through four screens of a Bengali learner's phone. A tool run by hand when
the screens change (owner, 2026-10-20), not deck tools, and not run by CI:
it lives in `tools/readme_gifs/`, outside `test/`, so `flutter test` never
reaches it. `readme_fonts.py` needs fontTools and `make_gif.py` Pillow
(`pip install fonttools pillow`), with the Flutter SDK on `PATH`.

A widget test draws text in boxes and turns font fallback off, so
`readme_fonts.py` first merges the SDK's Roboto with static Noto Sans Bengali
files (`NotoSansBengali-Regular.ttf`, `-SemiBold.ttf` and so on, from
[notofonts/bengali](https://github.com/notofonts/bengali), OFL-1.1). Then
`tools/readme_gifs/readme_gifs_test.dart`, skipped unless `README_GIFS=1`, writes
each screen's frames as PNGs, and `make_gif.py` turns each directory of
frames into a looping GIF at 11 frames a second, one palette, under 1.5 MB
(it narrows the GIF, then cuts colours, until it fits).

```sh
python3 tools/readme_fonts.py path/to/noto-bengali build/readme_fonts
README_GIFS=1 README_GIFS_FONTS=build/readme_fonts \
  flutter test tools/readme_gifs/readme_gifs_test.dart
for g in deck-path today progress review; do
  python3 tools/make_gif.py build/readme_gifs/$g docs/screenshots/$g.gif
done
```

The frames go to `build/readme_gifs/` (`README_GIFS_OUT` changes that). The
learner, their three and a half weeks of reviews, and the clock are fixed, so
a rerun changes a GIF only when the app's screens change.
