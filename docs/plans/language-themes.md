# Plan: a look for each language (colour, icon, background image)

Written 2026-10-10. Not yet tracked by an issue. Builds on #461 (the
language dropdown), ADR-0027 (language icons) and ADR-0037 (decks download
from `main`).

## What the owner asked

2026-10-10:

> each language should get their own themes (a separate yaml). Theme should include colour, icon, and background image.

## Name clash to settle first

"Theme" already means a course topic: `decks/themes.yaml` and ADR-0010 list
"First words", "Family" and so on, and `BUNDLED` in `tools/deck_index.py`
names that file. This plan calls the new thing a **look** in files and code
(`kind: look`, `LanguageLook`), and "theme" only in the interface. See
Open questions.

## What exists

- **Icon.** A deck's `language:` block may carry `icon`, up to four
  characters, the first letter of the language's own name (ADR-0027). The
  validator (`tools/validate_decks.py`, ~line 526) checks it on every deck
  file of a language; `tools/deck_index.py` copies it into the index
  (`languages[].icon`); the app reads it into `LanguageInfo.icon`, and
  `LanguageChips` (`lib/ui/widgets/language_chips.dart`) draws it, falling
  back to the first deck's glyph.
- **App colours.** `AppTheme.light/dark` (`lib/ui/theme.dart`) build the
  scheme with `ColorScheme.fromSeed` from `ThemeSeed` (`lib/app/settings.dart`:
  forest, ocean, clay, iris), at contrast level 1.0 for high contrast.
  Pure black overrides `surface`, `surfaceDim` and `surfaceContainerLowest`
  of the dark scheme only. `test/ui/theme_test.dart` already measures WCAG
  contrast of the mode colours and of `onSurface` on pure black.
- **Where decks live.** `decks/<code>/`, one YAML per deck plus
  `<code>-path.yaml`, `-facts.yaml` and similar non-deck kinds
  (`NOT_DECKS`). `decks/index.json` lists each language's files with
  `size`, `sha256`, `content_sha256`, `kind` and `schema`; CI fails while it
  is stale; the app downloads from `main` and verifies SHA-256 (ADR-0037).
- **Selection.** #461: one language shared by the whole app, or **All
  languages**, remembered across launches, on every screen but Settings.

## The file

`decks/<code>/<code>-look.yaml`, one per language, optional. A language
without one keeps today's behaviour. Alongside the existing non-deck kinds,
so `look` joins `NOT_DECKS` and is never mistaken for a deck.

```yaml
schema: 1
kind: look
language: "hi"
colour:
  seed: "#C2410C"            # quoted: a bare # starts a YAML comment
icon:
  glyph: "हि"                # what today's `icon` becomes
  image: "hi-icon.png"       # optional; see below
background:
  image: "hi-background.webp"
  credit: "Photo by A. Name, 2024"
  licence: "CC-BY-4.0"
  source: "https://example.org/original"
  alt: "Marigolds at a temple in Varanasi"
  focus: "centre"            # where to crop: centre, top, bottom, start, end
```

All scalars quoted (AGENTS.md rule 2). The glyph is still the first letter
of the language's own name.

### Colour

One `seed`. The app builds all three variants from it with the same
`ColorScheme.fromSeed` call it uses now: light, dark, and pure black (dark
plus the three black surfaces), each also at high contrast. No hand-picked
palette per variant, so a deck author cannot ship an unreadable pairing.

The validator checks the seed is `#RRGGBB` and rejects seeds whose tonal-spot
scheme would fail contrast (same maths as `theme_test.dart`: `onPrimary` on
`primary`, `onPrimaryContainer` on `primaryContainer`, `onSurface` on
`surface`, each at least 4.5:1, in light, dark and pure black). M3 tonal spot
usually passes by construction; the check is a guard for very grey or very
light seeds. The ratio code is ported into the validator (stdlib only,
rule 6), with a Dart test that runs the same seeds through the real
`ColorScheme.fromSeed` so the two cannot drift.

