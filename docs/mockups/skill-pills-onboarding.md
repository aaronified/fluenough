# Skill pills and the first launch: self-check, notes and open questions

Companion to `skill-pills-onboarding.html` (owner, 2026-11-01). The page holds only the screens and their tweak controls, with what changed outlined in red. Revised 2026-11-01 for the owner's answers: icons only on the pills, tooltips, plain toasts, and the Decks path screen. The checks and notes are here. Nothing below is decided except what the owner answered (marked).

Owner's words, 2026-11-01:

- Pills: "The pill transitions are not very clear. On read it is a double tick, then on write, it is a double tick plus a keyboard! Same confusion on spoken. There needs to be 3 things, we already have skill icons for read write say hear. So use them! Add the double tick as well when it is verified via placement as well. For the combined skill, there is no need for an icon at all! Since there will always be a pill. For leave, instead of -, write NA or something, to make it short and clear. For each level, use a different tint of the same colour. Show me a mockup, and then build exactly like that."
- Onboarding: "During onboarding, show the language screen and explain the options, and then let the users choose what they know and what they want to learn."
- Answers to the pills (2026-11-01): "variant B (use icons, not text)", then "Icons only. Toast explains". Answer to the Decks path: chose C (a section for the skipped script) and D (a Your script pill); not dimmed steps, not reordering.
- Answers to the open points: the English translation line only under the question, own script alone on every answer line; the Perso-Arabic option drafted in Perso-Arabic script and shown with the existing "unchecked" bug icon until an Urdu speaker verifies it; "I can only speak X" in English only; toasts in plain words, without the skill names.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Hindustani and Bengali. Theme, course, highlight and every choice below are controls on the page.

## What the screens are today

`lib/features/languages/skill_widgets.dart` (`SkillBadge`, `markIcon`, `markExtraIcon`), `language_skills_sheet.dart`, `languages_page.dart`. A Spoken pill and one pill per script cycle Leave, Learn, Know, Know both. Today's Know is a tick, Know both is a tick plus the Write or Speak icon, level found is a double tick that replaces both, Leave is a dashed minus, Learn is the cap with a primary border. So "Read" at level found (two ticks) looks like "Read and Write" without it (tick and keyboard), the confusion the owner names.

## What the proposal changes (revised 2026-11-01, after the owner's answers)

