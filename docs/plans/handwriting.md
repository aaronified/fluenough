# Plan: handwriting the script, stroke by stroke

Written 2026-10-05.

## What the owner asked

> script handwriting to be added as well when scripts start appearing. app
> will show the sequence of strokes in a GIF animation. user will have two
> levels, once trace over existing character line, and then draw blind.
> like how wagatomi does this for japanese. ask if there is still doubt

Decided with the owner:

- **The animation is drawn live in the app** from vector stroke paths, not
  shipped as GIF files. It stays sharp at any size and follows the theme
  and text size, and the same paths check the drawing.
- **The app checks both levels.** Each stroke is compared with the model
  for order, direction and shape, within a tolerance. If the app is wrong,
  the learner can override it with "I drew it right".
- **Handwriting is a skill of its own, with reviews:**
  - tracing comes first;
  - drawing blind once tracing is passed;
  - then spaced reviews like the other skills;
  - it can be switched off.
- **First the letters and vowel signs:** vowels, consonants and vowel signs,
  about 70 per Indian script, plus hiragana and katakana. Conjuncts and
  kanji come later.

## What exists

- **Each Indian language has script decks:** 11–13 vowels, 34–39
  consonants, 18–24 vowel signs, 17–25 conjuncts, and a reading deck.
  Japanese has a hiragana deck of 46, kept but hidden.
- **The script comes late** in every path (owner's ruling). A learner who
  learns without the alphabet skips the script units, and would skip
  handwriting with them (ADR-0023).
- **The app has no drawing input.** Its painters only draw the brand mark
  and a progress wave.
- **Skills are modes**, stored by name, so adding a `writing` mode is
  additive in the database.

## Stroke data

- Each character needs its strokes, in order. Each stroke is a path with a
  start and a direction. Some scripts also need the frame they are written
  in, such as Devanagari's headline.
- **Japanese:** [KanjiVG](https://kanjivg.tagaini.net/) has stroke paths in
  order for kana and kanji. Its licence is CC BY-SA 3.0, so it must be
  credited and shared alike. That is the same licence question the
  Wiktionary plan raises for the CC0 decks.
- **Indian scripts:** I know of no open dataset of stroke orders
  (confidence medium). The strokes would be drawn by hand, about 490
  characters for seven scripts.
  - Stroke order also differs between schools. Devanagari's headline is
    often drawn last, for example.
  - Each script needs one stated convention, and a check by someone who
    writes it.
- **Format:** a stroke file per script, such as
  `decks/<lang>/<lang>-strokes.yaml`, with one SVG path per stroke for each
  character. That is a new file kind, and a deck format change needs the
  owner's answer (AGENTS.md). The validator checks that every character has
  strokes and that each path is valid.

## What it takes

1. **The animation:** strokes drawn one after another, at the learner's
   speed, with replay. The start of each stroke is marked.
2. **Tracing:**
   - the model shows faintly, and the learner draws over it, stroke by
     stroke;
   - each stroke is resampled and compared with the model's: the right
     start, end and direction, near its path;
   - a wrong stroke is shown at once, and can be drawn again.
3. **Drawing blind:**
   - an empty box, with only the script's guide lines;
   - the same check, more forgiving of position and size, since the drawing
     is scaled to its box first;
   - afterwards the model is shown beside the drawing.
4. **Recorded as the `writing` skill:**
   - right first time is 5, right with forgiveness is 3, and wrong is 1;
   - "I drew it right" counts as right with forgiveness.
5. **Where it appears:** after a character is taught in the script units,
   and then in reviews. A learner without the alphabet never sees it.
6. **Tests** for stroke matching on drawn fixtures, the levels, the
   override, and the skill's scheduling.

## To decide

- The stroke-order convention for each Indian script, and who checks it.
- KanjiVG's CC BY-SA licence beside the CC0 decks.
- How forgiving the check is, tuned on real drawings.
- Whether a vowel sign is drawn alone, or on a consonant (कि).

## Estimate

| Part | Hours |
|---|---|
| Drawing, the animation, stroke matching, the two levels | 9–13 |
| The skill and its scheduling | 2–3 |
| Kana from KanjiVG | 2–3 |
| Strokes drawn by hand for about 490 characters in seven Indian scripts | 40–80 |

Confidence: low for the strokes, medium for the app.
