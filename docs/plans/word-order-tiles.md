# Plan: word-order tiles without giveaways, and with extra tiles

Written 2026-10-05.

## What the owner asked

> sentence production drills should not have pills with punctuation marks
> or capitalisations, so that they are not obvious. add punctuations
> separately. and also add words / punctuations which are not needed (at
> least 2-3 in total) but similar (hand craft the options for each card).

## What exists

- A sentence is produced by putting its words in order (`Ask.rearrange`,
  ADR-0024). This applies to a card of three words or more, or a phrase of
  two or more: 1,098 cards.
- The tiles are the card's words, split at spaces (`wordsOf`). Punctuation
  stays on its word, so the tile with "।" or "?" is plainly the last.
  Hindi hi-0480, मैंने चाय पी। (I drank tea), gives the tiles मैंने · चाय ·
  पी।
- 856 of the 1,098 cards have punctuation. Each mark appears this often:

  | Mark | . | । | ? | … | ' | , | ! | - |
  |---|---|---|---|---|---|---|---|---|
  | Times | 351 | 281 | 196 | 23 | 23 | 18 | 15 | 3 |

- No tile has a capital today: the Indian scripts have none, and the
  Spanish sentences are lowercase. A capitalised sentence, or a reading in
  Latin letters, would give its first word away the same way.
- Every tile must be placed before Check can be pressed, and the answer is
  right when the words, joined by spaces, match an accepted answer.

## What it takes

1. **Tiles without giveaways:**
   - the words with no punctuation at their edges;
   - in lowercase, where the script has case.

   An apostrophe or a hyphen inside a word stays in it.
2. **Punctuation as tiles of their own:** each mark the sentence has
   (। . ? , ! …) is a tile, placed like a word. The answer shown afterwards
   is the sentence as written, with its capital and marks.
3. **Extra tiles, written for each card:** two or three in total, words or
   marks, that are not needed but are close to the ones that are. For
   hi-0480:

   | Needed | Extra |
   |---|---|
   | मैंने · चाय · पी · । | पिया (the masculine form; चाय is feminine) · मैं (without ने) · ? |

   This needs a field on the card, such as:
   ```yaml
   extra_tiles: ["पिया", "मैं", "?"]
   extra_readings: ["piyā", "maim̐", "?"]   # the same, for Latin letters
   ```
   That changes the deck format, which needs the owner's answer
   (AGENTS.md).
4. **Validator:**
   - 2 or 3 extra tiles;
   - none equal to a tile the answer needs;
   - extra readings in ISO 15919 letters, matching the extras one for one.
5. **Checking:**
   - Check can be pressed once as many tiles are placed as the answer has;
   - the answer is right when the words and marks are in order and no extra
     is used.
6. **Content:** extra tiles for the 1,098 cards, written per language by
   agents, then validated and marked for a speaker's check. They are best
   chosen from what learners confuse: gender and number agreement, ने
   (Hindi), case endings, a similar word, a question mark for a full stop.
7. **Tests** for the tiles, the marks, the extras, the check, and the
   validator.

## To decide

- The field names, and whether Latin-letter extras are required.
- Whether a missing or wrong mark makes the answer wrong, or almost right
  (graded 3).
- Whether every card needs extra tiles before the drill shows any, or the
  drill uses them where a card has them.

## Estimate

- The app: about 3–4 hours.
- The extras: about 1–2 hours per language with checking, for the 1,098
  cards.

Confidence: medium.
