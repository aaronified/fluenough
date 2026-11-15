# Mockups

Source of truth: this wiki page.


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


## Repo skills and agents

- [build-deck](https://github.com/aaronified/fluenough/blob/main/.claude/skills/build-deck/SKILL.md): build or extend a deck.
- [flutter-dart-code-review](https://github.com/aaronified/fluenough/blob/main/.claude/skills/flutter-dart-code-review/SKILL.md): a review checklist for Flutter and Dart code, copied from another project; its licence is in [SOURCE.md](https://github.com/aaronified/fluenough/blob/main/.claude/skills/flutter-dart-code-review/SOURCE.md).
- [work-rating](https://github.com/aaronified/fluenough/blob/main/.claude/skills/work-rating/SKILL.md): an opt-in rating of finished work by an independent agent, run only when the owner asks. The agent is [work-rater.md](https://github.com/aaronified/fluenough/blob/main/.claude/agents/work-rater.md).

See also: [Contributing](Contributing) · [Home](Home)
