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
  ja/  ja-en-hiragana.yaml
       ja-en-path.yaml
  te/  te-en-first-words.yaml     one deck per theme in themes.yaml; not yet checked by a Telugu speaker
       te-en-questions.yaml …
       te-en-path.yaml
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
checks what you pointed it at.

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

A `reading` is there to help a learner say the word, so every Indic deck
writes it the same way, in plain ASCII:

- **Long vowels are doubled:** `aa`, `ii`, `uu` (पानी is `paanii`, दूध is
  `duudh`). Short ones are single.
- **A nasal vowel is followed by `n`:** हाँ is `haan`, नहीं is `nahiin`.
- **The schwa a speaker drops is not written:** कमल is `kamal`, सड़क is
  `sadak`, not `kamala`, `sadaka`.
- **Aspiration is an `h`:** `kh`, `gh`, `chh`, `th`, `dh`, `ph`, `bh`. श and ष
  are both `sh`.
- **Retroflex and dental consonants are not told apart** in the reading. The
  script tells them apart, and the notes say so where it matters.

Bengali differs in two ways, and its readings follow how it is said:

- **The inherent vowel is `o`, never `a`:** কমল is `komol`, বন is `bon`.
  `o` stands for both অ and ও.
- **No doubled vowels:** Bengali does not tell long and short vowels apart,
  so আ is `a`, ই and ঈ are `i`, উ and ঊ are `u`. শ, ষ and স are all `sh`,
  except where a speaker says s. স is `s` when it is joined in a conjunct
  with t, th, n, r or l (স্টেশন is `steshon`, আস্তে is `aste`), and in
  many English words. It stays `sh` before k and p (হাসপাতাল is
  `hashpatal`, নমস্কার is `nomoshkar`), and where it is written apart from
  the next letter (আসতে is `ashte`, আসলাম is `ashlam`).

Telugu tells short e and o from long ones, so its readings double those
too: ఏడు (seven) is `eedu`, and ఎడమ (left) is `edama`.

## Decks no speaker has checked

Tag a deck `unreviewed` when no native speaker has checked it. The app then
says so on the deck's screen and asks speakers to report mistakes, and the
deck's `description` should say so too. The Telugu decks carry it (#39).

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
