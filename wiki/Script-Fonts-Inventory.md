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

- Only open licences: SIL OFL-1.1 here. Fonts are Noto, from Google Fonts'
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
| sitelen pona | tok | none yet | none | see below |

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

No font is added yet. The Toki Pona decks hold only Latin words (no UCSUR
code points, U+F1900 to U+F19FF), so the app would also need to draw them in
sitelen pona: either a ligature font that turns the Latin words into glyphs,
or a table that maps each word to its UCSUR code point. The candidate found,
nasin-nanpa (ETBCOR), has ligatures and UCSUR, but its licence is MIT, not
OFL, Apache or CC0; the licences of Linja Pona, Fairfax HD and sitelen pona
pona could not be read from here. The owner chooses the font and the licence
rule before one is added.

See also: [ADR-0042](ADR-0042-Script-Fonts-Download-Per-Course) ·
[Deck Format](Deck-Format) · [Plans Index](Plans-Index)
