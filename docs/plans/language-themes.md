# Plan: a look for each language (colour, icon, background image)

Written 2026-10-10; owner's answers recorded 2026-10-11. Not yet tracked by an issue. Builds on #461 (the
language dropdown), ADR-0027 (language icons) and ADR-0037 (decks download
from `main`).

## What the owner asked

2026-10-10:

> each language should get their own themes (a separate yaml). Theme should include colour, icon, and background image.

## Owner's answers (2026-10-11)

1. Naming. Owner: "Must be consistent." Course topics keep "theme"
   (`decks/themes.yaml`, ADR-0010, the theme filter). The per-language
   visual identity is a **look** everywhere: files
   (`decks/<code>/<code>-look.yaml`, `kind: look`), code (`LanguageLook`),
   docs and the app's interface. "Theme" is never used for it.
2. Icon. Owner: "Image allowed, and it will be part of deck building.
   Small image." A look may carry a small icon image made during deck
   building, alongside the decks. The first-letter glyph stays as the
   fallback when there is none.
3. Background. Owner chose all four places: the course card on Decks, the
   Today lesson card, the language picker row, and the Decks header /
   Progress. And: "This will be a line drawing. Like cultural silhouette".
   So backgrounds are line-drawing cultural silhouettes drawn in the look's
   colour, tinted to the scheme, not photos, and subtle so text stays
   readable.
4. Size. Owner: "It will be svg only." Icon and background are SVG only (no
   WebP, JPEG or PNG). Limits set by this plan: 50 KB for a background,
   10 KB for an icon.

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
  image: "hi-icon.svg"       # optional; see below
background:
  image: "hi-background.svg"
  credit: "Drawing by A. Name, 2026"
  licence: "CC-BY-4.0"
  source: "https://example.org/original"
  alt: "Line drawing of a temple silhouette"
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

