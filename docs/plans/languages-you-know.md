# Plan: Languages you know, for many languages

Written 2026-10-12, for 0.5.0. Tracks #490.

**The approved design is
[`docs/mockups/languages-you-know.html`](../mockups/languages-you-know.html)**
(owner, 2026-10-12: "this is perfect"; commit efec961). It is the spec for
this screen. Build to it. Don't delete, rewrite or replace it; if the design
changes, the owner approves a new version first.

## What the owner asked (2026-10-12)

> Languages I know needs a lot more of the Indian languages, even if the
> daily facts are not updated. This will open the review opportunities for
> those pairs as well.
>
> We need a better way to show that screen initially, the tickmark approach
> works when we have a few languages.
>
> This will change onboarding and also the settings page (onboarding can
> later be told to just use the settings page anyway).
>
> Bottom sheet is the best option. The language families need to be folded
> by default. The bottom sheet question and the script-yes answer should be
> in the same script. The options shall not be termed as yes or no, verbose
> only. Like "I can read the Hindi script" and "I can only speak Hindi".
>
> [On the English line under the question:] the presence of the
> translation defeats the purpose of the question here.

## The languages

- English, India's 22 scheduled languages, plus Bhojpuri, Tulu, Rajasthani,
  Magahi, Chhattisgarhi, Awadhi, Haryanvi, Kumaoni, Garhwali, Mizo, Khasi and
  Goan Konkani: about 35 in all, listed in #490.
- Each entry in `assets/languages.yaml` has:
  - `code`, `iso639_3`, `name`, `own_name`, `script` and `family`;
  - the sheet's two own-script sentences, `script_question` and
    `script_can_read`, written by a speaker of the language.
- A language with no facts file shows no daily facts. Nothing else changes.

## The screen: one screen, two places

Settings shows it with an app bar, back and Save. First launch shows the same
screen, with the onboarding header and Continue. Only that chrome differs.

From top to bottom:

1. **Search:** one line, "Search languages". It finds a language by its
   English name or its own name ("hin", "বাং"), whatever is folded.
2. **Your languages:** the chosen ones, each with its answer line ("Can read
   the Bengali script" or "Can only speak Bengali"). Tapping one reopens its
   sheet, or removes it.
3. **Top picks:** from the phone's language and region.
4. **All languages, grouped by family and folded by default:** Indo-Aryan,
   Dravidian, Tibeto-Burman, Austroasiatic and Germanic. Each family header
   shows its name, its count and an arrow. Screen readers hear "Indo-Aryan,
   24 languages, collapsed". Each row shows the English name and the own
   name.

## The bottom sheet: language and script in one tap

Tapping a language opens a sheet with two choices. One tap answers both the
language and its script, so no language is ever left unanswered.

- **The question and the "can read" option are only in the language's own
  script,** with no English line. Screen readers also read them in that
  script. Being able to read that option is the test.
- **The other option is in English only:** "I can only speak {language}".
- **Never Yes or No.** Both options are written out in full.

| | Bengali | Hindi |
|---|---|---|
| Question | আপনি কি বাংলা লিপি পড়তে পারেন? | क्या आपको हिंदी लिपि पढ़नी आती है? |
| Can read | আমি বাংলা লিপি পড়তে পারি | मुझे हिंदी लिपि पढ़नी आती है |
| Speak only | I can only speak Bengali | I can only speak Hindi |

The Hindi lines don't depend on the speaker's gender: आती agrees with लिपि.
Bengali doesn't mark gender here.

A language with no own-script sentences yet asks in English, a fallback until
a speaker writes them.

## Layout rules (from the mockup)

- At 2x text, the search text, the Settings title and the sheet's text grow
  at most 1.5x, so they stay on one line and both options stay in view.
- Pinned buttons and the sheet sit above the 3-button navigation bar (#489).
- Tap targets are 48dp or more, and contrast meets WCAG in every theme
  (Clay, Forest, Ocean, Iris; light, dark, pure black).

## Rules unchanged from #462

- A course can be reviewed only if the reviewer knows both its languages and
  reads both scripts.
- The script answer feeds that rule.

## Tests

- Search finds a language by its English or own name across folded
  families.
- Families start folded, and the fold state is announced.
- The sheet:
  - one tap sets both the language and the script answer;
  - the question and "can read" option are in the own script, with no
    English;
  - the speak-only option is English;
  - no Yes or No anywhere.
- First launch and Settings show the same screen.
- Every entry in `languages.yaml` has the required fields, an own name in
  its own script, and a valid, unique `iso639_3`.
- Accessibility at 2x text, light and dark, with the 3-button bar.

## Estimate

About 1.5 to 2 days for the screen and the sheet. The YAML for about 35
languages is about half a day, with Sonnet writing it and the own-script
sentences checked by speakers. Confidence: medium.
