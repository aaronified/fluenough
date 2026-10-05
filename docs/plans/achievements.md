# Plan: achievements, quietly

Written 2026-10-05.

## What the owner asked

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
