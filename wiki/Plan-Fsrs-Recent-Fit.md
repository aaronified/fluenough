# Plan: a recent fit for FSRS, with the window chosen from the learner's own reviews

Source of truth: this wiki page.

Status: Plan, not built (2026-11-06). Design only; no code changed. Line numbers are of `origin/main` on 2026-11-06.

Owner's request, quoted: the owner has 11k reviews and worries the FSRS calculations get worse as the history grows. "Recent fit should be a thing. Look for the sweet spot when it is recent enough to be relevant and still have enough data to be very confident." The owner accepted measuring the time of a fit and of a log replay at 11k and 50k synthetic reviews in CI.

## Audit (what the code does today)

**A window already exists.** The worry "a fit uses all history" is not what the code does; the open question is whether the fixed window is the right one.

| Question | Answer |
|---|---|
| What history does a fit use? | A skill's last 1,000 reviews or its last 3 months, whichever is more (`SkillFit.windowReviews`/`windowMonths`, `skill_fit.dart:91-92`; `windowStart` `:128-142`; ADR-0035). Null (all) only when the skill has 1,000 reviews or fewer. |
| Is `from` ever passed? | Yes, always: `SkillFit.canFit` (`:148`) and `SkillFit.run` (`:170-181`, `:186`) pass it to `FsrsFit.gate`, `fit` and `logLoss`. `FsrsTuner` never passes a window itself (`fsrs_tuner.dart:88, 119, 231`); it hands the whole history to `SkillFit`. |
| Meaning of `from` | `fsrs_fit.dart:133-137, 325-342`: every review still builds its pair's history, only reviews at or after `from` are predicted, learnt from, gated on, weighted and scored. |
| `SkillFitJob` / `SkillFitResult` | Job: key, **all** pairs' histories, `reviewCount`, `inUse`, `now` (`skill_fit.dart:33-39`). Result: key, `fitted` (null when too little), `before`/`after` outlook (`:42-53`). `FittedParameters`: 21 values, `fittedAt`, `reviewCount`, `lossBefore`, `lossAfter` (`skill_parameters.dart:21-58`; table `fsrs_parameters.dart`, no window column; schema 10, `database.dart:93`). |
| Kept or discarded? | `keepBetter` (`skill_fit.dart:208-225`): the fitted set is kept if its log loss on the window is lower than that of **the set in use** (the skill's last fit, else the baseline language's, else defaults; `fsrs_tuner.dart:230`). Not against the defaults. Both losses are on the same training window, so the test is **in-sample**, recency-weighted (`fsrs_fit.dart:246`, weights `:348-357`). A loss keeps `inUse` and stores the new `reviewCount`. |
| 10% trigger | `FsrsTuner.grown` (`fsrs_tuner.dart:49`) compares the skill's review count with `fitted.reviewCount` (`:192`); `_checkedAt` (`:196-198`) stops retries after a fit that gave nothing. Counts reviews, not items, and ignores the window. |
| Gate | `FsrsFitGate.outcome` (`fsrs_fit.dart:68-78`): train items < 8 defaults; < 64, or all train items being first long-term, pretrain only (w0 to w3); else trained. Items are one per review that is not a pair's first and comes a day or more after the last (`:325-342`). `_Prepared` (`:750-808`) drops first-rating groups under `max(20, total/20)` (`:778`), so 20 surviving pairs per first rating. In a window, a pair whose first long-term review came earlier has none, so a window can hold many items and no surviving first long-term one: w0 to w3 stay the start's (`:209-217`, comment `:22-26`). A window shrinks `trainItems` and the per-rating counts, so a small window can fall to pretrain-only or defaults. |

