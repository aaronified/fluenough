# Words, rules and sentences: self-check, notes and open questions

Companion to `words-rules-sentences.html` (#416, #417, #418, parts of #413; owner, 2026-10-23: "mockup right away"). The page holds only the screens and their tweak controls, with what is new or changed outlined in red. The checks, notes and questions are here. Nothing below is decided except what is quoted as the owner's answer; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Hindustani and Bengali. The example words, rules and sentences are made up for the page; reviewers check the real deck text (the Bengali readings follow the course: no final a).

## Screens

**#416 Lessons without the quota, and the unlock gate**
1. **Unit page.** The built unit page already counts words, rules and sentences; the three counts at the top change to "known" and "open", and the list is the phrasebook (marked Phrasebook, never held back), the words, the rules (with "7 of the last 10 right") and the sentences. A closed sentence is greyed with a lock and, by default, what it waits for.
2. **Why a sentence is closed** (a sheet from a closed sentence): each word and rule in it, with its state and the bar (9 of the last 10), and "Practise the rule".
3. **Lesson start.** What the next lesson takes, and why fewer new items.

**#417 The rule card drill**
4. **The rule card, first time:** name, a one-line explanation with readings, and the forms on 2 or 3 known words (owner, 2026-10-18: "Name, explanation, worked forms"), with a stem-change note where the word changes its stem.
5. **The drill:** choosing among forms of the same word, or typing the form; after answering, the word's forms in the rule (as the built grammar drill shows the table) with the asked cell marked.
6. **The rule's table:** rows are known words, columns the rule's forms, 3 new cells per lesson (owner, 2026-10-16), each cell known, learning or not asked yet.

**#418 Progress in words, rules and sentences unlocked** (all three places, owner, 2026-10-18)
7. **End of a lesson:** the built summary, with an "Unlocked in this lesson" card.
8. **Progress:** per language (and for All).
9. The unit page's counts (screen 1).

Decided by the owner and drawn as decided: the bar is 9 of the last 10 (2026-10-16); a lesson adds fewer new items until those in progress reach the bar, and everyone switches at once (2026-10-18); reviews never wait.

## Open questions for the owner

1. **Closed sentences on the unit page.** Control "Closed sentences".
   - Greyed with what it waits for, tap for the sheet (default): the learner sees why and what to practise. Downside: more on the page, and the sheet is another screen to build and translate.
   - Greyed with what it waits for, no sheet: simpler. Downside: it cannot show the progress bar, so "7 of 10" is lost.
   - Greyed with a lock only: least clutter. Downside: nothing says what to do.
   - Hidden until open (the plan's "not offered"): a short page. Downside: the learner cannot see what is coming, and a unit looks smaller than it is.
2. **Lesson start.** Control "Lesson start".
   - A plan screen before the lesson: explains the smaller lessons. Downside: one more tap before every lesson.
   - One line on Today ("Fewer new items today: 3 words are under 9 of 10 right"): no extra screen. Downside: Today is already busy, and the line needs a plain wording of the bar.
   - Nothing: the lesson just starts. Downside: a lesson with 2 new items instead of 6 looks like a bug.
3. **What the drill shows after an answer.** Control "After answering".
   - The word's forms in the rule (drawn first): teaches the pattern. Downside: a taller screen, and one more thing to read after every card.
   - The correct banner only: faster. Downside: the stem change and the other forms are only seen on the rule's table.
4. **Choosing or typing.** The plan has both (the options are forms of the same word; typing is given the word and the meaning). Which comes first for a new cell, and does typing replace choosing once a cell is learning? Downside of choosing first: guessing among four forms is easier to get right than to produce.
5. **The rule table.** Control "Table". Rows of known words only (plan), or also the next word, locked. Downside of showing it: more to look at, and a lock on something the learner cannot act on yet.
6. **End of a lesson.** Control "Lesson end". Counts and the sentences just opened (drawn), or counts only. Downside of examples: the card grows, and a lesson that opens many sentences needs a cut-off (drawn: two).
7. **Progress.** Controls "Progress" and "Counts are".
   - A, three tiles in place of the Words tile (Words, Rules, Sentences), the Level tile alone below: the three counts are the first thing seen. Downside: the Words tile loses its "mastered / taught" line, and the Level tile loses its place beside it.
   - B, a panel below the week: the Words and Level tiles stay as built. Downside: Words is then counted twice (the tile and the panel).
   - Counts of what is taught so far (as the Words tile is), or of the B1 plan (the owner's rule for hours was "in the decks so far", 2026-10-10). Downside of the plan: a tiny share early on (86 of 900), which can feel like no progress.
8. **What counts as a word.** "Words known" is by base word (`b1-plans`), so two forms of one word are one word. Should the Words tile's "mastered" (today's figure) become the same count? It would change today's number.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) in Chromium, both themes. Text 4.5:1, icons, outlines and fills 3:1. All  pairs pass.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | captions, readings | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | text on cards | onS on sLow | 15.5 :1 | 4.5 :1 | pass |
| light | captions on cards | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | text on raised blocks | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | captions on raised blocks | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | tonal button, Learning chip, correct option, learning cell | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | filled button, Known chip, known cell | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | link and icon on cards | p on sLow | 5.85 :1 | 4.5 :1 | pass |
| light | Rule and Phrasebook chip | onTC on tC | 7.24 :1 | 4.5 :1 | pass |
| light | pronounced stem letter on page | p on s | 6.16 :1 | 4.5 :1 | pass |
| light | stem letter on a raised block | p on sHigh | 5.29 :1 | 4.5 :1 | pass |
| light | option outline against page | ol on s | 4.28 :1 | 3 :1 | pass |
| light | not-asked cell outline against card | ol on sLow | 4.06 :1 | 3 :1 | pass |
| light | not-asked cell text on page | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | locked cell text on raised block | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | bar fill on track | p on sHigh | 5.29 :1 | 3 :1 | pass |
| light | change tag | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change outline on card | E on sLow | 5.85 :1 | 3 :1 | pass |
| light | flame on card | fire on sLow | 5.48 :1 | 3 :1 | pass |
| dark | body text | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | captions, readings | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | text on cards | onS on sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | captions on cards | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | text on raised blocks | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | captions on raised blocks | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | tonal button, Learning chip, correct option, learning cell | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | filled button, Known chip, known cell | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | link and icon on cards | p on sLow | 10.05 :1 | 4.5 :1 | pass |
| dark | Rule and Phrasebook chip | onTC on tC | 7.24 :1 | 4.5 :1 | pass |
| dark | pronounced stem letter on page | p on s | 10.86 :1 | 4.5 :1 | pass |
| dark | stem letter on a raised block | p on sHigh | 8.46 :1 | 4.5 :1 | pass |
| dark | option outline against page | ol on s | 5.84 :1 | 3 :1 | pass |
| dark | not-asked cell outline against card | ol on sLow | 5.4 :1 | 3 :1 | pass |
| dark | not-asked cell text on page | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | locked cell text on raised block | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | bar fill on track | p on sHigh | 8.46 :1 | 3 :1 | pass |
| dark | change tag | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change outline on card | E on sLow | 10.09 :1 | 3 :1 | pass |
| dark | flame on card | fire on sLow | 10.04 :1 | 3 :1 | pass |

## 1.4x fit

- Every size on the phones is `calc(N px * 1.4)`. Checked in Chromium at 1280 px wide: no page error, no console error, no horizontal page scroll, and no element past its phone's edge, with every tweak control pressed in both courses and both themes (84 presses). Screenshots were taken of the whole page in both themes and in Bengali with the typing, answered, locked-row and panel options on.
- The rule table has three form columns plus the word, so a cell is about 70 dp wide: the cell text is 12.5 dp x 1.4 (a little under body size) and a long Bengali form such as বাজারের wraps inside the cell. This is the tightest place on the page; a fourth column would not fit at 1.4x.
- The Progress tiles (option A) are 104 dp wide: the label is one word, the figure fits, and the line under it ("known of 540 taught") wraps to two lines.
- The unit page, the rule card and the drills scroll inside the phone; the bottom button stays.

## Notes

- A sentence names the rules it uses and its base words; it opens once all are known at the bar. Until then it is not offered and does not hold back its unit. Reviews never wait.
- A rule's question tests the rule, never the word: the options are forms of the same word (घर में, घर पर, घर से, घर का), never a different word. The word is always one the learner knows.
- Where a word changes its stem (लड़का to लड़के से; Bengali বই + এ to বইতে), the rule card and the answer say so, as `docs/DECK-FORMAT.md` asks of a card's notes.
- The language bar is drawn simplified, as in `hours-per-language.html`; the lesson summary is the built one with its tiles reduced to three and the skill rows left out, to keep the page about the new card.
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts.
