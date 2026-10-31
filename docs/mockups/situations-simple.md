# Situations, simple: self-check, notes and open questions

Companion to `situations-simple.html` (owner, 2026-10-31: "The situations decks are about quick help in those situations. Don't overload people with useless information that they do not absolutely need there. Just give them a way to learn / practice them and also easily access and select and play them."). The page holds only the screens and their tweak controls, with what changed on an existing screen outlined in red; the other screens are new. Nothing below is decided.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark. Courses: Telugu (the real content: the rail station sheet of #938, its real phrases, readings and IPA), Hindustani and Bengali (the same screens with illustrative phrases, readings in the course's convention; the Hindustani and Bengali phrases and roots were written for this mockup and have not been checked by a speaker).

## What the situations feature shows today (as built)

Read from `lib/app/situations.dart`, `lib/features/today/situations_card.dart`, `lib/features/situations/*`, `lib/core/models/situation.dart`, `decks/te/te-situations.yaml`, `docs/DECK-FORMAT.md` ("Situations files") and `wiki/Today-and-Daily-Lessons.md`.

- **Content.** A situations file per language (`decks/<code>/<code>-situations.yaml`) lists card ids only: `phrases` and `words`, in order, with a title per language. Telugu has six sheets (#938): Taxi (20 phrases, 25 words), Shopping (12, 14), Eating out (11, 14), Doctor and pharmacy (9, 13), Traffic stop (7, 9), Rail station (9, 12). The icon key is one of six fixed keys, so a seventh sheet would have no button.
- **Access.** Today only: a "Situations" card under quick revision with an "Offline" mark and six coloured buttons in two rows of three, each with an icon, the title and "N new". There is no list, no search, no entry on Decks. A course without a file shows the buttons dimmed with an "Upcoming" pill. The language is the one the language bar shows.
- **The situation page** (`SituationPage`). App bar with the title and an "Inspect cards" icon. Two sections, "Phrases" and "Words", each a grouped list of rows: a dot if the learner has not met the card, the script, the reading, the meaning in bold, a speaker (if the phone has a voice) and an info mark. A tap on a row opens the card. At the foot one button, "Practise this sheet" (teaches up to 9 new cards, then revises the rest), "Revise this sheet" when nothing is new, disabled with a reason when nothing is ready. There is no way to play the phrases one after another.
- **The card** ("Rail station: card 2 of 21", `SituationInspectPage`). Title "<sheet>: card N of M"; a strip of numbered chips to jump (a dot on those not learnt); "Also on: ..." when the card is on other sheets; then the full word sheet (`WordSheet`: the word large, reading, speaker, IPA and each sound with practice, meaning, part of speech, other meanings and accepted answers, picture, notes, base words, warnings, dictionary entry, every example, facts, tags, difficulty per skill, id, where the learner stands, Report); at the foot Previous, "Open in deck" and Next. Moving is by buttons or chips; there is no swipe. Phrases and words are one run of cards (21 for the rail station).
- **The other branch.** `fix/card-browse-swipe` (a swipe-only, minimal card with the IPA behind an info dot) was not on the remote when this was written, so the card here follows the owner's description (below), not its code. The earlier approved mockup (`mockup/situations-724`, `situations.html`) is the page the built screens follow.

## Screens (proposal)

1. **Finding a situation.** Today keeps its six buttons and gains one "All" button; Decks may gain one "Situations" row; both open one list. The list is a plain row per situation: one icon, the name, how many phrases, and a star to pin it. Pinned first, then the one used last. Nothing else on a row (no "N new" count, no mastery). With six situations there is no need to search; a search field is a tweak for later.
2. **A situation.** Three buttons: **Play all**, **Learn**, **Practise**. The app bar has the title and the pin star. When a phrase is starred, a fourth button "Play starred (N)" appears. Nothing else: no phrase list, no words list, no counts of new cards.
3. **The card** (owner amendment, 2026-10-31). The phrase, its transliteration, a play button, the IPA with its info dot, the swipe position (dots and "2 of 9") and the meaning. A scroll down may show the root words. Nothing else. A star keeps the phrase. Swipe moves between cards. Everything the word sheet has beyond this (notes, examples, tags, id, difficulty, Report, picture, dictionary entry, "Also on", "Open in deck") is not on this card; it stays on the deck's own word sheet.
4. **Playing.** Play all reads the phrases in order, hands-free, with an optional pause to say each one back. Full screen: the phrase, its reading, its meaning, previous, play or pause, next, and a swipe on the phrase for next or previous. A mini player (phrase, previous, play or pause, next) stays over the other pages. The lock screen and the media notification carry the same three buttons, so it works with the screen off or in a pocket.
5. **Practise.** The existing "hear and choose" drill on the situation's phrases, 5, 8 or 10 questions.

Subset: a star on a card pins that phrase; "Play starred" on a situation plays only the starred ones of it; a "My phrases" row at the top of the list gathers every starred phrase across situations and plays them.

## Tweak controls (each an open choice)

Entry (Today and a Decks row, or Today only); list as rows or grid; order (pinned then recent, or fixed); search field; includes (phrases only, or phrases and words); the Play starred button; the "My phrases" row; pause between phrases (none, 2 s, 4 s); end of the list (plays once or repeats); player state; practise length.

## Doubts and questions for the owner (not decided)

1. **Phrases only, or phrases and words?** Play, Learn and Practise are drawn with the nine phrases (default). Today's sheet also has 12 words, so the card count would be 21 as in "card 2 of 21". Are the words part of quick help, or only of the deck?
2. **New and learnt.** Today's dot and "N new" are removed from the situation screens. Should Practise still teach new cards first and revise the rest (as built, up to 9 new), or only drill every phrase, ignoring what the learner has met? Does Practise count towards the learner's reviews and progress?
3. **Meaning on the card and in Play.** The card shows it (your amendment). Should Play also speak the meaning after the phrase (a tweak could add it), or only the phrase?
4. **Root words.** Where do they come from? The deck's `bases` of the card (as `te-6701` has) is sparse: most phrases have none. Show the block only when the card has bases, or write them for every sheet phrase?
5. **Star scope.** Is a star per phrase (shared by every situation that has the card) right, or per situation? Is "My phrases" across situations wanted, or only the per-situation "Play starred"? Are pinned situations and starred phrases stored per profile and backed up?
6. **Hands-free with the screen off.** Needs a foreground media service with a media session (lock screen and notification controls), and audio focus. The app has `flutter_tts` and `audioplayers` but no media-session package; system TTS in the background can be stopped by the phone's battery saver. Is a new dependency acceptable (e.g. `audio_service`), and is recorded audio (not TTS) wanted for the situations so the player is reliable? The pause between phrases is a timer in that service. Is "screen off" a requirement or a later step after an on-screen player?
7. **Mini player scope.** Over every page of the app (needs a host above the navigator) or only over the Situations pages?
8. **Entry.** Today's six buttons stay and "All" is added: is one more entry (the Decks row) wanted? Today's six buttons are the six icon keys; a seventh sheet (the list shows any number) has no Today button. Should Today show the pinned and recent ones instead of the fixed six?
9. **Order.** Pinned first then recent is drawn; "recent" needs a stored last-used time per situation. Fixed order is the simpler choice.
10. **Speaker on the card.** The card has one play button next to the IPA line; should it play the phrase only, with a second one on the IPA's sound?
11. **IPA wording.** The info dot opens a short note with the narrow IPA in `[ ]` when the card has one (ipa-revamp plan), else the broad `/ /`. The mockup shows the broad line from the deck; the note text is a placeholder.
12. **Hindustani and Bengali.** Their situations files do not exist; the phrases here are illustrative only.
13. **Swipe and accessibility.** A swipe-only card needs the Previous and Next actions for screen readers and switch access (semantic actions or visible buttons). Is that accepted without drawn buttons?

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All 40 pairs pass. The inactive swipe-position dots are decorative: the position is also written as "2 of 9" (and read as "Phrase 2 of 9"), so they are not in the table.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | captions, readings | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | captions on cards | onSv on sLow | 8.45 :1 | 4.5 :1 | pass |
| light | text on cards | onS on sLow | 15.5 :1 | 4.5 :1 | pass |
| light | text on raised blocks (popover, mini player) | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | captions on raised blocks | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | tonal button, audio, icon discs | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | filled button, play, pinned star disc | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | star pinned and text button on cards | p on sLow | 5.85 :1 | 4.5 :1 | pass |
| light | star pinned on page | p on s | 6.16 :1 | 3 :1 | pass |
| light | icon on raised block | p on sHigh | 5.29 :1 | 3 :1 | pass |
| light | outline against page | ol on s | 4.28 :1 | 3 :1 | pass |
| light | outline against card | ol on sLow | 4.06 :1 | 3 :1 | pass |
| light | unpinned star on cards | onSv on sLow | 8.45 :1 | 3 :1 | pass |
| light | unpinned star on page | onSv on s | 8.9 :1 | 3 :1 | pass |
| light | selected answer text | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | change tag | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change outline on card | E on sLow | 5.85 :1 | 3 :1 | pass |
| light | active position dot against page | p on s | 6.16 :1 | 3 :1 | pass |
| dark | body text | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | captions, readings | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | captions on cards | onSv on sLow | 10.08 :1 | 4.5 :1 | pass |
| dark | text on cards | onS on sLow | 13.28 :1 | 4.5 :1 | pass |
| dark | text on raised blocks (popover, mini player) | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | captions on raised blocks | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | tonal button, audio, icon discs | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | filled button, play, pinned star disc | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | star pinned and text button on cards | p on sLow | 10.05 :1 | 4.5 :1 | pass |
| dark | star pinned on page | p on s | 10.86 :1 | 3 :1 | pass |
| dark | icon on raised block | p on sHigh | 8.46 :1 | 3 :1 | pass |
| dark | outline against page | ol on s | 5.84 :1 | 3 :1 | pass |
| dark | outline against card | ol on sLow | 5.4 :1 | 3 :1 | pass |
| dark | unpinned star on cards | onSv on sLow | 10.08 :1 | 3 :1 | pass |
| dark | unpinned star on page | onSv on s | 10.88 :1 | 3 :1 | pass |
| dark | selected answer text | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | change tag | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change outline on card | E on sLow | 10.09 :1 | 3 :1 | pass |
| dark | active position dot against page | p on s | 10.86 :1 | 3 :1 | pass |

## Behaviour checks (Chromium, Playwright)

- Chromium 1194 (Playwright's build) loaded the page at 1280 px and at 390 px wide: no page errors, no console errors, no horizontal page scroll.
- Every tweak control was pressed in Telugu, Hindustani and Bengali, light and dark, and the stars, play and pause and IPA dot clicked: no errors; no text clipped outside its box in any phone.
- Full-page screenshots of each theme and course were taken.
- Fonts: Roboto, Noto Sans Devanagari, Noto Sans Bengali and Noto Sans Telugu from Google Fonts; where offline the system fallback is used.
