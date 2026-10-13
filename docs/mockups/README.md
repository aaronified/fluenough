# Mockups

## Current and approved

Each is the spec for its screen. Don't rewrite one without the owner's
approval.

- `languages-you-know.html`: Languages you know, with the bottom-sheet
  script question (#490, `docs/plans/languages-you-know.md`).
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

## Awaiting approval

Drawn to the approved shape, with what they decide themselves marked
Proposed. Not spec until the owner approves.

- `set-cards.html`: a set card in a lesson (#515): the whole closed group
  shown once, before its members, the known ones marked; then only the new
  members taught and asked. Hindi and Bengali, at 1x and 1.4x.

## Older: to be adapted (owner, 2026-10-12)

Bring these up to the current app and plans, in the style of
`languages-you-know.html`: real theme colours, light and dark, 1.4x text (the app's cap, #505), a
contrast self-check, and Hindi or Bengali examples. Until then, they are
history, not spec.

- `reviewer-mode.html` and `drafts/`: reviewer mode. It needs the owner's
  2026-10-09 notes (`drafts/README.md`, also in
  `docs/plans/reviewing-scope.md`), plus #476, #477 and #471.

Order: after the current mockups (#486 and #227) and the Settings mockup.

## Deleted (owner, 2026-10-12)

These were fully built, so their mockups were deleted. Code comments still
name them. They are in git at 19d200b
(`git show 19d200b:docs/mockups/<name>.html`):

- `adapted-to-you.html`, with its earlier versions `ambient.html`,
  `moment.html` and `story.html`: "Adjusted to you" (ADR-0035).
- `language-picker.html`: the language picker (#443).
