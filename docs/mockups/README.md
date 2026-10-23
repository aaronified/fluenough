# Mockups

The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

## Awaiting approval

- `progress-mastery.html`: the Progress tab's mastery view (#678): the
  words count (**312** / 540), a 6-point star of mastery per skill (grammar,
  script, read, write, hear, say; the filled shape is known / B1 total and is
  overall mastery; an outline with no fill is known / taught, always on or
  outside the filled shape, at the centre for an untaught skill; both grow from
  the centre in 400 ms on open), the line chart of known / taught over time,
  then the weakest tags, leeches and calendar (with streaks) the tab has today
  (owner, 2026-10-23). Hindi (Hindustani) in light and Bengali in dark, 1.4x.
  Open choices are tweak controls and are listed in `progress-mastery.md`, with
  the self-check.

- `today-chain.html`: every screen the Today chain needs on one page (owner,
  2026-10-23: "Do all the mockups needed for the today chain together, in one
  screen."): Today with one ring button, minutes and Catching up (#521, #680),
  the minutes-a-day setting (#485), situation cheatsheets and their inspect view
  (#724), the decks page's Learn only... chooser for every course (#723) and the
  conversation screen (#722). Hindustani and Bengali, light and dark, 1.4x.
  Open choices are tweak controls and are listed in `today-chain.md`, with the
  self-check.

## Current and approved

Each is the spec for its screen. Don't rewrite one without the owner's
approval.

- `session-result-and-hours.html`: the session result's count line,
  correct share and minutes (#486), and hours spent and hours left on
  Progress (#227). Approved by the owner, 2026-10-12.
- `settings.html`: Settings as a short list of section pages, with every
  planned change folded in: Sources in Your languages (#469); Look and
  language as the Look screen with an App language row, English only until
  #46; Your data as the backup page itself, with backup and restore
  (cloud, recent and cloud backups, the restore sheet) and the review log
  fully expanded on it, no page between (#473, #470; owner, 2026-10-12); Your
  decks with the custom deck check after an upload (#475, #495, 0.6.0);
  switches only for the activities a learner may skip (#243); Reminders for
  several languages (#90, 0.6.0); an App log screen; Profiles and privacy
  (PIN lock, profiles, Delete this profile) from the profile card (#204);
  and destructive actions in the error colour. Approved by the owner,
  2026-10-12, with the decisions the page marks Proposed (#496).
- `deck-search.html`: the Decks tab's one search for decks, units and
  words, in place of the filter row (#527; owner, 2026-10-16: "I just want
  people to quickly find stuff. The filters can be replaced by a fts5
  search with typo tolerance and the kind can be a chip."). Revised for the
  owner's later answers (2026-10-16): the close button is in the search
  bar; with nothing typed the path shows under a scrim, results start with
  the first letter, and deleting every letter leaves a blank area; Latin
  letters search the transliteration and the English meanings, and the
  course's script searches the words; a query in another script says "This
  script is not part of this course." and offers each of the learner's
  courses that uses it as its target or native script (Devanagari: Hindi
  and Marathi), or says it is not part of any; every card, set card, deck
  and unit is its own row ("Don't group by meaning"); and "travl" also
  finds "Bus, auto, cab" through its theme's tag ("Yes, also transport").
  Each result has a kind chip that narrows the search ("Both"). Revised
  again for the owner's answers on 0777b95 (2026-10-16): `kind:`,
  `status:` and `tag:` tokens open a dropdown combobox of their values and
  become chips inside the bar, a result's kind chip adds `kind:`, and chips
  combine with text; the ✕ clears, then closes; the hint is "Search
  Hindi", this course only; the `travel` tag is on the transport theme in
  `decks/themes.yaml`, with a build-time check that the 0.4.3 reader
  accepts it; and a script none of the learner's courses use offers to add
  a catalog course written in it and, for any script not yet native, to add
  its language to the languages you know. It uses the #528 language bar,
  edge-masked where its row does not fit. Revised again for the owner's
  answers on 65224c7 (2026-10-16): opened with nothing typed, the search
  offers the tokens over the darkened path, a picked token offers its
  values, typing replaces them with suggestions (completions of what is
  typed) above the results, and clearing all text offers the tokens again,
  in place of the blank area; `status:` is not learnt, learning, learnt,
  forgetting, struggling or set aside, one per card, forgetting winning
  over learning, each defined from the app's skills, FSRS due, leeches and
  set-aside; `theme:` replaces `tag:`, its values the themes in
  `decks/themes.yaml`, while "travl" still finds "Bus, auto, cab" through
  the travel tag; and a script several languages use gets one row per
  language to add to the languages you know. Hindi and Bengali, light and
  dark, 1.4x, and a note on how FTS5 does it. Approved by the owner,
  2026-10-16 ("Approve"), with the decisions the page marks Proposed and
  the last answers folded in: `theme:` offers only this course's themes
  ("Only this course's"); the status order and the 21-day learnt line
  stand ("Yes, both"); and the languages-you-know rows leave out languages
  the learner already has a course in ("Leave them out").
- `reviewer-mode.html`: reviewer mode, adapted to today's app (owner,
  2026-10-17: "Mockup first"). Waiting for review with Reviewed, not sent
  and Reviewed and sent first, each sent suggestion Accepted, Rejected or
  Waiting for a second review with no rater codes, then the languages
  folded with their counts (#471); Suggest a change with a BASE card's
  pencil, Add a base, Remove with Undo before ✓, and a Word change as a
  new identity that keeps the old word as `alt_target` and goes as one
  review (#476); PLACE, offering only the B1 plan's units and themes, the
  meaning rule, and the reviewer rules and daily question count (default
  10) in onboarding (#477); and every field of a card, with Flag this
  recording alone and Wiktionary items marked semi-verified and placed
  last (#508). Hindi and Bengali, light and dark, 1x and 1.4x. It replaces
  the 2026-10-09 drafts, which are in git history
  (`git show 6715716:docs/mockups/reviewer-mode.html`). Approved by the owner, 2026-10-17, with the decisions the page marks
  Proposed ("The reviewer mode mockup looks fine. Build it.").

## Approved

- `deck-page-and-teach-card.html`: one phone with the new deck page (#693: every
  word with its meaning and a mastery chip, live tag chips, Practice and
  + Learn with a count badge that becomes Relearn, Inspect retired), the word
  sheet with everything inline, and the one-screen teach card (#691) with its
  pronunciation and dictionary popups, a tab-swipe spring and chevrons.
  Course and theme are tweak controls. Hindustani and Bengali, 1.4x (owner,
  2026-10-22). The self-check and notes, with Proposed items marked, are in
  `deck-page-and-teach-card.md`.
  Approved (owner, 2026-10-22: "Approved", with "Just give the meaning
  more space": the picture sits beside the word and the meaning takes the
  full width).

- `language-wheel.html`: the language wheel (#703, #682): ratchet detents
  with a tick and vibration, the round wheel, and the label under the bar,
  as first drawn, plus the expansion. Owner, 2026-10-21: damping ratio 0.4,
  stiffness 800 (mass 1), fling friction 8 per second, expansion 0.3 s.
  "The tooltip should become the expansion via some animation that will
  take that 0.3 seconds" (chose a cross-fade: the label fades out as the
  pill grows); "After expanded, the two languages to either side will still
  show, as per the wheel distance" (chose: pushed out, the same gap from
  the pill's edge). The pill is centred, glyph and name.
  Approved (owner, 2026-10-21: "Works. Approved.").

- `tab-swipe.html`: the tab swipe spring (#702, #683): damping ratio 0.75,
  stiffness 400, mass 1 (owner, 2026-10-21: "400, 0.75 approved for tab
  swipe").


## Deleted (owner, 2026-10-12)

These were fully built, so their mockups were deleted. Code comments still
name them. They are in git at 19d200b
(`git show 19d200b:docs/mockups/<name>.html`):

- `adapted-to-you.html`, with its earlier versions `ambient.html`,
  `moment.html` and `story.html`: "Adjusted to you" (ADR-0035).
- `language-picker.html`: the language picker (#443).
- `language-bar.html`: the language bar on Today, Decks and Progress,
  built in #528 and removed once built (owner, 2026-10-16: "Remove when
  built"). It is in git history:
  `git show 25522ea:docs/mockups/language-bar.html`.
- `languages-learning.html`: Languages I'm learning (#626), built and
  removed once built (owner, 2026-10-16: "Remove when built"). It is in git
  history: `git show 4e094b9:docs/mockups/languages-learning.html`.
- `languages-you-know.html`: Languages you know, with the bottom-sheet
  script question (#490), built and removed once built (owner, 2026-10-16:
  "Remove when built"; tidied 2026-10-20). It is in git history at
  `c6925d6c`: `git show c6925d6c:docs/mockups/languages-you-know.html`.
- `set-cards.html`: a set card in a lesson (#515), built in 0.4.4 and
  removed once built (owner, 2026-10-20: "delete all obsolete ones"). It is
  in git history at `c6925d6c`:
  `git show c6925d6c:docs/mockups/set-cards.html`.
