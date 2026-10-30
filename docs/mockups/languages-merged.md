# Languages (merged): notes

Mockup: `languages-merged.html`. One interactive page, one phone: tap through it. The page holds only the screens and their controls (theme, colour seed, text size, jump buttons, "Simulate: the app opens again", reset); everything below is here.

Owner's direction (2026-10-30): "know and learning should be based on skills. speak, hear, read, write. the latter two will also be script specific. speak, hear will be dialect specific (the app only teaches one dialect for each language now anyway). use proper dialect names, not random ones. user can tick multiple." Answers to the first mockup's questions (2026-10-30, issue #907) are built in: a cycling tick with three states, read-only icon chips, no separate Stop learning, decks removed at the next app open, minutes a day per language, one onboarding step, and a check before a known skill can be reviewed.

## What changed (round 4, owner's orders and answers, 2026-10-30)

This round supersedes the earlier "Check to review" quiz, the double tick for "checked", the sheet's Deck updates and Decks on this phone blocks, and the info panel's Find my level and Placed words; where the older sections below still mention them, this section wins.

1. **Find my level and Placed words** are rows on the sheet's first screen (language with a course, not in the add draft). The first reads "Find my level" until a level is found, then "Fit my level".
2. **List filter pills**: one edge-masked row (fades at both edges), side scroll, order Learning, Know, Speak, Hear, Read, Write. One pill at a time; tap again to clear.
3. **Space** between the Beta badge row and the A1 path.
4. **Scripts**: one row per script with two logo-only pills, Read (eye) and Write (keyboard); Speak and hear is one row with its two pills. Tap cycles Leave, Know, Learn with the state mark as on the list chips. Every change on the sheet shows a toast, such as "Hindustani (Devanagari): Read set to Learn".
5. **Top-right of the sheet**: update check, i, cross. The check covers this language's decks only, updates "Last update checked" in the i panel and toasts the result. Deck size ("Decks on this phone") and the last update check moved into the i panel; "Units" is "Units built".
6. **Check button.** A skill changed TO Learn leaves the bottom button as "Check" (also in the add draft, before "Add"). Speak or Hear: a sound test; Read or Write: a script-visible check. One test per language for sound, one per script. Changing away from Learn needs no check; changing to Learn again repeats it. Tweak controls: "Sound test: Passes/Fails", "Script on this phone: Visible/Not visible". On a failure the dialog offers Test again or Close; the skill stays Learn, a toast says what failed and how to fix it (install a voice or a font), and the button stays "Check" for a retry. Onboarding runs no check (not drawn).
7. **Level found, and the ticks (owner's answers).** One level per language covers all four skills; one "Fit my level" step checks them. Double tick = Know and the level covers that skill. Single tick = Know marked by the user, or a partial level that does not cover it; with Review on it shows "Fit your level to be able to review". The "Found level" tweak control (None, Partial, Complete) sets what the app data holds and what Fit my level finds; ticks follow it. Complete covers Speak, Hear, Read and Write; Partial covers Speak and Read only (mock). Review decks need Read and Write covered. Delete data now clears the level. The Review switch stays (default off); with it off the fit-your-level line is hidden.

### Round 4 assumptions (every ambiguous point)

- Level found "directly": a language whose level is in the app data does not get Know set for it; its Know skills show the double tick and no fit-your-level line. Add Spanish shows this.
- The level survives a language returning to the pool; only Delete data now clears it.
- Filter pills beyond Learning are my guess at "the other filters in the normal order": Know, then the four skills in their usual order. Filters on Speak/Hear/Read/Write match any non-Leave state.
- Toast wording uses the language name, plus the script name when the language has several scripts ("Hindustani (Devanagari)"), not "Hindi".
- Minutes-a-day steps, review deck on/off, fit level and update check also toast ("every change"); a language returned to the pool keeps its Undo snackbar.
- Speak and Hear share one sound test; Read and Write of one script share one visibility check; a failure stops the queue.
- Find my level opens nothing real here: it sets the level from the tweak control and toasts. Placed words only toasts. Neither shows in the add draft.
- Find my level and Placed words show for every language with a course, learning or not, since Know needs the level to review.
- The update-check icon shows only when decks are on the phone or a skill is Learn.
- Read and Write pills have no text, so the row header is the script name and each pill has a tooltip and an accessible label.
- Download progress for the full decks is a bar under the badges; the Learning block keeps only minutes a day.

### Round 4 self-check

**Contrast.** `window.__contrast`: 87 pairs x 4 (two seeds, light and dark) = 348, **0 failing**. New pairs: filter pills (text, outline, selected), the three sheet icons, check result text and icons, sound bars, script sample outline, toast, Find my level title and hint. Chromium (Playwright) at 900 px and 420 px: no sideways scroll, no page errors; screenshots of the list, Hindustani, Marathi, the i panel, Check, sound pass and fail, script failure, toast and Add Maithili in light and dark. Fonts could not load in the sandbox.

## What changed (round 3, owner's orders, 2026-10-30)

1. **Skill icons and colours from the app.** Speak (mic), Hear (ear), Read (eye) and Write (keyboard) use `Skill.speaking`, `listening`, `recognition` and `production` from `lib/ui/skill_visuals.dart`, with their fixed `ModeColors` (green, purple, blue, orange; container and on-container). They colour the row tile, the pill and the list chips. A Learn skill has a 2 px accent (primary) border drawn inset, so the pill's size does not change; Know is a tick (double when checked) in the skill's ink; Leave is dashed.
2. **No language is all Leave.** Setting the last non-Leave skill to Leave (or Delete data now leaving none) returns the language to the pool: it leaves the list, with a snackbar and Undo, and Add a language finds it again. The Leaving section and the Gujarati sample are gone.
3. **Know, not yet checked, Review on.** The bar says "Done and Check" (done, then the check runs, one unchecked skill after another). The delete button is a bare red bin, no outline, no label, 48 px wide in place of 67 px. The skill row says "Reviewing decks needs this skill verified"; a script's other row says "Reviewing decks in this script needs this skill verified".
4. **Details behind a plain "i"** left of the cross: badge, % of B1, You, the A1/A2/B1/Culture path, dialect, Find my level and Placed words (learning), scripts with decks, progress and "Also in", Taught from, Size, Units, Words. Course and Taught from left the sheet's body, nothing is lost.
5. "Dialect" is now "Dialect taught in the app".
6. **Beta badge with the A1 path** directly under it; "4/6 skills known" in place of "4 known".
7. **Auto Know for known scripts.** Read and Write start as Know when the same script's Read or Write is Know in another language (try Add Maithili); still unchecked there, with the line "Known from Hindustani. Checked separately for Maithili." Onboarding does the same, live.
8. **Minutes a day** is a stepper (minus, "15 min a day", plus), 5 to 60 in steps of 5, default 15, the button disabled at each end; in the sheet and in onboarding (for a language with a Learn skill).

### Assumptions

- **A1 path place:** full width on its own line under the Beta badge row (the 4-segment A1, A2, B1, Culture line of the earlier mockup; labels in the muted text colour). Also in the i panel.
- **"6 skills":** Speak, Hear, plus Read and Write per script (Hindustani 6, Bengali 4, Marathi 4, script-only Braille 2). Only Know counts as known; "2 learning" stays before it.
- **Colours:** Read is `recognition` (eye), Write `production` (keyboard), not `Skill.reading` (book, yellow), as Progress does. Pill fill is the skill container for Know and Learn.
- The bare bin applies in every state of the bar, not only with "Done and Check".
- A language returned to the pool has its decks removed at the next app open.
- Auto-Know is per skill (Read from Read, Write from Write) and matches by script id; Assamese and Bengali script count as different scripts.
- The script-variant subtext shows on a script row that is not Know when another script's same skill is Know and Review is on.

## Earlier round (owner's orders, 2026-10-30)

- **One pill per skill row** (Speak, Hear, Read and Write per script), in the sheet and in onboarding. Tap it: Leave, Know, Learn. No other control on a skill row. The sheet's key of the three states is gone (the pill says the word).
- **One Know look everywhere.** Know is the tertiary-container colour with a tick, and a double tick once checked, on every pill and list chip, checked or not. Learn is the filled primary colour with the cap; Leave is dashed with a minus.
- **The "Not checked" and "Checked: review cards on" lines are gone.** A Know skill not yet checked shows a full-width "Check to review" button under its row; after the check the pill shows the double tick.
- **Review decks are rows of the same kind** in the sheet (script glyph, name, one pill: Review or Leave; disabled with a one-line reason until Read and Write are known and checked). The download button is gone: tapping the pill downloads, tapping again removes.
- **Review switch in Settings, default off.** Checks and review decks appear only when it is on. Also a "Review (Settings)" tweak control at the top of the page, kept in step with the switch. The Marathi, check and Assamese jump buttons turn it on.
- **Tighter rhythm**: smaller row, header, section and bottom-bar padding, 36 px tiles, smaller gaps in the learning blocks; touch targets stay at 48 px.

## The design

- **One list of languages**, in three sections: Learning (any skill is Learn), Know (skills are Know and Leave only), Leaving (every skill is Leave but decks are still on the phone).
- **Four skills per language: Speak, Hear, Read, Write.** Speak and Hear carry the language's one taught dialect. Read and Write have one row per script (Hindustani: Devanagari and Perso-Arabic (Urdu); Japanese: Kana and Kanji; Mandarin: Simplified and Traditional; Punjabi: Gurmukhi and Shahmukhi).
- **Three states per skill: Know, Learn, Leave.** One pill per skill, showing the state in words and an icon; each tap cycles to the next: Leave, Know, Learn, Leave. Where there are no decks yet (course coming or none) Learn is skipped. Know is tinted with a tick (double tick when checked), Learn is filled, Leave is dashed; always icon and word, never colour alone.
- **Know is instant.** No check, no download (owner: "rely on the user to know what they know").
- **Learn means the full decks.** One Learn skill, in any script, downloads the language's full decks (course words and audio plus every script's decks); a dialog names the size first. Cancel leaves the skill as it was. Minutes a day is one stepper per language, shown when any skill is Learn.
- **Review needs Review on and a check.** With Review off in Settings (default) nothing about checks is shown. With it on, a Know skill that is not checked shows a full-width Check to review button (a short mock: three questions, two of three pass). Passing turns the pill to a double tick; failing leaves it Know. Changing a skill away from Know clears its check.
- **Review decks (Review on, Know only languages).** A section of rows in the sheet, one per script, each a pill (Review or Leave). Offered only where Read and Write of that script are both Know and both checked; otherwise the row is disabled with the reason. A language with a Learn skill already holds the full decks, so the section is not shown.
- **Leave and the next app open.** Decks that no skill needs are removed the next time the app opens, not at once. What each state needs: a Learn skill keeps the full decks; with none, only the review decks of scripts that are Know and Checked (Read and Write) stay; with nothing left, no decks. A row or sheet that has decks to lose says so: "Its decks will be removed the next time the app opens." (or "cut down to review decks"). Setting a skill back before the app opens keeps the decks. A language with every skill Leave and no decks leaves the list at once. The page's "Simulate: the app opens again" button runs the next-open clean-up.
- **List rows are read-only and icons only.** Four skill icons (mic, ear, book, pencil), one per script for Read and Write when there are several, each with a small state mark in the same colours as the pills: tick (Know), double tick (Know, checked), cap (Learn), minus (Leave). A key above the list explains them; each chip has a tooltip and an accessible label. Tapping a row opens the sheet, where the pills change the states.
- **Delete data now** (bin, with typed confirmation) is the only immediate removal. It stays for someone who cannot wait for the next app open; it turns Learn skills to Leave and keeps Know. There is no Stop learning and no Remove button (all three states Leave is the removal).
- **Script-only course** (English Braille): no Speak, Hear or dialect, only Read and Write in Braille.

### Screens (all live, reached by the jump buttons or by tapping)

1. **Settings entry.** A Review switch (default off) and one row, "Languages" (subtext: only the number of languages being learnt, such as "2 languages learning" or "1 language learning", "Not learning any language" at zero; a language counts if at least one skill is Learn; it updates as skills are cycled), and a card, "What each state does", that explains Learn, Know and Leave, review and the next-open removal.
2. **The list.** Read-only skill chips, Know in the pill's colour. Sample: Hindustani learning Perso-Arabic (Urdu) Read and Write and knowing the rest (all checked); Bengali learning all four; Marathi Know with Write not checked; Assamese Know with Read and Write checked and a review deck on the phone; Gujarati all Leave with its decks still on the phone (the Leaving section and notice).
3. **The language sheet.** Dialect, Speak, Hear, Read by script, Write by script (one pill each, plus Check to review under an unchecked Know when Review is on), then Review decks (Review on, Know-only languages) or Learning controls (minutes a day, deck updates, decks on this phone, taught from, course). The bottom bar has Delete data now and Done.
4. **Check to review.** A dialog over the sheet: three questions, then Checked or Not yet.
5. **Add a language.** Search over the families; Beta, Coming, No course yet, Added. Picking one opens the sheet as a draft; nothing is saved until "Add <language>", which waits for a skill that is not Leave. A Learn skill shows the full-decks download dialog then.
6. **The empty state.**
7. **Onboarding, one step.** A single "Languages" step: each language's skills as cycling chips (Know, Learn, Leave; Learn skipped for languages without decks), a live search, Start. Know needs no check here. Learn downloads the full decks on Start.

Not drawn: any earlier or present frame, the two-step onboarding, Stop learning, Remove, the two-button control.

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

**Contrast.** Computed in the page (`window.__contrast`, logged to the console) for both seeds and both themes: Round 3: 72 pairs x 4 = 288, **0 failing** (new: each skill's pill text, Learn inset border and tile icon on its colour, the i glyph, the A1 path). Earlier round: 52 pairs x 4 = 208, 0 failing. Text 4.5:1; the Leave dashed outlines, the Review switch outline and thumb, the stepper icons, the progress fill, the check answer outlines and the chevron 3:1. New pairs this round: Know pill (on its tint) and Learn pill (on its fill), Leave pill and chip, the Check to review button, review-deck subtext, the Review switch. Disabled pills (Learn where there is no course, review-deck rows not yet offered) are drawn at 38% and are exempt, as in the app's theme.

**Chromium (Playwright).** Opened at 900 px and 420 px wide (no sideways scroll, no page errors). Looked at the screenshots at 1.4x text, light and dark, of: Settings (switch off and on), the list, the sheets (Hindustani, Marathi, Assamese), the check dialog, and onboarding; clicked the Review switch and the tweak control, the pills, and the review-deck pill. Hindi, Hindustani in Urdu and Bengali show in rows, dialect names and glyph tiles; the Noto fonts load from Google Fonts, which the test sandbox could not fetch (fallback fonts were used). Not checked: other text sizes (the app caps at 1.4x), high-contrast themes, a real phone, TalkBack.

### Remaining doubts

- Know now uses the tertiary container (tc), which is also the Beta badge colour; they never sit side by side, but say if a different Know colour is wanted.
- List chips stay read-only (icon only) and open the sheet; only the sheet and onboarding have the tappable pill.
- The review-deck pill reads Review or Leave; turning it off removes the deck at once (with Undo), not at the next app open.
- The Checked key chip on the list stays with Review off, since a skill checked earlier keeps its double tick.
- With Review off, review decks already on the phone are kept and shown nowhere in the sheet (only Delete data now removes them).

## Design decisions: options and the main downside

1. **Cycle order** is Leave, Know, Learn, Leave. Option: Leave, Learn, Know (the downside: the first tap would start a download, and Know is the common, free choice). A tap past Learn from Know opens the download dialog; Cancel keeps Know. Going from Learn to Know takes two taps (via Leave), which can start the "decks removed" notice for a moment; Undo shows when the last skill is left.
2. **Speak and Hear and review.** Review decks are per script, so a known and checked Speak or Hear has no review deck to offer; the check only marks it ready. Option: also offer audio review cards for Speak and Hear (the downside: needs an audio review deck that does not exist yet).
3. **Moving Learn to Know needs a check again.** Option: keep a skill's check when it goes from Know to Learn and back (the downside: a skill learned for months would count as checked without a check).
4. **Check is the same short quiz for every skill.** Option: a longer placement per script (the downside: a new learner may meet a quiz before a first lesson). The pass mark is two of three here.
5. **The check unlocks review for known skills inside a Learn language too.** Option: review in a Learn language needs no check, since the course tracks progress (the downside: a skill can be marked Know with nothing to confirm it).
6. **Decks removed at the next app open.** Option: a "Remove now" next to the notice (the downside: a second way to delete beside Delete data now). Delete data now stays for progress and immediate removal.
7. **Full decks cut down on the next open.** A language that moves from Learn to Know only loses its full decks at the next open and keeps review decks for checked scripts, with no re-download. Option: keep the full decks until the learner deletes them (the downside: the phone keeps decks that nothing needs).
8. **A Leaving section.** A language with decks but no skills stays in a third section until the next open. Option: hide it at once and remove silently (the downside: the learner cannot undo by setting a skill back).
9. **Several Learn skills, one language, one minutes-a-day.** Per language, as the owner answered. Option: per skill (the downside: four steppers and a daily total).
10. **Read and Write per script, as rows.** For two scripts the sheet has four script rows (a longer sheet at 1.4x). Option: a compact grid of script columns (the downside: tight at 360 dp with 1.4x text).
11. **List chips**: one chip per script for Read and Write, so Hindustani wraps to two lines. Option: one chip per skill with the states of its scripts stacked (the downside: harder to read at a glance).
12. **Dialect is shown, not chosen.** One dialect per language, above Speak. When a second dialect arrives, this becomes a chooser.
13. **Languages with no course** (English, Coming ones) can be set to Know; the cycle skips Learn. Option: hide them from the picker until a course exists (the downside: a learner cannot record a language they speak).
14. **Onboarding chips use words** (the owner's icons-only rule is for the list). Option: icons in onboarding too (the downside: a new learner meets the icons first, with no key).
15. **Page name:** "Languages". Option: "My languages" (friendlier; the downside: the Settings section is also called Your languages).
16. **Which names are right**: every **to confirm** row in the table above.

Round 3 Chromium check: 900 px and 420 px wide (no sideways scroll, no page errors), light and dark at 1.4x: list, Hindustani, Marathi (Done and Check), the i panel, Add Maithili, onboarding with the stepper; the walk Assamese to Leave returns it to the pool. Fonts could not load in the sandbox.