### Icon

The `glyph` replaces the block `icon`. It moves out of every deck file's
`language:` block into the look file, so one place holds it. Migration: keep
reading the block `icon` as a fallback for a language with no look file, and
mark it deprecated in `docs/DECK-FORMAT.md`; the index writes
`languages[].icon` from whichever exists, so older apps keep working and
`INDEX_VERSION` does not rise.

An **image icon** is optional and off by default: `icon.image`, PNG or WebP,
square, at most 128 x 128 px and 20 KB, with a transparent or solid
background, shown where the glyph shows now. The glyph stays required
because it is the fallback, and the text a screen reader and the chip's
label use. Whether to allow images at all is an open question.

### Background image

- **Format and size.** WebP or JPEG (no PNG photos), at most 1080 x 720 px
  and 150 KB, landscape. The validator reads the header with the stdlib
  (no Pillow, rule 6) and checks type, dimensions and size.
- **Licence.** `credit`, `licence` (an SPDX id such as `CC0-1.0`, `CC-BY-4.0`)
  and `source` are required when `image` is set; the validator refuses an
  image without them and a licence that is not on an allow-list that is
  GPL-compatible for the repo's content (CC0, CC-BY, CC-BY-SA, public domain).
  The credit shows in the app (a line on the language's page in the deck
  browser and in About), never hidden.
- **`alt`** is required, in English, and is the image's description. The
  image is decorative on every screen, so a screen reader skips it; `alt`
  is for review and the credits page.
- **Where it shows:** the language's **course card** and its **Today lesson
  card** (a header band behind the title), and the **language picker** row.
  Not behind lists, drills or card faces. The whole-screen background is out
  of scope.
- **Text over it stays readable.** The image sits under a scrim of
  `scheme.surface` at 70 to 85 percent, so title and body text use ordinary
  `onSurface` and keep 4.5:1 against the worst case. A widget test renders a
  white image and a black image under the scrim in all three variants and
  asserts the ratio. No text sits on the bare image.

## Where it applies

- **A language is selected** (#461's dropdown): the app theme is rebuilt
  from that language's seed, so every screen but Settings takes its colours:
  app bar, buttons, navigation bar, chips. The language's background shows on
  its course card and Today lesson card.
- **All languages:** the app theme, from the learner's `ThemeSeed`. Each
  language's own look still shows on its own cards in lists, because a card
  belongs to one language.
- **Settings** always uses the app theme, so the controls that undo a
  colour choice never change under the learner.
- A language with no look file uses the app theme, with its glyph from the
  block `icon`.
- The theme change animates over `AnimatedTheme`'s default duration; with
  reduced motion on it switches at once.

`AppTheme.light/dark` take an optional seed override; the language's seed
replaces `settings.seed` only when the language is selected. No new
dependency.

## Downloads

- `tools/deck_index.py` lists each look file and each image it names as
  files of that language, with `path`, `size`, `sha256`, `content_sha256`
  (equal to `sha256` for an image) and `kind` (`look`, `look-image`). It
  writes the glyph and seed into `languages[]` too, so the picker can show
  them before any download.
- The app fetches the look file with the language's first files, so the
  colour and icon are there at once, then the background images afterwards;
  a missing or failed image just means no image, never a failed language.
  An image whose SHA-256 does not match is discarded (ADR-0037).
- Removing a language deletes its look files. Updates follow the existing
  "ask, don't push" rule; an image change is a small update.
- The index rises in size by roughly 100 to 200 KB per language with an
  image. No change to `INDEX_VERSION`: new file kinds are ignored by an app
  that does not know them.

## Validator (`tools/validate_decks.py`)

- Accepts `kind: look`; one per language at most; `language` matches the
  folder; unknown keys are errors (as for decks).
- Checks the seed, the contrast, the glyph (letter or two of the language's
  own name, as ADR-0027), image paths exist inside `decks/<code>/`, image
  type, size and dimensions, and the licence fields.
- Errors if a deck's block `icon` differs from the look glyph.
- `deck_index.py`'s staleness check covers the new files.

## Accessibility

- Contrast: derived schemes, the validator guard above, and the existing
  high-contrast mode applied on top of the language seed.
- Colour is never the only signal: a language is also named by its glyph and
  name wherever its colour shows.
- Text over images only on the scrim; images are decorative to a screen
  reader; the glyph carries the chip's semantic label.
- Reduced motion and system font scaling are untouched.
- RTL: `focus` uses `start` and `end`, not left and right (rule 10).

## The learner's own choice

- Light, dark, system and pure black keep working: the language seed feeds
  all three. Pure black still forces the three surfaces black, so a language
  never lights up an OLED screen.
- High contrast stays an overlay on whatever seed is in force.
- **Proposed:** an Appearance switch, "Use each language's colours", on by
  default, plus "Show language pictures", so a learner can have the app seed
  everywhere and no images. Each is one `StoredSettings` key, additive
  (rule 9), with an English token in `app_en.arb` (rule 10) and a row in the
  settings tests. Both are listed as an open question.
- The learner's chosen `ThemeSeed` stays the colour for All languages and
  Settings.

## Tests

- Validator: a good look file passes; bad seed, low contrast, missing
  licence, oversized or wrong-type image, wrong language and unquoted
  boolean-like scalars each fail with a clear message; the block-icon
  mismatch fails.
- Index: look files and images appear with correct SHA-256 and sizes;
  a changed image makes the index stale.
- Dart: a seed's three variants meet 4.5:1 for the key pairs (shares
  seeds with the Python check); the dropdown switches the theme and All
  languages restores the app one; Settings never changes; scrim text
  contrast over white and black images; the switch off gives the app theme
  and no images; a failed image download leaves the language working;
  glyph fallback without a look file.
