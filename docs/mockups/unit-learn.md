# Unit page, Learn and Relearn: self-check, notes and doubts

Companion to `unit-learn.html` (#694; owner, 2026-10-31: "Why would units need 'continue'? Learn / relearn is the only thing they need. I didn't get this"). The page holds only the screens and their tweak controls, with what changed outlined in red. The checks, notes and doubts are here. Where nothing is decided the most conservative option is drawn; each alternative is a tweak control and a numbered doubt below.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed (#3F6C51), light and dark, Hindustani and Bengali examples (Bengali readings follow the course: no final a). Theme, course and highlight are global controls.

## What is decided (drawn as decided)

- The unit page gets Learn / Relearn only, not the Continue bar (owner, 2026-10-31).
- Learn is the card-by-card walkthrough, on main since PR #943: each first view appends one lowest-window review-log row (graded 0, `Ask.teach`), nothing is asked. Swipe and chevrons go on and back; no Continue button. The walk ends when the learner goes on from the last card or closes it.
- Stats skip view rows; a repeat view writes nothing; Today's lesson is unchanged (owner, 2026-10-31, #694).
- Due reviews are subtext on the control (doubt 1). No tag chips on the unit page (doubt 3). The walk covers the whole unit whatever is taught (doubt 8). A waiting sentence is walked and logged (doubt 5).

## What the screen is today

`lib/features/decks/unit_page.dart`: app bar (course heading, report), header (level pill, "Unit 4", name, description), tiles (words known, rules known, sentences open, each where the unit has some), Words (first 6, "Show all"), Rules, Sentences (a sentence not open is greyed, locked, "Waiting for ..."), "Decks in this unit", and the pinned `_ContinueBar`: "Continue · N new, M due" (reviews what is due, else teaches the next words in a lesson), or "Nothing new or due", off. The unit page has no tag chips. The left phone of section 1 is that, with the example unit "Family" (three decks: Family words, More relatives, Family sentences).

## What the proposal changes

1. **The Continue bar becomes one Learn / Relearn control**, full width, in the same pinned bar: `add` icon and "Learn", with the counts under the label as subtext, "6 new · 4 due". "New" is the cards of the unit not taught yet, anywhere in it; "due" is the reviews due in the unit, as Continue's label counted. When every card of the unit is taught it is Relearn (`replay` icon), "0 new · 3 due". It is off for a unit with no card to walk (readings only). No badge, no separate Review button, no separate due line.
2. **Tap opens the walkthrough over the whole unit**: every deck, every card, in the order the decks list them and each deck's own order, one count across all ("6/12"), the deck's name beside the "New word" pill changing at each deck boundary. Learn and Relearn are the same walk, from the first card. Taught status is information only (the subtext), not a filter.
3. **A waiting sentence is walked and logged** like any teach card: a sentence not yet open (greyed on the page) is shown in the walk and its first view logs the usual lowest-window row, recognition mode.
4. **Today's "Continue" goes.** Its reviewing and lesson jobs are not on the unit page any more; the due count survives as subtext.
5. Unchanged: header, tiles, lists, the decks list, the Review button for reviewers, the path.

### Build notes (not drawn)

- `WalkthroughRequest` takes one `deckId`; a unit needs a request over several decks (or a list of ids) and the deck name per card.
- **The deck page must change to the same rule.** As merged in PR #943 its Learn walks only the untaught cards (`untaughtOnly`, `AppState.untaughtCards`, with a badge) and its Relearn shows only when every card is taught. Under the owner's rule (doubt 8) both walk every card in view, taught or not, so `untaughtOnly` goes, the walk is the whole deck (filtered by the tag chips when on), and the badge question is the deck page's own (section 4 draws it as built).
- `AppState.viewCard` returns null for a card that is taught or `!unlocks.isOpen(card)` (a waiting sentence, a rules-table cell waiting for its word). Doubt 5 means it must log for a waiting sentence too; the guard changes.

## Doubts

Answered ones are quoted; the rest are not decided and the conservative option is drawn.

1. **Where do a unit's due reviews go?** **Answered** (owner, 2026-10-31): due reviews are shown as subtext on the Learn / Relearn control ("Learn" with "N new · M due" under it); no separate Review button, no separate due line. Drawn so. Remaining detail: the subtext counts the unit's due reviews, but the control does not review them; Learn / Relearn walks. The due reviews are done from Today, and from the deck rows' "N due" badges.
2. **Where does the button sit?** Drawn: the pinned bottom bar, where Continue was and where the deck page's buttons are. Tweak "Where".
   - Bottom bar (drawn). Downside: it takes a 56 dp strip plus padding of a 1.4x screen, now a little taller with the subtext line.
   - Under the tiles, scrolling with the page. Downside: it scrolls away, and on a long unit the learner must scroll back up.
3. **Tag chips on the unit page?** **Answered** (owner, 2026-10-31): no tag chips on the unit page, as drawn; the alternative is removed from the page.
4. **Does a unit row on the path need Learn?** Drawn: no, a row opens the unit page. Tweak "Row shortcut" draws a "Learn · 6 new" chip in the row (the "To review" pill's place).
   - No chip (drawn). Downside: two taps (row, then Learn) to start.
   - A chip on rows with cards to teach. Downside: it competes with the "To review" pill, makes rows taller at 1.4x, and its tap target must not swallow the row's.
5. **Is a waiting sentence walked?** **Answered** (owner, 2026-10-31): a sentence still waiting (not yet open) is walked and logs the usual lowest-window row in recognition mode like any teach card. Drawn so: the 12th card of the walk is the waiting sentence, and "12 new" counts it. Note: the page still greys it and locks it in the Sentences list until its words are known; only the walk ignores that. Whether being taught by a walk also opens the sentence is not asked (`Unlocks.isOffered` says "taught or every word and rule known", so it would open: say if not wanted).
6. **A unit of readings only.** Drawn as the deck page draws a reading deck: the control is off, "0 new · 0 due", since a passage's questions are not walked. Options: keep it off (drawn; downside: an off button with no reason), or hide the control (downside: the bar's space is empty and the page looks unfinished).
7. **What distinguishes Learn from Relearn?** (New.) With Learn walking everything, the walk is the same. Drawn default: same walk, label only, driven by whether every card is taught; the log rule is one rule for both, a first view of a card not taught writes a lowest-window row, a taught card writes nothing, so in practice Learn writes and Relearn does not, without either mode checking the label.
   - Label only (drawn). Downside: the label is the only difference, so a learner with one new card out of 40 walks all 40 under "Learn" with nothing to tell them where the new one is, and the control says "Learn" for what feels like Relearn.
   - Mode with a different write rule: Learn logs first views, Relearn is explicitly read-only (never writes, even for a card that turned out untaught). Downside: two code paths for one walk, and a card not taught that a Relearn walks stays untaught, which contradicts "viewed means taught".
   - Learn opens at the first untaught card as a position (the walk still covers every card, the earlier ones one swipe back), Relearn at the first card. Downside: the count shows "7/12" on arrival and the learner can think the first six were skipped; it also differs from the "starts at the first card" rule just given.
8. **Which cards does the walk cover?** **Answered** (owner, 2026-10-31): the walk covers the whole unit, every deck, every card, in deck order, regardless of what is already taught; taught status is information only (badges, subtext), not a filter. Drawn so, from the first card. Open follow-up inside it: whether Learn should open at the first untaught card as a position (the third option of doubt 7); not drawn. The deck page must change to the same rule (build notes).
9. **Order of the walk across decks.** Drawn: deck by deck, in the decks list's order. Option: the page's own order across decks (all words, then rules, then sentences). Downside of the option: the walk jumps between decks, and the deck name changes more often.
10. **Where the walk returns.** Drawn: back to the unit page, whose control has changed to Relearn if every card is now taught. Option: a short "Unit taught" screen first. Downside: one more screen, and the deck page has none.
11. **Section asides and rules.** The words heading's "Known means ..." aside, the Rules section and the Review button are left out of the drawn unit for space; they do not change.

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
| light | Learn subtext (12 px) on the button | onP on p | 6.46 : 1 | 4.5 : 1 | pass |
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
| dark | Learn subtext (12 px) on the button | onP on p | 7.68 : 1 | 4.5 : 1 | pass |
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

Notes: the container tokens (`pc`, `onPc`, `tc`, `onTc`, `sHst`) are approximated from the seed, as in the other mockups; check them against the app's `ColorScheme` when building. Disabled controls are drawn at 70% opacity and are exempt. The 12 px subtext sits on the primary button in `onP` at 400 weight, scaled to 1.4x; it passes 4.5:1. The deck page keeps the error-colour badge as built (section 4). Counts in today's Continue label are illustrative (the first deck's lesson, up to nine words).

## Behaviour checks (Chromium, Playwright)

- Loaded in Chromium at 1280 px wide: no page errors, no console errors, no horizontal page scroll.
- 60 combinations set (theme 2 x course 2 x State 4 x Where 2, plus both walk flows, both row shortcuts and three deck states, per theme and course): no errors, and no horizontal overflow inside any phone.
- Control per state (Today's label beside): Nothing taught "Learn, 12 new · 0 due"; Some taught "Learn, 6 new · 4 due"; All taught "Relearn, 0 new · 3 due"; Reading-only "Learn", off.
- Walk frames: both flows 1/12, 6/12 (deck changes), 9/12 (deck changes), 12/12 (the waiting sentence). After Learn the unit page shows Relearn.
- Deck page chips (Some taught, "More relatives", as built): none badge 2 (3 of 3 words); "extended" badge 2 (2 of 3); "grandparent" Learn off (1 of 3, that word is taught); All taught shows Relearn.
- Screenshots of each theme and course were taken of the full page.
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts; where offline the system fallback is used.