1. **Icons only, no word on any pill** (owner: "variant B (use icons, not text)", then "Icons only. Toast explains"). The words variant is removed. The tooltip and the toast carry the words.
2. **Single skill:** its own icon (eye, keyboard, microphone, ear, raised hand for Gestures) and the mark. **Combined pills show only the icons of the levels reached:** Script is the eye (Read) or the eye and keyboard (Read and Write); Spoken is the ear (Hear) or the ear and microphone (Hear and Say). Learn shows the cap alone, on a combined pill, inside a ring (a single skill shows its icon and the cap).
3. **Marks:** cap Learn, one tick Know, two ticks Know checked by placement.
4. **A different tint of the same colour per level** (Learn, Know, Know with both), three steps of the skill's own colour, as before. The middle step is now placed so the two steps are equal in luminance (before, light was 2.13 and 3.39 :1). The ring on Learn, the icon count and the tick count carry the level in addition to the tint.
5. **Not learning** is a dashed outline with either the text `NA` or a block icon. Tweak "Not learning shows". **Recommended: the block icon.** `NA` is the only word on any pill, clashes with "icons only" and needs a translation per app language (#46); the block icon needs none, and the tooltip reads "Not learning". Choose `NA` if you want the short word you first asked for.
6. **Tooltip on every pill** (hover, keyboard focus, touch and hold), the exact wording below. Each pill's accessible name is the row's name and the tooltip ("Spoken: Listening").
7. **The list row** still names each combined pill in text ("Spoken", "Devanagari"): the row is not a pill. The key under the filters is redrawn with icons.
8. **Onboarding** keeps the explanation screen, now saying what the icons are and that a touch and hold names a pill, then the shared list, the draft skills sheet and the Know sheet, unchanged.
9. **New screen 4, the Decks tab for a learner of one script** (see below).

## Tooltip wording (exact)

Plain words, no invented skill names. "checked" is added when the level was found by placement.

| Pill | State | Tooltip |
|---|---|---|
| any | not learning | Not learning |
| Spoken (combined) | Learn | Learning |
| Spoken | Hear | Listening |
| Spoken | Hear and Say | Listening and speaking |
| Spoken | Hear, checked | Listening, checked |
| Spoken | Hear and Say, checked | Listening and speaking, checked |
| Script (combined) | Learn | Learning |
| Script | Read | Reading |
| Script | Read and Write | Reading and writing |
| Script | Read, checked | Reading, checked |
| Script | Read and Write, checked | Reading and writing, checked |
| Read (single) | Learn / Know / checked | Learning to read / Reading / Reading, checked |
| Write | Learn / Know / checked | Learning to write / Writing / Writing, checked |
| Say | Learn / Know / checked | Learning to speak / Speaking / Speaking, checked |
| Hear | Learn / Know / checked | Learning to listen / Listening / Listening, checked |
| Gestures | Learn / Know / checked | Learning to sign / Signing / Signing, checked |

A combined pill's Learn tooltip is only "Learning" because the row beside it names the pill (Spoken, Devanagari). Say if you want "Learning to speak and listen" there.

## Toasts (the wording of PR #975)

Shape: "{language}: you’re learning {skill}", "{language}: you already know {skill}", "{language}: not learning {skill} now". Shown 3.5 s after a pill change in the sheets.

| Pill | Change | Toast |
|---|---|---|
| Spoken | to Learn | Hindustani: you’re learning speaking and listening |
| Spoken | to Hear | Hindustani: you already know listening |
| Spoken | to Hear and Say | Hindustani: you already know speaking and listening |
| Spoken | to not learning | Hindustani: not learning speaking and listening now |
| A script | to Learn | Hindustani: you’re learning reading and writing Devanagari |
| A script | to Read | Hindustani: you already know reading Devanagari |
| A script | to Read and Write | Hindustani: you already know reading and writing Devanagari |
| A script | to not learning | Hindustani: not learning reading and writing Devanagari now |
| Gestures | to Learn | Indian Sign Language: you’re learning sign language |
| Gestures | to Know | Indian Sign Language: you already know sign language |
| Gestures | to not learning | Indian Sign Language: not learning sign language now |

## Screen 4: the Decks tab for a learner of one script (new)

Problem (owner's screenshot): Hindustani with only Perso-Arabic chosen shows the same path as for everyone, ending in "Perso-Arabic letters" and "Perso-Arabic vowels and marks", and nothing says what was skipped; the 7 Devanagari script decks (125 cards) sit at the bottom under the generic "Other decks" with a Start or Not done badge.

Chosen (owner, 2026-11-01): **C** a titled section for the skipped script's decks and **D** a "Your script" pill on the first unit of the learner's script. Not chosen, not drawn: dimmed steps on the path, reordering script units.

- **C:** the section replaces "Other decks" for those decks. Title "Devanagari · not in your scripts", under it "7 decks · 125 cards" and the script's own name (देवनागरी), one line ("You learn Hindustani in the Perso-Arabic script, so these decks are not on your path. You can still open any of them.") and an **Add it** button that opens the Languages page (the Hindustani sheet, where the Devanagari pill is). Tweak "Skipped script decks": listed under the box, or folded behind the chevron. Folded keeps the path short; I suggest folded for a long list.
- **D:** a small "Your script" pill (tertiary container) under the title of the first unit of the learner's script, "Perso-Arabic letters". Only on that first unit.
- Examples: Hindustani with Perso-Arabic only (Hindi example), and a Bengali speaker learning Hindustani in Devanagari only (Bengali example: the section names Perso-Arabic, the pill sits on "Devanagari letters"). Course control switches them.
- Out of scope, as the owner said: 337 cards have no Perso-Arabic spelling and stay shown in Devanagari. That is deck work.
- Placeholders: the deck names, their order and the Bengali example's names and counts are mine, drawn to show the layout; the real ones come from the deck index. Counts for the Perso-Arabic section are not known and are left out; the 37 and 38 letters are from the owner's screenshot.
- The path is drawn as the app draws it (zigzag nodes, solid line behind, dotted ahead; unit cards from `path_view.dart`), shortened to the last done unit and the script units.

## Variants (tweak controls)

- **Not learning shows:** the block icon (recommended, default) or the text NA.
- **List row chips:** combined pills with a text name, or one chip per skill with its icon.
- **English line on the Know sheet:** only under the question (the owner's answer, default), under every line, or none.
- **Perso-Arabic option:** in Perso-Arabic script (default), or in Devanagari as built.
- **Only speak:** English only (default), or with an own-script form.
- **Skipped script decks (screen 4):** listed or folded.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes, Hindustani and Bengali. Text, icons and ticks on a tint 4.5:1 (the strictest bar, as the tint carries icons and ticks); outlines and the ring 3:1. 43 pairs checked per theme, none fail.

| Theme | Pair | Ratio | Needs |
|---|---|---|---|
| light | body text on page | 16.33 :1 | 4.5 :1 |
| light | secondary text and NA text on page | 8.9 :1 | 4.5 :1 |
| light | icons and ticks on the tints, lowest of 15 (Gestures Know) to highest | 4.92 to 13.32 :1 | 4.5 :1 |
| light | Learn ring on its own fill | 7.22 to 7.24 :1 | 3 :1 |
| light | Learn ring on the sheet | 8.42 to 8.46 :1 | 3 :1 |
| light | NA text, dashed outline and block icon on page | 8.9 / 4.28 / 4.28 :1 | 4.5 / 3 / 3 :1 |
| light | Your script pill text on its tint | 13.29 :1 | 4.5 :1 |
| light | Add it (outline button text) on the section | 5.85 :1 | 4.5 :1 |
| light | tooltip text on its bubble | 16.33 :1 | 4.5 :1 |
| dark | body text on page | 14.33 :1 | 4.5 :1 |
| dark | secondary text and NA text on page | 10.88 :1 | 4.5 :1 |
| dark | icons and ticks on the tints, lowest to highest | 5.25 to 12.37 :1 | 4.5 :1 |
| dark | Learn ring on its own fill | 5.46 to 5.51 :1 | 3 :1 |
| dark | Learn ring on the sheet | 10.02 to 10.09 :1 | 3 :1 |
| dark | NA text, dashed outline and block icon on page | 10.88 / 5.84 / 5.84 :1 | 4.5 / 3 / 3 :1 |
| dark | Your script pill text on its tint | 7.17 :1 | 4.5 :1 |
| dark | Add it (outline button text) on the section | 10.05 :1 | 4.5 :1 |
| dark | tooltip text on its bubble | 14.33 :1 | 4.5 :1 |

**Telling the levels apart, the number the owner asked for.** Tint steps (luminance contrast between Learn, Know and Know-with-both, information only): light 2.66 to 2.72 :1 per step (before: 2.13 and 3.39); dark 2.32 to 2.35 :1 per step (before: 2.36 and 2.31). I made the steps equal, which fixed light's lopsided pair, but dark cannot go much higher: its two ends are the container and the high-contrast container of `ModeColors`, and about 5.3:1 over two steps is all they hold. So the tint is not trusted alone: Learn has a ring (a 2 px inset ring in the strong tint, 5.5 :1 or more against its fill) and the cap; Know has no ring, a tick, and one icon; Know with both has two icons; checked has two ticks. Four independent cues, of which the tint is the weakest. Pill text colour is the mode's own on-colour where it reaches 4.5:1, else white or black. The Your script pill (`tertiaryContainer`, approximated: light `#bdeaf6` on `#001f26`, dark `#1f4d58` on `#b9eaf9`) must be checked against the app's real scheme.

## Behaviour checks (Chromium, Playwright)

- Loaded at 1300 px wide, light and dark colour schemes, Hindustani and Bengali (4 runs), with the new Decks screen and the tooltips: no page errors, no console errors, no horizontal page scroll. The tooltip bubble was hovered in Chromium and reads as in the table above; a toast was triggered and read as in the toast table.
- 1.4x overflow check: every element of every phone was measured against the phone's edges; none leaves it sideways in any of the 4 runs (the filter chip row scrolls sideways by design and is excluded). Vertical content scrolls inside the phone.
- Pills in the sheets were tapped in a browser run of the build: they cycle and the list follows. Not run: every control combination, the other text sizes (the app caps at 1.4x), high contrast, pure black, a real phone.
- Touch and hold is drawn as the right-click (context menu) in this page; hover and keyboard focus are real. Fonts from Google Fonts (Roboto, Noto Sans Devanagari, Noto Sans Bengali, Noto Naskh Arabic); offline, the system fallback is used. The Urdu line is set in Naskh, not Nastaliq.

## Assumptions

- Icons are Material's outlined set, as the app uses them (`skill_visuals.dart`, `skill_widgets.dart`).
- The tint mixes are in sRGB, approximating HCT tones; build them from tone steps of each hue (for example 90, 70, 40 in light) and recheck the ratios.
- `primaryContainer` of the forest seed is approximated (light `#b0f0c6`, dark `#0f5132`); check it against the app's `ColorScheme`.
- Level found keeps its level's tint. A tweak that darkens it one step more was not drawn.
- Sign languages: Gestures cycles NA, Know, as in the wiki ("Learn is offered when a course exists"). Learn is drawn in the table only.
- Block icon: Material's `block`, outlined, as the app's other icons.
- Hindustani sample state: Spoken Hear + Say with level found, Devanagari Read, Perso-Arabic Learn.
- The Know sheet's speak-only own-script lines ("मुझे हिन्दुस्तानी सिर्फ़ बोलनी आती है", "আমি শুধু বাংলা বলতে পারি") are my drafts for the optional variant, not the default, for a speaker to write.

## Open questions

1. **NA or the block icon?** I recommend the block icon (icons only, no translation). Your answer fixes the default.
2. **Learn tooltip on a combined pill** is "Learning" (the row names it). Or "Learning to speak and listen" and "Learning to read and write"?
3. **Skipped script section: listed or folded?** Listed shows every deck; folded keeps the path short. The page defaults to listed.
4. **"Add it" target:** the Languages page (as you said). I drew it opening the language's skills sheet, where the script's pill is. Or the Languages page list only?
5. **Does the Know sheet stay in the new flow?** Options: (a) keep it as the first question when a language is added (screen 4 of the first launch), with its in-language text; (b) drop it and let the draft skills sheet do the job. The downside of (b) is that a learner who reads only that language loses the in-language question.
6. **Does onboarding need at least one Learn?** English is fixed Know, so nothing blocks Next today. Options: allow Skip, or ask for one.
7. **Perso-Arabic line.** The Urdu wording is a draft by us, unverified until an Urdu speaker checks it; the sheet's bug icon is the existing "unchecked" one. Nastaliq rather than Naskh in the app needs a font decision.
8. **List row, combined or per skill?** Per skill shows every icon but takes up to six chips for Hindustani; combined shows the pill with a text name. The page offers both.
