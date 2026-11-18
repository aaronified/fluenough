# ADR-0056: Sign languages are written in SignWriting: symbols as text, whole signs as pictures

Source of truth: this wiki page.

- **Status:** Accepted (owner, 2026-11-18: "Yes. Use it. But explain it well in the cards first.")
- **Date:** 2026-11-18

## Context

Indian Sign Language (`ins`) and American Sign Language (`ase`) are in the
list of languages with no decks. The first-words session had to skip them:
a sign has no sound and no letters, and [Deck Format](Deck-Format) had no
way to write one. The app already treats a sign language as one with no
script and a single Gestures skill (`LanguageInfo.isSign`), and that stays.

Sutton SignWriting (Valerie Sutton, 1974) writes a sign by drawing its
handshape, which way the palm faces, where it is, how it moves, what the
hands touch and what the face does. It is open: the International
SignWriting Alphabet 2010 (ISWA) is encoded in Unicode (U+1D800 to
U+1DAAF), and the Sutton fonts and libraries are MIT or OFL.

What was checked (2026-11-18, from the build sandbox):

- **Noto Sans SignWriting** (OFL-1.1, Google Fonts `ofl/notosanssignwriting`)
  draws the Unicode block with plain text layout. A base symbol followed by
  a fill modifier (U+1DA9B to U+1DA9F) and a rotation modifier (U+1DAA1 to
  U+1DAAF) is composed into one glyph by the font's own `ccmp` rules, so a
  single symbol such as a black flat hand turned a quarter turn is
  three characters of text. The font is 7.9 MB whole, 224 KB subset to the
  symbols the explainer decks use.
- **A whole sign is two-dimensional**, and Unicode does not encode that. A
  sign is a set of symbols, each at its own x and y in a sign box; Unicode
  has the symbols and the modifiers, not the positions (the positions are
  in Formal SignWriting in ASCII, FSW, and in SignWriting in Unicode, SWU,
  which uses private-use code points). A font laid out in a line can show
  the symbols of a sign in a row, which is not the sign. So no font draws a
  sign, and an honest display needs a picture.
- **FSW can be drawn** with the Sutton SignWriting fonts (SIL OFL-1.1, from
  the npm package `@sutton-signwriting/font-ttf`, MIT): every symbol is a
  fill glyph (white) and a line glyph (black) at its key's code point,
  placed at its x and y. `tools/signwriting_image.py` does it with Pillow and
  has no other dependency; the fonts are 10 MB and stay out of the
  repository.
- **Reachable sources:** the npm registry, PyPI, jsdelivr, raw GitHub files
  and Google Fonts' files. Signbank, SignPuddle, signwriting.org, GitHub
  releases and the GitHub API are blocked. The one reachable dataset of
  signs, SignBank Plus on Hugging Face, is CC-BY-NC-4.0, which the decks'
  CC BY-SA 4.0 cannot take. The one open set of signs with meanings that
  could be checked is the fingerspelling and number signs of the MIT
  `signwriting` package (sign-language-processing, `ase` alphabet and
  digits).

## Decision

1. **The script key is `signwriting`.** A sign-language deck's language
   block is `script: "signwriting"`, `typed: false`, with no `tts` and no
   `scripts` (as the IPA and braille are written in their own script, and as
   a deck's `script` is not a language's `scripts` in `assets/languages.yaml`:
   `ins` and `ase` keep none there, so the app's sign-language handling,
   Gestures only, is untouched).
