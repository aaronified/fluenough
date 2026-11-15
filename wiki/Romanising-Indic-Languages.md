# Romanising Indic languages

Source of truth: this wiki page.

## A base whose stem changes

When a card's `bases` word changes its stem in the inflected form, so the
learner cannot see the link, the card's notes say so in one short line: for
వచ్చింది (vaccindi), she came, "రావడం (rāvaḍam) changes its stem in the past:
వచ్చ- (vacc-)." See "Base words" in the format specification.

## Romanising Indic languages

A `reading` is there to help a learner say the word (#47). Each language
writes every reading in **letters based on ISO 15919's, spelled as the word is
said**, and says how in its `<code>-romanisation.yaml`
([ADR-0025](ADR-0025-Iso-15919-And-Ipa)). It is not strict ISO 15919:
the readings depart from it wherever a learner is better served. The
[README](Readings-ISO-15919#how-words-are-written-in-latin-letters-iso-15919)
has the table of letters and the
[list of departures](Readings-ISO-15919#where-the-readings-depart-from-iso-15919);
the common rules are in
[the format specification](Deck-Format#romanisation):

- **Length is marked** where the language says it: పాలు is `pālu` and పలు
  `palu`; पानी is `pānī`, दूध `dūdh`.
- **Retroflex is marked:** పాట is `pāṭa`, పాత `pāta`.
- **A nasal vowel ends in `m̐`:** हाँ is `hām̐`, नहीं is `nahīm̐`.
- **The schwa a speaker drops is not written:** कमल is `kamal`, सड़क is
  `saṛak`, not `kamala`, `saṛaka`.
- **Aspiration is an `h`:** `kh`, `gh`, `ch`, `th`, `dh`, `ph`, `bh`, each one
  sound. च is `c` and छ is `ch`, as ISO 15919 writes them.
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

Assamese writes স, শ and ষ as `x` (*ôxôm*) and the vowel sign ো as `u` (*mur*,
*muk*), as it is said (the letter ও alone is `o`); `decks/as/as-romanisation.yaml` says so.

Bengali's readings follow how it is said:

- **The inherent vowel is `ô` where it is said [ɔ] and `o` where it is said
  [o]:** কথা is `kôthā`, কমল is `kômol`, and it is left out where it is
  silent: নাম is `nām`.
- **শ, ষ and স are all `ś`,** except where a speaker says s. স is `s` when
  it is joined in a conjunct with t, th, n, r or l (স্টেশন is `sṭeśon`,
  আস্তে is `āste`), and in many English words. It stays `ś` before k and p
  (হাসপাতাল is `hāśpātāl`, নমস্কার is `nômośkār`).

See also: [Deck-Building-Guide](Deck-Building-Guide) · [Home](Home)
