# Decks

Deck content, one YAML file per deck, organised by language code.

```
decks/
  bn/  bn-en-first-words.yaml     one deck per theme in themes.yaml
       bn-en-questions.yaml …
       bn-path.yaml               the order Bengali is taught in, from every language
  es/  es-en-core-100.yaml
       es-en-grammar-present-ar.yaml
       es-path.yaml
  hi/  hi-en-first-words.yaml     one deck per theme in themes.yaml
       hi-en-questions.yaml …
       hi-path.yaml
  ja/  ja-en-hiragana.yaml        kept in the repository but not bundled in the app for now
       ja-path.yaml
  te/  te-en-first-words.yaml     one deck per theme in themes.yaml; not yet checked by a Telugu speaker
       te-en-questions.yaml …
       te-home.yaml               a core: the Telugu side of a deck, for every learner
       en/  te-en-home.yaml       its English layer; merged, they are the deck te-en-home
       te-path.yaml               the path, by core id, with Telugu's regions
  mr/  mr-en-first-words.yaml     the same, for Marathi; not yet checked by a Marathi speaker
  kn/  kn-en-first-words.yaml     the same, for Kannada; not yet checked by a Kannada speaker
  gu/  gu-en-first-words.yaml     the same, for Gujarati; not yet checked by a Gujarati speaker
  as/  as-en-first-words.yaml     the same, for Assamese; not yet checked by an Assamese speaker
  themes.yaml
```

**A deck may be a core and its layers.** The core,
`decks/<lang>/<lang>-<name>.yaml`, holds the language learnt; each layer,
`decks/<lang>/<native>/<lang>-<native>-<name>.yaml`, holds one native
language's meanings, notes and labels, and the two merged are the deck
`<lang>-<native>-<name>`. Every deck in a B1 plan is split as its plan is
written. See "Core and layer files" in the format specification.

**Every deck is on its language's path.** `<lang>-path.yaml` lists the
language's decks in teaching order, in units, by core id (`te-home` for
`te-en-home`), once for every language it is taught from; each course reads
it through its own decks, and a unit with none of them is "Coming" for that
course. The validator fails a deck left off it. See "Paths" in the format
specification.

- Format specification: [../docs/DECK-FORMAT.md](../docs/DECK-FORMAT.md)
- How to contribute one: [../CONTRIBUTING.md](../CONTRIBUTING.md)

**Adding a language means adding its directory to `pubspec.yaml`.** A Flutter
asset entry bundles only the files directly inside the directory it names, so
`flutter.assets` needs one `- decks/<lang>/` line per language. Validating the
whole of `decks/` — which is what CI does — fails if a directory holding decks
has no entry, because the alternative is an app that builds and ships without
that language in it. A layer folder needs its own line too, `- decks/te/en/`,
added in a one-line commit with the language's first layer. Validating a single deck or one language directory only
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

A `reading` is there to help a learner say the word (#47). Each language
writes every reading in **ISO 15919's letters, spelled as the word is said**,
and says how in its `<code>-romanisation.yaml` ([ADR-0025](../docs/adr/0025-iso-15919-and-ipa.md)).
The [README](../README.md#how-words-are-written-in-latin-letters-iso-15919)
has the table; the common rules are in
[the format specification](../docs/DECK-FORMAT.md#romanisation):

- **Length is marked** where the language says it: పాలు is `pālu` and పలు
  `palu`; पानी is `pānī`, दूध `dūdh`.
- **Retroflex is marked:** పాట is `pāṭa`, పాత `pāta`.
- **A nasal vowel ends in `m̐`:** हाँ is `hām̐`, नहीं is `nahīm̐`.
- **The schwa a speaker drops is not written:** कमल is `kamal`, सड़क is
  `saṛak`, not `kamala`, `saṛaka`.
- **Aspiration is an `h`:** `kh`, `gh`, `ch`, `th`, `dh`, `ph`, `bh`, each one
  sound. च is `c` and छ is `ch`, as in ISO 15919.
- **A letter card for ङ or ञ on its own** reads `ṅa` or `ña`; Bengali's
  read `ṅô` and `ñô`, so that ঞ differs from ন.
- **A grammar row whose lemma is English** has no `reading`; its forms do.
- **Every reading has an `ipa` beside it,** broad, without slashes.
- **To write both for a new card,** run
  `python3 tools/transcribe.py <code> "<word>" <how it is typed>`: the word as
  people type it shows what is said.

A typed answer needs none of the marks. The romanisation file's `typed`
list says how its letters are typed (`c` as `ch`, `ś` as `sh`), and its
`equivalents` the spellings learners also type for one sound, such as `ee`
for `i`; grading treats them all as the decks' own.

Assamese writes স, শ and ষ as `x` (*ôxôm*) and ও as `u` (*mur*), as it is
said; `decks/as/as-romanisation.yaml` says so.

Bengali's readings follow how it is said:

- **The inherent vowel is `ô` where it is said [ɔ] and `o` where it is said
  [o]:** কথা is `kôthā`, কমল is `kômol`, and it is left out where it is
  silent: নাম is `nām`.
- **শ, ষ and স are all `ś`,** except where a speaker says s. স is `s` when
  it is joined in a conjunct with t, th, n, r or l (স্টেশন is `sṭeśon`,
  আস্তে is `āste`), and in many English words. It stays `ś` before k and p
  (হাসপাতাল is `hāśpātāl`, নমস্কার is `nômośkār`).

## Decks no speaker has checked

Tag a deck `unreviewed` when no native speaker has checked it. The app then
says so on the deck's screen and asks speakers to report mistakes, and the
deck's `description` should say so too. The Telugu decks carry it (#39), and
so do the Marathi, Kannada, Gujarati and Assamese ones. Once a speaker has
checked a deck, tag it `reviewed` instead: a deck is one or the other, and a
file with a culture note must carry one of the two.

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
