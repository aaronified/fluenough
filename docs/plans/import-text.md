# Plan: import any text, and make cards from its words

Written 2026-10-05.

## What the owner asked

> Import any text (LingQ): paste text, tap unknown words, create cards with
> sentence context. think about this feature as well

The ROADMAP already lists "Sentence mining from imported text" under
"Later".

## What exists

- **Decks can be added** (#22), as files, and are kept by `FileDeckStore`
  under `added/`. A deck of mined words can live there.
- **Readings and IPA are not made in the app.** `tools/transcribe.py`
  writes them when decks are made, and the app only compares typed answers
  with them (`romanised.dart`). A pasted word has no reading until one is
  made.
- **Meanings come only from the decks.** The app has no dictionary.
- **Words are split at spaces** (`wordsOf`). That does not work for Thai,
  Chinese or Japanese (`language-paths.md`).

## The feature

1. **Paste or share text** into the app, for a language being learnt.
2. **The text is shown with each word marked:**
   - known: a card the learner has learnt;
   - learning: a card being learnt;
   - in the course, not yet taught;
   - new: in no deck.
3. **Tap a word** to see its card, if it has one, or to make one:
   - **the meaning:** from the decks where the word is in one; otherwise
     typed by the learner, or from an offline dictionary (see below);
   - **the sentence it was in**, kept as the card's example, with its
     source;
   - **the reading and IPA**, if the app can make them; otherwise typed.
4. **The cards go to a deck of the learner's own** per language, such as
   "My words", and are learnt and reviewed like any other.
5. **The text is kept** to read again, with its words marked as they are
   learnt.

## What it takes

1. **A reader screen:** words marked by state, tapping, and the sentence
   around a word.
2. **Matching words to cards,** forgiving inflection where it can: a form a
   grammar table lists matches its lemma.
3. **A card maker** that writes cards into the learner's own deck, with ids
   that stay unique and permanent (AGENTS.md).
4. **Readings and IPA in the app:** a Dart port of `transcribe.py`'s rules,
   for the languages it knows (`in-app-readings.md`, which measures how
   accurate they are). Otherwise the learner types the reading.
5. **Meanings,** one of:
   - the learner types them (works offline, no licence question);
   - an offline dictionary per language, downloaded like the decks, built
     from Wiktionary through kaikki.org. That is CC BY-SA, the licence
     question in `wiktionary-ipa.md`.
6. **Tests** for word states, matching, the card maker, and ids.

## To decide

- Where meanings come from: typed, a downloaded dictionary, or both.
- Whether to port the reading and IPA rules to Dart, or ask the learner.
- Whether imported texts can be shared, or stay on the phone.
- The languages without spaces: wait for their word splitting, or leave
  them out.

## Estimate

| Part | Hours |
|---|---|
| Reader, word states, tapping, card maker | 8–12 |
| Readings and IPA in Dart, for the seven Indian languages | 8–12 |
| An offline dictionary from Wiktionary, per language | 4–6 each |

Confidence: low; most of it depends on the choices above.
