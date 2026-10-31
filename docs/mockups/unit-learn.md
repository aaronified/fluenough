# Unit page, Learn and Relearn: self-check, notes and doubts

Companion to `unit-learn.html` (#694; owner, 2026-10-31: "Why would units need 'continue'? Learn / relearn is the only thing they need. I didn't get this"). The page holds only the screens and their tweak controls, with what changed outlined in red. The checks, notes and doubts are here. Where nothing is decided the most conservative option is drawn; each alternative is a tweak control and a numbered doubt below.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed (#3F6C51), light and dark, Hindustani and Bengali examples (Bengali readings follow the course: no final a). Theme, course and highlight are global controls.

## What is decided (drawn as decided)

- The unit page gets Learn / Relearn only, not the Continue bar (owner, 2026-10-31).
- Learn is the card-by-card walkthrough, on main since PR #943: each first view appends one lowest-window review-log row (graded 0, `Ask.teach`), nothing is asked. Relearn shows once every card is taught and writes nothing.
- Swipe and chevrons go on and back everywhere in the walkthrough; no Continue button. The walk ends when the learner goes on from the last card or closes it.
- Stats skip view rows; a repeat view writes nothing; Today's lesson is unchanged (owner, 2026-10-31, #694).

## What the screen is today

`lib/features/decks/unit_page.dart`: app bar (course heading, report), header (level pill, "Unit 4", name, description), tiles (words known, rules known, sentences open, each where the unit has some), Words (first 6, "Show all"), Rules, Sentences (a sentence not open is greyed, locked, "Waiting for ..."), "Decks in this unit", and the pinned `_ContinueBar`: "Continue · N new, M due" (reviews what is due, else teaches the next words in a lesson), or "Nothing new or due", off. The unit page has no tag chips; the chips are on the deck page (`deck_detail_page.dart`). The left phone of section 1 is that, with the example unit "Family" (three decks: Family words, More relatives, Family sentences).

## What the proposal changes

1. **The Continue bar becomes one Learn / Relearn button**, full width, in the same pinned bar. Learn is `add` icon plus "Learn", with a badge in its top-right corner counting the unit's open cards not taught yet (the deck page's badge: error colour). When every open card of the unit is taught it is Relearn (`replay` icon), no badge. It is off, with no badge, when the unit has no card to walk (a unit of readings only).
2. **Only open cards count and are taught.** A sentence waiting for its words, or a rules-table cell waiting for its word, is not counted and not walked by Learn (`AppState.untaughtCards` skips them, and `viewCard` writes nothing for them). So the "11" on a unit of 12 cards where one sentence waits.
3. **Tap opens the walkthrough over the unit's decks**, in the order the decks list them, each deck in its own order, one count across all of them ("3/5"), the deck's name beside the "New word" pill changing at each deck boundary. Learn: the open cards not taught, so it starts at the first untaught card (section 2: the first deck is taught and is skipped). Relearn: every card, from the first of the first deck.
4. **Today's drilled "Continue" goes.** Its two jobs, reviewing what is due and teaching the next lesson, are not on the unit page any more (see doubt 1).
5. Unchanged: header, tiles, lists, the decks list, the Review button for reviewers, the path.

Needs build support the deck page does not have: `WalkthroughRequest` takes one `deckId`, so a unit needs a request over several decks (or a list of ids) and the deck name per card.

## Doubts (not decided; the conservative option is drawn)

