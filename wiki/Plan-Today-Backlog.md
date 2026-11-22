# Plan: Today's backlog after placement

Source of truth: this wiki page. Decision record: [ADR-0063](ADR-0063-Never-Asked-Skills-Are-Not-Backlog).

Owner order, 2026-11-22: fix the Today queue after placement.

## What the owner saw

A learner deleted all Hindustani data, re-added it and took Find my level (fluent or expert overall, Write low; reads Devanagari, learns Perso-Arabic). Today then said "Catching up: no new words today. 19810 reviews, about 5778 min. At 15 min a day you will catch up in 389 days." The Script tile showed 0 and could not be started.

## Causes (read in the code)

1. Placement credits only some skills of a card, each at that skill's placed level, with one Easy review. A credited pair is not due.
2. A card with any credited skill is taught (`AppState.isTaught`), so Today's queue offers every other skill of it as a new pair at once (`SessionQueue.build`, `canIntroduce: isTaught`).
3. The daily plan counted those new pairs as due reviews (`_dailyPools` read `buildSession(...).items`, which is due plus new). Grammar decks make one card per lemma and slot, so the count reached 16,800.
4. More than three days of cards means "catching up": no new words, which also stops lessons, the only way an untaught script deck (the Perso-Arabic letters) is started.

## Rules

### 1. A skill never asked is not a backlog

- The backlog, the "Catching up" rule, the "reviews waiting" number and the days to catch up count only pairs whose scheduling state is due now.
- The new skills of taught words ("new pairs") enter the day through the new share: up to `DailyBudget.newPairsPerDay` a day, which is a fifth of the day's cards and at least three (10 at 15 minutes), less those already introduced today. They come in path order, after the due reviews, and are asked like reviews (the planner treats them as reviews to ask, never as waiting).
- **Path order.** New pairs are ordered by the course path (the unit their deck is in), then by card order, so the first deck listed never takes every new skill of the day while later units wait.
- **A guaranteed place.** Even when due reviews (under three days of cards) would fill a round, a third of the day's share (rounded up, 4 at 15 minutes) keeps a place in each round, so the new skills never starve.
- **Passages stay whole.** A reading passage's questions are never split by the daily share (`SessionQueue.takeWhole`).
- **Placement day.** Pairs credited by placement today count against the day's share, so on the day of placement no session offers a fresh ten.
- While the learner is really catching up (more than three days of due cards), no new pairs are introduced, as no new words are.
- Nothing is lost: a pair left over is offered on the next days, a few at a time.

### 2. Script lessons are not blocked by catching up

- While catching up, the daily plan still teaches the untaught cards of the script decks of the scripts the learner is learning, at most `DailyBudget.catchUpScriptWords` (5) a day in all, however many sessions run (script words already taught today, not counting letters placement credited, are subtracted), taking the words' place of the usual 15. Script decks of a script the learner does not learn are not in the course, so a script already read changes nothing: no new words while catching up.
- "Script decks": the decks listed under `alphabet:` in the course path. The cards come from the pending units, as every lesson does, so the rule is as fast as the path.
- Words stay blocked while catching up. The line "no new words today" stays; script letters are not counted as words.

## Consumers checked

| Consumer | Counts | Change |
|---|---|---|
| Today ring, plan, "Catching up" line (`dailyPlanFor`) | due pairs | now only due pairs; new pairs paced into the plan |
| Session rounds (`nextDailyRound`) | due, then paced new pairs | same pools as the plan |
| Keep going (`keepGoingNewCap`) | due | only due pairs |
| Skill tiles (`skillTile`) | what a tap serves: due and new pairs | none; the tile does not feed the backlog decision |
| Script tile | due script pairs | none; untaught script letters come as a lesson in the day's session, not from the tile |
| Reminders, widgets, `dueForecast`, `dueTomorrow` | scheduling states | none; already counted only due states |
| Language-bar dot, `todayLanguages` | any work waiting | none; new pairs still count as work |
| `TodayNumbers.due` | what the session would ask | none; it only chooses between the empty and the full Today body |

## Tests

`test/today_backlog_test.dart`: 300 words with one skill credited give no due pairs, no catching up, new words and reviews planned; the new skills are introduced no more than a day's share; a real backlog of 200 is still catching up; new skills follow the path, keep a place under a due backlog, and none is offered on the day of placement; two sessions in a day teach at most five script words; while catching up, the Urdu letters are taught and words are not; with the script already read, nothing new is taught.

## Not done

Placement credit is unchanged (another work item handles per-script gates). No new screen or string.
