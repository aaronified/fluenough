# Plan: a listening tier in context

Written 2026-10-05.

## What the owner asked

> add a new difficulty tier in listening exercises: use the word in a
> sentence or the sentence in a short paragraph of related content and then
> ask questions whose answers depend on the word being recognized (hand
> craft the options for each card).

## What exists

- **Listening today is the word alone:**
  - lessons ask *hear and choose*: the word is played, and the learner picks
    it among other words the app chooses (`choicePool`);
  - reviews ask *hear and type*;
  - the phonemic-contrasts drill (#31), which plays one of two words that
    differ by one sound, is built but not switched on.
- **Heard passages** (ADR-0019) are the nearest thing to this tier. A
  reading deck's passage is read aloud with its text hidden, then 2–4
  questions are asked. Each question is a card with its own schedule, and
  its options are written by hand, keyed by the learner's language with
  `en` required. That machinery can be reused.
- **3,809 vocabulary cards** outside the script decks would each need a
  context written:

  | as | bn | gu | hi | kn | mr | te | es |
  |---|---|---|---|---|---|---|---|
  | 525 | 681 | 560 | 530 | 478 | 545 | 449 | 41 |

## The tier

After the word alone, two harder steps:

1. **The word in a sentence.** The sentence is played, then a question is
   asked whose answer is the word's meaning.
2. **The sentence in a short paragraph** of two to four sentences on the
   same subject, so the word has to be picked out of more speech.

The options are written for each card. Besides the right answer, they hold
words of the same kind, so only recognising the word gives the answer. For
example, Hindi दूध, milk (hi-0259):

- Heard: मैंने दूध पिया। *mainnē dūdh piyā.*
- Asked: What did I drink?
- Options: milk · water · tea · buttermilk

This example is illustrative and has not been checked by a speaker.

## What it takes

1. **Format:** a `context` field on a vocabulary card, written by hand:
   ```yaml
   context:
     sentences:          # 1 for the sentence step, 2–4 for the paragraph
       - text: "मैंने दूध पिया।"
         reading: "mainnē dūdh piyā."
         ipa: "mɛːnneː d̪uːd̪ʱ pɪjaː"
     question:
       prompt: { en: "What did I drink?", bn: "…", hi: "…" }
       options:
         - { en: "milk", bn: "…", hi: "…" }
         - { en: "water", bn: "…", hi: "…" }
         - { en: "tea", bn: "…", hi: "…" }
         - { en: "buttermilk", bn: "…", hi: "…" }
       answer: 0
   ```
   This changes the deck format, which needs the owner's answer
   (AGENTS.md).
2. **Validator:**
   - the word occurs in one of the sentences, as a passage's glossary word
     must;
   - 3 or 4 options, with `en` in every prompt and option;
   - the answer is in range;
   - readings in ISO 15919 and the IPA, as on cards.
3. **Scheduling**, one of two ways:
   - a harder way of asking the word's Hear schedule (`skill-model.md`),
     once its FSRS stability passes a threshold, with no new schedule; or
   - a schedule of its own.
4. **The drill:**
   - plays the sentences at the learner's rate, with replay;
   - hides the text until the question is answered, as heard passages do;
   - then shows the text, its reading and the IPA.

   It obeys the sound switch and the muted-volume message, as other heard
   questions do.
5. **Content, in phases:**
   - first the opening units of each language: first words and the first
     five themes;
   - then the rest, deck by deck.

   Each batch passes the validator and is marked for a speaker's check, as
   the other agent-written decks are.
6. **Tests** for the parser, the validator, the drill and the threshold.

## To decide

- A harder way of asking Hear, or a schedule of its own.
- The threshold for the sentence step, and for the paragraph step.
- The languages the question and options are written in: `en` alone, or
  `en`, `bn` and `hi`, as the facts are.
- Which decks come first.

## Estimate

- The app: about 4–6 hours.
- Content: about 2 hours per 50 cards with checking, so roughly two days
  of work per language for the whole course.

Confidence: low for the content, medium for the app.
