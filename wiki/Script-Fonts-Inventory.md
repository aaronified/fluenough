# Script fonts inventory

Source of truth: this wiki page.

Which font draws each script the app teaches, where it lives, its licence and
what it was checked against (owner, 2026-11-16: "Add the fonts in the deck
repo. App should get them from there."; "I don't want to depend on system
fonts for content"). The decision is in
[ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course); the files are in
`decks/fonts/<script>/` on the `decks-live` branch, each with its `OFL.txt`,
and `FONTS` and `FONT_ALIASES` in `tools/deck_index.py` register them.

## Rules

- Open licences: SIL OFL-1.1 here; MIT and other permissive licences are
  also accepted, with their text kept in the folder (owner, 2026-11-16). Fonts are Noto, from Google Fonts'
  `ofl/` folder (the same Noto Project sources as notofonts.github.io).
- **Content fonts**: Latin, Cyrillic and Greek are one Noto Sans subset each,
  shared by every language in the script. They always download with a course
  and are always drawn with; the learner is never asked. Every course also
  lists the Latin font, because its readings and IPA are Latin letters. They
  are the fallback behind every other script's font and behind the
  interface's Roboto, so a deck character never falls to the phone's font.
- Other scripts keep the font check (a sample, "can you read it?"), which
  downloads the font only on "No".
- A script that shares another's file is an **alias**, with no folder.

## Fonts

| Script (key) | Languages | Font | File and size | Coverage check |
|---|---|---|---|---|
| latin | 43 languages | Noto Sans, subset (Basic Latin, Latin-1, Extended A/B/Additional/C/D/E, IPA Extensions, Spacing Modifiers, Phonetic Extensions, combining marks, punctuation; wght 400 to 700) | NotoSansLatin.ttf, 358 KB | 0 missing across the 514 characters of the Latin-script decks, and across every IPA and combining character of all decks |
| ipa | ipa | alias of latin | none | 0 missing across the 506 characters of decks/ipa |
| cyrillic | ru, uk, isv, hbs | Noto Sans, subset (Cyrillic and extensions, Basic Latin, combining marks) | NotoSansCyrillic.ttf, 220 KB | 0 Cyrillic characters missing; the Latin readings and IPA in those decks come from the Latin font |
| greek | el, grc, qgh, qgk | Noto Sans, subset (Greek, Greek Extended for polytonic, Basic Latin, combining marks) | NotoSansGreek.ttf, 201 KB | 0 Greek characters missing; Latin readings and IPA from the Latin font |
| thai | th | Noto Sans Thai (variable) | NotoSansThai.ttf, 219 KB | 0 missing across 157 characters |
| meitei_mayek | mni | Noto Sans Meetei Mayek (variable) | NotoSansMeeteiMayek.ttf, 96 KB | no Meitei text in the decks yet; the whole block is covered but two unassigned slots (U+ABEE, U+ABEF) |
| brahmi | qap | Noto Sans Brahmi | NotoSansBrahmi.ttf, 115 KB | 0 missing across 126 characters; all 114 assigned code points of the block |
| arabic | ar | alias of perso_arabic_naskh (Noto Naskh Arabic) | existing, 308 KB | 0 missing across 138 characters |
| shahmukhi | pa | alias of perso_arabic (Noto Nastaliq Urdu) | existing, 690 KB | 0 missing across 182 characters |
| braille | qbe | shadow-dot font that ships in the app (ADR-0043) | none | not applicable |
| sitelen_pona | tok (second script) | sitelen seli kiwen asuki (Kreative Software, SIL OFL-1.1), subset to the UCSUR block U+F1900-F19FF | SitelenSeliKiwen.ttf, 582 KB | all 142 words and name glyphs of the decks are in its cmap; see below |
| signwriting | ins, ase (the decks' script; the languages list none) | Noto Sans SignWriting (Google, SIL OFL-1.1), subset to the 31 symbols of the explainer decks plus the fill and rotation modifiers, layout features kept | NotoSansSignWriting.ttf, 224 KB | every symbol and modifier of the explainer decks drawn and looked at; see below |

The scripts that had fonts before (bengali, cuneiform, devanagari, egyptian
hieroglyphs, gujarati, gurmukhi, the Han family, hangul, hebrew, kana,
kannada, linear B, malayalam, odia, Ol Chiki, perso_arabic and its Naskh
variant, tamil, telugu) are unchanged.

The subsets are made with fontTools from Noto Sans (`NotoSans[wdth,wght].ttf`),
keeping all layout features, with the width axis fixed at 100 and the weight
axis limited to 400 to 700. Coverage was checked by reading every YAML file of
each script's languages in `decks/` and testing each character against the
font's cmap.

## Sitelen pona (Toki Pona)

Owner, 2026-11-16: "Yes, accept MIT for any font. Also add sitelen pona
decks." The licence rule is widened: MIT and other permissive licences are
accepted for fonts when their text is kept in the font's folder.

The font is sitelen seli kiwen asuki, version 2.2, by Rebecca Bettencourt of
Kreative Software, under the SIL OFL-1.1 (so the wider rule was not needed). It
came from the npm package `sitelen-layer-plugin`, which bundles it with the
upstream licence text, because GitHub releases are blocked from the build
sandbox (nasin-nanpa, ETBCOR, MIT, was the other candidate and its binaries
are only in those releases). It is subset to the UCSUR block U+F1900 to
U+F19FF, the registry's chart for sitelen pona, with all layout features kept.

Toki Pona's vocab decks keep their Latin `target` and give each card and
example `target_scripts: { sitelen_pona: ... }`, written by
`tools/tok_sitelen.py`: [ADR-0055](ADR-0055-Sitelen-Pona-As-A-Second-Script).
Grammar tables and reading passages stay Latin.

## SignWriting (sign languages)

Owner, 2026-11-18: "Yes. Use it. But explain it well in the cards first."
The decision is [ADR-0056](ADR-0056-SignWriting-For-Sign-Languages): the
symbols of the explainer decks are text, in Noto Sans SignWriting; whole
signs are pictures drawn from Formal SignWriting (FSW).

- **The font.** Noto Sans SignWriting v2.005 (The Noto Project Authors,
  SIL OFL-1.1), from Google Fonts' `ofl/notosanssignwriting`, 7.9 MB whole
  (all 37,000 symbol variants are glyphs reached by the font's `ccmp`
  rules from a base symbol, a fill modifier and a rotation modifier). It is
  subset with fontTools to the 31 symbols the explainer decks use and the
  modifiers U+1DA9B to U+1DA9F and U+1DAA1 to U+1DAAF, with every layout
  feature kept: 224 KB. A base symbol followed by its modifiers draws as
  one glyph. A symbol a later deck needs is added by subsetting again, from
  the whole font.
- **Build-time only, not in the repository.** `tools/signwriting_image.py`
  draws a sign from FSW with the two Sutton SignWriting fonts
  (`SuttonSignWritingFill.ttf` and `...Line.ttf`, SIL OFL-1.1, Copyright
  1974-2014 Center for Sutton Movement Writing, Inc., symbols by Valerie
  Sutton, refined by Adam Frost, encoded by Stephen E Slevinski Jr),
  distributed in the MIT package `@sutton-signwriting/font-ttf` (10 MB).
  The pictures it makes are CC BY-SA 4.0 deck content; the credit is
  Sutton SignWriting.
- **Sign data.** The only open-licensed signs checked: the ASL alphabet and
  digits in the MIT `signwriting` package by Sign Language Processing
  (`signwriting/fingerspelling/data/ase.json`; its upstream source, likely
  SignBank, was not verified). Not usable: SignBank Plus on Hugging Face
  (CC-BY-NC-4.0, which CC BY-SA 4.0 cannot take); Signbank, SignPuddle,
  signwriting.org and GitHub releases are not reachable from the build
  sandbox, so their licences are not recorded. No Indian Sign Language
  signs in SignWriting were found.

See also: [ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course) ·
[ADR-0055](ADR-0055-Sitelen-Pona-As-A-Second-Script) · [ADR-0056](ADR-0056-SignWriting-For-Sign-Languages) · [Deck Format](Deck-Format) · [Plans Index](Plans-Index)
