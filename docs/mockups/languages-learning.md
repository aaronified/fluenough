# Languages I'm learning: self-check, notes and open questions

Companion to `languages-learning.html` (owner, 2026-10-27: a mockup of the Languages I'm learning page and its popups: script-only, language with scripts, before and after learning started, and the script toggle). The page holds only the screens and their tweak controls, with what changed outlined in red. Nothing below is decided; every open choice is a tweak control on the page.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the clay seed (the owner's phone) and the forest seed, light and dark, Hindustani and Bengali. Theme, seed, course, script style and highlight are global controls.

## What the screens are today

`lib/features/downloads/` (the list) and `lib/features/placement/language_sheet.dart` (the sheet). The sheets and the list are drawn from the real strings (`pickerSheet*`, `pickerScript*`, `pickerChangeScripts`).

- **List.** Check for deck updates, last checked, Check automatically, search, "Learning · N". A row is the name, a badge (Beta or Complete), "You: x%", a tick, and for the open row: "Up to date · size", Minutes a day with chips, and the cards-a-day line.
- **Script-only course** (English Braille). Course size, Taught from, Size, Units. No Level, no Scripts.
- **Language, before learning.** Badge, "x% of B1 written", Course line, Written toward B1, Script(s) as text, Learn Hindustani from (chips), Size, Units, and "Learn this language" pinned. The scripts are chosen on the next screen ("Step 1 of 2 · Script", checkboxes), then Where to start.
- **Language, after learning started.** Level (Find my level), Placed words, Scripts as text with "Change scripts" (which opens the checkbox step), Course, and "Stop learning" pinned.

## What the proposal changes

1. **Scripts are switches in the sheet**, before and after learning. Before: a "Scripts to learn · pick any" section with a switch each, so the checkbox step after Learn this language is dropped. After: each script's row has a switch, "Not learning this script" or "learning" with its deck progress bar, and "Change scripts" is gone. The "Devanagari, Perso-Arabic (2/2)" summary stays. With none on, the sheet says it is Latin letters only.
2. **A script-only course's button says "Learn this script"** in place of "Learn this language".
3. Everything else is as built.

## Open questions

1. **Switches or the step?** Switches remove a screen and a button and apply at once (the downside: stopping a script is one tap, with no confirm; a dialog could confirm it, as Stop learning does). The step keeps today's flow. Tweak control: *Scripts in the sheet*.
2. **Turning the last script off** in a learned course: allow it (the sheet says Latin letters only, as the page draws), or keep at least one on?
3. **Turning a script off after learning.** Progress is kept as for Stop learning (assumed); confirm.
4. **Before learning, which script is on by default?** The page starts with the course's own script on and the other off. Option: all on.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both seeds and both themes. Text 4.5:1, switches, bars and outlines 3:1. All 60 pairs pass (15 pairs x clay and forest x light and dark). Hindi and Bengali glyphs and the Perso-Arabic title show at 1.4x without clipping; the title wraps to two lines. The switch is a 52 x 32 control in a 56 x 48 target.
