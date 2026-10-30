# Languages (merged): notes

Mockup: `languages-merged.html`. One interactive page, one phone: tap through it. The page holds only the screens and their controls (theme, colour seed, text size, jump buttons, reset); everything below is here.

Owner's direction (2026-10-30): "know and learning should be based on skills. speak, hear, read, write. the latter two will also be script specific. speak, hear will be dialect specific (the app only teaches one dialect for each language now anyway). use proper dialect names, not random ones. user can tick multiple. in the mockup, no need to show the present or older mockup. just show the new combined one with the features and make it interactive so I can check the screens interactively." This supersedes the earlier merged mockup's questions (roles, filter chips, Know switch).

## The design

- **One list of languages.** Learning languages first, then Know-only ones. A language is in the list while any of its skills is ticked.
- **Four skills per language: Speak, Hear, Read, Write.** Each is, per person, **I know it** or **I'm learning it** (or neither). Speak and Hear carry the language's one taught dialect. Read and Write have one row per script, so Hindustani has Read Devanagari, Read Perso-Arabic (Urdu), Write Devanagari, Write Perso-Arabic (Urdu); Japanese has Kana and Kanji; Mandarin, Simplified and Traditional; Punjabi, Gurmukhi and Shahmukhi.
- **The control.** In the sheet each skill row has two buttons side by side, I know it and I'm learning it. The chosen one fills and shows a tick; tapping it again clears the skill. Both states are written in words, never colour alone. In the list the same states are small chips: outlined with a tick for Know, filled with a cap icon for Learning.
- **Ticking Learning starts the download flow; Know never does.** A dialog names what will be fetched (course words and audio, plus the decks of a script when a Read or Write skill needs them) and its size. Cancel leaves the skill unticked. A progress bar runs in the row and the sheet. A second Learning skill that needs nothing new asks nothing.
- **Learning controls appear only for a language with at least one Learning skill:** minutes a day (the approved stepper, 5 to 60), deck updates (Check now), decks on this phone and their size, taught from, course progress, and the bottom bar Delete data and Stop learning. "Check for deck updates" at the top of the list also appears only then. A Know-only language's sheet has none of these, only Remove.
- **Course availability.** Learning is offered only where decks are written (Beta). For a language whose course is only a path (Coming) or that has none (English) the Learning button is disabled and the sheet says why; Know can still be ticked.
- **Script-only course** (English Braille): no Speak, Hear or dialect, only Read and Write in Braille.

### Screens (all live, reached by the jump buttons or by tapping)

1. **Settings entry.** The two rows of Your languages become one, "Languages", with a line "Learning 2 · Know 1". Other rows are drawn for context and do nothing.
2. **The list.** Mixed states in the sample: Hindustani learning only Read and Write in Perso-Arabic (Urdu) and knowing the rest (Speak, Hear, Devanagari); Bengali learning all four; Marathi Know only; Spanish fresh (add it from Add a language).
3. **The language sheet.** Dialect, then Speak, Hear, Read by script, Write by script, then the learning controls.
4. **Add a language.** A search that filters live (try "urdu"-style names, native names or a family) over languages grouped by family; each row shows Beta, Coming, No course yet or Added. Picking one opens the same sheet as a draft: nothing is saved until "Add <language>", which stays disabled until a skill is ticked. If Learning skills need a download, the dialog comes then. Punjabi shows two scripts with Learning disabled (course coming); Spanish shows a fresh Beta course.
5. **The empty state**, with the Add a language button. Reached by the jump button or by removing every language.
6. **Removing and unticking.**
   - Tap a chosen option again: that one skill is unticked, with Undo in a snackbar.
   - Untick everything and close the sheet: the language leaves the list (Undo). Its decks stay on the phone if it had any.
   - **Stop learning**: every Learning skill becomes unticked, Know skills stay, decks and progress stay (so starting again needs no download). Confirmed in a dialog; Undo after.
   - **Delete data**: type the language name; removes decks and progress, unticks Learning skills, never touches Know skills.
   - **Remove <language>** (Know only): unticks everything, Undo.