**Cost model (reading the code; nothing measured yet).**
- A fit is O(epochs x items x prefix length). 5 epochs, batches of 512, items over 256 reviews of one pair dropped (`fsrs_fit.dart:157-158, 557`). Each item replays its pair's prefix, so `from` bounds the item count, not the prefix. The window bounds the epoch loop only.
- Not bounded by the window: `SkillFit.histories` and `FsrsTuner._histories` walk the whole log (`skill_fit.dart:96-123`, `fsrs_tuner.dart:245-251`), per review for the skill when it crosses its trigger and in `canAdjust` (`:84-92`), on the UI isolate; `_counts` rebuilds from the whole log (`:172-178`); the job copies all histories to the isolate; `windowStart` sorts all times, called in both `canFit` and `run`; `_items` builds a `_Pair` for the whole history and sorts the items.
- Replay at open: `openLog` sorts and replays the log **twice** (state cache, then memory with script skills and implied reviews), builds the index, and encodes the snapshot (`replay_isolate.dart:75-118`), on `Isolate.run` (`:191`). With a valid snapshot the open only decodes (`openFromSnapshot` `:139-158`; about 2.5 MB at 50k reviews, `replay_snapshot.dart:23-31`). The snapshot bounds the start-up, not the cost of a fit or a reschedule.
- Memory: every event keeps its `before` and `after` `FsrsState`; the log lives in `_log`, `LoggedReview` lists and `OpenedLog.memory` at once; a fit holds `LoggedReview` copies, `FitReview` pairs, `_Item`s and the batches.

**Reschedule after a fit.** `FsrsTuner._fit` calls `putFitted` whenever the fit is not null (`fsrs_tuner.dart:233-235`), **including a fit that lost** (`keepBetter` then returns `inUse`). `putFitted` replays the whole log on the calling isolate in memory (`memory_progress.dart:266-269`, `_replace` `:452-480`, with script skills and implied reviews), rebuilds `card_states` by reading and replaying every review (`database_progress.dart:237-248`, `review_log.dart:297-304, 331, 514`), and arms a snapshot that replays the log once more (`:246`). So one fit that changes nothing still costs about three full replays. Finding: skip the replay when the stored values equal `inUse`, and write only the row.

## Floor: how little a window may hold

