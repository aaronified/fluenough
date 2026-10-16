# Plan: what reviewing covers, and how reviewers change cards

Written 2026-10-11, for 0.6.0 (moved from 0.5.0 by the owner). Tracks #476 and #477.

## What the owner asked

> The overall meaning must not change. This is the direction that reviewers
> should get. Good morning is not to be replaced with goodbye.
>
> And there should be review options to suggest a different positioning for
> the cards (based on introduction of distinct themes which will be there in
> the B1 planning itself). Adding a new theme requires direct modification to
> the deck via a PR. Reviewers need to be told that as well.
>
> Reviewing shall cover the entire content as well as logic of the language
> decks.
>
> And a reviewer must be bilingual, and he can only review decks where they
> know both target and native languages, this is to be part of the reviewer
> onboarding.

Also (owner, 2026-10-11): the main word may change, as when শুভ সকাল!
(śubho śôkāl!) gives way to শুপ্রভাত! (śuprobhāt!), which is far more
common; and a reviewer must be able to change, add and remove base words.

## Rules reviewers are given

These go in the reviewer onboarding in the app, in `docs/REVIEWING.md`, and
as a one-line reminder at the top of Suggest a change.

1. **You must be bilingual.** You can review a course only if you know both
   its languages, the one taught and the one it is taught from, and read
   both scripts. The app enforces this through Languages you know (#462);
   the onboarding says why.
2. **The meaning never changes.** A card teaches one meaning. You may
   change how it is said: a better or more common word, a different
   register, a correct spelling. You may not change what it means. "Good
   morning" may become a more natural "good morning", never "goodbye". If a
   card's meaning is wrong for its place, suggest moving it (rule 4) or
   say so in Why. Don't rewrite it.
3. **Review everything, content and logic.** That covers each card's word,
   reading, IPA, meaning, notes, example, picture and base words. It also
   covers the logic: whether a card belongs in its unit, whether the units
   come in a sensible order, whether a grammar note is right, and whether
   something a learner needs is missing.
4. **You can suggest where a card belongs.** Move it to another unit or
   theme that already exists in the course's B1 plan.
5. **New themes are not made in the app.** Adding a theme, or a unit
   that isn't in the B1 plan, needs a direct change to the deck through a
   pull request on GitHub. The onboarding says so and links to how to
   contribute.

## What the sheet adds

- **Word, with a new identity** (#476 comment). The word can be replaced
  outright. The card's id and meaning stay, so learners keep their
  progress. The sheet then offers to:
  - replace the bases;
  - keep the old word as an accepted alternative answer, ticked by default;
  - check the notes and the example.

  It all goes as one change.
- **Bases** (#476). Change a base's word, reading and meaning; add a base;
  remove one.
- **Place** (#477). A new card at the bottom, PLACE, shows the card's unit
  and theme. Its pencil offers the units and themes the B1 plan already
  has. It is never free text, so it can't make a theme.
- **Meaning**: editing the meaning shows rule 2 above the field.

## What the bot does

- **A Word change:** applied with everything it brought, in one PR. The
  reading and IPA are filled in unless proposed (#468 comment).
- **A base change, add or remove:** written to `bases` line by line, with
  YAML scalars quoted. A base whose form matches a card becomes a `ref`.
- **A move:** the card's entry moves to the target unit's deck file, or its
  path position changes. Its id stays, and the index and validator run.
  The bot refuses a move to a unit or theme the plan doesn't have.

## Tests

- **Round trips:** each new suggestion kind (word with its follow-ups, base
  change, base add, base remove, move) goes through the mail file and the
  bot. Old mails still read.
- **Move:** offers only the plan's units and themes. The bot refuses an
  unknown target.
- **Onboarding:** shows the five rules, and the Meaning field shows rule 2.

## Estimate

About 3 to 4 days for the sheet, the bot and the onboarding. Confidence is
medium, because moving cards between deck files is the least known part.

## Earlier notes on reviewer mode (owner, 2026-10-09)

These come from the reviewer-mode mockup drafts (`docs/mockups/drafts/`;
their notes file is folded in here):

`reviewer-mode-screens.js`: half-done rework of `../reviewer-mode.html`
(owner, 2026-10-09): the deck screen becomes the owner's Unit design
(Unit, Review a unit, Enrol first), the sound-alike warning also shows on
the daily drill cards (seen, spoken, written words), "How reviewing works"
drops to five steps, and the switch is called "Review decks" everywhere.
It replaces everything from section 3 to the end of `SCREENS` in the HTML;
the CSS for the unit, review and drill parts and the `play` icon are still
to add. Parked: the owner set the order FSRS + skills, then B1 planning,
then the redesign.

Also to add when the redesign resumes (owner, 2026-10-09): several decks
sent in one mail, said at every step (turn-on dialog, How reviewing
works, the unit's foot, a send sheet listing every deck with unsent
reviews, the mail body); see `docs/plans/deck-browser.md`.
