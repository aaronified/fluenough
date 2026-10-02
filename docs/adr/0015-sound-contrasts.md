# ADR-0015: A language's sound contrasts live in a file of their own

- **Status:** Accepted
- **Date:** 2026-10-02

## Context

#89's rule for pronunciation feedback: say something only when the slip
changes the word. An accent that keeps the word is recognised as the
target and passes. But when the word heard is the target with one sound
changed, such as খাল for কাল in Bengali, the learner should hear which
sound: here, the breath after the k.

Which sounds a language tells apart that English doesn't, and how each is
written, is knowledge about the language, not the app. The maintainer
chose, on 2 October 2026, to keep it in `decks/<lang>/<lang>-sounds.yaml`,
shared with the minimal-pair drill (#31).

## Decision

- **One sounds file per language,** `kind: sounds`, beside its decks:
  `decks/bn/bn-sounds.yaml`. It lists contrasts. Each has an id, a name
  that completes "The difference is …", and the pairs of letters or signs
  that make it in writing: ক and খ for aspiration, or a vowel sign and
  nothing, as in জল and জাল.
- **The speaking drill uses it** after grading. When a spoken answer is
  wrong, and the word heard is an accepted answer with exactly one pair
  swapped, the feedback names the contrast. If a deck in the language has
  the word heard, the feedback also says what it means. Otherwise it says
  only what was heard, as before.
- **A sign added or taken away can be limited to inside a word**
  (`within_word`). Adding a vowel sign at the end of a word adds a
  syllable, which isn't the same contrast.
- **Letters are compared whole.** The grader's spelling normaliser takes
  some letters apart: Bengali ো becomes ে and া, and ড় becomes ড and a
  nukta. Taken apart, an e said for an o would look like an a added. So
  the check puts them back together first, both the words and the file's
  pairs.
- **Contrast ids are the tags** a language's sound-differences deck puts
  on its minimal pairs. That way the minimal-pair drill can find a
  contrast's pairs by tag.
- **The validator checks the file:**
  - the id and the folder match the language;
  - contrast ids are unique;
  - each contrast has a name;
  - each pair is two different strings, at most one of them empty.

## Consequences

- Contrast feedback is data. A new language gets it by adding a sounds
  file; no code changes.
- Only one swap is named. A word heard with two changes is "another word",
  which is honest: the drill can't tell which change the learner meant.
- Matching runs on writing, not sound. A recogniser that spells a word
  its own way misses the match, and the feedback falls back to "You said
  …". It never names a contrast that isn't there.
- The contrasts shipped for Bengali, Hindi and Telugu are drafts for the
  maintainer to check, like the decks tagged `unreviewed`.

## Alternatives considered

- **Contrasts inside each deck.** They belong to the language, not one
  deck, and they would be repeated in every deck.
- **Phonetic comparison** (IPA, or the recogniser's audio). That needs
  more than the recogniser gives, and is #29 and later.
- **Comparing against the minimal pairs only.** It would name a contrast
  only for words in the sound-differences deck. Pairs of letters cover
  every word.