An **image icon** is optional (owner, 2026-10-11: "Image allowed, and it
will be part of deck building. Small image."): `icon.image`, an SVG, square
viewBox, at most 10 KB, made during deck building and committed beside the
decks. It is drawn in the look's colour, shown where the glyph shows now.
The glyph stays required because it is the fallback when there is no image,
and the text a screen reader and the chip's label use.

### Background image

- **Style.** A line drawing, a cultural silhouette (owner: "This will be a
  line drawing. Like cultural silhouette"), not a photo. It is drawn in the
  look's colour: the app tints strokes to the scheme (`primary` at low
  opacity), so one file serves light, dark and pure black. Subtle, so text
  stays readable.
- **Format and size.** SVG only (owner: "It will be svg only."), at most
  50 KB, landscape viewBox. The validator checks with the stdlib (no
  third-party package, rule 6) that the file parses as XML with an `svg`
  root, and rejects: a `<script>` element, any `on*` event-handler
  attribute, any `href` / `xlink:href` or `url(...)` pointing outside the
  file (http, https or anything not a `#fragment`), and an embedded raster
  (`<image>`, `data:image/` URIs). The icon follows the same rules with a
  10 KB cap.
- **Licence.** `credit`, `licence` (an SPDX id such as `CC0-1.0`, `CC-BY-4.0`)
  and `source` stay required when `image` is set; the validator refuses an
  image without them and a licence that is not on an allow-list that is
  GPL-compatible for the repo's content (CC0, CC-BY, CC-BY-SA, public domain).
  The credit shows in the app (a line on the language's page in the deck
  browser and in About), never hidden.
- **`alt`** is required, in English, and is the drawing's description. The
  drawing is decorative on every screen, so a screen reader skips it; `alt`
  is for review and the credits page.
- **Where it shows** (owner chose all four): the language's **course card**
  on Decks, the **Today lesson card**, the **language picker** row, and the
  **Decks header / Progress**. Not behind lists, drills or card faces.
- **Text over it stays readable.** Line art covers little of the card, so the
  scrim can be lighter than for a photo: `scheme.surface` at 40 to 60
  percent under the drawing, text in ordinary `onSurface`. The contrast
  tests stay: a widget test renders the strongest drawing (a dense, fully
  opaque stroke in `primary`) behind text in all three variants and asserts
  4.5:1. No text sits on bare strokes.
- **Rendering.** Needs an SVG renderer. `pubspec.yaml` has no `flutter_svg`
  today, so adding it is a **new dependency for review** (AGENTS.md); it is
  the one change to `pubspec.yaml` in this plan.

## Where it applies

- **A language is selected** (#461's dropdown): the app theme is rebuilt
  from that language's seed, so every screen but Settings takes its colours:
  app bar, buttons, navigation bar, chips. The language's drawing shows on
  its course card, Today lesson card, picker row and the Decks header /
  Progress.
- **All languages:** the app theme, from the learner's `ThemeSeed`. Each
  language's own look still shows on its own cards in lists, because a card
  belongs to one language.
- **Settings** always uses the app theme, so the controls that undo a
  colour choice never change under the learner.
- A language with no look file uses the app theme, with its glyph from the
  block `icon`.
- The look change animates over `AnimatedTheme`'s default duration; with
  reduced motion on it switches at once.

`AppTheme.light/dark` take an optional seed override; the language's seed
replaces `settings.seed` only when the language is selected. One new
dependency, `flutter_svg`, for review (see Background image).

## Downloads

- `tools/deck_index.py` lists each look file and each SVG it names as
  files of that language, with `path`, `size`, `sha256`, `content_sha256`
  (equal to `sha256` for an SVG) and `kind` (`look`, `look-image`). It
  writes the glyph and seed into `languages[]` too, so the picker can show
  them before any download.
- The app fetches the look file with the language's first files, so the
  colour and icon are there at once, then the SVGs afterwards;
  a missing or failed SVG just means the glyph and no drawing, never a failed
  language. An SVG whose SHA-256 does not match is discarded (ADR-0037).
- Removing a language deletes its look files. Updates follow the existing
  "ask, don't push" rule; an SVG change is a small update.
- The index rises in size by at most about 60 KB per language (50 KB
  background plus 10 KB icon, usually far less). No change to `INDEX_VERSION`: new file kinds are ignored by an app
  that does not know them.

## Validator (`tools/validate_decks.py`)

- Accepts `kind: look`; one per language at most; `language` matches the
  folder; unknown keys are errors (as for decks).
- Checks the seed, the contrast, the glyph (letter or two of the language's
  own name, as ADR-0027), image paths exist inside `decks/<code>/`, `.svg` only,
  the SVG safety rules and byte caps above (50 KB background, 10 KB icon),
  and the licence fields.
- Errors if a deck's block `icon` differs from the look glyph.
- `deck_index.py`'s staleness check covers the new files.

## Accessibility

- Contrast: derived schemes, the validator guard above, and the existing
  high-contrast mode applied on top of the language seed.
- Colour is never the only signal: a language is also named by its glyph and
  name wherever its colour shows.
- Text over drawings only on the scrim; drawings are decorative to a screen
  reader; the glyph carries the chip's semantic label.
- Reduced motion and system font scaling are untouched.
- RTL: `focus` uses `start` and `end`, not left and right (rule 10).

## The learner's own choice

- Light, dark, system and pure black keep working: the language seed feeds
  all three. Pure black still forces the three surfaces black, so a language
  never lights up an OLED screen.
- High contrast stays an overlay on whatever seed is in force.
- **Always on** (owner, 2026-10-10: "Always on"): no switch turns a
  language's colours or pictures off. With a language chosen, its look
  applies.
- The learner's chosen `ThemeSeed` stays the colour for All languages and
  Settings.

## Tests

- Validator: a good look file passes; bad seed, low contrast, missing
  licence, oversized SVG, non-SVG file, SVG with script, event handler, external
  reference or embedded raster, wrong language and unquoted
  boolean-like scalars each fail with a clear message; the block-icon
  mismatch fails.
- Index: look files and images appear with correct SHA-256 and sizes;
  a changed image makes the index stale.
- Dart: a seed's three variants meet 4.5:1 for the key pairs (shares
  seeds with the Python check); the dropdown switches the look and All
  languages restores the app one; Settings never changes; scrim text
  contrast under the strongest line drawing in all three variants; a failed
  SVG download leaves the language working;
  glyph fallback without a look file.
- Existing `theme_test.dart` and `language_chips` tests stay green.

## Pieces, in order

1. Format, `docs/DECK-FORMAT.md`, validator and index (Python, no Flutter).
2. Hindi and Spanish look files as the first two, without images.
3. Download, `LanguageLook`, glyph read from the look file.
4. Per-language look with #461's dropdown (needs it first).
5. Add `flutter_svg` (after review); SVG icons and backgrounds, the scrim,
   credits.
6. An ADR once the owner has answered the questions (it changes the deck
   format, which AGENTS.md says needs a human answer first).

## Estimate

About 5 to 7 days with tests, unchanged in total: 1 to 2 for format, SVG
validator and index, 1 to 2 for download and `LanguageLook`, 1 to 2 for
theming and the dropdown, 1 to 2 for SVG rendering, scrim and four
placements (the SVG safety checks replace the raster header checks; the
extra placements and `flutter_svg` add about half a day). Drawing the
silhouettes and icons and checking their licences, for the seven or eight
languages, is separate, human work during deck building, not counted.
Confidence: medium on the code, low on the dropdown's timing (it depends on
#461 landing) and on image sourcing.

## Open questions

1. ~~**Name.**~~ Decided (owner, 2026-10-11: "Must be consistent."): topics
   keep "theme"; the per-language identity is a "look" everywhere.
2. ~~**User override.**~~ Decided (owner, 2026-10-10): always on, no
   switches.
3. ~~**Image icons.**~~ Decided (owner, 2026-10-11): small SVG image allowed,
   made during deck building; glyph is the fallback.
4. ~~**Silhouettes: who draws and licenses them?**~~ Decided (owner,
   2026-10-11: "You"): Claude draws each language's silhouette and icon as
   original SVG line art, written by hand as paths, never traced from a
   photo or another artist's work. Each is released as `CC0-1.0`, with
   `credit: "Fluenough"`, so it needs no attribution and contributors
   may change it. Contributed drawings stay allowed under the allow-list,
   and the owner checks their licence at merge.
5. ~~**Where backgrounds show.**~~ Decided (owner, 2026-10-11): course card,
   Today card, picker row, and Decks header / Progress.
6. ~~**Size cap.**~~ Decided (owner, 2026-10-11: "It will be svg only."):
   SVG only, 50 KB background and 10 KB icon.
7. **Block `icon` migration.** Move it to the look file and deprecate the
   block field (proposed), or keep both?
8. **Colour in All languages.** App seed, as proposed, or the colour of the
   language that owns the card on each card?
9. **Cultural care.** Who reviews a language's colours and silhouettes so a
   choice is not a stereotype or has an unintended meaning?
10. **`flutter_svg`.** Approve the new dependency (see Background image).
