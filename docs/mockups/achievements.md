# Achievements: self-check, notes and decisions

Companion to `achievements.html` (owner order, 2026-11-27: start the Achievements family, mockup first; owner, 2026-10-22: the self-checks and notes live in a Markdown file of the same name). Plan: `wiki/Plan-Achievements.md`, issue #223 ("not as aggressive as Duolingo"), children #322 (rules over the log), #323 (summary, Progress grid and badges), #324 (level badges from the B1 marks, needs the milestones of `Plan-B1-Plans`).

Phone 360 dp at 1.4x text only (the app's cap, #505), the app's own palette (`ColorScheme.fromSeed` of the forest seed), light and dark, Hindustani and Bengali examples. Controls: theme, text size (1.4x only), course, badge states (mixed, just started, nearly all), level rule (remembered or taught), past reviews (quiet or celebrated), highlight of what is new, and motion (fades in, reduced). Everything is new except the Level tile, which is shown unchanged.

## Screens

1. **Summary entry.** A single quiet line under the Level tile on Progress: the latest badge and its date, tapping opens the grid. Hidden before the first badge. No count, no red dot.
2. **Progress grid** (#323). Three columns, grouped: Levels, Words, Firsts for the chosen language, then Streaks and Answers for every language. Earned is filled with its date; in progress has a ring and "312 of 500"; locked is dashed with a lock. Only the next badge of a chain shows progress; the rest of the chain is locked.
3. **Badge sheet.** One sheet in three states (earned with a few of the learner's words, in progress with a bar, locked with how to earn it). The "how to earn" lives here, not in the grid, so the grid stays three even columns at 1.4x. The plan's "greyed, with how to earn them" is met by tap-to-see; each tile's screen-reader label already says how.
4. **Level badges** (#324). A1 bronze, A2 silver, B1 gold, drawn with `LevelBadge` (`lib/features/stats/level_badge.dart`, #678), the same in both themes. A Levels sheet lists the three, with the next one's bar and a sentence that follows decision 1.
5. **Announcement.** On the session summary, under its numbers: a tonal card, "New badge", fading in over 0.2 s (nothing moves under reduced motion). Two cards at most, then "and N more". No confetti, no sound, no vibration, no pop-up over a lesson, no notification, no reminder. Nothing ever says a streak is at risk or was lost; a streak badge appears only when earned and a lapse changes nothing on screen.

## Contrast self-check (WCAG 2.1)

| Pair | Ratio | Needed |
|---|---|---|
| Level text `#1F1700` on bronze `#C07C45` (darkest stop) | 5.3:1 | 4.5:1 |
| on gold `#D1A02A` / silver `#AEB3B8` (darkest stops) | 7.4 / 8.4:1 | 4.5:1 |
| on bronze highlight `#EFC9A3` | 11.5:1 | 4.5:1 |
| Icon `#FFFFFF` on earned fill `#296A48` (light) | 6.5:1 | 3:1 (graphic) |
| Icon `#003920` on earned fill `#92D5AB` (dark) | 7.7:1 | 3:1 |
| Badge name `#171D19` on card `#F0F5EE` / `#DFE4DD` on `#171D19` | 15.5 / 13.3:1 | 4.5:1 |
| Status line `#404942` on card (light) / `#C0C9C0` on `#171D19` (dark) | 8.4 / 10.1:1 | 4.5:1 |
| Progress ring `#296A48` on card (light) / `#92D5AB` on `#171D19` (dark) | 5.8 / 10.1:1 | 3:1 |
| Dashed locked border `#717972` on card (light) / `#8A938B` (dark) | 4.1 / 5.4:1 | 3:1 |
| New-badge card text `#374B3E` on `#D1E8D6` (light), reverse in dark | 7.2:1 | 4.5:1 |

State is never colour alone: filled plus date, ring plus count, dashed plus lock plus "Locked". Verified in Chromium (Playwright) at a 400 px viewport, light and dark, Hindustani and Bengali: no horizontal scroll and no clipped text.

## Decisions to answer (one line each)

Each has the options, the main downside and my recommended default (marked **Default**). Answer "yes" to take them all.

1. **Level badges: taught or remembered?**
   - Taught: a level comes as soon as a lesson has taught every card up to the mark. Downside: you can earn B1 having forgotten most of it, which cheapens the gold.
   - Remembered: every card up to the mark is known. Downside: slower, and one lapsed card can hold a level back for weeks.
   - **Default: remembered, with a card counting once it has been known at any time** (so a later lapse never takes a badge away; the log is never edited, ADR-0005). The Level tile already measures known cards, so the two agree.
2. **Basic badges and thresholds.**
   - Plan list as drawn: first lesson, first deck, script, first passage, first spoken; 100, 500, 1,000, 2,500 words; streaks 3, 7, 30, 100, 365; answers 1,000 and 10,000. Downside: 19 badges, some tiers far away (2,500 words, 365 days).
   - Shorter list, dropping 500 words and 100 days. Downside: bigger gaps between rewards.
   - **Default: the plan's list as drawn.** It is a quiet grid, and the far ones only appear locked. Add 5,000 words later only if B1 plans exceed 2,500.
3. **Streaks: whole app only, or per language too?**
   - Whole app only. Downside: a learner of two languages who reviews only one keeps the badge, which is fair, but gets no credit for a per language run.
   - Per language as well. Downside: doubles the streak badges (10 more tiles) and invites exactly the daily pressure the plan rejects.
   - **Default: whole app only.** Progress still shows per language streak numbers as today; no badges for them.
4. **Achievements from past reviews on the first launch: celebrated or quiet?**
   - Celebrated: a full card, "6 achievements already yours", a Look through them button. Downside: a loud first impression and it breaks the "once, at the end of a session" rule.
   - Quiet: one small card with the badges in a row, dated when first met, "See them". Downside: a long-time learner's history gets a muted welcome.
   - **Default: quiet.** One card on that first summary, never repeated; the dates are the real record. The Past reviews control shows both.
5. **Play Games build: replace the GitHub build or sit beside it?**
   - Replace: one build, always signed in to Play Games where available. Downside: Google Play services come into every build and F-Droid users lose the app.
   - Beside it: a Play flavour with `games_services`, the GitHub and F-Droid build unchanged. Downside: two flavours to test and release.
   - **Default: beside it, as a separate flavour, built after the app is on the Play Store.** No screen in this mockup changes either way; sign-in would be an optional row in Settings, Your data.

## Notes

- Nothing is stored but which badges have been shown; every badge is a rule over the review log and the catalog that finds its date (plan, "What it takes"), so backup and restore keep them.
- Badge names and how-to lines are app text (English until #46); only the language chip and example words are in Devanagari or Bengali script.
- Icons are Material icons already in the app's icon set; no new fonts or images.
- No CHANGELOG line and no code until the owner approves this.
