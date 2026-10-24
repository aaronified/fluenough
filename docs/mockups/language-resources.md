# Language resources: self-check, notes and open questions

Companion to `language-resources.html` (#832; owner, 2026-10-24: "In the Japanese course, suggest the game Wagotabi (we are not affiliated, the suggestion is out of respect for the game). Do this when the user selects Japanese ... The suggestion will be shown in the languages i learn page later as well."). The page holds only the screens and their tweak controls, with what changed outlined in red. Nothing here is decided; the choices are tweak controls or questions below.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark. Course is a control: Japanese, and Hindustani and Bengali, which have no resource file yet and so show nothing new (no empty section, no placeholder). Resources for those two are not invented here.

## Where it shows today

`lib/features/placement/language_picker_page.dart` is Languages I learn. Tapping a language opens its sheet (`language_sheet.dart`): the course, the scripts, "Find my level" for a language already learned, and "Learn this language" fixed at the bottom, which leads to Which scripts, then Where to start. There is no other "pick a course" flow: first launch and Settings use the same page.

## What the proposal changes

1. **(a) Picking Japanese.** Variant A: a card at the top of the language's sheet, above "The course", so it is seen before "Learn this language". Variant B: one extra step after "Learn this language", "Before you start", with the same words, a "Visit Wagotabi" button and "Continue with Fluenough"; steps become 1 of 3.
2. **(b) Languages I learn.** On a language already learned, the sheet shows the same card, with a shorter text, under the language's name. It is never a step.
3. **Nothing else moves.** A language with no resource file shows nothing new.
4. The button opens the website in the phone's browser ("Opens wagotabi.com in your browser"). The app sends nothing; the link is used only when tapped.

## Drafted text

Card title: **Another good way to learn Japanese**
Label: **Not affiliated with Fluenough**
Picking (A and B):

> Wagotabi is a game for learning Japanese, made by someone else. We are not affiliated with it. We suggest it out of respect: we do not think Fluenough can beat it at teaching Japanese. Our course is built differently and will not follow it, but the aim is that you learn and have fun, so try both if you like.

Already learned (b):

> Wagotabi is a game for learning Japanese, made by someone else. We are not affiliated with it; we suggest it out of respect, because it may teach you more than we can. Use it beside this course, or instead of it.

Buttons: "Visit Wagotabi" (opens https://www.wagotabi.com/), and in B "Continue with Fluenough". Step title in B: "Before you start". The text is built from the file's `name`, `kind` and `why`, so each language gets its own wording through its file, with English wording in the app's `.arb` for the frame (title, label, buttons).

## Variants (tweak controls)

- **A: a card in the sheet.** Seen before the learner commits, no added step, but it can be scrolled past. Costs nothing in the flow.
- **B: a step before the scripts.** Cannot be missed and has a button each way, but adds a screen for every learner of a language with a suggestion, and for a learner who chose the language to learn it, may read as a detour.

## Proposed data: one YAML file per language

`decks/<lang>/<lang>-resources.yaml`, for example `decks/ja/ja-resources.yaml`. It will also hold film, music and book suggestions later (#215), so `kind` covers them. **Released apps do not read this file yet.** The app learns the file first; the suggestions show from the release that carries it. Like other deck files it is fetched from `main` and listed in `decks/index.json` by `tools/deck_index.py`, and the validator checks it. (Adding it is a deck-format change, so it needs the owner's approval and a section in `docs/DECK-FORMAT.md` first.)

```yaml
language: "ja"
resources:
  - id: "ja-res-wagotabi"      # permanent, like a card id; never reused
    name: "Wagotabi"
    url: "https://www.wagotabi.com/"
    kind: "game"               # app | game | site | book | film | music
    why: "A game for learning Japanese, which we do not think we can surpass at teaching."
    affiliated: false          # true only if Fluenough or its authors made or are paid by it
    level: "A1"                # optional: A1 | A2 | B1 | any
    shown_at: ["pick", "learning"]   # optional: pick | learning (default both)
```

Rules: every scalar quoted (AGENTS.md rule 2); `url` is https; `affiliated` is a real boolean and, when true, the card says so instead of "Not affiliated"; `why` is plain English, with transliteration for any non-Latin script word; `kind` is a fixed list; film, music and book entries add `creator` and `year`.

## Open questions

1. **Variant A or B?** Or A on the sheet and B only for a first course.
2. **Wording.** Is "we do not think Fluenough can beat it" the sentence the owner wants shown, or only kept as the reason in the file? It is drafted as asked.
3. **Several resources.** The card shows the first; with two or more, a list of up to three. Confirm.
4. **Wagotabi's permission.** We link out of respect, with no logo, name styling or screenshots. Is a courtesy message to them wanted before release?
5. **Language scope.** Which language gets a suggestion next, and who chooses the resource (a deck contributor by pull request, or owner only)?
6. **Dismissal.** Should a learner be able to hide the card for good on (b)? Not drawn.
7. The "Script" row now reads "Kana, Kanji".

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, outlines 3:1. All 24 pairs pass.

| Theme | Pair | Colours | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light | body text on page | onS on s | 16.33 :1 | 4.5 :1 | pass |
| light | body text on the card | onS on sHigh | 14.01 :1 | 4.5 :1 | pass |
| light | muted text on the card | onSv on sHigh | 7.64 :1 | 4.5 :1 | pass |
| light | muted text on page | onSv on s | 8.9 :1 | 4.5 :1 | pass |
| light | Visit button text | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| light | Continue button text | onP on p | 6.46 :1 | 4.5 :1 | pass |
| light | outlined button text | p on s | 6.16 :1 | 4.5 :1 | pass |
| light | Stop button text | E on sLow | 5.85 :1 | 4.5 :1 | pass |
| light | not-affiliated outline on card | ol on sHigh | 3.67 :1 | 3 :1 | pass |
| light | change outline on page | E on s | 6.16 :1 | 3 :1 | pass |
| light | change tag text | onE on E | 6.46 :1 | 4.5 :1 | pass |
| light | toast text | s on onS | 16.33 :1 | 4.5 :1 | pass |
| dark | body text on page | onS on s | 14.33 :1 | 4.5 :1 | pass |
| dark | body text on the card | onS on sHigh | 11.17 :1 | 4.5 :1 | pass |
| dark | muted text on the card | onSv on sHigh | 8.48 :1 | 4.5 :1 | pass |
| dark | muted text on page | onSv on s | 10.88 :1 | 4.5 :1 | pass |
| dark | Visit button text | onSc on sc | 7.25 :1 | 4.5 :1 | pass |
| dark | Continue button text | onP on p | 7.68 :1 | 4.5 :1 | pass |
| dark | outlined button text | p on s | 10.86 :1 | 4.5 :1 | pass |
| dark | Stop button text | E on sLow | 10.09 :1 | 4.5 :1 | pass |
| dark | not-affiliated outline on card | ol on sHigh | 4.55 :1 | 3 :1 | pass |
| dark | change outline on page | E on s | 10.89 :1 | 3 :1 | pass |
| dark | change tag text | onE on E | 7.72 :1 | 4.5 :1 | pass |
| dark | toast text | s on onS | 14.33 :1 | 4.5 :1 | pass |

## Behaviour checks (Chromium, Playwright)

- Loaded in Chromium at 1280 px: no page errors, no console errors, no horizontal page scroll, no horizontal overflow inside a phone.
- Every combination of theme (2), course (3), variant (2) and highlight (2) was set: no errors; screenshots of each theme, course and variant were looked at.
- "Visit Wagotabi" pressed: the toast "Opens https://www.wagotabi.com/ in the browser" shows.
- At 1.4x the card is about 380 dp tall, so the sheet scrolls; the card is first in the sheet so its button is in view with "Learn this language" visible below.
- Fonts: Roboto, Noto Sans Devanagari and Noto Sans Bengali from Google Fonts; offline the system fallback is used. Japanese text uses the system CJK font.