2. **A symbol is text.** A card that teaches one symbol (the explainer's) has
   as its `target` the Unicode characters: the base symbol and, if it has
   them, its fill and rotation modifiers. A font draws it. The font is
   `decks/fonts/signwriting/NotoSansSignWriting.ttf` on `decks-live`, the
   subset above, registered in `FONTS` and offered by the font check like
   any script's. The validator checks that the text is in U+1D800 to
   U+1DAAF (`SCRIPT_BLOCKS`).
3. **A sign is FSW and a picture.** A card that teaches a whole sign has as
   its `target` one sign in FSW (`M507x507S1f720487x492`), validated by
   `FSW_RE` in the validator, and as its `image` the picture
   `tools/signwriting_image.py` draws from it, deterministically, a WebP of
   256 pixels in `decks/<lang>/images/<card id>.webp` with its
   `image_credit`. The FSW is the source of truth: the picture is made from
   it and can be redrawn or checked against it. No new field and no new card
   kind: `target`, `image` and `image_credit` already exist
   ([Deck Format](Deck-Format#a-cards-own-image-image)). The format is
   specified in [Deck Format, Sign languages](Deck-Format#sign-languages-signwriting).
4. **The description is the card's note.** A SignWriting card has no
   `reading` (`signwriting` is in `NO_READING`, as braille is: it would be
   the meaning). Its `native` is the meaning, a gloss in capitals by sign
   language convention for a sign (`HELLO`) and a plain name for a symbol
   (`index finger`), and its `notes` describe what the hands do in plain
   English: handshape, which way the palm faces, where, how it moves, what
   the face does.
5. **No sound.** Sign cards carry `modes: ["listening", "speaking"]`, the
   opt-out qbe's cards carry, and the language has no `tts`. What remains is
   recognition, picture to meaning, and production, choosing the sign among
   others (never typed).
6. **Explain it first.** The path of each language opens with an alphabet
   unit, the explainer: a script guide (`<code>-script`, "How SignWriting
   works") and four decks of symbols (the hands, facing and turning, touch
   and movement, the face and the body), taught before any sign
   (`tools/gen_planned_paths.py` plans it). Every card says what the symbol
   is and why it looks so. The explainer files are gated to the release that
   ships the font, `decks/min_app.json`.
7. **The explainer is the same for both languages**, each in its own ids
   (`ase-0001`, `ins-0001`): SignWriting is one writing system, but a card id
   names its language, and a language's progress is its own.
8. **Whole signs are not built by this decision.** The language sessions
   build the first signs with the format above.

## Consequences

- **Honest limit, and work not done here.** Drawing a sign as a picture
  needs the app to draw `image` as a card's prompt: a sign card's `target`
  is FSW, not text a learner reads, so a drill must show the picture
  large (not at the 88 pixel size of `CardPicture`), and a choice among
  signs must offer pictures, not text. `TargetText` knows only text. This is
  the second stage of the app work and is not built here; until it is, sign
  cards are not shipped (only the explainer, whose symbols are text, which
  existing drills already show).
- **The font check plumbing for a sign language is unverified.** The app
  asks about a script only for the scripts a language lists, and a sign
  language lists none. The font download for `signwriting` therefore
  depends on how the decks' script reaches `offerFonts`, which was read but
  could not be run here (no Flutter SDK in the build sandbox).
- The explainer's single symbols are text, so a phone without the font
  shows boxes until the font downloads: one more font, 224 KB.
- A picture per sign means about 1 KB of WebP per card.
- Left and right hand are mirror images of one symbol (rotation 9 to 16
  mirror 1 to 8); the explainer says "the other hand", not which.
- Facial grammar, location and sentence-level layout are left to the sign
  cards; the explainer covers symbols, not signing.
- Sign data is hard to source: the only checked, open-licensed signs are
  ASL's letters and numbers. Other signs need an open dataset or a Deaf
  signer; both languages' decks stay `unreviewed` until one has checked
  them.

## Alternatives considered

- **Unicode text for whole signs, in a font.** Rejected: positions are not in
  Unicode, so a row of symbols is not the sign; a screen full of them would
  teach the wrong thing.
- **A canvas or SVG renderer in the app (the `@sutton-signwriting`
  libraries are JavaScript).** Rejected: a new dependency, and the app has
  no SVG or WebView renderer; a picture made once costs nothing at run
  time.
- **Pictures for the symbols too.** Rejected: one code path would be neater,
  but then the explainer would wait for the stage two display work; text in a
  font works in every existing drill.
- **A video of each sign.** Rejected for this decision: licences, size and
  the filming are another project; the picture is what SignWriting is.
- **A second language entry per sign language with its own script.** Rejected:
  it changes what the app knows about sign languages (no Read or Write).

See also: [ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course) ·
[ADR-0055](ADR-0055-Sitelen-Pona-As-A-Second-Script) ·
[Script Fonts Inventory](Script-Fonts-Inventory) · [Deck Format](Deck-Format) ·
[ADR-Index](ADR-Index)
