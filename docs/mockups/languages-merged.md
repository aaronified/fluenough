# Languages (merged): notes

Mockup: `languages-merged.html`. One interactive page, one phone: tap through it. The page holds only the screens and their controls (theme, colour seed, text size, jump buttons, "Simulate: the app opens again", reset); everything below is here.

Owner's direction (2026-10-30): "know and learning should be based on skills. speak, hear, read, write. the latter two will also be script specific. speak, hear will be dialect specific (the app only teaches one dialect for each language now anyway). use proper dialect names, not random ones. user can tick multiple." Answers to the first mockup's questions (2026-10-30, issue #907) are built in: a cycling tick with three states, read-only icon chips, no separate Stop learning, decks removed at the next app open, minutes a day per language, one onboarding step, and a check before a known skill can be reviewed.

## The design

- **One list of languages**, in three sections: Learning (any skill is Learn), Know (skills are Know and Leave only), Leaving (every skill is Leave but decks are still on the phone).
- **Four skills per language: Speak, Hear, Read, Write.** Speak and Hear carry the language's one taught dialect. Read and Write have one row per script (Hindustani: Devanagari and Perso-Arabic (Urdu); Japanese: Kana and Kanji; Mandarin: Simplified and Traditional; Punjabi: Gurmukhi and Shahmukhi).
- **Three states per skill: Know, Learn, Leave.** One control per skill, a pill that shows the state in words and an icon, and each tap cycles to the next: Leave, Know, Learn, Leave. Where there are no decks yet (course coming or none) Learn is skipped. Leave is drawn dashed, Know outlined, Learn filled, and always with an icon and a word, never colour alone.
- **Know is instant.** No check, no download (owner: "rely on the user to know what they know").
- **Learn means the full decks.** One Learn skill, in any script, downloads the language's full decks (course words and audio plus every script's decks); a dialog names the size first. Cancel leaves the skill as it was. Minutes a day is one stepper per language, shown when any skill is Learn.
- **Review needs a check.** A Know skill shows "Not checked: it shows as known, with no review cards until checked" and a Check to review button. The check is a short mock (three questions drawn from the course's words: read, write, hear, speak; two of three pass). Passing marks the skill Checked ("review cards on"); failing leaves it Know and unchecked. Changing a skill away from Know clears its check.
- **Review decks (Know only languages).** A language with no Learn skill offers a review deck per script, only where Read and Write of that script are both Know and both Checked. Each script row says why it is or is not offered (needs Read and Write known, needs checking, ready to download, on this phone). A language with a Learn skill already holds the full decks, which carry review cards for checked skills.
- **Leave and the next app open.** Decks that no skill needs are removed the next time the app opens, not at once. What each state needs: a Learn skill keeps the full decks; with none, only the review decks of scripts that are Know and Checked (Read and Write) stay; with nothing left, no decks. A row or sheet that has decks to lose says so: "Its decks will be removed the next time the app opens." (or "cut down to review decks"). Setting a skill back before the app opens keeps the decks. A language with every skill Leave and no decks leaves the list at once. The page's "Simulate: the app opens again" button runs the next-open clean-up.
- **List rows are read-only and icons only.** Four skill icons (mic, ear, book, pencil), one per script for Read and Write when there are several (the script's glyph beside the icon), each with a small state mark: tick (Know, not checked), double tick (Know, checked), cap (Learn), minus (Leave). A key above the list explains them (it is the only text for them); each chip has a tooltip and an accessible label ("Read Devanagari: Know, checked"). Tapping a row opens the sheet, where the states are changed.
- **Delete data now** (bin, with typed confirmation) is the only immediate removal. It stays for someone who cannot wait for the next app open; it turns Learn skills to Leave and keeps Know. There is no Stop learning and no Remove button (all three states Leave is the removal).
- **Script-only course** (English Braille): no Speak, Hear or dialect, only Read and Write in Braille.

### Screens (all live, reached by the jump buttons or by tapping)

1. **Settings entry.** One row, "Languages" ("Learning 2 · Know 2 · Leaving 1"), and a card, "What each state does", that explains Learn, Know and Leave, review and the next-open removal.
2. **The list.** Sample: Hindustani learning Perso-Arabic (Urdu) Read and Write and knowing the rest (all checked); Bengali learning all four; Marathi Know with Write not checked; Assamese Know with Read and Write checked and review decks on the phone; Gujarati all Leave with its decks still on the phone (the Leaving section and notice).
3. **The language sheet.** A short key of the three states, then the dialect, Speak, Hear, Read by script, Write by script (each a cycling pill, with the Checked or Check to review line under a Know), then Review decks (Know-only languages) or Learning controls (minutes a day, deck updates, decks on this phone, taught from, course). The bottom bar has Delete data now and Done.
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

**Contrast.** Computed in the page (`window.__contrast`, logged to the console) for both seeds and both themes: 55 pairs x 4 = 220, all pass. Text 4.5:1; the Know and Leave outlines, switches, the progress fill, the stepper icons, the check answer outlines and the chevron 3:1. New pairs this round: Leave chip and control (text and dashed outline), Know and Learn controls, the Checked and Not checked status lines, the three key chips in the sheet, the Settings explanation card, the next-open notices on the page and on the sheet, and the check dialog (question, answers, outline, Play). Disabled controls (Learn where there is no course, the disabled download button) are drawn at 38% and are exempt, as in the app's theme.

**Chromium (Playwright, 1.56).** Opened at 900 px and at 420 px wide (no sideways scroll). Looked at the screenshots, light and dark at 1.4x text, of: Settings, the list (top and bottom), the sheets (Hindustani, Marathi, Assamese, Gujarati, add Spanish, add Punjabi, each scrolled top and bottom), the check dialog (question, passed, failed), the download dialog, the review-decks download in progress and done, the Leaving section before and after Simulate, and onboarding. Also looked at forest, dark, 1x for the list and the Hindustani sheet. Clicked through: cycling every skill, the download dialog and Cancel, Check to review pass and fail, the review-deck download, all-Leave notices and Simulate, add, search, Undo, Delete data, the minutes stepper, onboarding cycling. No page errors. Hindi, Hindustani in Urdu and Bengali show in rows, dialect names and glyph tiles; the Noto fonts load from Google Fonts, which the test sandbox could not fetch (fallback fonts were used there). Not checked: other text sizes (the app caps at 1.4x), high-contrast and pure-black themes, a real phone, TalkBack.

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