- **Hard floor (from the gate): outcome must be `trained`**, so at least 64 train items and 20 surviving first long-term items per first rating, or no surviving one at all (the existing rule). 64 only makes the code run, it is not a trustworthy fit.
- **Trusted floor: 400 train items** for a candidate window. Verified: the fsrs4anki tutorial says Anki 24.04 needed at least 400 reviews to optimise and older versions 1,000, and that Anki 24.06+ sets no minimum but decides from the count which parameters to optimise (the same idea as our gate's pretrain-only stage). Below 400 the window is not a candidate. A window of 400 items is about 500 to 600 reviews, so the 1,000-review rule of today is above it.
- Unverified (from memory, not read): that the benchmark's per-user reviews threshold or accuracy-versus-reviews curve puts the knee near 1,000 reviews. The synthetic experiment below measures the knee for this app's own fit instead of relying on it.
- Fewer than 800 train items in all: no choice is made (not enough for a held-out slice and a 400-item window); use all history.

## Candidate windows

Counted in train items, so the floor and the gate agree: **all**, last **4,000**, **2,000**, **1,000**, **500** items; a day window (last 180 or 90 days) is added only as a second family if the experiment shows it beats the item count for learners who pause. A candidate at or above the item count equals "all" and is dropped; one under the floor or whose gate outcome is not `trained` is dropped. At most 5 candidates (6 with the legacy rule while migrating). The current rule (1,000 reviews or 3 months) is always a candidate, so the new choice can never be worse than today's in the held-out score.

## Choosing the window without a human

1. Hold out the most recent slice of the skill's items: H = clamp(15% of items, 200, 1,000).
2. For each candidate, fit on the items before the held-out slice (the window counted back from the cut), starting from the set in use, in the same isolate and sharing the prepared pairs.
3. Score each on the held-out slice with the **unweighted** log loss (`logLoss` today is recency-weighted, so a flag is needed) and RMSE by bins of predicted recall. The FSRS benchmark uses log loss, AUC and RMSE (bins), with bins by interval length, review count and lapses, and splits by time so that older reviews train and newer test (`srs-benchmark` README, verified); the bins by predicted recall are our simplification, marked as such. The set in use is scored as a baseline.
4. Tie-break by one standard error: take the paired per-item loss differences against the best candidate, and prefer the **largest** window whose mean loss is within one standard error of the best and whose RMSE is no more than 0.005 worse. The margin and the 0.005 are starting values for the experiment to set.
5. Refit the chosen window through today (including the held-out slice) as the stored fit. Keep it only if it also beats the set in use on the held-out slice (an out-of-sample keep test replaces today's in-sample one for a fit that chose a window); the in-sample `keepBetter` stays as a second guard.
6. Store the choice with the fit: `windowItems` (null = all), `windowChosenAtCount`, the held-out loss of the winner and of `inUse`. The 10% trigger keeps counting reviews since `reviewCount`; the window start is the K-th most recent item at fit time, so it moves with the log but its size is fixed until the next choice.

Cost control: the choice runs when the skill's items have doubled since the last choice, after 180 days, or on "Adjust to me"; every other refit (the 10% trigger) only refits the stored window, which costs what a fit costs today. Candidates run one after another in one `Isolate.run`, capped at 5, with a time budget (skip the rest and keep the best so far). Results are cached by `(skill, items, windowItems)` in the stored fit, so nothing is recomputed on a read. Also bound the work the window does not: build `histories` only for the skill, not the log, and send the isolate only the pairs the window touches.

Fallbacks: too little data for a choice, or any candidate error: all history with today's rule. A window with no surviving first long-term item: allowed, w0 to w3 stay the start's, as the gate comment `fsrs_fit.dart:22-26` says; every candidate is then fitted in the same way, so the comparison stays fair.

## Telling the learner (Settings, "Adjust to me")

One sentence under the button, filled in from the stored window: "Adjusted to your last 2,000 answers in this skill, because they predict your next ones best." For all history: "Adjusted to all your answers in this skill." While the choice is not yet made: nothing is added. Never says "window" or "log loss". The result sheet keeps its before and after outlook.

## Migration, privacy

Migration 11 adds nullable `window_items`, `window_chosen_at_count`, `held_out_loss_best`, `held_out_loss_in_use` to `fsrs_parameters`. A stored fit with null `window_items` is "legacy": the 1,000-reviews-or-3-months rule keeps applying and its values stay in use; the first choice happens at the next refit after the items have doubled or on "Adjust to me". No recompute, no change of due dates at the update. The backup `parameters` line gains optional fields ([Log-Format](Log-Format)); an old backup restores as legacy. Everything runs on the phone from the learner's own log; nothing is sent.

## Synthetic experiment (before building)

Goal: find the window that is best per drift profile and size, and check that the auto rule finds it.

- **Generator** (`lib/core` only, a Dart tool, no Flutter): a learner whose true FSRS-6 parameters theta(t) move over the history. Profiles: **none** (theta fixed at a drawn user set); **slow** (stability gains w8 to w10 and the difficulty terms rise 15% over the history); **fast** (rise 80%, with a step at 40% of the history, as when a learner changes method). Reviews follow the app's scheduler at 90% retention with recall drawn from the true theta(t); sizes 1k, 3k, 11k, 50k reviews; 20 seeds (3 at 50k); several skills at once to reach the gate. `test/support/fit_learner.dart` is a simpler start (constant recall).
- **Measure** per (profile, size, candidate, seed): held-out unweighted log loss; RMSE by bins; because truth is known, the **RMSE between predicted and true recall** on the held-out slice (the number that matters, and not available on real data); the window the auto rule chooses and its regret against the best candidate; how often "all" and the legacy rule lose; the gate outcome. Report where each profile's best window sits and where the one-standard-error margin must be set so the auto rule picks within one step of it.
- **Hypotheses (unverified, to be tested):** none: all history wins at every size; slow: a 2,000 to 4,000 window ties all; fast: 500 to 1,000 wins from 11k. If none holds, the sweet spot is whatever the table says.
- **In CI, without the app:** `dart run tool/fsrs_window_experiment.dart` imports only `package:fluenough/core/...`; a scheduled and manual workflow (not per PR, as it is long) writes a CSV and a Markdown table as artifacts. A 1k smoke test in `test/` asserts determinism (same seed, same table), as the fit's own tests do. Tests run only in CI (owner rule).
- **Timing** (owner accepted): `Stopwatch` around `SkillFit.run` and `FsrsFit.fit` at 11k and 50k reviews for all history and for the window; around `openLog` (two replays plus snapshot) and `openFromSnapshot`; and one `putFitted` equivalent (a replay with skills); peak memory from `ProcessInfo.currentRss` before and after. Printed and uploaded. Gate: a budget on the ratio to a fixed calibration loop run in the same job, as runners vary; never a bare seconds limit. No number is known today; none is guessed here.

## Open questions for the owner

1. Choose the window automatically (this plan) or let "Adjust to me" show the choice and ask? 2. Is skipping the replay for a fit that lost (a finding above) in scope as its own small change? 3. Day windows too, or items only?
