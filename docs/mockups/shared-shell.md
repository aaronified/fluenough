# One shared shell: self-check, notes and doubts

Companion to `shared-shell.html` (phase 0 of [Plan-Question-Engine-2-And-Exams](https://github.com/aaronified/fluenough/wiki/Plan-Question-Engine-2-And-Exams); owner, 2026-10-31, on #509: "One shared shell for teach and question screens. Ok, do this then"). The page holds only the screens and their tweak controls, with what is new or changed outlined in red. Nothing below is decided except what the owner has said; every open choice is a doubt here, and where a control can show it, a tweak control on the page.

Phone 360 by 860 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed (#3F6C51), light and dark, Hindustani and Bengali examples (readings follow the course: no final a in Bengali). Mocked from today's screens (`lib/ui/widgets/drill_frame.dart`, `teach_drill.dart`, `teach_card.dart`, `set_drill.dart`, the choice, typed, rearrange, hear and speaking drills, `AnswerFeedback`), no owner screenshots.

## What the shell is

Today's `DrillFrame` (scrolling body over a fixed foot) with the teach card and sets moved into it, in six slots: 1 header (unchanged), 2 context row (skill pill and deck name; "New word" on a teach card), 3 card (one `DrillCard`), 4 answer area (choices, tiles, field, microphone; empty for teach and set), 5 feedback area (the banner; empty on teach, set and in an exam), 6 action area (one place, 56 dp buttons: grades while something is left to grade, goes on when nothing is, except on a teach card, where it is empty; Back and Next in an exam).

Owner decisions drawn (2026-10-31, #509): no per-item feedback in an exam until the result; free navigation with a review-answers step; mock the shell first.

## Doubts (not decided; the plan's proposal is drawn)

1. **How does the learner go on?** Teach is decided; questions and sets are open.
   - Teach (answered, owner, 2026-10-31: "Continue is not needed when swipe and the chevron click is there. Right? It also frees up the screenspace"): no Continue button on a teach card (new word, Relearn, rule card). Going on is the swipe and the chevrons only, as the owner decided on #691 on 2026-10-22; the action area is empty and the foot's space goes to the card. The Going on control does not change teach.
   - Questions and sets (open; the plan says "one gesture or one button"). Drawn: one Continue button in the action area on a set and on an answered question, and the swipe with the end-edge chevron on those too. Tweak control "Going on, questions and sets".
   - Button and swipe (drawn): matches both habits. Downside: two ways to learn, and a question's chevron is new against today.
   - Button only: one thing to learn. Downside: loses the swipe that teach has, so questions and teach differ.
   - Swipe only (as teach): one way on everywhere. Downside: a question's Continue disappears, harder for screen-reader and switch users, and nothing says it is time to go on.
2. **Are "grading area" and "going on" one area or two?** Answered (owner, 2026-10-31): one action area that changes content, as drawn. Drawn: one action area that changes content (Check, Show answer, ratings, Count right or wrong, then Continue), so the thumb target never moves.
   - One area (drawn). Downside: the grading buttons and Continue cannot show together.
   - Two stacked areas (grade above, Continue below, always present). Downside: a taller foot, which at 1.4x leaves a short body.
3. **Where do "Don't know" and "Can't listen or speak now" live?** Drawn as today: Don't know beside Check, Can't now as a link above. 
   - Keep in the action area (drawn). Downside: more buttons in the one place.
   - Move to an overflow menu in the header. Downside: hides a way out that the learner may need under time pressure.
4. **Does a teach card keep its neutral "New word" pill?** Drawn: yes, as today.
   - Neutral (drawn). Downside: the teach card does not show which skill it leads into.
   - The skill's colour. Downside: the pill then means two things (new, and skill).
5. **Exam header progress.** Drawn: the wave and the count show the position (4/35), as practice does. #509 lists the progress indicator as still to ask.
   - Position (drawn). Downside: with free navigation it says nothing about how much is answered.
   - Answered count. Downside: the number moves without the learner moving.
   - Both (wave answered, count position). Downside: two numbers in a 64 dp header.
6. **Exam: when is a tile or typed answer committed?** Drawn: there is no Check; the answer is whatever is on the answer line when the learner leaves the item, and the item shows as answered once it is full.
   - Kept as placed (drawn). Downside: a half-built answer is unclear (drawn: counts as unanswered, then wrong).
   - A Check button that commits. Downside: it is feedback-shaped, and learners may expect a verdict.
7. **Exam: how is a chosen answer drawn?** Drawn: a filled radio and a primary outline, not the green of Correct, so it cannot read as a verdict.
   - Outline and radio (drawn). Downside: less visible than a filled tile.
   - Filled tonal tile. Downside: close to the right-answer colour in some seeds.
8. **Exam: Say.** Drawn: a recorded tick and "Tap to record again", no heard text, no verdict.
   - Re-record allowed (drawn). Downside: unlimited tries before submitting.
   - One take. Downside: a mic glitch costs the item.
9. **Exam: how the review step is reached.** Drawn: the last Next becomes Review answers; the step lists items by skill with Answered or Not answered, and Submit exam. Items can be tapped.
   - Last Next only (drawn). Downside: a learner who wants an overview mid-exam must walk to the end.
   - Also a tap on the header count. Downside: a hidden control.
   - Flags to come back to an item. Downside: more to build; no flag has been decided.
10. **Exam: what an unanswered item counts as.** Answered (owner, 2026-10-31): Submit is blocked until every item is answered. The review step lists the unanswered items, disables Submit until all are answered, and a tap on an item jumps to it. This replaces the earlier drawn default (unanswered counts as wrong).
    - Block Submit until all are answered (answered, drawn). Downside: forces a guess; where a device lacks a microphone, speaking and listening items must never gate (the plan), so they need a way to be skipped or replaced.
    - Wrong (the earlier default, not chosen). Downside: harsh.
11. **Exam: leaving.** Answered (owner, 2026-10-31): Close mid-exam saves the position and the answers, and the learner can resume the same day. Drawn: the leave confirmation ("Save and leave", "Keep going") and the resume entry ("Paused at item 4 of 35", Resume exam). Not decided: what happens after the day ends, and whether a learner can start over.
12. **Typed answers (romanised) in the shell.** Drawn with the keyboard open: the card and foot go compact as today. The plan retires script typing, so only the romanised field is shown.
13. **Height at 1.4x.** An answered choice with its feedback and Continue leaves the body short, so the options scroll behind the foot (as today). Options: leave; hide the taught details under the prompt until the learner opens them (downside: the lesson-after-the-answer is the review's teaching moment).
14. **Does "cannot change any answer" also apply to the exam?** Answered (owner, 2026-10-31): exam answers are editable until submit; practice stays read-only on going back. Earlier owner remark, 2026-10-31: in practice, going back (swipe or the back chevron, on teach and on questions) is allowed, but an answer already given can never be changed. Drawn: practice is read-only on return (answered state, no input, no re-grading, a neutral "Already answered" banner with a lock, not the error colour), and the exam stays as the owner decided earlier (free navigation and a review step, so answers can be changed until Submit).
    - Exam editable until submit (answered, drawn): matches the earlier decision and the review step's tap to go back to an item. Downside: the two modes differ on return, so the learner must be told which one they are in.
    - Exam read-only too: one rule everywhere. Downside: the review step can only look, not fix, so a forgotten item cannot be answered later.

## Going back: practice and exam

Practice: swipe back or the back chevron is available on teach (new word, Relearn, rule card) and on a question once it is answered. A teach card shows as it was. A question gone back to is read-only: answered state kept, controls locked, no re-grading, and a neutral "Already answered" banner (lock icon, surface colour, not the green or red of a verdict). Exam: free navigation with the review step; answers can be changed until Submit (doubt 14, answered: it stays editable).

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All 68 pairs pass (the Already answered banner uses onS on sHigh, already in the list as "text on the card", and so does its lock icon).

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text on page | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | captions on page | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | text on the card | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | captions on the card | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | text on an inner box or choice | onS on sLow | 15.5 :1 | 4.5 :1 | pass |
| light | captions on an inner box | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | filled button | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | outlined button and link text | p on s | 6.16 :1 | 4.5 :1 | pass |
| light | New word pill, speaker, tonal | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | Correct banner and right choice | onPc on pc | 13.31 :1 | 4.5 :1 | pass |
| light | Not quite banner and wrong choice | onEc on ec | 13.26 :1 | 4.5 :1 | pass |
| light | Almost banner | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | Right but mind banner | onTc on tc | 7.24 :1 | 4.5 :1 | pass |
| light | wave fill on page | p on s | 6.16 :1 | 3 :1 | pass |
| light | choice and tile outline on page | ol on s | 4.28 :1 | 3 :1 | pass |
| light | field outline on page | ol on s | 4.28 :1 | 3 :1 | pass |
| light | selected exam choice outline on its tile | p on sLow | 5.85 :1 | 3 :1 | pass |
| light | meaning icon and link on the card | p on sHigh | 5.29 :1 | 3 :1 | pass |
| light | answer word on the card | p on sHigh | 5.29 :1 | 4.5 :1 | pass |
| light | review row warning icon on its row | E on sLow | 5.85 :1 | 3 :1 | pass |
| light | review row text on its row | onS on sLow | 15.5 :1 | 4.5 :1 | pass |
| light | review row status on its row | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | swipe chevron | onSc on sc | 7.25 :1 | 3 :1 | pass |
| light | change tag | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change outline on the card | E on sHigh | 5.28 :1 | 3 :1 | pass |
| light | badge number | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | selected tile in the answer line | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | microphone button | onP on p | 6.46 :1 | 3 :1 | pass |
| light | skill pill Recognition | #284777 on #d6e3ff | 7.22 :1 | 4.5 :1 | pass |
| light | skill pill Write | #6e3900 on #ffdcc2 | 7.24 :1 | 4.5 :1 | pass |
| light | skill pill Hear | #4f378b on #eaddff | 7.23 :1 | 4.5 :1 | pass |
| light | skill pill Say | #255023 on #bdf0b3 | 7.23 :1 | 4.5 :1 | pass |
| light | skill pill Grammar | #00504a on #b8f0e4 | 7.4 :1 | 4.5 :1 | pass |
| dark | body text on page | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | captions on page | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | text on the card | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | captions on the card | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | text on an inner box or choice | onS on sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | captions on an inner box | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | filled button | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | outlined button and link text | p on s | 10.86 :1 | 4.5 :1 | pass |
| dark | New word pill, speaker, tonal | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | Correct banner and right choice | onPc on pc | 7.21 :1 | 4.5 :1 | pass |
| dark | Not quite banner and wrong choice | onEc on ec | 7.24 :1 | 4.5 :1 | pass |
| dark | Almost banner | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | Right but mind banner | onTc on tc | 7.24 :1 | 4.5 :1 | pass |
| dark | wave fill on page | p on s | 10.86 :1 | 3 :1 | pass |
| dark | choice and tile outline on page | ol on s | 5.84 :1 | 3 :1 | pass |
| dark | field outline on page | ol on s | 5.84 :1 | 3 :1 | pass |
| dark | selected exam choice outline on its tile | p on sLow | 10.05 :1 | 3 :1 | pass |
| dark | meaning icon and link on the card | p on sHigh | 8.46 :1 | 3 :1 | pass |
| dark | answer word on the card | p on sHigh | 8.46 :1 | 4.5 :1 | pass |
| dark | review row warning icon on its row | E on sLow | 10.09 :1 | 3 :1 | pass |
| dark | review row text on its row | onS on sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | review row status on its row | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | swipe chevron | onSc on sc | 7.25 :1 | 3 :1 | pass |
| dark | change tag | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change outline on the card | E on sHigh | 8.49 :1 | 3 :1 | pass |
| dark | badge number | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | selected tile in the answer line | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | microphone button | onP on p | 7.68 :1 | 3 :1 | pass |
| dark | skill pill Recognition | #d6e3ff on #284777 | 7.22 :1 | 4.5 :1 | pass |
| dark | skill pill Write | #ffdcc2 on #6e3900 | 7.24 :1 | 4.5 :1 | pass |
| dark | skill pill Hear | #eaddff on #4f378b | 7.23 :1 | 4.5 :1 | pass |
| dark | skill pill Say | #bdf0b3 on #255023 | 7.23 :1 | 4.5 :1 | pass |
| dark | skill pill Grammar | #b8f0e4 on #00504a | 7.4 :1 | 4.5 :1 | pass |

Other checks: tap targets are 48 dp (header icons, Back, Next) and 56 dp (action buttons, choices); the swipe chevron is 40 dp: on a teach card it is, with the swipe, the only way on (owner, doubt 1), on questions and sets a convenience beside the button (and the only way on in "Swipe only"). Text sizes are all 1.4x. The disabled Check button is below 4.5:1 by design (a disabled control is exempt).

## Behaviour checks (Chromium, Playwright 1.56)

- Loaded at 1280 px and 390 px wide: no page errors, no console errors, no horizontal page scroll.
- Every tweak control pressed in both courses and both themes, with Going on in all three settings (teach unchanged by it: no foot in any), Content short and long, every practice screen type and every exam item type: no element wider than its phone, no clipped text, no errors.
- Screenshots of the page in light and dark were looked at.
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts; where offline the system fallback is used.

## Not in this mockup

The Latin and Cyrillic letter-tile keyboard, exam start, the result, the locked state on the path and the retake wait: later mockups of the plan, built on this shell. The review step here is drawn only far enough to show the shell.
