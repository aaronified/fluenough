# Minimal pair: self-check, notes and open questions

Companion to `minimal-pair.html` (#423, part of #209; owner, 2026-10-31, "Mockup first": "the minimal pairs can be a button where found and clicking it will show the words side by side and let the user play their sounds and practice them together (like whether the speech is detecting kalam or kaalam) in that same card. No logging here, pure practice."). The page holds only the screens and their tweak controls, with what is new outlined in red dashes. Nothing below is decided; every open choice is a tweak control on the page. Data: the `pair` note (typed notes, PR #934, ADR-0036; the b1-plans page of the wiki, "The minimal-pair button").

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark. Theme, course, pair, direction, highlight and hints are global controls. Examples: Telugu కలం (kalaṁ) / కాలం (kālaṁ), Bengali কাল (kāl) / কল (kol), Hindustani कल (kal) / काल (kāl), and the same in Urdu script کل / کال; a long-script pair for each (ప్రాంతం / ప్రాణం, অধিকার / অন্ধকার, विज्ञान / विज्ञापन, عالم / علم). Words, IPA and the note texts are drawn by hand for the mockup, not taken from a deck; a native reviewer must check any pair a deck names.

## The screens

1. **Where the button sits.** The teach card and a card after an answer, button closed; and the Hear question before an answer, with no button (the partner is one of its options, so the button would give the answer away).
2. **The panel, live.** Tap Play, Slow, the microphone, Play one and the answers; set what the phone "hears" (first, second, neither, nothing) and the phone's condition. Card: teach or after an answer.
3. **States.** Idle; playing (normal, slow); listening; heard matched the first, the second, neither, nothing; Which did you hear: playing, before tapping, after tapping (right, wrong).
4. **No voice, no microphone.** Sound off; no voice for the language; Speaking off; no recogniser; microphone denied; needs the online recogniser (the speaking drill's own sentences).
5. **Every script, the longest pair, at 1.4x.** Telugu, Bengali, Devanagari, Urdu script (RTL script, LTR app), and the app mirrored (RTL), side by side and stacked.

## How it behaves

- **Shown** only on a card with a `pair` note, when the word is taught (teach card) and after an answer (with the taught details). Never before. A card with no `pair` note has no button.
- **The button** sits in the card's "Sounds alike" block (the care note the pair note already makes), so the note says what the pair is and the button opens it. It opens the panel on the same card, under the block; the button stays as the toggle (chevron up, tonal fill) and the panel has its own Close for when the button has scrolled away.
- **The panel**: the two words side by side, each with script, reading and meaning, Play and Slow under each; Say one; Which did you hear.
- **Say one** (only where speaking is on): the phone listens (the microphone turns tertiary and a stop, as the speaking drill's hearing state) and shows what it heard, "Heard: కాలం (kālaṁ), time", and which of the two it matched (the tile is ringed and tagged "Matched"), or "Matched neither of the two", or "Didn't catch that. Say it again." Never "right" or "wrong", never a red or green: a recogniser prefers common words and may miss vowel length. The caveat line is under every result.
- **Which did you hear?** Play one plays one of the two at random; the learner taps one. Only here does the panel say right or wrong, with an icon and words, since the app chose the word. Play it again repeats the same word; Play another picks again (it may repeat).
- **Records nothing.** No review, schedule or strength, no counter, no streak. The panel says so in its subtitle: "Practice only. Nothing here is recorded."
- **Hints** on icon-only controls are one word: Play, Slow, Speak, Stop, Close, Replay.
- **RTL.** Urdu script is drawn right to left at the app's RTL line height (1.9, `TargetSizes.rtlHeight`) with its own font. Mirrored, the panel's header, tiles, answers and icons swap sides; media icons (play) do not mirror.

## Open questions

1. **Button position.** In the note block (drawn) ties the button to what it is about; under the card, above Continue, is easier to find in a long card but is far from its note. Which?
2. **Button label.** "Compare with కాలం (kālaṁ)" names the partner (shown only after an answer, so it gives nothing away) but wraps to two lines at 1.4x; "Compare sounds" is short and never wraps. Which?
3. **Side by side at 1.4x.** Each column is about 150 dp; long meanings ("right, authority") wrap to two or three lines and long Telugu or Bengali conjuncts fit (checked). Stacked is a tweak. Should the panel fall back to stacked on its own when a word overflows its column, or always stay side by side as asked?
4. **No voice: grey out or leave out?** The plan says greyed, as elsewhere; the speaking drill leaves a speaker out where the phone has no voice (the `Speaker` doc). The page greys Play, Slow and Which did you hear and says why in a line. Leave them out instead?
5. **Speaking off, or "Not now" to online.** Say one is left out (drawn), not greyed. Should it be greyed with "Speaking is off in Settings" so the learner learns where it went?
6. **Matching.** The app compares what was heard with the two words after the drill's normal clean-up. Telugu, Bengali and Urdu are often not on the phone's recogniser (the online ask is drawn). A recogniser that always writes the commoner partner will never match the other: is "Matched" enough, or should the panel also show how sure the phone was?
7. **Quiz length.** One word at a time with "Play another", no count. Should it be a short run (for example 5 plays) with a tally? The owner may count a tally as logging; drawn: none.
8. **Swipe on the teach card.** The teach card goes on with a swipe or the end chevron. A swipe inside the open panel could leave the card by accident: should the panel stop the swipe, or does a swipe close it first?
9. **Which drills.** Both cards of a pair show the button (each names the other). Where the partner is among the answer options (Hear, Meaning) the button appears only after the answer (drawn). Is that enough for Typing and Speaking, where the partner is not an option?
10. **Mirrored English.** In the mirrored app, English sentences that carry a script word ("Not quite. It was ... You tapped ...") reorder their punctuation. The page draws it as a browser does; Flutter's `Directionality` will do the same. Accept, or restructure those sentences so a script word never ends one?

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, rings and outlines 3:1. All 27 pairs pass in both themes.

| Pair | Colours | Light | Dark | Needs |
|---|---|---|---|---|
| body text, word, meaning on card | onS on sLow | 15.5 | 13.28 | 4.5 |
| reading, pos, help line on card | onSv on sLow | 8.45 | 10.08 | 4.5 |
| panel title, tile word and meaning on tile | onS on s | 16.33 | 14.33 | 4.5 |
| panel subtitle, help line on panel | onSv on sHigh | 7.64 | 8.48 | 4.5 |
| tile reading on tile | onSv on s | 8.9 | 10.88 | 4.5 |
| button label, outlined (on panel) | p on sHigh | 5.29 | 8.46 | 4.5 |
| button label, text (on bottom bar) | p on sLow | 5.85 | 10.05 | 4.5 |
| Compare button label, closed (on note block) | p on sHigh | 5.29 | 8.46 | 4.5 |
| Compare button, open | onSc on sc | 7.25 | 7.25 | 4.5 |
| Play and Slow icon on its circle | onSc on sc | 7.25 | 7.25 | 4.5 |
| playing circle | onP on p | 6.46 | 7.68 | 4.5 |
| microphone icon | onP on p | 6.46 | 7.68 | 4.5 |
| listening microphone | onTt on tt | 6.48 | 7.73 | 4.5 |
| Matched chip text | onSc on sc | 7.25 | 7.25 | 4.5 |
| Matched tag text | onP on p | 6.46 | 7.68 | 4.5 |
| "neither" chip text on heard box | onS on s | 16.33 | 14.33 | 4.5 |
| tile ring, matched or playing | p on s | 6.16 | 10.86 | 3 |
| quiz right text | p on sHigh | 5.29 | 8.46 | 4.5 |
| quiz wrong text | E on sHigh | 5.28 | 8.49 | 4.5 |
| quiz right ring on answer | p on s | 6.16 | 10.86 | 3 |
| quiz wrong ring on answer | E on s | 6.16 | 10.89 | 3 |
| error line on panel | E on sHigh | 5.28 | 8.49 | 4.5 |
| answer outline | ol on s | 4.28 | 5.84 | 3 |
| listening ring | tt on sc | 5 | 5.52 | 3 |
| hint text | s on onS | 16.33 | 14.33 | 4.5 |
| change outline on page | E on s | 6.16 | 10.89 | 3 |
| change tag text | onE on E | 6.46 | 7.72 | 4.5 |

Notes: `onTt` (on-tertiary) and the tertiary colour are approximated from the seed (light `#3b6470` and `#ffffff`, dark `#a4cddd` and `#063543`); check them against the app's `ColorScheme` when building. Disabled controls are drawn at 38% opacity and are exempt from the ratio; the reason is given in words under the header. A wrong quiz answer is carried by an icon and words as well as the red ring, so it is not colour alone.

## Behaviour checks (Chromium, Playwright)

- Loaded at 1280 px wide: no page errors, no console errors, no horizontal page scroll, and no horizontal overflow inside any phone, in both themes, for all four courses and both pairs (16 combinations).
- Live phone: the microphone listens, then shows what the phone "heard" as set; Play one then tapping an answer shows the verdict.
- Screenshots of both themes, Telugu and Urdu script, were taken of the full page.
- Fonts: Roboto, Noto Sans Telugu, Devanagari and Bengali, and Noto Nastaliq Urdu from Google Fonts; where offline the system fallback is used.
