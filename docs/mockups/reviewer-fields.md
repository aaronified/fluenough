# Reviewer fields: self-check, notes and open questions

Companion to `reviewer-fields.html` (issue #508, reviewers see and correct every card field; image proposals from #523). The page holds only the screens and two tweak controls, with what is new outlined in dashed lines. Nothing below is decided except what is quoted.

## What this page is, and is not

`reviewer-mode.html` is approved (owner, 2026-10-17: "The reviewer mode mockup looks fine. Build it.") and its section 4 already shows every field of a card. It is not rewritten here. This page adds only what that sheet lacks:

1. **Looks right on each item** of a list field, with a count, because "every imported field, the image included, is reviewed" (owner, 2026-10-16, #523).
2. **The teach-card warning** (`warning`, #691; owner, 2026-10-23, #508: reviewers can also choose it).
3. **Image proposals** (#523): how a proposal reaches a reviewer. The owner's answers: proposals go "to the language's reviewers in the same way as their daily questions (#519)", the mail bot files the approvals, an approval pins the file (`hi-0419=File.jpg`), proposals cover nouns, verbs and adjectives, and reviewers drop the unclear ones. #519's own screen has "No mockup" (owner, 2026-10-17), so only the image case of a question is drawn, as the vehicle.

Phone 360 dp, 1x and 1.4x text (#505), `ColorScheme.fromSeed` of the four seeds (clay is the default, as in `reviewer-mode.html`), light, dark and pure black. Hindi and Bengali examples, every deck word with its reading. The cards' ids and the fields their decks do not carry yet are sample data, marked "(sample data)" in the captions. The photos are drawn stand-ins.

## Screens

| Frame | Shows |
|---|---|
| 1a Hindi | Synonyms, antonyms, confusables: Looks right on each item, "N to check", Claude-written items first, Wiktionary last (semi-verified), a checked item saying so |
| 1b Hindi | The Image box with a proposal: the photo, the pinned file, credit, licence, why, Use this image / Not this one |
| 2a Hindi | Notes titled by kind, and the Teach-card warning box with the teach card's strip |
| 2b Hindi | Choose the warning: the card's notes, other meanings, no warning, Why |
| 2c Bengali | Other meanings not offered because the card has none; tick off while nothing changed |
| 3a Hindi | Image proposal as a question, noun: photo, file, credit, licence, why, rule, No / Yes, Skip |
| 3b Bengali | No: reasons, Why, what dropping means |
| 3c Bengali | A verb proposal |
| 3d | After answering: each answer names the exact file; the two-answer rule |
| 4a to 4f | 1.4x of 1a, 2b, 2c, 3a, 3b, 3d |

Tweak controls: **Item check** (Looks right on each item, or pencil only as approved) and **Warning picker** (only the card's warnings, or also an Automatic row).

## Open questions (doubts)

1. **Per-item Looks right.** The approved sheet has Looks right per card only. The owner said every imported field is reviewed, so 1a gives each item one. Alternative: keep the card-level tick and let a pencil or a flag carry the rest. Is per-item wanted, and does a checked item move below the unchecked ones?
2. **Label for Claude-written items.** Wiktionary items say "Wiktionary · semi-verified"; Claude-written ones carry no label today, so the page marks none. Should they say "Not yet checked"?
3. **Does the sheet show image proposals at all (1b)?** The owner said proposals go like the daily questions. 1b is my addition: the same proposal inside the card's Image box. Drop 1b if proposals are question-only.
4. **Where does the image question live?** #519 has no screen and no mockup. 3a to 3d borrow its "Question N of 10" shape and Skip. Confirm that is the shape, or say where proposals appear.
5. **Answers: Yes, No, Skip.** Skip returns tomorrow (#519: unanswered questions wait for the next day). Is a Why needed on Yes (the page asks none)?
6. **The reasons on No** (shows something else, shows a kind, poor picture, not suitable) are my invention. Keep them, or Why only?
7. **A dropped file.** "Not this one" drops that file for the card; a later import might propose another. Is a second proposal allowed, and does "Not suitable" block the card from proposals for good?
8. **Agreement.** #519: two agreeing answers settle a data point, a disagreement goes to a third. For an image the pin is `card=File`: do two answers agree only on the same file, and is a No on one file a vote against that file only? 3d says so; confirm.
9. **Images already imported** (cards with a Noto `picture` get Commons or OpenMoji images directly, not as proposals). Are those checked by a question too ("every imported field is reviewed"), or only by Flag this image, which the approved sheet has? 1b and 3a show only proposals.
10. **Image size.** Files are shrunk (for example 256 px WebP). The page draws them full width at 16:9; an upscaled 256 px file may look soft. Show at native size, centred?
11. **Licence on screen.** The question shows credit and licence so a reviewer can refuse one that cannot ship in a CC BY-SA 4.0 deck (a #523 commenter's point). Should the reviewer judge licences, or only the bot?
12. **Warning: an Automatic row** (tweak). It would remove the `warning` key. Can the bot write a removal, and should a reviewer be able to ask for it? Default off on the page.
13. **Warning: a rude word.** DECK-FORMAT picks a rude word only when it is very close and very rude. Should the picker block "No warning" or another choice on such a card, or only warn?
14. **Warning needs the field released.** The app and validator learn `warning` one release before the decks use it (DECK-FORMAT, two releases). Until then the box is disabled, "Feature incoming" (ADR-0008)? The sheet draws it enabled.
15. **Other meanings not offered** when the card has no `senses` (the validator errors on it). Could a sense proposed in the same review enable it? The page keeps it off.
16. **Fields still not on the sheet.** `dictionary` (a layer's imported entry, "the app does not show it yet"), `phonetic` (tools only), `hears`, `not_sounds_like` and `not_looks_like` (the offensive-alikes review) and a set card's members. Are they part of "every field"? I assumed no; none is drawn.
17. **Reading passages** are exam-only and never reviewed (owner, 2026-10-13); I assume reviewers do not see their fields.
18. **Mail timing.** 3d says answers go "with your next review". #519 says "the same route as review answers today". Is there a separate send for questions?
19. **Which reviewers get image proposals.** The bilingual rule (rule 1) is about language; a picture needs none. Do all of the language's reviewers get them?
20. **Milestone.** #508 is 0.7.0 now (it was 0.6.0 and 0.5.0 before); #519 and #523 are 0.7.0 and blocked. The approved mockup says built in 0.5.0 terms. Confirm the order.

## Self-check results

Run in Chromium (Playwright, the bundled build) on `reviewer-fields.html`, console only (`window.__check`), all four tweak combinations laid out, 30 frames (15 screens, dark and light):

- **Layout:** 0 problems. No text sticks out or is cut, no line cut at a frame edge, every tap target at least 48 dp, no "Looks right" or other label wraps, the page does not scroll sideways.
- **Structure:** 0 problems. Every frame shows what it claims: each list item has Looks right or its checked state with the right count and Wiktionary items last (1a); the proposal has its pinned file, licence and two answers (1b); notes titled and the warning box (2a); exactly one warning picked and every warning the card has offered (2b); Other meanings dimmed on a card without senses and the tick off (2c); each question has file, credit, licence, Skip, No and Yes, use it (3a, 3c); four reasons and the dropped line (3b); three distinct answers and the two-answer rule (3d); text really at 1.4x in the 4a to 4f frames; every Hindi or Bengali word followed by its reading; no rater code anywhere.
- **Contrast:** 20,376 text, icon and outline checks across the four seeds in light, dark and pure black, with and without the Item check and Automatic tweaks: 0 below WCAG AA (text 4.5:1, icons and outlines 3:1). Disabled controls and the page under a scrim are not counted. The drawn photos are not text and are not counted.

Not checked: the real Google fonts load only online, so the Noto Devanagari and Bengali glyphs in the screenshots came from the Chromium fallback in this run.
