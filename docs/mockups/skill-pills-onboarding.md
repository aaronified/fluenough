# Skill pills and the first launch: self-check, notes and open questions

Companion to `skill-pills-onboarding.html` (owner, 2026-11-01). The page holds only the screens and their tweak controls, with what changed outlined in red. The checks and notes are here. Nothing below is decided except what the owner answered (marked).

Owner's words, 2026-11-01:

- Pills: "The pill transitions are not very clear. On read it is a double tick, then on write, it is a double tick plus a keyboard! Same confusion on spoken. There needs to be 3 things, we already have skill icons for read write say hear. So use them! Add the double tick as well when it is verified via placement as well. For the combined skill, there is no need for an icon at all! Since there will always be a pill. For leave, instead of -, write NA or something, to make it short and clear. For each level, use a different tint of the same colour. Show me a mockup, and then build exactly like that."
- Onboarding: "During onboarding, show the language screen and explain the options, and then let the users choose what they know and what they want to learn."
- Answers to the open points: the English translation line only under the question, own script alone on every answer line; the Perso-Arabic option drafted in Perso-Arabic script and shown with the existing "unchecked" bug icon until an Urdu speaker verifies it; "I can only speak X" in English only; toasts in plain words, without the skill names.

Phone 360 dp at 1.4x text (the app's cap, #505), `ColorScheme.fromSeed` of the forest seed, light and dark, Hindustani and Bengali. Theme, course, highlight and every choice below are controls on the page.

## What the screens are today

`lib/features/languages/skill_widgets.dart` (`SkillBadge`, `markIcon`, `markExtraIcon`), `language_skills_sheet.dart`, `languages_page.dart`. A Spoken pill and one pill per script cycle Leave, Learn, Know, Know both. Today's Know is a tick, Know both is a tick plus the Write or Speak icon, level found is a double tick that replaces both, Leave is a dashed minus, Learn is the cap with a primary border. So "Read" at level found (two ticks) looks like "Read and Write" without it (tick and keyboard), the confusion the owner names.

## What the proposal changes

1. **Words and marks, not stacked icons.** The mark says only how sure the state is: cap Learn, one tick Know, two ticks level found by placement. Which skills are covered is told by the tint (and the words in variant B), never by an extra icon.
2. **Leave reads NA** (dashed outline kept, no minus). Tweak: NA, Off, None.
3. **One tint per level**, three tints of the skill's own colour: Learn, Know, Know with both skills. Light: lighter is less. Dark: darker is less, so "stronger" always means "more". The strongest tint is the high-contrast container of `ModeColors`, the lightest the normal container, the middle one a 45% mix. Level found keeps the tint of its level and only changes the tick.
4. **Single skills use their own icon** (eye, keyboard, microphone, ear, raised hand for Gestures, as on the Today tiles) followed by the mark. They appear in the list row as the "One per skill (icons)" chips (tweak), and Gestures is already a single pill.
5. **Combined pills have no icon** (a pill is always there; the row names it). Two variants on the page: A, tint and tick only; B, tint, tick and the level in words ("Read", "Read + Write", "Hear", "Hear + Say"). In A, Read and Read + Write differ by tint only; B is the one the mockup defaults to.
6. **The list row** names each combined pill in text ("Spoken", "Devanagari") because the icon that did it is gone. The key under the filters is redrawn.
7. **Onboarding** gets an explanation screen (Learn, Know, NA, how the pills step, what two ticks mean, the privacy line as built), then the Languages page's own list and skills sheet, adding a language in draft mode ("Add Hindustani"), then the Know sheet.

## Toasts (plain words)

A pill change shows a toast that does not use Know, Learn or Leave. Wording on the page (the sheet's pills are tappable, the toast shows 3.5 s):

| Pill | Change | Toast |
|---|---|---|
| Spoken | to Learn | You'll practise hearing and speaking Hindustani |
| Spoken | to Hear | You can now understand spoken Hindustani |
| Spoken | to Hear + Say | You can now understand and speak Hindustani |
| Spoken | to NA | Hearing and speaking Hindustani left out |
| A script | to Learn | You'll learn to read and write Devanagari |
| A script | to Read | You can now read Devanagari |
| A script | to Read + Write | You can now read and write Devanagari |
| A script | to NA | Reading and writing Devanagari left out |
| Gestures | to Learn | You'll learn Indian Sign Language signs |
| Gestures | to Know | You can sign and understand Indian Sign Language |
| Gestures | to NA | Signs of Indian Sign Language left out |

## Variants (tweak controls)

- **Combined pill:** A (tint and tick only) or B (with words).
- **Leave reads:** NA, Off, None.
- **List row chips:** combined pills with a text name, or one chip per skill with its icon.
- **English line on the Know sheet:** only under the question (the owner's answer, default), under every line, or none.
- **Perso-Arabic option:** in Perso-Arabic script (default), or in Devanagari as built.
- **Only speak:** English only (default), or with an own-script form.

## Self-check results

WCAG contrast, computed in the page's JS (`window.__contrast`, console only) and run in Chromium for both themes. Text 4.5:1, icons and outlines 3:1. All 54 checked pairs pass.

| Theme | Pair | Ratio | Needs |
|---|---|---|---|
| light | body text on page | 16.33 :1 | 4.5 :1 |
| light | secondary text and NA text on page | 8.9 :1 | 4.5 :1 |
| light | pill text, lowest of 15 (Gestures, Know tint) | 5.38 :1 | 4.5 :1 |
| light | pill text, Learn tint (all five colours) | 13.2 to 13.3 :1 | 4.5 :1 |
| light | pill text, Know both tint | 9.3 :1 | 4.5 :1 |
| light | NA dashed outline on page | 4.28 :1 | 3 :1 |
| light | change outline / tag text | 6.16 / 6.46 :1 | 3 / 4.5 :1 |
| dark | body text on page | 14.33 :1 | 4.5 :1 |
| dark | secondary text and NA text on page | 10.88 :1 | 4.5 :1 |
| dark | pill text, lowest of 15 (Gestures, Know tint) | 4.65 :1 | 4.5 :1 |
| dark | pill text, Learn tint | 7.2 :1 | 4.5 :1 |
| dark | pill text, Know both tint | 12.3 :1 | 4.5 :1 |
| dark | NA dashed outline on page | 5.84 :1 | 3 :1 |
| dark | change outline / tag text | 10.89 / 7.72 :1 | 3 / 4.5 :1 |

Distinguishing the tints (information only, the marks and words carry the level too): Script colour, light, Learn against Know 2.13 :1 and Know against Know both 3.39 :1; dark, 2.36 and 2.31 :1. The tints are therefore close in dark, which is why A is weak there and B is the default. Pill text colour is the mode's own on-colour where it reaches 4.5:1, else white or black.

## Behaviour checks (Chromium, Playwright)

- Loaded at 1300 px wide, light and dark colour schemes, Hindustani and Bengali (4 runs): no page errors, no console errors, no horizontal page scroll.
- 1.4x overflow check: every element of every phone was measured against the phone's edges; none leaves it sideways in any of the 4 runs (the filter chip row scrolls sideways by design and is excluded). Vertical content scrolls inside the phone.
- Pills in the sheets were tapped in a browser run of the build: they cycle and the list follows. Not run: every control combination, the other text sizes (the app caps at 1.4x), high contrast, pure black, a real phone.
- Fonts from Google Fonts (Roboto, Noto Sans Devanagari, Noto Sans Bengali, Noto Naskh Arabic); offline, the system fallback is used. The Urdu line is set in Naskh, not Nastaliq.

## Assumptions

- Icons are Material's outlined set, as the app uses them (`skill_visuals.dart`, `skill_widgets.dart`).
- The tint mixes are in sRGB, approximating HCT tones; build them from tone steps of each hue (for example 90, 70, 40 in light) and recheck the ratios.
- `primaryContainer` of the forest seed is approximated (light `#b0f0c6`, dark `#0f5132`); check it against the app's `ColorScheme`.
- Level found keeps its level's tint. A tweak that darkens it one step more was not drawn.
- Sign languages: Gestures cycles NA, Know, as in the wiki ("Learn is offered when a course exists"). Learn is drawn in the table only.
- Hindustani sample state: Spoken Hear + Say with level found, Devanagari Read, Perso-Arabic Learn.
- The Know sheet's speak-only own-script lines ("मुझे हिन्दुस्तानी सिर्फ़ बोलनी आती है", "আমি শুধু বাংলা বলতে পারি") are my drafts for the optional variant, not the default, for a speaker to write.

## Open questions

1. **Does the Know sheet stay in the new flow?** The skills sheet's script pills already answer "which scripts do you read". Options: (a) keep it as the first question when a language is added (what screen 4 shows), with its in-language text; (b) drop it and let the draft skills sheet do the job, the in-language text going to the script rows. The downside of (b) is that a learner who reads only that language loses the in-language question.
2. **Combined pill A or B?** A is cleaner and relies on tint; B is clear without colour, wider at 1.4x (the list row wraps more). The mockup defaults to B.
3. **NA in other app languages.** "NA" is an English abbreviation; the owner said "NA or something". Off and None are on the page as options. Needs a word per app language once #46 lands.
4. **Does onboarding need at least one Learn?** English is fixed Know, so nothing blocks Next today ("Choose at least one language" is gone). Options: allow Skip (nothing to learn yet) or ask for one.
5. **Perso-Arabic line.** The Urdu wording is a draft by us ("مجھے فارسی-عربی (اردو) رسم الخط پڑھنا آتا ہے"), unverified until an Urdu speaker checks it; the sheet's bug icon is the existing "unchecked" one. Nastaliq rather than Naskh in the app needs a font decision.
6. **List row, combined or per skill?** Per skill shows every icon but takes up to six chips for Hindustani; combined shows the pill with a text name. The page offers both.
