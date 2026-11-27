# Achievements: self-check, notes and decisions

Companion to `achievements.html` (owner order, 2026-11-27: start the Achievements family, mockup first; owner, 2026-10-22: the self-checks and notes live in a Markdown file of the same name). Plan: `wiki/Plan-Achievements.md`, issue #223 ("not as aggressive as Duolingo"), children #322 (rules over the log), #323 (summary, Progress grid and badges), #324 (level badges from the B1 marks, needs the milestones of `Plan-B1-Plans`).

**Revision 2 (owner, 2026-11-27: "approved on the looks, but you need to add more categories, like for each skill (start and master). and then for mastering specific topics or sets (like the pronouns, or kins). the plan is to build achievements spaced to unlock throughout the course at a more or less even manner.")** keeps the look and the five defaults below, and adds the section "Revision 2" before the contrast check and "New decisions" after the earlier decisions.

Phone 360 dp at 1.4x text only (the app's cap, #505), the app's own palette (`ColorScheme.fromSeed` of the forest seed), light and dark, Hindustani and Bengali examples. Controls: theme, text size (1.4x only), course, badge states (mixed, just started, nearly all), level rule (remembered or taught), past reviews (quiet or celebrated), highlight of what is new, and motion (fades in, reduced). Everything is new except the Level tile, which is shown unchanged.

## Screens

1. **Summary entry.** A single quiet line under the Level tile on Progress: the latest badge and its date, tapping opens the grid. Hidden before the first badge. No count, no red dot.
2. **Progress grid** (#323). Three columns, grouped: Levels, Words, Firsts for the chosen language, then Streaks and Answers for every language. Earned is filled with its date; in progress has a ring and "312 of 500"; locked is dashed with a lock. Only the next badge of a chain shows progress; the rest of the chain is locked.
3. **Badge sheet.** One sheet in three states (earned with a few of the learner's words, in progress with a bar, locked with how to earn it). The "how to earn" lives here, not in the grid, so the grid stays three even columns at 1.4x. The plan's "greyed, with how to earn them" is met by tap-to-see; each tile's screen-reader label already says how.
4. **Level badges** (#324). A1 bronze, A2 silver, B1 gold, drawn with `LevelBadge` (`lib/features/stats/level_badge.dart`, #678), the same in both themes. A Levels sheet lists the three, with the next one's bar and a sentence that follows decision 1.
5. **Announcement.** On the session summary, under its numbers: a tonal card, "New badge", fading in over 0.2 s (nothing moves under reduced motion). Two cards at most, then "and N more". No confetti, no sound, no vibration, no pop-up over a lesson, no notification, no reminder. Nothing ever says a streak is at risk or was lost; a streak badge appears only when earned and a lapse changes nothing on screen.

## Revision 2: skills, sets and the even spread

Real names used: the app's four skills are Speak, Hear, Read and Write (`SkillKind`, `lib/core/languages/language_skills.dart`); Read and Write belong to a script (Devanagari for Hindustani, Bengali for Bengali), and a sign language has one skill, Gestures, so it gets one Start and one Master. Sets come from decks-live: word sets are themes (`decks/themes.yaml`: Pronouns and people words, Family, Numbers 1-20, Food and drink, Festivals) and grammar tables are the grammar decks of the path (`hi-grammar-nouns`, `hi-grammar-past`, `bn-grammar-relative` and so on).

### Progress is now four tabs

- **Levels**: A1, A2, B1 and the four word counts (100, 500, 1,000, 2,500).
- **Skills**: for each skill a **Start** and a **Master** (below).
- **Sets**: **Word sets** (Pronouns, Family, Numbers, Food, Festivals) and **Grammar tables** (Noun forms, Past tense, Future tense, Relative clauses, If clauses, Purpose, Causative and so on). Hindustani shows 14 sets and Bengali 15, chosen from the path (see the rule below).
- **Other**: First lesson, streaks and answer counts (not on the path).
- A **Next** row above the tabs names the next unlock and opens the Journey.

### Skills: Start and Master

| Skill | Start (first real step) | Master (high, defined bar) | On the Hindustani path |
|---|---|---|---|
| Hear | Hear and answer 10 audio cards | Know every listening card up to the A2 mark | unit 4 and 75 |
| Speak | Say an answer aloud and have it heard | Know every speaking card up to the A2 mark | unit 23 and 83 |
| Read (per script) | Know your first 5 letters | Know every script and reading card up to the A1 mark | unit 9 and 47 |
| Write (per script) | Write your first 5 letters | Know every writing card up to the A1 mark | unit 26 and 49 |
| Gestures (sign languages) | Recognise and make 10 signs | Know every gesture card up to the A2 mark | one pair, as Hear |

"Know" is the Level tile's rule (decision 1): a card counts once it has been known at any time, so a lapse never takes a badge away. A Master badge is dated when the last card of its bar became known. A skill the learner marked Leave on the Languages page shows its two badges dimmed (decision 11).

### Sets: what "mastered" means

A set is one deck group of the path: the deck, its sentences deck and its reading deck. It is **mastered when every card of those decks is known**, by the same rule as the Level tile. The sheet shows "11 of 16 cards known" and the cards still to know, with the word in script. Examples: Hindustani **Pronouns** (मैं, तुम, आप, वह, हम), **Family** (माँ, पिता, भाई, बहन, बुआ), **Numbers 1-20** (एक, दो, तीन), **Food and drink**, and the grammar tables **Noun forms**, **Past tense**, **Relative clauses**; Bengali **Pronouns** (আমি, তুমি, আপনি, সে, আমরা), **Family** (মা, বাবা, ভাই, বোন, পিসি), **Numbers 1-20** (এক, দুই, তিন) and its tables. A grammar-table set counts the cards of its forms deck and its sentences; a language with no grammar deck for a topic has no set for it.

### The even-pacing rule

The path is the timeline: units 1 to the B1 mark (Hindustani 114 units with the marks at 43, 71 and 114; Bengali 187 with 60, 109 and 187; the real numbers of decks-live's paths). Every achievement is attached to a position on it, and the Journey shows them.

1. **Target gap**: one unlock about every **3.5% of the B1 plan**, about 30 per course (Hindustani one per 3.9 units, Bengali one per 6.2). Never closer than **2 units**, never farther apart than about **7%** of the plan.
2. **Fixed anchors first**:
   - the three levels sit on their marks;
   - the word counts sit where the plan's sizes (about 700, 900 and 1,200 words per level) reach them: 100 words at about 5% of the plan, 500 at 27%, 1,000 at 46%, 2,500 at 90%;
   - a Start sits where its first step is first possible (Hear after the first audio units, Read and Write after the script units, Speak when the first speaking card appears); a Master sits just after the mark of its bar.
3. **Sets fill the rest**: each tenth of the course should hold 3 unlocks. A set's natural position is its last path unit plus a review lag; if that tenth already holds 3, it slides to the nearest tenth with fewer. Word sets are taken first, then grammar tables in path order.
4. **Streaks and answer counts are not on the path**: they follow days, so they sit under Other and are never counted in the spread.
5. **A short path** (45 units to B1) keeps all anchors, picks fewer sets, and the 2-unit minimum gap applies, so the gap becomes about 2.6 units. A path with only A1 built shows only the A1 part: A2, B1 and what lies past them stay hidden until the plan exists, so the strip never promises what is not there.

Result, from the mockup's figure: Hindustani has 3 unlocks in each tenth of the course (2 in the ninth); Bengali 3 in every tenth; the furthest gaps are 7 and 10 units. Nothing bunches at the start or the end.

### The Journey

A horizontal strip of the course: levels as diamonds, words as squares, skills as circles, sets as triangles (shape, not colour, tells them apart), the reached part filled, the next marker ringed and named in a pill above. It scrolls sideways inside its own box and opens centred on the next unlock. Under it: **Next up** with how many units away, and the next two. It never shows what was missed and never counts days.

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
| Tab label `#404942` on tab bar `#F0F5EE` / selected `#374B3E` on `#D1E8D6` (light) | 8.4 / 7.2:1 | 4.5:1 |
| Tab label `#C0C9C0` on `#171D19` / selected `#D1E8D6` on `#374B3E` (dark) | 10.1 / 7.3:1 | 4.5:1 |
| Journey marker outline `#717972` on `#F6FBF4` (light) / `#8A938B` on `#0F1511` (dark), unreached | 4.2 / 5.6:1 | 3:1 |
| Next-unlock pill `#FFFFFF` on `#296A48` / `#003920` on `#92D5AB` | 6.5 / 7.7:1 | 4.5:1 |
| New-badge card text `#374B3E` on `#D1E8D6` (light), reverse in dark | 7.2:1 | 4.5:1 |

State is never colour alone: filled plus date, ring plus count, dashed plus lock plus "Locked". Verified in Chromium (Playwright) at a 400 px viewport, light and dark, Hindustani and Bengali: no horizontal page scroll and no clipped text. Revision 2 re-checked the same way: the Journey strip is the only thing that scrolls sideways (inside its own box, keyboard focusable, with a screen-reader label), frames were enlarged where 1.4x text needed room, and the sheet's large badge is now centred.

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

## New decisions from revision 2 (answer yes to take all of them)

The five decisions above stay at their defaults. These are new; each has options, the main downside and my recommended default.

6. **The Start and Master bars per skill** (table above).
   - Counts instead (for example Master = 200 cards of that skill known). Downside: a count means little to a learner and ignores the path.
   - Bars tied to path marks, as drawn. Downside: a skill with few cards on the path, such as Speak, has a small Master, and one lapsed card holds it back.
   - **Default: marks, as drawn.** Read and Write Master at the A1 mark, Hear and Speak Master at the A2 mark.
7. **Which sets count.**
   - Every deck of the path. Downside: 80 or more badges, a flood.
   - A chosen list per course: about 14 sets, five word sets and nine grammar tables. Downside: someone must choose them, once, in the path file.
   - **Default: a chosen list per course**, kept in the path file beside the units, so a language gets only the sets it has decks for.
8. **"Mastered" for a set.**
   - All cards known, the Level tile's rule. Downside: one hard card holds the badge back.
   - 90% known. Downside: a second rule, and "mastered" with gaps.
   - **Default: all cards known, a card counting once it was ever known**, like decision 1.
9. **The pacing target.**
   - One unlock per 3.5% of the plan, about 30 a course, as drawn. Downside: more than the earlier 19.
   - One per 5%, about 20. Downside: longer waits and fewer sets.
   - **Default: 3.5%, minimum 2 units, maximum about 7%.**
10. **What happens to the old Firsts.** Passage and spoken fold into Hear Start and Speak Start, Script into Read Start and Master, First deck is dropped (the first set stands for it), First lesson stays under Other.
   - Keep all five. Downside: duplicates, and they bunch at the very start.
   - **Default: folded as described.** This replaces part of decision 2's list; its words, streaks and answers are unchanged.
11. **Skills marked Leave.**
   - Hidden. Downside: the grid changes shape with the choice.
   - Shown dimmed and not earnable. Downside: still on screen.
   - **Default: shown dimmed**, with "Not part of your plan" under the name.
12. **One Journey per language, or one for all?**
   - One per language, as drawn. Downside: switch language to see the other.
   - A combined strip. Downside: unreadable beyond two languages.
   - **Default: per language.**

## Notes

- Nothing is stored but which badges have been shown; every badge is a rule over the review log and the catalog that finds its date (plan, "What it takes"), so backup and restore keep them.
- Badge names and how-to lines are app text (English until #46); only the language chip and example words are in Devanagari or Bengali script.
- Icons are Material icons already in the app's icon set; no new fonts or images.
- The Journey figure is computed from the real unit numbers of decks-live's paths and illustrative in its placements; the app computes the real ones from the path files and the card counts.
- No CHANGELOG line and no code until the owner approves this.
