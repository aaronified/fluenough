# Deck tools

Source of truth: this wiki page.


Python, not Dart, so that deck contributors need no Flutter toolchain.
Requires Python 3.11+ and PyYAML (`pip install pyyaml`).

## `validate_decks.py`

Checks decks against schema 1. CI runs this on every pull request.

```sh
python3 tools/validate_decks.py decks/
python3 tools/validate_decks.py decks/es/es-en-core-100.yaml
python3 tools/validate_decks.py --private my-package/        # a private language package (folder or .fnzip)
```

Errors fail the build; warnings do not. Exit status is 0 when every deck is
valid, 1 on any error, 2 if the arguments are wrong.

`--private` checks a private language package ([Private-Language-Package](Private-Language-Package),
#1017) instead: its names, sizes, manifest, `fnpd-<code>-` ids and path, then each
deck and layer with these rules (`tools/validate_private.py`; the package part
mirrors the app's own import, and the two share the fixture
`test/fixtures/private/qaa-tiny`). Outside `--private` the validator refuses a
`fnpd-` id and a private manifest, so a private package never goes under `decks/`.

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
ADR-0037). The `deck-index.yml` workflow runs it on decks-live after each merge
that touches `decks/` and commits the result (owner, 2026-10-23); builders
do not run it (it runs the full validator, up to an hour).

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
`HIDDEN` are left out (the set is empty now: 0.7.1 is released and the planned
languages' starter decks, #959, are listed, owner, 2026-11-01; add a code to
hide a language again, and keep `SHIPPED` in `tools/test_deck_index.py` in
step). The new languages are visible to every phone: a phone still on 0.7.0
sees them on the Download page and the placement picker but not on the
Languages page (known and accepted by the owner). `decks/themes.yaml` stays bundled
in the app. One file is one line, so a changed deck is a one-line diff.

`validate_decks.py decks/` fails while the index is out of date, so CI keeps
it current.

