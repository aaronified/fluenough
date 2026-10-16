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

## Awaiting approval

Built 2026-10-16 at the owner's request ("Both", "Yes, build them now").
They are not spec until the owner approves them. Everything they mark
Proposed is listed in their decisions tables.

- `deck-search.html`: the Decks tab's one search for decks, units and
  words, in place of the filter row (#527; owner, 2026-10-16: "I just want
  people to quickly find stuff. The filters can be replaced by a fts5
  search with typo tolerance and the kind can be a chip."). It finds deck
  and unit names and every card's word, reading and meaning, forgives
  typos, and groups the results, decks and units first, then words. Each
  result has a kind chip (Words, Grammar, Script, Reading) that narrows
  the search to that kind ("Both"), with a chip and a ✕ to go back.
  Sentence decks have no chip and show only while no kind is chosen. It
  draws the owner's three cases with a typo each: "travl" (the coming
  Travel unit), "numbrs" (the numbers units) and "you" and "yuo" (the
  words for "you" in Hindi and Bengali, under their set cards), then
  nothing found, nothing of a kind, and 1.4x. A note shows how FTS5 does
  it (a trigram index, then edit distance). It replaces `deck-filter.html`.
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
  screens."). Drawn with 1, 2, 4 and 6 languages, before, during
  and after a swipe, the menu, Today, Decks (with the proposals' search
  bar, unchanged) and Progress, light, dark and pure black, 1.4x and
  TalkBack. It supersedes `language-swipe.html` and
  `language-bar-proposals.html`.
- `language-swipe.html`: superseded by `language-bar.html`. A sideways swipe on the top row of Today, Decks
  and Progress changes the language shown, and the row's marks show the
  active one (#528). It shows before, during and after a swipe, with two
  and with four languages, at 1.4x, and with the menu and TalkBack as the
  tap and screen-reader alternatives.
- `language-bar-proposals.html`: superseded by `language-bar.html` (the
  owner chose D's folded bar, 2026-10-16). Four proposals (A to D) for a top bar on
  Today, Decks and Progress that holds only the language chips and the
  bug report button (owner, 2026-10-16: "Language chips is better. I was
  thinking a top bar only for the language and the debug button. Do 3-4
  different proposals on this first."). A is a scrolling chip row, B
  segments with More, C the shown language named and the others as
  glyphs, and D every chip at the top, folding to one line on scroll.
  Each is drawn with 1, 2, 4 and 6 languages, a swipe before, during and
  after, all three screens, 1.4x and TalkBack. Section 0 shows where the
  rest of today's headers goes, and a measured comparison table ends it.
  All Proposed: the owner chooses one.

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
