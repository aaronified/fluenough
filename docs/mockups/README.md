# Mockups

The wiki is the source of truth for documentation: https://github.com/aaronified/fluenough/wiki

## Awaiting approval

- `web-install-hint.html`: the web app's install hint (#1012, Storage
  eviction; owner, 2026-11-04: "Web needs to cover iOS fully... complete all
  web jobs"). A dismissible card on Today for iPhone Safari and Android
  Chrome, no hint once installed, and a Storage group in Your data. Telugu,
  Bengali and Hindustani, light and dark, 1.4x. Tweak controls and open
  choices are in `web-install-hint.md`, with the self-check.

- `today-chain.html`: the Today chain's screens still to build (owner,
  2026-10-23: "Do all the mockups needed for the today chain together, in one
  screen."): situation cheatsheets and their inspect view (#724, built in 0.7.0, so no longer awaiting), the decks
  page's Learn only... chooser for every course (#723) and the conversation
  screen (#722). Today with one button (#521, #680) and the minutes-a-day
  setting (#485) are built, so their screens are removed. Hindustani and
  Bengali, light and dark, 1.4x. Open choices are tweak controls and are
  listed in `today-chain.md`, with the self-check.

## Current and approved

Each is the spec for its screen. Don't rewrite one without the owner's
approval.

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

## Approved

None at the moment.

## Deleted (owner, 2026-10-12)

These were fully built, so their mockups were deleted. Code comments still
name them. They are in git at 19d200b
(`git show 19d200b:docs/mockups/<name>.html`):

- `reviewer-mode.html`: reviewer mode (#471, #476, #477, #508), approved by
  the owner, 2026-10-17 ("The reviewer mode mockup looks fine. Build it."),
  built and removed once built (owner, 2026-10-16: "Remove when built"; all
  four issues are in the CHANGELOG, removed 2026-11-04). It is in git history
  at `98be3004`: `git show 98be3004:docs/mockups/reviewer-mode.html`.
- `session-result-and-hours.html`: hours spent and hours left on Progress
  (#227) and the session result (#486), built and removed once built
  (CHANGELOG 0.6.x; the result is now a pill per skill, owner, 2026-10-30;
  removed 2026-11-04). It is in git history at `98be3004`:
  `git show 98be3004:docs/mockups/session-result-and-hours.html`.
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
- `progress.html`: the Progress tab redesigned, one colour per skill (owner,
  2026-10-26), built and removed once built (CHANGELOG: "Progress is
  redrawn"). It is in git history at `3ceac77`:
  `git show 3ceac77:docs/mockups/progress.html`, with `progress.md`.
- `all-tags.html`: the All tags page (#499), beautified (owner, 2026-10-24),
  built and removed once built (CHANGELOG: "All tags is two lines and a thin
  bar a row"). It is in git history at `3ceac77`:
  `git show 3ceac77:docs/mockups/all-tags.html`, with `all-tags.md`.