**`min_app`** (ADR-0052). `decks/min_app.json` names the oldest app version
that can read a language or one file:
`{"languages": {"pt": "0.7.1"}, "files": {"decks/es/es-en-x.yaml": "0.7.2"}}`.
The tool writes it as `min_app` on that language or file entry; an app that
knows the key does not download what needs a newer app and shows "Needs app X,
Update", and an older app ignores it. The tool, and so the validator, fails
when the file is not JSON of that shape, a value is not `major.minor.patch`,
a language is not in the index (no decks, or hidden), or a file is not listed.
Set it only for a version that is released. The tool refuses a language
that `assets/languages.yaml` lists at the latest `v*` git tag, and a file that
`decks/` holds at that tag: the released app already ships them and could not
know the key. Gate new files only. Without git or the tag it warns and skips
the check; `--strict-released` (or `FLUENOUGH_STRICT_RELEASED=1`, set by CI's
"Released app reads the decks") makes that an error. Empty maps change
nothing.

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
issues (#160, ADR-0021). `.github/workflows/feedback-mail.yml` runs it every 15 minutes (GitHub may delay scheduled runs; the workflow can be run by hand from the Actions tab).
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

Every branch, `review-bot/…`, starts afresh from `decks-live`, finds the card by
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
Setting it up: [Review-Bot-Setup](Review-Bot-Setup).
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

## `gen_planned_paths.py`

Writes `decks/<code>/<code>-path.yaml` for the planned languages (#959): the
whole plan to B1, unit 1 written and every other unit planned. It also turns
unit 1 of the older all-planned paths into the written unit. Deterministic;
`--check` exits 1 if a file differs. See the Plan-Language-Paths page.

```
python3 tools/gen_planned_paths.py
python3 tools/gen_planned_paths.py --check
```

## `split_deck.py`

Splits a single-file deck into a core and an English layer, as
[Deck-Format](Deck-Format), "Splitting a deck", describes (#397, #498). It
keeps every card id, entry key and slot, deletes the old file, and refuses a
split that, merged back, would not give the old deck. A language's script
guide and sounds file split the same way: the core keeps the path, the
English text goes to `en/<lang>-en-script.yaml`.

```sh
python3 tools/split_deck.py decks/te/te-en-home.yaml     # te-home + en/te-en-home
python3 tools/split_deck.py --check decks/te/te-en-*.yaml  # try, write nothing
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

## `fetch_sound_audio.py` and `wikimedia_client.py`

Fetches a recording for each sound card of a language's `<lang>-sound-inventory`
deck ([ADR-0059](ADR-0059-Sounds-Decks-With-Compressed-Audio),
[Plan-Sounds-Decks](Plan-Sounds-Decks), #734). The owner's design: a loop of
fetch requests; whatever is fetched ships with its card, whatever is not stays
as it is (the phone's text-to-speech).

```sh
python3 tools/fetch_sound_audio.py --survey                      # read-only: what exists, no audio downloaded
python3 tools/fetch_sound_audio.py --lang te --dry-run           # download and encode, write nothing
python3 tools/fetch_sound_audio.py --lang te --limit 20          # a slice of the cards
python3 tools/fetch_sound_audio.py --lang te --report te.md --json te.json
python3 tools/fetch_sound_audio.py --lang te --refresh           # redo cards that already have audio
python3 tools/fetch_sound_audio.py --lang te --download-interval 10 --wait-rate-limit   # slower, and sleeps out a Retry-After up to 900 s
python3 tools/fetch_sound_audio.py --lang te --accept-assumed-author   # only after the owner decides (see below)
```

For each card with no valid audio, in order, stopping at the first usable file:
Commons's recording of the IPA symbol the card's `ipa` is (a table of symbol to
Commons title in the tool; `--symbols FILE` adds or replaces entries), tried as
written first and then, for Telugu (`te`; other languages with `--inherent-a LANG`, never kana-style
CV cards), without a trailing inherent `a` (the Telugu syllable form:
`ʈa` is the consonant ʈ, `kʰa` is `kʰ`, which has no clip until `--symbols` gives
it one; the vowel `a` and the long `aː` are never stripped, nor a form like `ia`
that holds a vowel); a Commons
recording of the letter in the language's `Category:<Language> pronunciation`
(`--no-letters` skips it); with `--example-words --dump <kaikki.jsonl>`, the
Wiktionary recording of the example word (a recording of the word, not of the
sound, so it is off by default). A file is skipped and reported when its licence
is not CC0, public domain, CC BY or CC BY-SA 2.0 to 4.0 (NC, ND and GFDL-only
included: `licence_id` of `import_wiktionary.py`) or when Commons names no
author (`Unknown author` too, public domain included: ADR-0059 decision 8).
Commons's automatic `No machine-readable author provided. X assumed (based on
copyright claims).` is no author either, and is skipped as `skipped-no-author`;
`--accept-assumed-author` (off; it needs the owner's decision, because ADR-0059
decision 8 is strict) accepts it and credits `X (uploader; author assumed by
Commons)`, never the raw placeholder.
The download is decoded to 16-bit mono PCM at 24 kHz, trimmed of silence,
peak-normalised to -3 dBFS and encoded as Ogg Opus mono, variable bitrate, at
32 kbps, then 24, 16 and 12 if the clip passes 16 kB (never over 128 kbps);
what still does not fit is skipped as `over-size`. It writes
`decks/<lang>/audio/<card id>.opus` and adds `audio` and `audio_credit`
(`{ source: the Commons page, license, credit: the author }`) to the card, after
`phonetic_source`, `phonetic` or `ipa`, replacing the two lines on a refresh and
checking by a parse that nothing else in the file changed. A card with nothing
usable keeps no `audio` field.

It is idempotent and resumable: a card with valid audio is skipped, every answer
and download is cached, and each card is written when it is done. It writes only
the decks' audio folders, the card files, the cache and the report files you
name. `--survey` writes nothing and downloads no audio (bytes are estimated from
each file's length); `--dry-run` encodes in memory and writes nothing to the decks.
The report (Markdown on screen, `--report`, and `--json`) lists per language the
cards, those already done, asked, fetched, missing, skipped for author, licence
and size, errors, the bytes, the sources and licences seen (a file counted once),
the skipped files with the reason, why each card has no recording (no symbol
mapping, nothing found on Commons, no author, licence, size, file type), which
candidate rule and file matched each card that has one (`ipa-symbol`,
`ipa-symbol-stripped`, `letter`, `example-word`), the symbols with no clip (a
stripped symbol with no table entry shows as such, for `--symbols`), and the
share of the 50 MB ceiling. Exit 3 means the run stopped at the
rate limit or the request cap; run it again to resume.

`wikimedia_client.py` is the shared polite client (the culture media tool,
[ADR-0060](ADR-0060-Culture-Media-From-Wikimedia-Commons), reuses it): one request
at a time; a `User-Agent` naming the project and a contact URL from the
`WIKIMEDIA_CONTACT_URL` environment variable (the project's public page by
default; no personal data); separate pauses for API calls (1 s, `--api-interval`) and file downloads
(5 s, `--download-interval`: `upload.wikimedia.org` answered 429 with a long
`Retry-After` to a 0.25 s loop); the User-Agent is only that descriptive string
(a ` python-urllib` suffix drew a 429, and urllib's own default is replaced);
`Retry-After` honoured on 429 and 503, capped exponential backoff on 429,
5xx and network errors, and a stop (exit 3, not a wait) when the server asks for more than
5 minutes, unless the run was started with `--wait-rate-limit`, which sleeps
out a `Retry-After` of up to 900 s (no total runtime bound: up to four such sleeps a request) (the cache keeps reruns cheap); 50 titles or ids per request; an on-disk cache (`--cache`, default
`.cache/wikimedia`; API answers and "missing" for 30 days, downloads for good;
`--refresh-cache` ignores it); a hard cap per run (`--max-requests`, default 400);
downloads only from `https://upload.wikimedia.org/`, redirects followed only to the allowed hosts over https, bodies read in chunks with a hard limit (5 MB a file, 8 MB an API answer), a 30 s timeout on every request, and a `Retry-After` given as an HTTP date understood. Source files over 5 MB or 30 s, or not audio by MIME type, are skipped as `over-size` or missing; ffmpeg reads only a local file (`-protocol_whitelist file`), with `-t` before `-i` and streaming filters only. The report lists the IPA symbol clip titles tried and not found, for `--symbols`. Exit 4 means another Wikimedia error; the report is still written. The transport is injected, so
the tests use none. `test_wikimedia_client.py` and `test_fetch_sound_audio.py`
test them with a fake Wikimedia and a stubbed encode step; one test, skipped
without ffmpeg and libopus, checks real output against the validator's audio
checks. The fetching needs the hosts `commons.wikimedia.org`,
`upload.wikimedia.org` and, for `--example-words`, a kaikki.org dump downloaded
beforehand.

### Recordings: what the validator checks and `--audio-report`

`tools/validate_decks.py` checks every shipped `audio` file from its own
bytes (no ffmpeg; [ADR-0059](ADR-0059-Sounds-Decks-With-Compressed-Audio)): Ogg
Opus (`OggS` and `OpusHead`), mono, at most 128 kbps (size over the length
from the last page's granule position), at most 16 kB, and a credit with a
link, an author and a licence from the allow-list (never NC or ND). The
constants are `AUDIO_MAX_KBPS`, `AUDIO_MAX_BYTES` and `AUDIO_TOTAL_MAX_BYTES`
(50 MB for all the decks' recordings together; over it the run fails).

```sh
python3 tools/validate_decks.py --audio-report decks/
```

`--audio-report` also prints the files and bytes per language and the share of
the 50 MB used. It only reports: the exit code is the validator's own. A deck
with no `audio` is valid, and the existing Morse course's recordings pass the
caps (the largest is 7 kB, the highest bitrate about 29 kbps).

`ogg_opus_testlib.py` builds tiny Ogg Opus streams by hand for
`test_validate_audio.py`, so the tests need neither ffmpeg nor the network.

### Images: what the validator checks and `--image-report`

([ADR-0060](ADR-0060-Culture-Media-From-Wikimedia-Commons).) The validator
reads every image's own bytes (the header only, no ffmpeg), by kind:

| Image | Cap |
|---|---|
| A creator's portrait (`decks/creators/images/`) and a work's poster, cover or title page (`image` on a recommendation, `decks/recommendations/images/`) | 2048 px on the longest side and 500 KB: `SHARED_IMAGE_MAX_SIDE`, `SHARED_IMAGE_MAX_BYTES` |
| A card's own `image` (`decks/<lang>/images/`) | 1024 px and 300 KB: `CARD_IMAGE_MAX_SIDE`, `CARD_IMAGE_MAX_BYTES` |

One licence rule serves recordings, card images and shared images
(`check_licence_and_source`): `CC0-1.0`, `public-domain`, CC BY and CC BY-SA 2.0
to 4.0; never NC, ND, GFDL alone or fair use; the credit's source is an http or
https link, or, for a card's `image` or `audio` only, `Generated by
tools/<script>.py ...` with `CC0-1.0`. A shared image's credit also needs the
author (plain text, at most 300 characters), the licence URL (not for
`public-domain`) and, for a work, a `commons.wikimedia.org` source. A file in a
shared images folder that nothing cites is an error. The shared images together
fail over 100 MB (a warning at 75 MB) and one language's over 10 MB (a warning
at 8 MB). New files are `.webp`, written by the fetch tool, which never upscales
a source (that is the tool's rule: the validator cannot see the source).

```sh
python3 tools/validate_decks.py --image-report decks/
```

`--image-report` prints the files and bytes per language (creators and works
apart) and the share of the 100 MB used; it only reports. `test_validate_culture_images.py`
builds tiny WebP and PNG headers by hand, so the tests need neither ffmpeg nor
the network. `tools/deck_index.py` lists work images under `shared_media` beside
the creator images, with a `min_app` on the work entries.

## `fetch_culture_media.py`

Fetches a portrait for each creator and a poster, cover or title page for each
work of the culture decks, from Wikimedia Commons
([ADR-0060](ADR-0060-Culture-Media-From-Wikimedia-Commons),
[Plan-Culture-Media](Plan-Culture-Media), work package 2). The owner's design: a
loop of fetch requests; whatever is fetched ships with its entry, whatever is not
stays as it is (the app's placeholder). It reuses the shared client
(`wikimedia_client.py`) and the validator's own rules; it runs on a checkout that
has `decks/creators/` and `decks/recommendations/` (`decks-live`).

```sh
python3 tools/fetch_culture_media.py --survey                       # read-only: coverage, bytes, licences, skips
python3 tools/fetch_culture_media.py --lang te --facts              # Wikidata dates and places next to the deck's
python3 tools/fetch_culture_media.py --lang te --dry-run            # download and encode, write nothing
python3 tools/fetch_culture_media.py --lang te --kind creators --limit 10
python3 tools/fetch_culture_media.py --lang te --report te.md --json te.json
python3 tools/fetch_culture_media.py --lang te --refresh te-rec-foo # redo one entry
python3 tools/fetch_culture_media.py --lang gu --download-interval 10 --wait-rate-limit   # slower, and sleeps out a Retry-After up to 900 s
```

For each entry with no valid `image` (its file exists):

1. **Wikidata item.** The entry's `wikidata` key (trusted only after the same
   identity check, else `ambiguous`), else a `wbsearchentities` search
   by name or title, accepted only if the item fits: a creator is a human (Q5)
   whose label or alias matches and whose birth and death years agree with the
   deck's within a year (five if `circa`), with at least one date confirmed; a
   work has a type that fits its `medium` (`WORK_TYPES`, written from memory and
   meant to grow; an item whose type is only a subclass of a listed one is
   `ambiguous`, not matched), a matching label, a publication year within a year of the
   deck's and, when the deck work has creators, one of the deck's verified
   creators named by the item (P50, P57, P58, P86, P170, P175): an item that names
   none does not match a work that has creators. One fit is taken; none, or more than one, is reported as `ambiguous`
   with the candidates for a human, who can settle it by adding `wikidata:` to the
   entry. A QID found by search is written back as `wikidata`.
2. **Candidate files** are named by the item's statements only: a creator P18; a
   work P3383 (poster), P18, P996 (scan or cover), in that order, preferred rank
   first, deprecated never. Never Wikipedia's REST `originalimage`; a file whose
   URL is not `https://upload.wikimedia.org/wikipedia/commons/...` (the fair-use
   files are under `/wikipedia/en/`) is refused, and the source page must be on
   `commons.wikimedia.org`. A creator's file in a Commons category named Fictional,
   Alleged, Disputed or Unidentified goes to the `ambiguous` list.
3. **The licence gate** reads Commons's `extmetadata`: the licence goes through
   `validate_decks.check_licence_and_source` (CC0, public domain, CC BY and CC BY-SA
   2.0 to 4.0; never NC, ND, GFDL alone or fair use); a file with a `Restrictions`
   note, a type that is not a picture, no licence URL (except public domain) or a
   source over 15 MB is skipped; a file with no machine-readable author is skipped,
   except a public-domain one, credited `Unknown author` (ADR-0060 decision 7; the
   validator allows exactly that text for a `public-domain` image, so no
   `(public domain)` suffix is added). A bare `Unknown`, `Unknown author`,
   `Anonymous`, `?` or Commons's `No machine-readable author provided. X assumed`
   line counts as no author (the sound tool's placeholder rule). The author is read
   as plain text with a space between neighbouring elements, and a name Commons
   writes twice is kept once (the first Gujarati run credited `Unknown
   authorUnknown author`; rerun that entry with `--refresh ID`). It is at most 300
   characters. Each skip is reported with its reason.
4. **Download and encode.** The original when it is within the target and small
   enough for the client's body limit (5 MB), else the Commons thumbnail
   (`thumburl` from the API, on `thumb.wikimedia.org`, used as given). Commons serves
   only the standard widths (20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840), so
   the tool asks for the smallest standard width that is at least the width the
   target needs (a tall picture needs a smaller width) and not above the
   original's width, and ffmpeg makes the exact resize; if no standard width fits,
   it takes the original. A thumbnail Commons refuses (HTTP 400 or 404) is a
   per-file skip, `bad-thumb`, after a fallback to the original when that is under
   5 MB. ffmpeg decodes and writes WebP
   with `scale='min(N,iw)':'min(N,ih)':force_original_aspect_ratio=decrease`: the
   longest side is at most N, **never upscaled**; N is 1024 for a portrait and 2048
   for a work (`--portrait-px`, `--work-px`, at most 2048). Quality 80, then 75, 70,
   65 and 60 until the file is at most 500 KB; still over is skipped as `over-size`.
   The file is `decks/creators/images/<creator id>.webp` or
   `decks/recommendations/images/<work id>.webp`, and the entry gets an `image:`
   block (`file`, `credit`, `author`, `licence`, `licence_url`, `source_url`,
   `retrieved`, and `kind`: `poster` for P3383, `title-page` for P996; a portrait's
   `kind` is left for a reviewer) by a text patch, checked by a parse that nothing
   else changed, and by the validator's `check_image` on the written file, before
   the YAML is saved (`--refresh` checks the new file in a scratch folder and
   replaces the old one atomically, so a failure leaves the old image and YAML
   untouched). ffmpeg has a 120 s timeout and applies the picture's EXIF
   orientation.
5. **Living creators** get no portrait (decision 9): the deck must not say
   `living`, and Wikidata must give a date of death at least `--min-years-dead`
   years ago (5); `--include-living` lifts it.

`--download-interval` (default 5 s) and `--wait-rate-limit` are the sound tool's: a
`Retry-After` over 300 s stops the run with exit 3 unless `--wait-rate-limit` is set,
which sleeps out up to 900 s a request (no total runtime bound). A run that stops at
the rate limit lists the pictures it had chosen but not yet written as `deferred`
in the report; a plain rerun resumes from the cache. One file that fails (an HTTP
error, over size, a refused licence, an unexpected error) is counted and the others
are still tried; only a rate limit stops the run.

It is idempotent and resumable: an entry with a valid image is skipped (an entry
whose image file is missing is listed, not redone; `--refresh ID` redoes one),
every API answer and download is cached (`--cache`, default `.cache/wikimedia`,
shared with the sound tool; `--refresh-cache` ignores it), and each entry is
written when it is done. The plan's `--search` and `--max-bytes` are not built
(`--limit` and `--max-requests` bound a run). `--survey` and `--facts` write nothing and download no image (the survey
estimates bytes from the pixel size); `--dry-run` encodes in memory and writes
nothing to the decks. The report (Markdown on screen, `--report`, `--json`) lists
per language the entries, those already done, asked, fetched or available,
missing, skipped for author, licence and size, other skips, ambiguous, living,
errors and bytes, the licences seen, the skipped files with the reason, the
ambiguous matches for review, and the share of the 100 MB ceiling. Exit 3 means the
run stopped at the rate limit or the request cap; exit 4 another Wikimedia error;
exit 1 an error in the decks or files, reported mid-run; the report is always
written; run again to resume. Needs `ffmpeg` with libwebp. The
tests (`test_fetch_culture_media.py`) use a fake Wikidata, Commons and file server
and a stubbed encode step; one test, skipped without ffmpeg and libwebp, checks the
real resize. The fetching needs `www.wikidata.org`, `commons.wikimedia.org`,
`upload.wikimedia.org` and `thumb.wikimedia.org`.

## `mark_wiktionary.py`

Marks the cards whose word has a Wiktionary entry (#422), so that the app
links them to it ([The Wiktionary link](Deck-Format#the-wiktionary-link)).
It reads kaikki.org's extract, as `import_wiktionary.py` does, and fetches
nothing:

```sh
python3 tools/mark_wiktionary.py hi Hindi.jsonl                  # report only
python3 tools/mark_wiktionary.py hi Hindi.jsonl --write          # mark the decks
python3 tools/mark_wiktionary.py hi Hindi.jsonl --section Hindi  # one language of the dump
```

It adds `wiktionary: true` to the English layer's entry of each vocab card
whose target is exactly the title of an entry, and nothing else. It never
removes a mark: a marked card the extract has no entry for is listed for a
person to check. A card already marked, and one written in flow style, are
left alone. Another native language's layer needs that edition's own
extract, which the tool does not read yet. `test_mark_wiktionary.py` tests it
on `fixtures/wiktionary`.

## `topic_chars.py`

Writes the `chars` of a language's script topics from the one-character cards
of their `decks` (`python3 tools/topic_chars.py ja --write`; `--check` exits 1
when a topic differs, `--all-targets` also lists two-character cards). The
validator checks `chars` against the same decks. See
[Deck-Format](Deck-Format#script-topics), "Script topics".

## `transcribe.py`

`python3 tools/transcribe.py <code> "<text>" [hint]` prints a reading in the
course's letters (based on ISO 15919) and the broad IPA of a word or sentence
([ADR-0025](ADR-0025-Iso-15919-And-Ipa)). Each language has its own engine;
a hint is how the word is said, and the tool says when it did not fit.

**Urdu script** (`ur`, or `hi` when the text is Perso-Arabic). Hindustani is
one course in two scripts, so Urdu-script text is read into the same letters
and IPA as the Devanagari cards, by the `hi` tables:

```sh
python3 tools/transcribe.py ur "نقش فریادی ہے کس کی شوخیِ تحریر کا"
python3 tools/transcribe.py ur "کتنا" kitna          # a hint, one reading per word
python3 tools/transcribe.py ur "نَقْش"                # marks written: read as written
```

Urdu leaves its short vowels unwritten, so the tool never invents them. A word
is read, in this order, from its hint (Devanagari, accented letters, or plain
Latin letters, which it must fit the word's consonants); from its marks (zabar,
zer, pesh, sukun, shadda) when they are all written; from
`tools/urdu_words.tsv`, a plain list of bare word, reading and an optional note
that anyone can extend, or else from `tools/urdu_lexicon_kaikki.tsv` (below);
or else as its consonant skeleton with `?` where a
short vowel may be, and a note, so a person reviews it. A letter with several
readings (و ō, ū, v or au; ی ī, ē or y; ے ē or ai; a final ہ) gets its
commonest one and a note. The ezafe (a zer ending a word) is written `-e`, as in
the Perso-Arabic script cards (`vazīr-e azam`), and its IPA is `ɪ`, as theirs;
both are the one constant `UR_EZAFE`. Readings follow the decks: ش is `ś`,
ح `h`, خ `k͟h`, ق `q`, ں `m̐`. There is no Perso-Arabic to Devanagari helper:
Hindi's dropped inherent vowels cannot be read back from a reading.

**The bulk Urdu lexicon** (`tools/urdu_lexicon_kaikki.tsv`). Fetching hints
word by word is slow, so `tools/build_urdu_lexicon.py` builds a lexicon from the
[kaikki.org Urdu dump](https://kaikki.org/dictionary/Urdu/kaikki.org-dictionary-Urdu.jsonl)
of Wiktionary: one row per headword and per single-word inflected form for which
the dump gives an explicit transliteration. No vowel is inferred: an entry
without a transliteration gives no row (its IPA alone is not used). Each
transliteration is converted to the decks' letters (`ś`, `ṭ ḍ ṛ`, `ġ`, `k͟h`
for x, `m̐` for a nasal vowel, long `ē ō`) and kept only when its consonants are
the Urdu word's, so a wrong transliteration in the dump is dropped. The key is
the bare word. A spelling with several readings is listed with all of them,
`|`-separated, and the engine prints it as `ambiguous: a / b, review` without
picking one. `tools/urdu_words.tsv` wins over the generated file.

```sh
python3 tools/build_urdu_lexicon.py              # downloads the dump once, to ~/.cache/fluenough/kaikki
python3 tools/build_urdu_lexicon.py --dump PATH --dump-date 2026-10-30
```

The dump's text is from Wiktionary and is CC-BY-SA 4.0: the generated file says
so in its header and is shared under the same licence. Do not edit it by hand;
rerun the script, and pin or fix a word in `tools/urdu_words.tsv`.

## `transcribe_decks.py`

Checks, and fixes, a language's stored `reading` and `ipa` against
`tools/transcribe.py` (#1295). It walks the core deck files of one directory
(the `en/` layers are not read): every card, every card example and every
`{ word: ..., reading: ... }` entry (bases, note words), and re-transcribes
each from its target text exactly as the single-word mode does, with the
stored reading as the typed hint.

```sh
python3 tools/transcribe_decks.py --check decks/te te       # exit 1 if any differ
python3 tools/transcribe_decks.py --fix decks/te te         # anusvara only
python3 tools/transcribe_decks.py --fix --all decks/te te   # every difference
python3 tools/transcribe_decks.py --fix --citations decks/te te  # base citation readings
python3 tools/transcribe_decks.py --fix --layer-anusvara decks/te te  # en/ prose readings
```

Telugu input the tool reads (#1357, #1361; defaults in this paragraph set by
the architect, the owner can overturn them): a dependent vowel sign with no
consonant before it, as in a suffix written `-ిన` or a bare ending `ాం`, reads
as the vowel it stands for, with no inherent a (`-ina`, `āṁ`, `ā`); the hyphen
is kept in the reading. ఱ reads `ṟa` (IPA as ర, `r`). ఌ and ౡ read with the
ISO 15919 letters `l̥` and `l̥̄` (l with a ring below, U+0325, ISO 15919's mark
for a vocalic liquid, then a macron, U+0304, for the long one), while the IPA
stays tool-derived (`lu`, `luː`); the signs ౢ ౣ read the same (`kl̥`). The tool
still computes `ru` for ఋ and `rū` for ౠ; this rule does not touch them. ౘ and
ౙ read `tsa` and `dza` (IPA `ts`, `dz`); ISO 15919 has no letter for them. ఁ is
silent (empty reading and IPA), ః reads `ḥ`.

`--citations` is a pass of its own for the `reading` of an inline base
(`{ word, base, reading }`: the reading of the base's dictionary form, which
the other modes skip when `base` differs from `word`). It rewrites only a
stored word-final `m` where the rules write `ṁ` for the base (`andam` to
`andaṁ`, `uṇḍaḍam` to `uṇḍaḍaṁ`, the owner's final-anusvara rule), in the block
and the flow form, and reads no card, example or other reading. `--check
--citations` lists them (exit 1 if any). It is refused with `--all` and
`--propagate`.

`--layer-anusvara` is a pass of its own for the English layers (`en/*.yaml`),
which repeat Telugu words with their reading in parentheses (`అందం (andam)`,
`చేయడం (cēyaḍam, to do)`). Inside a quoted value, a Telugu word (as many words as
the reading has, for `ఒకే పుస్తకం (oke pustakam)`) followed by ` (reading)` or
` (reading, gloss)` has its reading's final `m` rewritten to `ṁ` only when the
rules compute exactly that reading with that one change. Nothing else is
touched (no other reading, gloss, key, `ipa` or id). `--check` lists each change
and exits 1 if any; `--fix` writes them. Refused with `--all`, `--propagate` and
`--citations`.

`--check` prints each id, field, stored value and recomputed value, in two
lists: "anusvara differences" (the target holds an anusvara and the two values
agree once every nasal is treated as one, the medial-anusvara rule of
[Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology#telugu-medial-anusvara))
and "other differences" (`ph` against `f`, `ṛ` against `ru` (ఋ is computed as `ru`), IPA spelling
choices), then the total. `--fix` replaces only the exact stored value on its
own line, so comments, quoting and ordering stay byte for byte, and leaves the
other differences alone unless `--all` is given. An entry with a repeated or
non-plain `reading` or `ipa` line, or a card id repeated in the file, is
listed under "not checked or not changeable" and never changed. Keys may be
bare or double-quoted, also mixed in one file; values must be plain
double-quoted strings; the key order of a block entry is id, target, reading,
ipa (a reading before its target is reported). A file whose `part` is not
`core`, or that has no `part` key, is listed as skipped, and the last line
reads "checked N files, M entries, skipped K files". `--all` leaves alone
entries whose text has no letter of the deck's script (IPA letter cards) and
words that start with a hyphen (suffixes), and lists them as skipped. After
`--fix` the scan runs again and prints the differences left. Exit codes:
`--check` 0 if all match, 1 if any value differs, any entry could not be
checked, or (with `--propagate`) any occurrence or ambiguous word is left; `--fix` 0, or 1 if it refused a value; 2 for a bad directory. Plain `--fix` also corrects the nasals of a value that differs in
more than its nasals (the rest of the stored value is kept character for
character; listed as "nasals only"), and a stored ṇḍ for a target with ంద
(ఉందా) becomes the dental `nd`.

`--propagate` (with `--check` to list, with `--fix` to write; refused with
`--all`, exit 2: it is for plain `--fix`, which writes anusvara corrections
only) carries the corrections to what `--fix` does not read: paradigm
`readings: { ... }` maps, prose in the `en/` layer, and files with no `part`
key. Old readings are taken word by word from the readings the run changes and
replaced whole, inside quoted values only. Never touched: keys, `ipa`,
`phonetic`, `id` and `ref` values, strings that hold IPA letters, anything
after an unquoted `#`, and Telugu-script runs. A word of three letters or
fewer is never rewritten (`c`, `th`, ... are English and IPA too), nor is a
word whose new form is plain ASCII under four letters. An old word that is
also a correct reading of some card, or that becomes two different words, is
reported as ambiguous and left unchanged. Limits: `--check --propagate` counts
include the core values `--fix` itself writes; the homograph test knows only
the readings of core files with a `part` key (not those kept in paradigm maps
or in files without one); words that occur only in prose, and in no core
reading, are not found; and a paradigm map is not re-derived, so it can end
half-fixed (`cempalu` next to `ceṁpalō`). Issue #1295 stays open for a pass
over the paradigm maps. Nasals are rewritten only where the target has an
anusvara (never for a nasal consonant), and a stored `ṇḍ` becomes the dental
`nd` only where the target has ంద. Run it on a `decks-live` checkout, not on
main's frozen `decks/`.

## `import_phonetic.py` and `derive_phonetic.py`

Write each card's narrow `[ ]` IPA into its `phonetic` field, with
`phonetic_source` saying where it came from (owner, 2026-10-26 and
2026-10-30; [Plan-Ipa-Revamp-And-Language-Phonology](Plan-Ipa-Revamp-And-Language-Phonology)).
Both patch the deck's text: two lines go in after the card's `ipa:` line and
no other line changes. A card that already has a `phonetic` is skipped, and
so is one without an `ipa:` line. Without `--write` they only report. Run
the import first, then the derivation for what is left.

```sh
python3 tools/import_phonetic.py bn                 # report; downloads the dump once
python3 tools/import_phonetic.py bn --write         # patch the decks
python3 tools/import_phonetic.py bn --dump Bengali.jsonl --report bn.md
python3 tools/derive_phonetic.py bn --write         # rules, for the rest
python3 tools/derive_phonetic.py bn --bracket-unchanged --write
```

`import_phonetic.py` reads the language's Wiktextract dump from
kaikki.org (`https://kaikki.org/dictionary/<Language>/kaikki.org-dictionary-<Language>.jsonl`,
English Wiktionary, CC BY-SA 4.0), downloaded once with `urllib` into
`.cache/phonetic/` (git-ignored; `--refresh` fetches it again, `--dump FILE`
uses one you have). It finds a card's entries as `import_wiktionary.py` does
(the title is the card's `target`, the part of speech and meaning fit), takes
the first narrow `[ ]` pronunciation of the language's variety, drops the
syllable dots, writes Latin g as ɡ, and keeps it only if it is IPA letters
and marks, NFC, and every entry that fits agrees. The variety per language
is data in `tools/phonetic_languages.yaml` (dump name and variety): Bengali
the Kolkata standard (Wiktionary's Rarh), Hindustani the Standard Hindi
forms, Spanish, Telugu and Japanese the untagged form. Another language is
one more entry there, with no change to the tool. Assamese is registered
with `untagged: false`, so no Wiktionary form is taken (its 60 narrow forms
are untagged, mix conventions and some are wrong); its cards get their narrow
form from the rules. Words and set phrases
are covered; sentences are not on Wiktionary.

A language may opt in to a `normalise:` list in the same file, regex
`pattern` and `replace` pairs applied in order to each Wiktionary form so it
reads in the conventions of the language's rules file (#1369, gap 5). Only
Spanish has one: lowered approximants ð̞ β̞ ɣ̞ lose U+031E (the rules write
bare ð β ɣ), tie-barred t͡ʃ d͡ʒ become tʃ dʒ, and n̟ before θ becomes n̪. The
tie-barred ɟ͡ʝ is left as written (the rules write it the same way), and
nasalised vowels stay, being real allophony. `--renormalise` applies the
pairs to the cards already imported (those whose `phonetic_source` is
`wiktionary`), in place and with no dump; rules cards are never touched, and
a second run changes nothing.

```sh
python3 tools/import_phonetic.py es --renormalise            # report
python3 tools/import_phonetic.py es --renormalise --write    # rewrite them
```

Pronunciations in [ ] adapted from [Wiktionary](https://en.wiktionary.org), licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The app's Sources screen carries the same line.

`derive_phonetic.py` applies the ordered rules of
`decks/<lang>/<lang>-phonetics.yaml` ([format](Deck-Format#phonetic-rules-files))
to the broad `ipa`. A card the rules do not change gets nothing unless
`--bracket-unchanged`. `--rederive` also re-derives the cards whose
`phonetic_source` is `rules`, from the current rules file, replacing their
`phonetic` (the source stays `rules`) after a rule changes. It never touches
a Wiktionary card, a card with a `phonetic` and no `phonetic_source`, or a card
without a `phonetic`; a card the rules now leave unchanged is rewritten only
with `--bracket-unchanged`. It composes with `--write` (without it, only a
report) and the language argument.

```sh
python3 tools/derive_phonetic.py bn --rederive --write
python3 tools/derive_phonetic.py bn --rederive --bracket-unchanged --report bn.md
```

Both report, per deck and in all, how many cards were filled (or, with `--rederive`, rederived), already had a
`phonetic`, had none (`no phonetic`, under `--rederive` only), had no `ipa` line, and why the rest were not (no entry, no narrow
form, another variety only, ambiguous, invalid; or, for the rules, unchanged
or invalid). `test_phonetic.py` tests them on a fake dump and a tiny
language, with no network.

The patcher reads the quoting and indent from the card's own `ipa` line, not
from its id line: a plain `- id:` over quoted `"ipa":` keys (some Telugu core
files on `decks-live`), all-plain, all-quoted and JSON-style cards each get
`phonetic` and `phonetic_source` in the style of that `ipa` line, directly
after it. A card the patcher still cannot write is never silent: it is
counted in the report's `could not write (layout)` row (in a dry run too, so
the counts match a `--write` run), each is named on stderr, and a `--write`
run then exits 1.

## `compare_wiktionary_ipa.py`

Lists where the decks' IPA and Wiktionary's disagree, for a person to review
(#305, part of #217). It reads the decks and writes only a report: never a
deck.

```sh
python3 tools/compare_wiktionary_ipa.py bn                      # Markdown to the screen
python3 tools/compare_wiktionary_ipa.py bn hi --markdown review.md --json review.json
python3 tools/compare_wiktionary_ipa.py bn --dump Bengali.jsonl --limit 200
python3 tools/compare_wiktionary_ipa.py bn --rules-only         # leave out cards taken from Wiktionary
```

It takes Wiktionary's data from the same place as `import_phonetic.py`: the
language's kaikki.org dump, downloaded once into `.cache/phonetic/` and read
from there afterwards (`--dump FILE`, `--cache DIR`, `--refresh`). It makes one
download per language and never a request per word; `--limit N` compares only
the first N core cards. Cards are matched to entries, and the variety's forms
chosen and normalised, with the importer's own code and the same
`tools/phonetic_languages.yaml`: narrow forms get the variety's `normalise` and
`align` rules; broad forms only the importer's basic clean-up (`align` would
rewrite a form to the card's own unit and hide the disagreement, and the
`normalise` pairs are written for narrow conventions). Its `agree` guard is not
applied: the cards it rejects are what this list is for. `--markdown` and
`--json` refuse a path inside `decks/` or ending `.yaml` or `.yml`, so a deck
is never overwritten. Two levels are compared: the card's `ipa`
with Wiktionary's `/ /` forms, and the card's `phonetic` with its `[ ]` forms.

Each row of the review list names the kind of difference, likeliest real
error first: `consonant`, `vowel quality`, `vowel and consonant` (the base
letters differ), `tone` (tone letters ˥ ˦ ˧ ˨ ˩ differ), `contrastive mark`
(aspiration, breathy or creaky voice, voicelessness, nasalisation, dental,
secondary articulations, ejective, prenasalisation, rhoticity ˞: marks that
make a different sound in some language), `multiple Wiktionary variants`
(several forms, none the card's; one matching is agreement), then
`length mark`, `stress` (compared only when the card's form has a stress mark:
the broad `ipa` seldom does), `cosmetic mark` (any other mark: tie bar,
syllabic, unreleased, ...), and last `missing in Wiktionary` (no entry or no form; not
counted in the agreement rate). Within a kind the smaller difference comes
first. The summary gives the agreement rate per language, per level, per kind
and, for narrow forms, per `phonetic_source` (a `wiktionary` card agrees by
construction; `rules` is the real check). The JSON has the same rows and
summary, with the Wiktionary page of each word. Both carry the CC BY-SA 4.0
credit; reviewers are not named. `test_compare_wiktionary_ipa.py` tests it on
a small language and a fixture extract in `tools/fixtures/phonetic_compare`,
with no network.

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

## `deck_similarity.py`

Lists, for a reviewer, the words of a language that are close to each other
(#692). It only warns: it changes no deck and the validator does not read it.

- **Sounds like** (a `pair` note): the IPA differs by exactly one segment, and
  only between very close sounds: short and long, unaspirated and aspirated,
  dental and retroflex.
- **Looks like** (a `homograph` or `lookalike` note): the same spelling with
  another sound, or spellings that differ only by a mark that is easy to
  miss: a nukta, or a chandrabindu against an anusvara. A different vowel
  sign (कि and की) is not reported.

A pair that a `pair`, `homograph` or `lookalike` note already names is marked
explained.

```sh
python3 tools/deck_similarity.py decks/
python3 tools/deck_similarity.py decks/ --language hi --unexplained
```

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

## `readme_fonts.py`, `make_gif.py` and `phone_frame.py`

Remake the README's screenshots in `docs/screenshots/` (owner, 2026-11-16):

- `home.png`, `decks.png` and `progress.png`: Home (the Today tab), Decks and
  Progress as stills, drawn at 360 x 780 dips and three pixels to the dip,
  each put inside a phone silhouette by `phone_frame.py` (a light silver
  bezel with a darker rim, a camera dot and side buttons, transparent outside,
  so it suits the light and the dark README), under 400 KB. The screen gets
  an Android status bar above the app (the camera dot sits in it) and the
  gesture handle below it. The status bar is a PNG crop if
  `docs/screenshots/frame/status-bar-light.png` (or `-dark.png`, by the
  screen's theme) exists, else one drawn by the tool;
- `learning-session.gif`: a real lesson driven through the drill screens,
  about ten seconds: the word shown, then questions of different types
  (choose the meaning, choose the word, put in order, type it), and
  "Learned" once the learn rule is met, phone-framed (`make_gif.py --phone`),
  under 1.5 MB;
- `deck-path.gif`, `today.gif`, `progress.gif` and `review.gif`: the slow
  scrolls through four screens, now at 7 frames a second (they were 11:
  owner, 2026-11-16, "a bit slower").

A tool run when the screens change (owner, 2026-10-20), not deck tools, and
not run by the tests: the capture lives in `tools/readme_gifs/`, outside
`test/`, so `flutter test` never reaches it. `readme_fonts.py` needs fontTools,
`make_gif.py` and `phone_frame.py` Pillow (`pip install fonttools pillow`),
with the Flutter SDK on `PATH`.

A widget test draws text in boxes and turns font fallback off, so
`readme_fonts.py` first merges the SDK's Roboto with static Noto Sans Bengali
files (`NotoSansBengali-Regular.ttf`, `-SemiBold.ttf` and so on, from
[notofonts](https://github.com/notofonts/notofonts.github.io/tree/main/fonts/NotoSansBengali/hinted/ttf),
OFL-1.1), and with the IPA letters and combining marks (U+0250-036F, U+1E00-1EFF) of static Noto Sans
(`--marks`: Roboto lacks some a reading uses, such as the candrabindu
U+0310, which a test would draw as a box). Then `tools/readme_gifs/readme_gifs_test.dart`, skipped unless `README_GIFS=1`, writes
each screen's frames, the three stills and the learning session's frames as
PNGs under `build/readme_gifs/`, `make_gif.py` turns each directory of frames
into a looping GIF at 7 frames a second, one palette, under 1.5 MB (it
narrows the GIF, then cuts colours, until it fits), and `phone_frame.py`
frames a still.

```sh
python3 tools/readme_fonts.py path/to/noto-bengali build/readme_fonts \
  --marks path/to/noto-sans
README_GIFS=1 README_GIFS_FONTS=build/readme_fonts \
  flutter test tools/readme_gifs/readme_gifs_test.dart
for g in deck-path today progress review; do
  python3 tools/make_gif.py build/readme_gifs/$g docs/screenshots/$g.gif
done
python3 tools/make_gif.py --phone build/readme_gifs/learning-session \
  docs/screenshots/learning-session.gif
for s in home decks progress; do
  python3 tools/phone_frame.py build/readme_gifs/static/$s.png docs/screenshots/$s.png
done
```

The frames go to `build/readme_gifs/` (`README_GIFS_OUT` changes that). The
learner, their three and a half weeks of reviews, and the clock are fixed, so
a rerun changes an image only when the app's screens change.

### The README media workflow

Without a Flutter SDK at hand, run the **README media** workflow
(`.github/workflows/readme-media.yml`) from the Actions tab: it is by hand
only (`workflow_dispatch`), with one input, `ref`, the branch to remake the
media on (default: the branch it is run on). It checks out, sets up Flutter at
the version CI uses, downloads Noto Sans Bengali from the official Noto
repository and merges it with the SDK's Roboto (`readme_fonts.py`), runs the
capture test with `README_GIFS=1`, runs `make_gif.py` and `phone_frame.py`
as above, keeps the raw frames as a run artifact for seven days, and commits
the changed files of `docs/screenshots/` to the same ref with the message
`Regenerate README media` (nothing is committed when no image changed). It
needs `contents: write`; a push made with the workflow's own token does not
start CI, so run the checks by pushing another commit when the branch needs
them.

See also: [Deck-Building-Guide](Deck-Building-Guide) · [Home](Home)