7. **Onboarding.** Step 1, "Languages you know": every language's skills as chips (Speak, Hear, Read per script, Write per script), tapping toggles Know; a live search. Step 2, "What do you want to learn?": the same chips toggle Learning; a skill known in step 1 can be ticked again to learn it (a heritage speaker learning the script) and ticking again returns it to Know. Languages without a course are disabled with a reason. Start saves, and downloads begin.

Not drawn: the earlier merged mockup's filter chips, the Know switch and the "Scripts I read" list (the skills replace them), and any present or older frame.

## Dialect and script table

What the page uses. "Stated" means a course file or the docs say it; **to confirm** means the course does not state its dialect and the name is the widely accepted name of the standard variety the course teaches. The owner or a native reviewer confirms each.

| Language | Dialect shown (Speak, Hear) | Scripts (Read, Write) | Source and status |
|---|---|---|---|
| Hindustani | Khari Boli (खड़ी बोली), standard Hindustani | Devanagari; Perso-Arabic (Urdu) | Scripts stated (`hi` language block, CLAUDE.md 2026-10-18). Dialect: the wiki's phonology plan takes Wiktionary's "Hindi, Standard" forms and the course is the shared colloquial vocabulary; the name Khari Boli is not stated: **to confirm** |
| Bengali | Standard Colloquial Bengali (চলিত), Kolkata (Rarhi) | Bengali script | Stated: wiki Plan-Ipa-Revamp (decided 2026-10-30: the Kolkata standard, Wiktionary's Rarh) and Deck-Tools. Rarhi is one of the path's rater regions |
| Marathi | Standard Marathi | Devanagari | Script stated (`mr`, tts mr-IN). Dialect **to confirm** |
| Assamese | Standard Assamese | Assamese script (the language block names it `bengali`) | Dialect **to confirm**; script name **to confirm** (Assamese or Bengali-Assamese) |
| Gujarati | Standard Gujarati | Gujarati script | Script stated. Dialect **to confirm** |
| Punjabi | Majhi (ਮਾਝੀ), the Eastern Punjabi standard | Gurmukhi; Shahmukhi | Dialect stated in `pa-path.yaml` (Majhi-based standard). Gurmukhi stated; Shahmukhi is an open question there (a second set of decks), drawn as Coming and Know only: **to confirm** |
| Maithili | Standard Maithili | Devanagari | Path only. **to confirm** (the traditional Tirhuta script is not drawn) |
| Odia | Standard Odia | Odia script | Path only. **to confirm** |
| Telugu | Standard Telugu | Telugu script | Script stated (`te`, tts te-IN). Dialect **to confirm**; the path's regions (Telangana, Coastal Andhra, Rayalaseema) are rater regions, not the taught one |
| Kannada | Standard Kannada | Kannada script | **to confirm** (dialect) |
| Tamil | Standard Tamil | Tamil script | Path only. **to confirm** |
| Malayalam | Standard Malayalam | Malayalam script | Path only. **to confirm** |
| Spanish | Castilian Spanish (Spain) | Latin | tts es-ES and the decks' θ say Castilian; the wiki's phonology plan leaves "Castilian or Latin American" for the owner: **to confirm** |
| French | Standard French (France) | Latin | Path only, no stated variety. **to confirm** |
| German | Standard German (Germany) | Latin | Stated in `de-path.yaml` ("the standard German of Germany"), which itself says which standard is to confirm with the owner and a native reviewer |
| Japanese | Standard Japanese (標準語), Tokyo | Kana; Kanji | tts ja-JP; the path's Kanto region lists Tokyo. Dialect name **to confirm**. Kana (hiragana and katakana) and Kanji follow the owner's brief and the path's script units; the language block says only `kana` |
| Mandarin Chinese | Putonghua (普通话), as taught in mainland China | Simplified; Traditional | Stated in `zh-path.yaml` (owner, 2026-10-20) |
| Korean | Standard Korean (표준어), Seoul | Hangul | tts ko-KR. Dialect **to confirm** |
| Toki Pona | No dialects: one standard | Latin | Stated in `tok-path.yaml` (no regional dialects). Latin only in the course data; sitelen pona is not a course script |
| Esperanto | No dialects: one standard (Fundamento) | Latin | Stated in `eo-path.yaml` |
| English | none (no course; any variety) | Latin | No course. A Know tick means any variety |
| English Braille | none (script only) | Braille | Script-only course (`qbe`) |

Decks written (Learning offered): Hindustani, Bengali, Marathi, Assamese, Gujarati, Telugu, Kannada, Spanish, Japanese, Mandarin Chinese, Korean, Toki Pona, English Braille. Path only (Coming): Punjabi, Maithili, Odia, Tamil, Malayalam, French, German, Esperanto. This is read from `decks/`; sizes and percentages in the sheet are placeholders.

## Self-check results

**Contrast.** Computed in the page (`window.__contrast`, logged to the console) for both seeds and both themes: 42 pairs x 4 = 168, all pass. Text 4.5:1; the Know chip and option outlines, switches, the progress fill, the stepper icons and the chevron 3:1. Pairs: body, label and hint text on the page and the sheet; section headings; filled, tonal and outlined buttons; the Know chip and the Learning chip; both options chosen and not chosen; script glyph tiles; badges; search; snackbar text and action; empty state; dialogs; Delete; onboarding chips. Disabled controls (Learning where there is no course, onboarding chips of languages without a course) are drawn at 38% and are exempt, as in the app's theme.

**Chromium (Playwright, 1.56).** Opened at desktop width and at 390 px; every jump screen at 1.4x text, light and dark, clay and forest, plus 1x. Looked at the screenshots of: Settings, list, sheets (Hindustani, Marathi, add Spanish, add Punjabi), the download dialog, progress, Stop learning, Delete data (empty and typed), Add a language and its search, adding Japanese, Undo, the empty state, onboarding 1 and 2, in light, dark, and 1x. Clicked through: ticking and unticking, the download flow, Stop learning, Delete data, Remove, Undo, search, add, theme, seed and text size, the minutes stepper. No page errors, no sideways page scroll at 390 px, no clipped text in the phone. Hindi, Hindustani in Urdu, Bengali, and the other scripts are in rows, dialect names and glyph tiles; their rendering depends on the Noto fonts the page loads from Google Fonts, which the test sandbox could not fetch (fallback fonts were used there). Not checked: other text sizes (the app caps at 1.4x), high-contrast and pure-black themes, a real phone, TalkBack.

## Design decisions: options and the main downside

1. **Control for a skill.** Drawn: two buttons, I know it and I'm learning it, tap the chosen one again to clear. Option: a tick that cycles Off, Learning, Know (one control; the downside: the state behind a tap is hidden, and cycling past Learning by mistake would offer a download).
2. **List chips are read-only.** Tapping a row opens the sheet; skills are changed there. Option: tap a chip in the list to cycle it (faster; the downside: easy to start a download by accident, and a 26 dp chip is a small target).
3. **Stop learning** unticks Learning skills and keeps decks. Option: turn them into Know (the downside: the learner may not know the skill, so Know would be a claim they did not make). Option: also delete data (the downside: loses progress on a mis-tap; that is what Delete data is for).
4. **A language with no skills left leaves the list**, with Undo, even if decks remain. Option: keep it in a "Not in use" section with its size until data is deleted (the downside: a third section for a state most learners never reach).
5. **Several Learning skills, one language, one minutes-a-day.** Minutes are per language, as approved. Option: per skill (the downside: four steppers per sheet and a daily total to explain).
6. **Read and Write per script, as rows.** For two scripts the sheet has four script rows (longer sheet at 1.4x). Option: a compact grid of script columns (the downside: tight at 360 dp with 1.4x text).
7. **Dialect is shown, not chosen.** One dialect per language, written above Speak. Option: show it only in the sheet's header badge (the downside: easy to miss that Speak and Hear are tied to it). When a second dialect arrives, this becomes a chooser.
8. **Languages with no course** (English, Coming ones) can be ticked as Know. Option: hide them from the picker until a course exists (the downside: the Languages you know step then cannot record a language the learner speaks).
9. **Onboarding:** two steps over the same chips. Option: one step with both choices per chip (shorter; the downside: the first screen asks a lot of a new learner).
10. **The list has no search**, since it holds the languages the learner uses; search is on Add a language and in onboarding. Option: a search at the top of the list (the downside: dead weight for a list of three to six).
11. **Page name:** "Languages". Option: "My languages" (friendlier; the downside: the Settings section is also called Your languages).
12. **Which names are right**: every **to confirm** row above.