1. **Where do a unit's due reviews go?** Continue reviewed what was due in the unit; the owner removed it. Drawn: nothing replaces it; due reviews are reached from Today and from the deck rows' "N due" badges, which stay.
   - Nothing (drawn). Downside: no way to review just this unit from its page.
   - A small "N due" line under the tiles, no button. Downside: it tells the learner something is due and gives no way to act on it.
   - A second, tonal "Review" button beside Learn (the deck page's Practice slot). Downside: it brings back the bar the owner just removed.
2. **Where does the button sit?** Drawn: the pinned bottom bar, where Continue was and where the deck page's buttons are. Tweak "Where".
   - Bottom bar (drawn). Downside: it takes a 56 dp strip plus padding of a 1.4x screen, and the badge needs headroom above the button.
   - Under the tiles, scrolling with the page. Downside: it scrolls away, and on a long unit the learner must scroll back up.
3. **Tag chips on the unit page?** #694 says Learn starts "on the deck as the tag chips filter it"; the unit page has no chips. Drawn: no chips; Learn acts on the whole unit. Tweak "Tag chips" and section 4 draw the alternative.
   - No chips (drawn). Downside: a learner cannot walk only the sentences, or only one tag, from the unit (they can from each deck page).
   - Chips over the unit's words and sentences, tags merged across its decks, with the deck page's rules (Learn follows the chips; Relearn only when the whole unit is taught). Downside: a second filter UI to build, tags that mean different things in different decks merge, and Relearn then ignores the chips' view of "all taught".
4. **Does a unit row on the path need Learn?** Drawn: no, a row opens the unit page. Tweak "Row shortcut" draws a "Learn · 5 new" chip in the row (the "To review" pill's place).
   - No chip (drawn). Downside: two taps (row, then Learn) to start.
   - A chip on rows with cards to teach. Downside: it competes with the "To review" pill, makes rows taller at 1.4x, and its tap target must not swallow the row's.
5. **Does Relearn walk a sentence that is still waiting?** On main the deck page's Relearn walks every card of the deck, including a sentence not yet open, and writes nothing for it (it cannot be taught yet). A unit whose only untaught card is a waiting sentence is Relearn already (section 1, "All taught, a sentence waiting").
   - Walk it too (the deck page's behaviour; the 12/12 count includes it). Downside: it shows a sentence whose words may be unknown, and it is not marked taught afterwards.
   - Skip waiting sentences in Relearn. Downside: the count differs from the cards on the page, and it differs from the deck page.
6. **A unit of readings only.** Drawn as the deck page draws a reading deck: Learn is off, no badge, since a passage's questions are not walked (the lesson teaches them). Options: keep it off (drawn; downside: an off button with no reason), or hide the button (downside: the bar's space is empty and the page looks unfinished).
7. **Order of the walk across decks.** Drawn: deck by deck, in the decks list's order. Option: the page's own order across decks (all words, then rules, then sentences). Downside of the option: the walk jumps between decks, and the deck name changes more often.
8. **Learn walks only untaught cards, or all cards from the first untaught?** Drawn as the deck page does since #943: only the open cards not taught. Option: every card, starting at the first untaught. Downside: the badge would not match what the walk shows, and taught cards would be repeated.
9. **Where the walk returns.** Drawn: back to the unit page, whose button has changed to Relearn if every open card is now taught. Option: a short "Unit taught" screen first. Downside: one more screen, and the deck page has none.
10. **Section asides and rules.** The words heading's "Known means ..." aside, the Rules section and the Review button are left out of the drawn unit for space; they do not change.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`) and run in Chromium for both themes. Text 4.5:1, icons and fills 3:1. All 54 pairs pass.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text, word, count | onS on s | 16.33 : 1 | 4.5 : 1 | pass |
| light | reading, meaning gloss, small notes | onSv on s | 8.9 : 1 | 4.5 : 1 | pass |
| light | small text on a row (surfaceContainerLow) | onSv on sLow | 8.45 : 1 | 4.5 : 1 | pass |
| light | target text on a row | onS on sLow | 15.5 : 1 | 4.5 : 1 | pass |
| light | Learn / Relearn / Continue label | onP on p | 6.46 : 1 | 4.5 : 1 | pass |
| light | Practice label (tonal) | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| light | badge count | onE on E | 6.46 : 1 | 4.5 : 1 | pass |
| light | Learning chip, New word pill, chosen tag chip | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| light | Known chip, level pill | onPc on pc | 13.31 : 1 | 4.5 : 1 | pass |
| light | Not open yet chip, Done badge | onSv on sHst | 7.24 : 1 | 4.5 : 1 | pass |
| light | Not done badge | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| light | due badge | onP on p | 6.46 : 1 | 4.5 : 1 | pass |
| light | New chip text | onSv on s | 8.9 : 1 | 4.5 : 1 | pass |
| light | Show all text button | p on s | 6.16 : 1 | 4.5 : 1 | pass |
| light | to-review pill | onTc on tc | 7.24 : 1 | 4.5 : 1 | pass |
| light | up-next row label | onP on p | 6.46 : 1 | 4.5 : 1 | pass |
| light | done row label | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| light | ahead row label | onS on sHigh | 14.01 : 1 | 4.5 : 1 | pass |
| light | ahead row meta | onSv on sHigh | 7.64 : 1 | 4.5 : 1 | pass |
| light | teach card meaning on the card | onS on sHigh | 14.01 : 1 | 4.5 : 1 | pass |
| light | teach card reading on the card | onSv on sHigh | 7.64 : 1 | 4.5 : 1 | pass |
| light | chevron on its disc | onSc on sc | 7.25 : 1 | 3 : 1 | pass |
| light | wave fill on page | p on s | 6.16 : 1 | 3 : 1 | pass |
| light | New chip outline on row | ol on sLow | 4.06 : 1 | 3 : 1 | pass |
| light | change outline on page | E on s | 6.16 : 1 | 3 : 1 | pass |
| light | change tag text | onE on E | 6.46 : 1 | 4.5 : 1 | pass |
| light | tap ring on page | onS on s | 16.33 : 1 | 3 : 1 | pass |
| dark | body text, word, count | onS on s | 14.33 : 1 | 4.5 : 1 | pass |
| dark | reading, meaning gloss, small notes | onSv on s | 10.88 : 1 | 4.5 : 1 | pass |
| dark | small text on a row (surfaceContainerLow) | onSv on sLow | 10.08 : 1 | 4.5 : 1 | pass |
| dark | target text on a row | onS on sLow | 13.28 : 1 | 4.5 : 1 | pass |
| dark | Learn / Relearn / Continue label | onP on p | 7.68 : 1 | 4.5 : 1 | pass |
| dark | Practice label (tonal) | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| dark | badge count | onE on E | 7.72 : 1 | 4.5 : 1 | pass |
| dark | Learning chip, New word pill, chosen tag chip | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| dark | Known chip, level pill | onPc on pc | 7.21 : 1 | 4.5 : 1 | pass |
| dark | Not open yet chip, Done badge | onSv on sHst | 7.25 : 1 | 4.5 : 1 | pass |
| dark | Not done badge | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| dark | due badge | onP on p | 7.68 : 1 | 4.5 : 1 | pass |
| dark | New chip text | onSv on s | 10.88 : 1 | 4.5 : 1 | pass |
| dark | Show all text button | p on s | 10.86 : 1 | 4.5 : 1 | pass |
| dark | to-review pill | onTc on tc | 7.24 : 1 | 4.5 : 1 | pass |
| dark | up-next row label | onP on p | 7.68 : 1 | 4.5 : 1 | pass |
| dark | done row label | onSc on sc | 7.25 : 1 | 4.5 : 1 | pass |
| dark | ahead row label | onS on sHigh | 11.17 : 1 | 4.5 : 1 | pass |
| dark | ahead row meta | onSv on sHigh | 8.48 : 1 | 4.5 : 1 | pass |
| dark | teach card meaning on the card | onS on sHigh | 11.17 : 1 | 4.5 : 1 | pass |
| dark | teach card reading on the card | onSv on sHigh | 8.48 : 1 | 4.5 : 1 | pass |
| dark | chevron on its disc | onSc on sc | 7.25 : 1 | 3 : 1 | pass |
| dark | wave fill on page | p on s | 10.86 : 1 | 3 : 1 | pass |
| dark | New chip outline on row | ol on sLow | 5.4 : 1 | 3 : 1 | pass |
| dark | change outline on page | E on s | 10.89 : 1 | 3 : 1 | pass |
| dark | change tag text | onE on E | 7.72 : 1 | 4.5 : 1 | pass |
| dark | tap ring on page | onS on s | 14.33 : 1 | 3 : 1 | pass |
Notes: the container tokens (`pc`, `onPc`, `tc`, `onTc`, `sHst`) are approximated from the seed, as in the other mockups; check them against the app's `ColorScheme` when building. The surfaceContainerHighest of the chips on Not open yet and Done is approximate. Disabled controls are drawn at 70% opacity and are exempt; the off Learn says why in the caption, not on screen (doubt 6). The badge uses the error colour, as the deck page does; its count is also the button's accessible label ("5 new cards").

## Behaviour checks (Chromium, Playwright)

- Loaded in Chromium at 1280 px wide: no page errors, no console errors, no horizontal page scroll.
- 108 combinations set (theme 2 x course 2 x State 5 x Where 2 x Tag chips 2, plus both walk flows, both row shortcuts, three deck states per theme and course): no errors, and no horizontal overflow inside any phone.
- Badge and button per state: Nothing taught "Learn" badge 11; Some taught badge 5; All taught "Relearn"; All taught with a sentence waiting "Relearn"; Reading-only "Learn", off. Today's phone shows its Continue label beside each.
- Walk frames: Learn 1/5, 3/5 (deck changes), 5/5; Relearn 1/12, 6/12, 9/12, 12/12. After Learn the unit page shows Relearn.
- Deck page chips (Some taught, "More relatives"): none badge 2 (3 of 3 words); "extended" badge 2 (2 of 3); "grandparent" Learn off (1 of 3, that word is taught); All taught shows Relearn.
- Screenshots of each theme and course were taken of the full page.
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts; where offline the system fallback is used.
