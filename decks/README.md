# Decks

Deck content, one YAML file per deck, organised by language code.

```
decks/
  bn/  bn-en-first-words.yaml     one deck per theme in themes.yaml
       bn-en-questions.yaml …
       bn-en-path.yaml            the order the course is taught in
  es/  es-en-core-100.yaml
       es-en-grammar-present-ar.yaml
       es-en-path.yaml
  hi/  hi-en-first-words.yaml     one deck per theme in themes.yaml
       hi-en-questions.yaml …
       hi-en-path.yaml
  ja/  ja-en-hiragana.yaml        kept in the repository but not bundled in the app for now
       ja-en-path.yaml
  te/  te-en-first-words.yaml     one deck per theme in themes.yaml; not yet checked by a Telugu speaker
       te-en-questions.yaml …
       te-en-path.yaml
  mr/  mr-en-first-words.yaml     the same, for Marathi; not yet checked by a Marathi speaker
  kn/  kn-en-first-words.yaml     the same, for Kannada; not yet checked by a Kannada speaker
  gu/  gu-en-first-words.yaml     the same, for Gujarati; not yet checked by a Gujarati speaker
  as/  as-en-first-words.yaml     the same, for Assamese; not yet checked by an Assamese speaker
  themes.yaml
```

**Every deck is on its course's path.** `<lang>-<native>-path.yaml` lists the
course's decks in teaching order, in units, and the validator fails a deck
left off it. See "Course paths" in the format specification.

- Format specification: [../docs/DECK-FORMAT.md](../docs/DECK-FORMAT.md)
- How to contribute one: [../CONTRIBUTING.md](../CONTRIBUTING.md)

**Adding a language means adding its directory to `pubspec.yaml`.** A Flutter
asset entry bundles only the files directly inside the directory it names, so
`flutter.assets` needs one `- decks/<lang>/` line per language. Validating the
whole of `decks/` — which is what CI does — fails if a directory holding decks
has no entry, because the alternative is an app that builds and ships without
that language in it. Validating a single deck or one language directory only
checks what you pointed it at. `decks/ja/` is left out on purpose for now: it
is listed in `NOT_BUNDLED` in `tools/validate_decks.py`, and still validated.

Validate before committing — CI runs exactly this:

```sh
python3 tools/validate_decks.py decks/
```

## Every language

- **An ISO 639-3 code on every language block.** `language` and `native` both
  carry `iso639_3` (`hin`, `spa`, `eng`) beside `code`. CI rejects a deck
  without one.
- **A facts file, `<code>-facts.yaml`, with at least 30 facts.** One fact about
  the language is shown each day, and 30 of them must be true whatever the
  learner's interface language. Facts that compare it with one interface
  language (say, how its s sounds differ from English) are extra and marked
  `contrast`. See "Facts files" in the format specification. CI checks a facts
  file when there is one; it does not yet require every language to have one.

## Romanising Indic languages

A `reading` is there to help a learner say the word, and to let them answer
in it (#47). Each language writes every reading in one scheme, the way its
speakers type it in a chat, and names that scheme in its
`<code>-romanisation.yaml`. The common rules are in
[the format specification](../docs/DECK-FORMAT.md#romanisation):

- **Lowercase ASCII, no marks:** no diacritics, no capitals, and **no doubled
  vowels** for length. पानी is `pani`, दूध is `dudh`, మీరు is `miru`.
- **A nasal vowel is followed by `n`:** हाँ is `han`, नहीं is `nahin`.
- **The schwa a speaker drops is not written:** कमल is `kamal`, सड़क is
  `sarak`, not `kamala`, `saraka`.
- **Aspiration is an `h`:** `kh`, `gh`, `chh`, `th`, `dh`, `ph`, `bh`. श and ष
  are both `sh`. ड़ is `r` and ढ़ is `rh`.
- **Retroflex and dental consonants are not told apart** in the reading. The
  script tells them apart, and the notes say so where it matters.
- **A letter card for ङ or ञ on its own** (and their Bengali, Telugu,
  Kannada and Gujarati twins) reads `nga` or `nya`, so that it differs from
  न. Words write `n`.
- **A grammar row whose lemma is English** has no `reading`; its forms do.
- **Spellings learners also type**, such as `ee` for `i` or `w` for `v`, are
  listed as `equivalents` in the romanisation file. Grading treats them as
  the decks' own.

Bengali differs in two ways, and its readings follow how it is said:

- **The inherent vowel is `o`, never `a`:** কমল is `komol`, বন is `bon`.
  `o` stands for both অ and ও.
- **শ, ষ and স are all `sh`,** except where a speaker says s. স is `s` when
  it is joined in a conjunct with t, th, n, r or l (স্টেশন is `steshon`,
  আস্তে is `aste`), and in many English words. It stays `sh` before k and p
  (হাসপাতাল is `hashpatal`, নমস্কার is `nomoshkar`), and where it is written
  apart from the next letter (আসতে is `ashte`, আসলাম is `ashlam`).

## Decks no speaker has checked

Tag a deck `unreviewed` when no native speaker has checked it. The app then
says so on the deck's screen and asks speakers to report mistakes, and the
deck's `description` should say so too. The Telugu decks carry it (#39), and
so do the Marathi, Kannada, Gujarati and Assamese ones.

## Two rules that matter more than the rest

**Quote your romanisations.** YAML turns bare `no`, `yes`, `on` and `off` into
booleans. The hiragana `の` romanises to `no`, so this is not hypothetical.

**Never reuse or renumber a card id.** Ids key every user's review history.
Changing one orphans their progress on that card; reusing one attaches old
history to new content. To retire a card, delete it.

## Quoted books

The Bengali reading deck quotes Rabindranath Tagore's *Sahaj Path*, part 1
(1930, in the public domain), letter for letter from the Visva-Bharati
printing of 1993; two readers checked every passage against the page images.
The spelling deck quotes older spellings printed in *Sahaj Path* and in the
Shaibya printing of Sukumar Ray's *Abol Tabol*.

The Hindi reading deck quotes Premchand's story *Panch Parmeshwar* (in the
public domain) from *Prem-Dwadashi*, the 1926 printing scanned on Wikimedia
Commons. Every sentence was checked against the page images: where the
Wikisource transcription differs (a missing nukta, mostly), the page wins.
The print's misprints are not corrected; a sentence with one is left out.

The Telugu reading deck quotes Gurajada Apparao's story *Diddubatu* (1910, in
the public domain) from *Gurujadalu* (MaNaSu Foundation, 2012), the collected
works scanned on Wikimedia Commons. Every sentence was checked against the
page images; where the Wikisource transcription differs (a long vowel sign
where the page has a short one, and punctuation, mostly), the page wins.

Never correct a quoted text: explain a difference in a note.

## Deck licences

Each deck declares its own `license`, separate from the app's GPL-3.0. The
decks here are CC0-1.0 (public domain). Contributed decks may use any licence
permitting redistribution, declared in the file.