- Existing `theme_test.dart` and `language_chips` tests stay green.

## Pieces, in order

1. Format, `docs/DECK-FORMAT.md`, validator and index (Python, no Flutter).
2. Hindi and Spanish look files as the first two, without images.
3. Download, `LanguageLook`, glyph read from the look file.
4. Per-language theme with #461's dropdown (needs it first).
5. Background images, the scrim, credits, the two settings switches.
6. An ADR once the owner has answered the questions (it changes the deck
   format, which AGENTS.md says needs a human answer first).

## Estimate

About 5 to 7 days with tests: 1 to 2 for format, validator and index, 1 to 2
for download and `LanguageLook`, 1 to 2 for theming and the dropdown, 1 to 2
for images, scrim and switches. Image sourcing and licence checking for the
seven or eight languages is separate, human work, not counted.
Confidence: medium on the code, low on the dropdown's timing (it depends on
#461 landing) and on image sourcing.

## Open questions

1. **Name.** Keep "theme" in the interface and `look` in files, to avoid
   the course-topic `themes.yaml`, or rename one of them?
2. **User override.** Add "Use each language's colours" and "Show language
   pictures" switches (proposed, on by default), or always apply them?
3. **Image icons.** Allow `icon.image`, or keep the glyph only (simpler,
   always legible, ADR-0027's "first letter of its own name")?
4. **Background images: who makes and licenses them?** Contributors under
   CC0 or CC-BY, commissioned art, or generated? Who checks the licence
   before merge? Is the licence allow-list above right?
5. **Where backgrounds show.** Course card, Today card and picker as
   proposed, or also the Decks tab header or Progress?
6. **Size cap.** Is 150 KB a card for about eight languages acceptable
   against the offline-first promise, or lower?
7. **Block `icon` migration.** Move it to the look file and deprecate the
   block field (proposed), or keep both?
8. **Colour in All languages.** App seed, as proposed, or the colour of the
   language that owns the card on each card?
9. **Cultural care.** Who reviews a language's colours and pictures so a
   choice is not a stereotype or has an unintended meaning?
