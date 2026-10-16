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
- `set-cards.html`: a set card in a lesson (#515): the whole closed group
  shown once, before its members, the known ones marked; then only the new
  members taught and asked. Hindi and Bengali, at 1x and 1.4x. Approved by the owner, 2026-10-13.
  Approved 2026-10-16: Telugu verb forms both ways, back to back, in
  cards of at most four (the nine forms of a verb, the request last, in
  three parts of 3), each new form straight to its question, with a Full
  list button on split sets and on an answered question, and long forms
  breaking between syllables (owner, 2026-10-16, #515).
- `language-bar.html`: the language bar the owner chose for Today, Decks
  and Progress (#528; owner, 2026-10-16: "The folded top bar. No dropdown.
  Instead of dots, use the glyphs (not filled icons, just the glyphs, alpha
  passed). Show mockup. Searchbar looked fine"). Always folded, 56 dp: the
  shown language as its chip, glyph and name, with no arrow; every other
  choice as its bare glyph at 64% alpha (4.5:1 or more everywhere); the bug
  report button at the end. A sideways swipe on the bar changes the
  language, and a tap opens the menu of every language with its chip
  (owner, 2026-10-16). All is a button on Progress only, fixed just
  before the bug button, and its slot is kept empty on Today and Decks so
  the bar never shifts between the three screens (owner, 2026-10-16:
  "Only on progress we need an all button.fix it to the right (near
  debug) so that the top bar doesn't shift when changing between the 3
  screens."). Where the row does not fit, its ends fade out over 16 dp,
  only on an end with more beyond it, and the row scrolls to keep the
  chip clear of the fade (owner, 2026-10-16: "The language bar needs to
  be edgemasked still"). Drawn with 1, 2, 4, 6 and 8 languages, before, during
  and after a swipe, the menu, Today, Decks (with the proposals' search
  bar, unchanged) and Progress, light, dark and pure black, 1.4x and
  TalkBack. Approved by the owner, 2026-10-16 ("Approve"); it replaces the
  earlier swipe mockup and the four bar proposals (in git history).

## Awaiting approval

Built 2026-10-16 at the owner's request ("Both", "Yes, build them now").
They are not spec until the owner approves them. Everything they mark
Proposed is listed in their decisions tables.

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
## Older: to be adapted (owner, 2026-10-12)

Bring these up to the current app and plans, in the style of
`languages-you-know.html`: real theme colours, light and dark, 1.4x text (the app's cap, #505), a
contrast self-check, and Hindi or Bengali examples. Until then, they are
history, not spec.

- `reviewer-mode.html` and `drafts/reviewer-mode-screens.js`: reviewer
  mode. It needs the owner's 2026-10-09 notes (in
  `docs/plans/reviewing-scope.md`), plus #476, #477 and #471.

Order: after the current mockups (#486 and #227) and the Settings mockup.

## Deleted (owner, 2026-10-12)

These were fully built, so their mockups were deleted. Code comments still
name them. They are in git at 19d200b
(`git show 19d200b:docs/mockups/<name>.html`):

- `adapted-to-you.html`, with its earlier versions `ambient.html`,
  `moment.html` and `story.html`: "Adjusted to you" (ADR-0035).
- `language-picker.html`: the language picker (#443).
