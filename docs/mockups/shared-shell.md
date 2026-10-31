# One shared shell: self-check, notes and doubts

**Status: approved by the owner 2026-10-31 apart from the open doubts.** (Owner, 2026-10-31: "The shell is fine." Revised the same day: the sets lose their Continue button ("Swipe is going to be universal, across all deck viewing"), then the questions too ("Swipe-only everywhere"): no Continue button anywhere.)

Companion to `shared-shell.html` (phase 0 of [Plan-Question-Engine-2-And-Exams](https://github.com/aaronified/fluenough/wiki/Plan-Question-Engine-2-And-Exams); owner, 2026-10-31, on #509: "One shared shell for teach and question screens. Ok, do this then"). The page holds only the screens and their tweak controls, with what is new or changed outlined in red. Nothing below is decided except what the owner has said; every open choice is a doubt here, and where a control can show it, a tweak control on the page.

Phone 360 by 860 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed (#3F6C51), light and dark, Hindustani and Bengali examples (readings follow the course: no final a in Bengali). Mocked from today's screens (`lib/ui/widgets/drill_frame.dart`, `teach_drill.dart`, `teach_card.dart`, `set_drill.dart`, the choice, typed, rearrange, hear and speaking drills, `AnswerFeedback`), no owner screenshots.

## What the shell is

Today's `DrillFrame` (scrolling body over a fixed foot) with the teach card and sets moved into it, in six slots: 1 header (unchanged), 2 context row (skill pill and deck name; on a teach card the pill is "New word" in the skill's colour), 3 card (one `DrillCard`), 4 answer area (choices, tiles, field, microphone; empty for teach and set), 5 feedback area (the banner; empty on teach, set and in an exam), 6 action area (one place, 56 dp buttons: grades while something is left to grade, goes on when nothing is, except on a teach card and a set, where it is empty; Back and Next in an exam; the review step follows the last item).

Owner decisions drawn (2026-10-31, #509): no per-item feedback in an exam until the result; free navigation, with the review-answers step as the last item before Submit, reached by going on (swipe); the teach pill takes the skill's colour; an answered choice shows the right answer and, when the learner chose wrong, the option they chose too, marked wrong (owner, 2026-10-31, doubt 13); Say recordings can be replayed; mock the shell first.

## Doubts

Open (not decided; the plan's proposal is drawn where a control can show it):

A. **What happens to a saved exam after the day ends?** Owner (doubt 11, 2026-10-31): a paused exam is saved and can be resumed the same day. Drawn: "carry on any time before midnight". Not decided: whether it is then lost, expires with its recording, or can be resumed later.
B. **Can a learner start over?** Not decided: restart an exam from item 1 (clearing the answers and the recordings), or never, or only after submitting.
C. **The no-microphone rule.** Drawn: on a device without a microphone or permission, the Say item shows "Recording is not available here" with a disabled microphone, never gates Submit, and counts as skipped. Not decided: whether it is skipped, replaced by a typed item, or dropped from the exam's count (the plan: speaking and listening items must never gate a device that lacks the hardware).

Answered (owner, 2026-10-31, #509; "drawn" means the owner confirmed the drawn default). The wording below is as relayed to this session; check it against the issue comment before the mockup is approved.

1. **How the learner goes on.** Answered: no Continue button on teach, sets or questions. Teach: "Continue is not needed when swipe and the chevron click is there. Right? It also frees up the screenspace". Sets: "Swipe is going to be universal, across all deck viewing." Questions: "Swipe-only everywhere". Check, Don't know, Show answer, the four ratings and Count right or wrong remain where an answer must be submitted or graded.
2. **Grading area and going on.** Answered: one action area that changes content, as drawn.
3. **Where "Don't know" and "Can't listen or speak now" live.** ANSWERED, confirmed as drawn (owner, 2026-10-31): Don't know beside Check, Can't now as a link above, in the action area.
4. **The teach pill.** ANSWERED (owner, 2026-10-31): the teach pill takes the skill's colour; the neutral "New word" pill is replaced. Drawn: a new word is the Recognition colour ("New word · Recognition"), a rule card is Grammar ("Rule · Grammar"), a set is Recognition ("New words · Recognition"). The same per-skill colours as the question pills (the Today pills' colours), contrast-checked in light and dark below. Accepted downside: the colour carries the skill, the words carry "new".
5. **Exam header progress.** ANSWERED, confirmed as drawn (owner, 2026-10-31): the wave and the count show the position (4/35).
6. **When a tile or typed answer is committed in an exam.** ANSWERED, confirmed as drawn: there is no Check; the answer is what is on the answer line when the learner leaves the item.
7. **How a chosen answer is drawn in an exam.** ANSWERED, confirmed as drawn: a filled radio and a primary outline, not the green of Correct.
8. **Exam Say.** ANSWERED, confirmed as drawn: re-recording allowed, no heard text, no verdict. Extended below (Say recordings).
9. **How the review step is reached.** ANSWERED (owner, 2026-10-31): in the exam the review-answers step is the last item before Submit, reached by going on (swipe) from item 35, and swiping back reaches the earlier answers. No other entry is drawn: the last Next is a plain Next (no "Review answers" button), the header count is not tappable, there are no flags, and the review rows are not tappable (an unanswered item is reached by swiping back). This replaces the drawn tap to jump to an item.
10. **Unanswered at submit.** Answered: "Block submit until all answered". The review step lists the unanswered items and Submit stays disabled until all are answered.
11. **Leaving an exam.** Answered: close mid-exam saves the position and the answers, and the learner can resume the same day. The part after the day ends is open (A), and starting over (B).
12. **Typed answers (romanised).** ANSWERED, confirmed as drawn (owner, 2026-10-31): with the keyboard open the card and foot go compact; only the romanised field is shown (script typing is retired).
13. **Height at 1.4x and the answered choice.** ANSWERED (owner, 2026-10-31, replacing the earlier answer, which showed only the right answer): "the answered choice screen shows the right answer, and when the learner chose wrong, the option they chose too, marked wrong; other options are not shown" (as relayed to this session; check it against the issue comment before the mockup is approved). Drawn on Choice and Hear: the right option in green, and when the learner chose wrong, the option they chose in the error colour with a wrong mark (outlined in red as new); the Not quite banner gives the answer. The other options are not shown. Word tiles keep only the right order and the banner says right or wrong, because a wrong arrangement is not an option that can be marked; not decided: whether a wrong arrangement is shown too. With at most two options shown, the 1.4x answered screen no longer scrolls the options behind the foot.
14. **Does "cannot change any answer" apply to the exam?** Answered: exam answers are editable until submit; practice is read-only on going back ("users should be able to backswipe as well, just cannot change any answer").
15. **Discoverability with swipe-only going on.** ANSWERED, confirmed as drawn (owner, 2026-10-31): the end-edge chevron is visible on every answered question and set, and the feedback banner stays until the learner swipes. No hint and no pulse.
16. **Say recordings: replay.** Answered (owner, 2026-10-31): on an answered Say item (in the exam, on swipe-back, and on the review step) the learner can check their own recording. Drawn: "The word" (the model Play) next to "Your recording" (a filled Play, with the take's length; it becomes a Pause with a progress bar while playing) and "Record again". States drawn: recording exists, playing, no recording yet, and recording unavailable (no microphone or permission: no gate). On the review step each recorded Say row has "Your recording"; an unrecorded one says "Not recorded". It is a replay, not a verdict. The recording stays on the device and is dropped when the exam is submitted or abandoned.
17. **How long a take is kept.** ANSWERED (owner, 2026-10-31): "Keep until submit; practice also keeps it". The take is kept until the exam is submitted, which includes a paused exam that is resumed the same day; it is dropped at submit, and when the exam is abandoned.
18. **Does practice Say keep the last take for replay?** ANSWERED (owner, 2026-10-31): "Keep until submit; practice also keeps it". Practice Say is drawn with the same "Your recording" control beside the model Play, after the answer is checked.

## Going back: practice and exam

Practice: swipe back or the back chevron is available on teach (new word, Relearn, rule card), on a set and on a question once it is answered. A set gone back to is read-only in practice too: it only shows its rows again (nothing on it is graded or changed), so there is no locked banner. A teach card shows as it was. A question gone back to is read-only: answered state kept, controls locked, no re-grading, and a neutral "Already answered" banner (lock icon, surface colour, not the green or red of a verdict). Exam: free navigation; going on from the last item reaches the review step, the last item before Submit, and swiping back reaches the earlier answers; answers can be changed until Submit (doubt 14).

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All 68 pairs pass (re-run 2026-10-31 on the revised file; the new teach, rule and set pills use the five skill-pill pairs below, so no new pair is needed) (the Already answered banner uses onS on sHigh, already in the list as "text on the card", and so does its lock icon).

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
| light | speaker, tonal | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
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
| dark | speaker, tonal | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
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

Other checks: tap targets are 48 dp (header icons, Back, Next) and 56 dp (action buttons, choices); the swipe chevron is 40 dp: on a teach card it is, with the swipe, the only way on (owner, doubt 1), on teach, sets and answered questions it is, with the swipe, the only way on (owner, 2026-10-31, "Swipe-only everywhere"); a set has no action buttons, so its card takes the foot's space. Text sizes are all 1.4x. The disabled Check button is below 4.5:1 by design (a disabled control is exempt).

## Behaviour checks (Chromium, Playwright 1.56)

- Loaded at 1280 px and 390 px wide: no page errors, no console errors, no horizontal page scroll.
- Re-run 2026-10-31 on the final file: 448 combinations (both themes, both courses, Content short and long, every practice screen type crossed with every exam item type, at 390 and 1280 px), 0 console or page errors, 0 overflow or clipping, 68 of 68 contrast pairs pass. Every tweak control pressed in both courses and both themes, Content short and long, every practice screen type and every exam item type: no element wider than its phone, no clipped text, no errors.
- Screenshots of the page in light and dark were looked at.
- Doubt-13 change (2026-10-31, the answered choice): the markup and the script were parsed, and the wrong option uses the existing `.ct.no` pair (onEc on ec, already in the table); the Chromium pass above was not re-run for this change.
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts; where offline the system fallback is used.

## Not in this mockup

The Latin and Cyrillic letter-tile keyboard, exam start, the result, the locked state on the path and the retake wait: later mockups of the plan, built on this shell. The review step here is drawn only far enough to show the shell.
