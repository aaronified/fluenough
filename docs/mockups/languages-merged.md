# Languages (merged): self-check, notes and open questions

Companion to `languages-merged.html` (owner, 2026-10-30: "can we merge languages I know with languages i am learning?"; chose "One list, two roles": each language is one row with a role, Learning or Know, and a language can be both). The page holds only the screens and their tweak controls, with what changed outlined in red. The checks and notes are here. Nothing below is decided; open choices are tweak controls where they can be.

Built on the approved Languages I'm learning mockup (owner, 2026-10-27; branch `ccr-63211c8e-c7eice`, `docs/mockups/languages-learning.html`, last commit `fb21731b`). Its list, sheets, script-only sheets, script switches, minutes-a-day stepper and Delete data dialog are kept as they were; the frames that are unchanged say so. Phone 360 dp at 1.4x text (#505), `ColorScheme.fromSeed` of the clay and forest seeds, light and dark, Hindustani and Bengali. Theme, seed, course, scripts in the sheet and highlight are global controls.

## What it merges

Today there are two pages in Settings, Your languages: Languages I know (`SpokenLanguagesPicker`, #53, #490, #551: a search, the chosen languages best known first, top picks, every language by family; a sheet asks whether the script is read, Save or Remove) and Languages I'm learning (`LanguagePickerPage`, #626: deck updates, Learning and Available, a row per course; the sheet holds Minutes a day #485, scripts, Find my level, Delete data, resources #832, size and units). Onboarding has both as two steps.

## What the proposal changes

1. **One list, a line per role.** A row is the language, then a Learning line (the approved one: minutes, scripts being learned, taught from) and/or a Know line (scripts read as ringed glyphs, or a voice icon when the language is only spoken). Role markers are Learning (secondary container) and Know (outlined). Tweak control *Role markers*: words or icons only.
2. **Filter chips** All, Learning, Know with counts, in place of the "Learning · 4" heading. The Know filter hides the deck-update controls (they are about decks).
3. **Add a language** is the last row. It opens a page that is the Languages you know picker (search, top picks, families), with a course badge or "No course yet" on each language. A language is picked, its sheet opens, and the roles are chosen there.
4. **The sheet gets one row**, "I know <language>", with a switch. On, "Scripts I read" lists the scripts as ticks (the old question; none ticked means only spoken). A role marker joins the Beta badge. Where Know is on, the approved "Scripts" heading reads "Scripts to learn". Tweak control *I know row in the sheet*: top or bottom. Everything else in the sheet is the approved one.
5. **A Know-only language** has the sheet of what it has: with a course (Marathi), the approved before-learning sheet plus Learn this language; with none (English), only the Know row and Done.
6. **Removing a role.** Stop knowing is the switch, immediate, with Undo in a snackbar; the row loses its Know line, or leaves the list when it was its only role. Stop learning and Delete data are the approved buttons and touch only Learning; for a language also known, the dialogs say it stays in the list. Delete data never touches Know.
7. **Entries.** Settings, Your languages: two rows become one, "Languages". Onboarding: Languages you know is the same list with its Add content inline, in Know only; What do you want to learn? is the same list in Learning, and a known language shows its Know marker there.
8. **Empty states**: nothing at all, Learning filter empty, Know filter empty.

Collapsed and expanded: the list is the collapsed row; the sheet (approved design) is the expanded state. No inline expansion is drawn.

## Open questions

1. **Page name.** Options: "Languages" (drawn; short, no I-voice, but the section is also called Your languages); "My languages" (friendlier, still close to the section); keeping "Languages I know and learn" (says both, too long at 1.4x). The two old names are gone either way.
2. **Learning role: switch or buttons.** Know is a switch; Learning is the approved bottom buttons, because starting needs a download and script choice and stopping needs a confirm. Option: a second switch "I'm learning it" that opens the same flow (symmetric; the downside: a switch that opens a flow and a dialog is not instant like the Know one).
3. **"Level" for Know.** The brief said Know holds script and level. Today it holds the scripts read and an order (best known first), no level. Options: keep the order, shown as the sort of the Know rows (nothing new); or add a level (Native, Fluent, Basic) to the Know row (the downside: a new field that onboarding must ask and nothing uses yet).
4. **Stop knowing without a confirm.** Drawn immediate with Undo. Option: a dialog, as Stop learning has (the downside: one more tap for something that loses only a script answer).
5. **Order of the list.** Drawn: Learning rows first, then Know-only. Options: A to Z, or best known first for Know rows (matches today's Know page, but mixes with Learning).
6. **Onboarding.** Drawn as two steps over one list. Option: one step with both roles per row (shorter; the downside: the first screen asks a lot of a new learner).
7. **Know for a course's own language.** A learner who learns Bengali and also knows it is allowed (a heritage speaker); the Know marker then also shows in the learning step.
8. **"Remove" on the old Learning card** (Remove deck) is Delete data now, as approved; nothing else changes there.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both seeds and both themes. Text 4.5:1; switches, outlines, rings and icons 3:1. All 184 pairs pass (46 pairs x clay and forest x light and dark): the approved 28, plus the Learning and Know markers, the ringed glyph, the filter chips, the chevron, the Add tile, the snackbar, the empty-state disc and text, the Know switch and the change outline and tag.

Checked in Chromium (Playwright) at 1.4x, light and dark, Hindustani and Bengali: no page errors, no sideways page scroll, no clipped text in a phone (the Hindustani title wraps to two lines, as in the approved page). The Know sheet's ticks and the switch are 48 dp targets. Not checked: other text sizes (the app caps at 1.4x), the high-contrast and pure-black themes, and a real phone.
