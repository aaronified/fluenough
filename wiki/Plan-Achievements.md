# Plan: achievements, quietly

Source of truth: this wiki page.


Written 2026-10-05.

Status 2026-11-27: the engine (#322) is in progress; the screens (#323, #324) are next, per the owner's approval of the mockup and the pacing on 2026-11-27. The approved decisions, the categories (Levels, Skills with Start and Master, Sets, Other), the pacing rule and the plots are in [Plan-Achievements-Pacing](Plan-Achievements-Pacing).

## What the owner asked

With the course path (owner, 2026-10-09; the path itself is now built):

> I also want the deck path to look a bit like duolingo (but not the small
> round shapes, the decks need to be shown as slightly rounded rectangles).
> The achievements can be bakes in, as well as milestones (the CEFR levels
> are achivements, new milestones have to be built, like 100 words learnt,
> etc.). Do discuss before implementation.
>
> It should look a little playful. Show me mockups before you change
> anything here.

> wait, the milestones need to be awarded to the user like badges /
> achievements. we need some gamification. add that as a plan as well. not
> as aggressive as duolingo, but basic achievements and streak based
> achievements, later when app is on play store, they google play
> achievements can be tagged.

The milestones are A1 and A2 on the way to B1, the level a full course
reaches. That target is set in aaronified/fluenough#187.

## What exists

- **Streaks** are computed from the review log, never stored
  (`streakIn`). A day counts if it has at least one review. Progress shows
  the current and longest streak, per language when one is chosen, and the
  session summary shows the streak.
- **No achievements or badges**, and no notifications. Nothing in the app
  nags.
- **Everything shown is derived from the review log**, which is never
  edited (ADR-0005). That makes achievements computable from history,
  including for reviews made before this feature.
- **No milestones on the paths yet.** A path is a list of units, with no
  level marked.

## Not as aggressive as Duolingo

- No hearts or lives, no leagues or leaderboards, no points to chase.
- No reminders, no "your streak is at risk", nothing sent to the phone.
- An achievement is shown once, at the end of the session that earned it,
  and then sits on Progress.

## The achievements

1. **Level milestones**, per language: A1, A2, B1.
   - Earned when every card on the path up to that milestone is remembered,
     or when it is taught; which is to decide.
   - Needs each path to mark where a level ends, such as `milestone: A1` on
     a unit. That changes the path format, which needs the owner's answer
     (AGENTS.md).
2. **Basic**, per language:
   - first lesson;
   - first deck finished;
   - script learned (its units done);
   - 100, 500, 1,000 and 2,500 words learned;
   - first passage heard;
   - first answer spoken.
3. **Streaks**: 3, 7, 30, 100 and 365 days in a row, for the app as a
   whole. A day counts as it does today.
4. **Reviews**: 1,000 and 10,000 answers in all.

## What it takes

1. **Rules over the log.** Each achievement is a rule over the review log
   and the catalog that finds the date it was first met. Nothing is stored
   but which ones have been shown, so achievements:
   - survive a backup and a restore;
   - cannot be lost;
   - are earned for past reviews on the first launch with this feature.
2. **On the summary:** the achievements a session earned, under its
   numbers.
3. **On Progress:** a grid of badges.
   - Earned ones are in colour, with the date.
   - The rest are greyed, with how to earn them.
   - A language's milestones show with its chip.
4. **Badges** drawn with the app's own icons and colours, in both themes.
5. **Tests** for every rule, on fixture logs, and for a session that earns
   one.

## Google Play Games, once the app is on the Play Store

- Each achievement gets a Play Games achievement, created in the Play
  Console. The app unlocks it when it is earned, and unlocks every earned
  one on first sign-in.
- The plugin [`games_services`](https://pub.dev/packages/games_services),
  version 5.3.0 (MIT), covers Google Play Games and Apple's Game Center.
- Caveats:
  - It needs the Play Console listing, and Play Games Services set up with
    the app's signing key.
  - It brings Google Play services, which are not open source, into the
    app. A build without them, for F-Droid, would need a separate flavour.
  - Signing in stays optional. Nothing but the unlocks is sent.

## The engine (#322)

Built before the screens (owner order, 2026-11-27, after the achievements mockup was approved; the mockup is removed once built, and its decisions are recorded in [Plan-Achievements-Pacing](Plan-Achievements-Pacing)). It lives in `lib/core/achievements/`
and draws nothing:

- **Catalogue** (`achievement_catalogue.dart`): the badges of a language as
  data, from its path's marks and chosen sets. Levels A1, A2 and B1; words 100,
  500, 1,000, 2,500; a Start and a Master for each skill; the path's sets; the
  first lesson; streaks 3, 7, 30, 100, 365 and answers 1,000, 10,000, which
  belong to the app. A path with only part of its plan written places only that
  part.
- **Pacing** (`achievement_pacing.dart`): where each badge sits on the path.
  Levels sit on their marks; word counts and skill badges sit at fixed shares of
  the plan and move only to keep two units apart; sets fill the tenths of the
  course, at most 3 a tenth, word sets first. About one unlock per 3.5% of the
  plan, never closer than 2 units, never farther than about 7%.
- **Evaluator** (`achievement_evaluator.dart`, `known_history.dart`): every badge
  is a rule over the review log, replayed oldest first. A card counts once it has
  ever been known (the Progress star's rule, `leavesKnown`), so a lapse never
  takes a badge away; the date is the first time the rule was met; placement
  credit counts for nothing. The rules are not stored; the dates they find are
  kept (see "Earned badges are kept" below).
- **Sets** are chosen in the path file with the optional `achievement_sets:` key
  ([Deck-Format](Deck-Format#paths)); a language that chooses none has none.
- **Wiring** (`lib/app/achievements_holder.dart`): `AppState.achievements`
  works the report out on an isolate, as Progress's numbers are, and recomputes
  it only when the log, the language's decks or its skills marked Leave change.

## The screens (#323, #324)

Built from the approved mockup (decisions 1 to 11; the Journey and the spacing
plots are not app screens). They live in `lib/features/achievements/`:

- **Progress** shows one quiet line under the Level tile, the latest badge and
  its date (`RecentBadgeEntry`); nothing before the first badge. A tap opens the
  **badges page** (`AchievementsPage`, route `/achievements`).
- **The badges page** has four tabs: Levels (A1 bronze, A2 silver, B1 gold,
  drawn with `LevelBadge`, and the word counts), Skills (a Start and a Master
  for each skill, Read and Write for each script), Sets (word sets and grammar
  tables; "No sets are chosen for this course yet." when the path chooses none)
  and Other (first lesson, days in a row, answers). A badge is earned (filled,
  with its date), in progress (a ring and "312 of 500") or locked (dashed with a
  lock); only the next badge of a chain shows progress. A skill marked Leave is
  dimmed, "Not part of your plan".
- **Sheets**: a tap on a badge opens its sheet (what it is, what remains, the
  date earned; a word count shows a few of the learner's words, a Master or a
  set the next cards still to know); a tap on a level opens the levels sheet
  with the three metals, the next level's bar and the rule of decision 1.
- **Announcement** on the session summary (`AchievementAnnouncement`): a tonal
  "New badge" card that fades in over 0.2 s, two at most then "and N more", no
  confetti, sound, vibration or pop-up, and nothing about a streak at risk or
  lost. The first time, badges the past reviews already earned are shown once,
  in one quiet card (decision 4).

### Earned badges are kept

The engine review found that a badge could be lost when a deck grew (the rule
no longer held). So the settings (the profile's database, and so backups) keep
`achievements_earned` (scope, then badge id, then the date first earned) and
`achievements_seen` (scope, then the ids shown). The scope is a language code
or `*` for the app-wide badges. Each report is given the kept dates as
`earnedBefore`; a kept date is only ever added or made earlier, never removed.
The review log is never edited. Nothing is lost on a restart.

### When the badges are worked out

Never after an answer. The holder listens to nothing: a report is worked out
only when a screen asks (`AchievementsHolder.of`), and the only screens that ask
are Progress (the line, when the tab is shown), the badges page and the session
summary, never a lesson or a drill. The summary waits for the report that
counts the session's answers (`currentOf`), so a session costs at most one job
per language, off the main thread.

Not yet: Play Games.

## To decide

- Milestones earned when the cards are taught, or when they are remembered.
- The list of basic achievements and their thresholds.
- Whether streaks are counted for the app as a whole, or per language as
  well.
- Whether the achievements earned by past reviews are celebrated on the
  first launch, or shown quietly.
- Whether the Play Games build replaces the GitHub one, or sits beside it.

## Estimate

- The achievements: about 5–7 hours.
- Milestones marked on the existing paths: 1–2 hours.
- Google Play Games, later: about 3–4 hours, plus the Play Console setup,
  which only the owner can do.

Confidence: medium.

See also: [Plan-Achievements-Pacing](Plan-Achievements-Pacing) · [Roadmap](Roadmap) · [Plans-Index](Plans-Index) · [Home](Home)
