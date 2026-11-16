# Plan: Vedic accent marks, and one Devanagari engine for Vedic and Classical Sanskrit

Status: design of 2026-11-16, tasks VSA-100 and the design half of VSA-110 of [Deck-Work-Queue-VSA](Deck-Work-Queue-VSA.md) (tracker #1206). Nothing here is built: the only code written is a scratch prototype outside the repository, used to measure the tables below against the 30 existing cards. Every file and line cited was read on `origin/main` (`f8d59607`) or `origin/decks-live` (`d05ac818`) on 2026-11-16.

Two questions are answered: (1) can a `vsn` card carry Vedic accent marks, and (2) what is the one engine that writes the `reading` and `ipa` of `vsn` and `sa` (Classical Sanskrit, owned by another session). Section 4 is the GitHub issue for the parent session to file. A claim about the language itself (a sound value, a spelling convention) is marked **to pin** until VSA-001 has read it in a public-domain work (Whitney 1879, Macdonell 1916); values taken from Wikipedia's *Vedic Sanskrit* and *Sanskrit* articles (read 2026-11-16, CC BY-SA 4.0) are named as such. Nothing about the language is written from memory.

## 1. Vedic accent marks: what the validator, the font and the app do

### The marks

| Code point | Unicode name | Class | Use here |
|---|---|---|---|
| U+0951 | DEVANAGARI STRESS SIGN UDATTA | Mn, 230 | In Rigveda and Atharvaveda editions this glyph (॑) marks the **svarita**; Unicode's name says udātta, the encoding is the editors' (to pin: Macdonell, *Vedic Grammar for Students*, on the accent signs) |
| U+0952 | DEVANAGARI STRESS SIGN ANUDATTA | Mn, 220 | The anudātta (॒); the udātta itself is unmarked in these editions |
| U+0953, U+0954 | DEVANAGARI GRAVE / ACUTE ACCENT | Mn, 230 | Not Vedic accents; refuse |
| U+1CD0 to U+1CF9 | Vedic Extensions | mostly Mn; U+1CD3 Po; U+1CE9 to U+1CF3 and U+1CF5, U+1CF6 Lo; U+1CE1, U+1CF7 Mc | The other recitation traditions' tone signs (U+1CDA is the double svarita), visarga and anusvara variants, and **U+1CF5 jihvāmūlīya, U+1CF6 upadhmānīya**, which are letters, not marks |
| U+A8E0 to U+A8FF | Devanagari Extended | Mn (A8E0 to A8F1), Lo, Po | Combining digits and letters used in Sāmaveda notation; out of scope |

Categories are from Python's `unicodedata` (Unicode 15.1).

### 1.1 Does the validator accept them in `target`?

**Yes, for U+0951 and U+0952 and for every other mark, in a card's own `target`.** The script checks that could reject them do not look at `target`:

- `check_card` reads `target` only for being a non-empty string, having no outer whitespace (`tools/validate_decks.py:1273-1291`) and being NFC, which is a **warning**, not an error (`:1289-1290`, `r.warn(... "target is not NFC-normalised")`). NFC reorders marks by combining class; the Unicode order (base, vowel sign, then accent) is already canonical, so a properly typed target does not trip it.
- `SCRIPT_BLOCKS["devanagari"]` is `((0x0900, 0x097F), (0xA8E0, 0xA8FF))` (`:103`). It is used by `_letters_in` (`:958-966`), which checks every letter and mark (category L or M) against the blocks, in exactly two places: a card's `target_scripts.<script>` spelling (`:999-1002`) and the text of a character-reading kind whose `script` names a script (`:7829`). Neither applies to `target`. **They would reject U+1CD0 to U+1CF9**, because the Devanagari entry stops at U+097F and U+A8FF and skips the Vedic Extensions block. U+0951 and U+0952 (inside U+0900-U+097F) and U+A8E0-U+A8FF pass.
- The **"script in prose" rule** (`check_transliterated`, `:2786-2930`, `check_transliterated` at `:2904`) is where a Vedic Extensions mark does real damage. `_SCRIPT` is `ऀ-෿` plus other blocks, i.e. U+0900-U+0DFF (`:2786`), and `_SCRIPT_RUN` (`:2793`) only extends a run over characters in that class. A U+1CDA in the middle of a Devanagari word cuts the run in two, and each piece then needs a reading beside it. In a **core** this is harmless (the core's own script, `own`, is read as written: `check_transliterated(... own=own)` at `:3846`, `_untransliterated` at `:2875-2900`). In an **English layer's prose** (notes, explanations, labels) a word with U+1CDA or any U+A8E0-U+A8FF mark inside it is reported as missing its transliteration, even when the reading is right beside it. U+0951 and U+0952 are inside the class and do not cut a run. `_CODE_BLOCK` lists `sa` but not `vsn` (`:2802-2804`); it only matters for fields written *for speakers of* a language, which Vedic is not, so no change is needed.
- `_words` keeps a mark with its letter (category M is not in "PSZ", `:4960-4975`); `_tiles` and `_rearranges` count letters only (`:1749-1775`). `U+1CD3` (Po) would split a word like punctuation; it is a punctuation sign, not an accent.
- `check_romanised` (`:2400-2424`) returns at once when the language has **no** `<code>-romanisation.yaml` (`:2412-2413`). `vsn` has none today, so the 30 existing readings are not checked. See 1.4: this hides a conflict.

So the policy that costs nothing: **marks in `target` are allowed: U+0951 and U+0952 anywhere; the Vedic Extensions marks only in a core's `target`, never in a layer's prose or a `target_scripts` spelling, until a small validator change adds U+1CD0-U+1CFF and U+A8E0-U+A8FF to `_SCRIPT` and to `SCRIPT_BLOCKS["devanagari"]`** (tools change, its own PR, own test; not needed for A1, whose accent unit teaches the Rigveda's two marks).

### 1.2 Is there a bundled font that covers them?

**Yes.** `decks/fonts/devanagari/NotoSansDevanagari.ttf` (Noto Sans Devanagari, version 2.007, OFL) is the same file, blob `163f04bd`, on `origin/main` and on `origin/decks-live`. It is the only Devanagari font; the app's `assets/fonts/` holds only Roboto and the braille shadow font (`pubspec.yaml:105-119`), and script fonts are downloaded per script from `decks/fonts/<script>/` (`lib/core/decks/deck_index.dart:49-51`). Its cmap (read with `fontTools`, scratch only) covers U+0951, U+0952, U+0953, U+0954, U+0933 ळ, U+0934, U+0960, U+0961, **all of U+A8E0-U+A8FF, and every code point of U+1CD0-U+1CF9 except U+1CF7** (the atikrama, which is not needed). Coverage in the cmap is not proof that the marks sit well on a conjunct plus vowel sign (that is the font's GPOS); the first script deck that carries an accent mark (VSA-072) includes a rendered check of `अ॒ग्नि` and `ई॑ळे` in light and dark at 1.4x text before it merges.

### 1.3 Does the app's grader strip combining marks before comparing typed answers?

**No, not these marks.** `foldDiacritics` is an explicit table (`lib/core/grading/diacritics.dart`, "Dart's core library has no Unicode normalisation"). Its dropped-mark group (`'':` at `:86-98`) holds the nukta U+093C and U+09BC, a handful of Latin combining marks (macron, dot below, candrabindu, ring below, tilde, double macron below, acute, grave, circumflex, dot above, diaeresis, caron, macron below), and the Arabic harakat. **U+0951, U+0952 and the Vedic Extensions are not in it.** `canonical()` (`lib/core/grading/canonical.dart`) only rewrites composed nukta letters, digits and joiners. So a learner who types a Devanagari answer for a card whose `target` carries accents must type them too: pass 1 (exact) fails and pass 2 (`_fold`, `answer_grader.dart:171-176`) does not remove them. For Latin readings the grader is fine: `foldDiacritics` maps ṁ and ṃ to m (`diacritics.dart:47`), ḥ to h (`:42`) and drops U+0325 and U+0304, so `agnih`, `agniḥ` and a typed `agni` all compare as the answer, and `RomanisedSpelling` (`romanised.dart`) applies the language's `typed` pairs.

**Policy that follows:** (a) A1 vocabulary cards carry **no accent marks in `target`**; accents appear only in the accent-marks script deck and in verse excerpts, where nobody types the line. (b) Where an accented target is also a typed answer, list the unmarked spelling in `alt_target` (a supported list of strings, `validate_decks.py:1297`). (c) The clean fix is a lib change, in its own PR: add U+0951, U+0952, U+1CD0-U+1CF4 (marks only: not U+1CD3, U+1CE9-U+1CF3, U+1CF5, U+1CF6), U+1CF8, U+1CF9 and U+A8E0-U+A8F1 to the dropped-mark group, so that a missing accent is a `closeDiacritics` outcome ("right, but watch the marks"), as the nukta is. `lib/core` stays free of Flutter imports; the change is a table row plus one test. It is not needed for A1 if (a) holds.

### 1.4 What else the check turned up

- **`ṃ` is not in the repo's ISO letters.** `ISO15919_LETTERS = "āīūēōṭḍṇṅñḷḻṟṛśṣṁḥôêẏġ"` (`validate_decks.py:123`) has ṁ (U+1E41) and no ṃ (U+1E43). The 20 of 50 existing items that differ from the engine include every `ṃ` ("ahaṃ jānāmi", "agniṃ paśya"). Today they pass only because `vsn` has no romanisation file. The moment `decks/vsn/vsn-romanisation.yaml` exists (needed for the `typed` pairs below), `ISO_ROMAN_RE` (`:129-130`) rejects `ṃ`. The repo's letter is `ṁ`, and `Readings-ISO-15919` says so ("ṁ ... the anusvara"). Decision D1.
- **ऋ is `r̥` in ISO, and the repo's `ṛ` is another letter.** `ṛ` (U+1E5B) is in the validator's list because it is the nukta flap ड़ in Hindi (`Readings-ISO-15919`, the ṛ ṛh row). The existing cards write `ṛtam`, `śṛṇu`. ISO 15919's letter is `r` plus U+0325 (`r̥`), and U+0325 is in `ISO15919_MARKS` (`:125`); `r̥̄` (U+0325 then U+0304) and `l̥` too. Decision D2.
- **Accents cannot go in the reading.** `ISO_ROMAN_RE` has no acute (U+0301) and the marks list has none either; a reading can carry no accent. So the accent is dropped from the reading and `ipa`, and kept in `target` (policy in 2.5).
- **`ipa` accepts everything the design needs.** `IPA_RE` (`:141-153`) takes `ɐ ɑ ɭ ʱ ɸ ɕ ɦ`, the syllabic ring (U+0329), the nasal tilde (U+0303), `ː`, `.`, and the tone letters U+02E5-U+02E9. Every output of the prototype fullmatches `IPA_RE` and `ISO_ROMAN_RE` (checked by compiling the validator's own constants in a scratch script; `validate_decks.py` itself was not run).

## 2. The `vedic` engine

### 2.1 How an engine is registered today, read-only

- **Script block.** `BLOCKS` (`tools/transcribe.py:36-38`) maps a code to the first code point of the Indic block; `parse(text, lang)` (`:107-213`) turns a word into `Unit`s (kinds C, V, S, I, N, M, H, VIR, SP, P) by offset in the block, using the shared tables `VOWELS`, `SIGNS`, `CONSONANTS`, `COMPOSED`.
- **Per-language tables.** `VOWEL_TABLES` (`:289`) and `CONSONANT_TABLES` (`:349`), keyed by code, give each language its ISO letters and IPA for a vowel name or consonant letter.
- **Dispatch.** `transcribe()` (`:729`) sends `es`, `fr`, `ja`, `ko`, `zh`, `tok`, `ml` and `ta` to their own function (`:732-747`: `malayalam(text, hint)`, `tamil(text)`), then tries `WORDS` (`:715`, hand-pinned words), then the generic Indic path `_transcribe` (`:775`), which needs a hint to decide inherent vowels. `tamil()` (`:2202`) is the model: no hint, parse, walk the units, look each up in the tables, join. `main()` (`:2241`) is the CLI: `python3 tools/transcribe.py <code> "<word>"`.
- **Tests.** `tools/test_transcribe.py`, one `unittest.TestCase` per language (`TamilTest` at `:689`).
- **Other tools that switch on `BLOCKS`.** `tools/import_wiktionary.py:406` (`lang = code if code in transcribe.BLOCKS else SCRIPT_LANG.get(script)`) and `tools/review_bot.py:717`. **Today `vsn` is read with Hindi's rules** by `import_wiktionary` (devanagari maps to `hi`): wrong for a language with no schwa deletion. Adding `vsn` to `BLOCKS` fixes that; `sa` is in `OWN_RULES` (`import_wiktionary.py:375`), which is checked first (`:402-404`) and leaves Sanskrit words unread; that entry is removed when the engine for `sa` lands (decision for the `sa` session).
- **No `sa` or `vsn` entry exists** in `BLOCKS`, `VOWEL_TABLES`, `CONSONANT_TABLES` or `tools/phonetic_languages.yaml`. A search of open and closed issues and pull requests on 2026-11-16 (`gh api repos/aaronified/fluenough/pulls`, issues search) and of the branches on `origin` finds **no PR or branch for a Sanskrit engine**: only #356 (New course: Sanskrit, open) and #1206. Nothing to merge with; the design below is for both courses.

### 2.2 Registration

One function serves both: `vedic(text: str, variety: str) -> Transcription`, with `variety` `"vsn"` or `"sa"`. Changes, all in `tools/transcribe.py`:

1. `BLOCKS`: add `"vsn": 0x0900, "sa": 0x0900` (whoever lands first adds both).
2. `transcribe()`: `if lang in ("vsn", "sa"): return vedic(text, lang)`, next to `ta`. The `hint` argument is ignored (no hint is needed; `fitted` is always True), like Tamil.
3. `parse()`: three gated additions, each guarded by `lang in ("vsn", "sa")` so no other language changes: (a) the vocalic ऌ ॡ and signs ॢ ॣ, which `parse` reads only for `te` today (`:179-181` and `_vowel_after`, `TE_VOWELS` and `TE_SIGNS`); (b) the avagraha ऽ, which `parse` drops without a trace (`:200-202`), becomes a `P` unit holding `'`; (c) nothing else: accents are removed before `parse` (2.5), because `parse` turns them into `P` units that `tamil()`-style joiners append to the reading (measured: `parse("अ॒ग्निः")` gives `V a, P ॒, C g, C n, S i, H`).
4. `CannotRead` (`:1815`, already defined) is raised, with the offending character, for anything outside the tables of 2.3, never passed through (today `parse` passes unknown characters through as `P`, e.g. `parse("ॐ")` gives `P ॐ`, `parse("ऌ")` gives `P ऌ`, `parse("ᳵ")` gives `P ᳵ`).
5. `tools/test_transcribe.py`: `VedicTest` (2.7). `tools/phonetic_languages.yaml` and `decks/vsn/vsn-phonetics.yaml`: 2.8 and 2.9.

### 2.3 Rule tables

Reading letters are **based on ISO 15919** (the repo's standing words, `Readings-ISO-15919`), IPA is the course's broad `ipa` convention (`tools/transcribe.py:339-348`, `_IPA`: no tie bars, `t̪ d̪` for the dentals, `ɡ`, `ɦ`, `ʋ`, `tʃ dʒ`, breathy `ʱ`). Sound values are the reconstructed ones of Wikipedia's *Sanskrit* and *Vedic Sanskrit* articles; **to pin** in Whitney and Macdonell by VSA-001 before any card note claims them.

**Vowels** (name from `VOWELS` and `SIGNS`; the inherent vowel is `a`):

| Devanagari | Name | Reading | `ipa` | Note |
|---|---|---|---|---|
| अ | a | a | ɐ | Wikipedia: [ɐ], a closer vowel than ā |
| आ | aa | ā | aː | |
| इ ई | i, ii | i, ī | i, iː | one value per length |
| उ ऊ | u, uu | u, ū | u, uː | |
| ऋ | r | r̥ (r, U+0325) | r̩ | syllabic r |
| ॠ | rr | r̥̄ (r, U+0325, U+0304) | r̩ː | |
| ऌ | l | l̥ | l̩ | occurs in the root कॢप् only; ॡ is a grammarians' letter, no word |
| ए | e | ē | eː | decision D3; ISO 15919 and Hindi's rule (`hi` writes ē) |
| ओ | o | ō | oː | |
| ऐ | ai | ai | `sa` ɑi; `vsn` aːi | Vedic ai is a long diphthong āi (Wikipedia citing Macdonell 1916, pp. 4-5; to pin) |
| औ | au | au | `sa` ɑu; `vsn` aːu | likewise āu |

**Consonants** (letter from `CONSONANTS`; reading = the letter; IPA from `_IPA` unless changed):

| Row | Letters (reading / `ipa`) |
|---|---|
| velar | k kʰ, g ɡ, gh ɡʱ, ṅ ŋ (kh kʰ) |
| palatal | c tʃ, ch tʃʰ, j dʒ, jh dʒʱ, ñ ɲ |
| retroflex | ṭ ʈ, ṭh ʈʰ, ḍ ɖ, ḍh ɖʱ, ṇ ɳ |
| dental | t t̪, th t̪ʰ, d d̪, dh d̪ʱ, n n |
| labial | p p, ph pʰ, b b, bh bʱ, m m |
| semivowels | y j, r r, l l, v ʋ |
| sibilants, h | ś ʃ (narrow ɕ by rule), ṣ ʂ, s s, h ɦ |
| Vedic | ळ ḷ ɭ (an intervocalic allophone of ḍ, Wikipedia citing Macdonell 1916, pp. 16-17); **ळ्ह ḷh ɭʱ** (written as one unit, 2.4) |
| conjunct values | ज्ञ reading jñ, `ipa` dʒɲ (as the 30 cards write it; Hindi's gy, Marathi's dny are not used); क्ष kṣ, kʂ; all other conjuncts are letter for letter, a held consonant is its letter twice (त्त t̪t̪, त्थ t̪t̪ʰ) |

**Signs and marks:**

| Sign | Reading | `ipa` | Rule |
|---|---|---|---|
| virama ् | none | none | the vowel is not said; **no inherent-a deletion anywhere else**: a final consonant with no virama keeps its `a` (न: na, nɐ). This is the central difference from `hi`'s `_schwa_drops` (`:678`) |
| ः visarga | ḥ | h | voiceless breath (Wikipedia). Echo vowels of some recitation traditions are not written |
| ᳵ U+1CF5 jihvāmūlīya | ḥ | x | a letter; before k, kh. The reading is ḥ because `ISO_ROMAN_RE` has no ẖ; the edition's choice stays in `target` |
| ᳶ U+1CF6 upadhmānīya | ḥ | ɸ | before p, ph |
| ः before k kh p ph | ḥ | x, ɸ **only if** `visarga_allophones` is set, off by default | traditions differ (to pin: Whitney on visarga); off for both varieties until pinned |
| ं anusvara | before a stop: that stop's nasal (ṅ ñ ṇ n m; IPA ŋ ɲ ɳ n m); before y r l v ś ṣ s h and at the end: ṁ | the preceding vowel nasalised (the tilde, U+0303: ɐ̃) before y r l v ś ṣ s h and at the end | the repo's rule for every anusvara (`Readings-ISO-15919`, "Anusvara ं and the nasal vowel"; `te-romanisation`), with the reading letter **ṁ**, never ṃ (D1). Whitney (cited in Wikipedia) also separates m-like before r ś ṣ s h and nasalised-plus-gemination before y l v; **left out**, one open question, not decided here |
| ँ candrabindu | m̐ (m, U+0310) | nasal vowel (tilde) | |
| ऽ avagraha | `'` | none | marks an elided a; the preceding vowel is as written |
| digits ०-९ | 0-9 | none | numbers in prose |
| pluti ३ after a vowel | the vowel and 3 (ā3) | the vowel with ːː (aːː) | three morae (Wikipedia, *Pluti*); only if a source card needs it; otherwise CannotRead |
| । ॥ | `.` | none | as every other Devanagari course |
| space | space | space | words are read separately; **no sandhi** is applied across words (hiatus stays hiatus, as written) |

**Refused with `CannotRead`** (so a wrong reading is never produced): the nukta letters and U+093C (`COMPOSED` 0x0958-0x095F), ऩ ऱ ऴ, the candra and short vowels ऍ ऑ ऎ ऒ and their signs, ॐ (its value is **to pin**; a `WORDS` entry later), ऀ, any character outside Devanagari, Latin letters and the signs above, and anything in the Vedic Extensions block that is not an accent or ᳵ ᳶ.

### 2.4 Edge cases

1. **ळ्ह is two letters in Unicode and one sound.** `parse("ळ्ह")` gives `C ḷ, C h`. The walker joins `ḷ` + `h` into reading `ḷh` and IPA `ɭʱ`; without the join it would write `ɭɦ`.
2. **Inherent a at a word's end**, with or without an accent mark after it (`क॑`: the accent lands on the `I` unit).
3. **Accent before the vowel sign.** Editions put the mark after the sign (base, sign, accent, canonical); some files put it between consonant and sign. The accent pass (2.5) removes marks first, so the order never reaches `parse`.
4. **Stacked marks** (U+0952 under, U+0951 above): both removed.
5. **Anusvara at a word's end, before a space**: nasalised vowel, reading ṁ (`अहं`: ahaṁ, ɐɦɐ̃).
6. **Anusvara before a vowel** (start of the next word after sandhi): read at the unit level, not across a space, so nasalised vowel and ṁ.
7. **Visarga inside a word** before a consonant (`दुःख`): ḥ, h; not a vowel.
8. **Conjunct with ज्ञ and with ह्न** are letter for letter (`वह्नि`: vahni); only ज्ञ has a stated sound.
9. **NFC.** The input is NFC-normalised first (the validator requires NFC of `reading` and `ipa`, `:2326`, `:2418`); output is NFC (`r` + U+0325 has no precomposed form and stays two code points; a nasalised vowel stays vowel plus U+0303).
10. **Pre-composed ळ?** None exists. U+0933 is already ळ; U+0934 is ऴ (refused).

### 2.5 Accent policy

1. **`target` keeps the marks** the source edition prints (U+0951, U+0952; the Vedic Extensions in cores only, 1.1). A card carries accents only where its source does, and only in the accent-marks script deck and in verse excerpts (1.3 policy a). No accent is added or moved by a tool.
2. **The engine strips accents before parsing**, with a single set `VEDIC_ACCENT_MARKS`: U+0951-U+0952 and U+1CD0-U+1CD2, U+1CD4-U+1CE8, U+1CED, U+1CF4, U+1CF8, U+1CF9, U+A8E0-U+A8F1 (all combining marks; not U+0953, U+0954, which are refused; not U+1CD3, U+1CE9-U+1CF3, U+1CF5, U+1CF6, which are letters or punctuation). An accent is therefore never in `reading` and never in `ipa`.
3. **The engine reports where the accents were**, so a contributor can check a card against its source: `Transcription.notes` (`transcribe.py:696-700`, an existing field) gets one line per accent, such as `svarita on syllable 2`. The CLI prints the notes. The validator never sees them.
4. **`ipa` has no pitch marks.** The Vedic accent is pitch, not stress (Wikipedia, *Vedic Pitch Accent*); `ˈ` would teach the classical stress, which is a different system. The narrow `phonetic` has none either, because it is derived from `ipa` by regular expressions that cannot know the accent; tone letters (U+02E5-U+02E9 pass `IPA_RE`) are an open question for a Vedicist, not a task.
5. **Typed answers**: the Latin reading carries no accent, so the grader's reading path is unaffected (1.3). Typed Devanagari follows 1.3 (a), (b), (c).
6. **The `sa` variety** strips accents silently and reports them the same way; classical texts seldom carry them.

### 2.6 What the engine gives for the 30 existing cards (measured)

A scratch prototype of 2.3 (not in the repository) was run on the 30 cards and their 20 examples of `decks/vsn/vsn-first-words.yaml` and `vsn-phrasebook.yaml`: **50 items, 20 differ in the reading, 48 in the `ipa`**. Every difference is a rule of 2.3 meeting a hand-written value, never silent:

| Pattern | Cards write | Engine writes | Cause |
|---|---|---|---|
| anusvara | ahaṃ, tvaṃ, agniṃ (6 items) | ahaṁ, tvaṁ, agniṁ | D1: ṁ, the repo's and the validator's letter |
| e, o | devaḥ, ekaḥ, namaste, ehi (12 items) | dēvaḥ, ēkaḥ, namastē, ēhi | D3: ē ō |
| ऋ | ṛtam, śṛṇu (2 items) | r̥tam, śr̥ṇu | D2 |
| short a | ə (əhəm) | ɐ | Wikipedia's [ɐ]; the cards copy Hindi's schwa |
| short i | ɪ (əɡnɪh) | i | one value per length |
| ऋ IPA | rɯ (ṛtam) | r̩ | rɯ is Malayalam's value, not Sanskrit's |
| aspirates | dʰ bʰ | d̪ʱ bʱ | voiced aspirates are breathy, `ʱ` (the repo's table) |
| dentals | t d | t̪ d̪ | the repo's broad `ipa` writes the dentals |
| ऐ | əi | aːi | Vedic long diphthong (variety delta) |
| अनुस्वार IPA | əm (tvəm) for the final anusvara | ɐ̃ (tvɐ̃) | nasalised vowel; but final म् stays `m` (tvam: t̪ʋɐm) |

The prototype disagreed with the cards in readings in only three ways (ṃ, ē ō, r̥). **Per CLAUDE.md the cards are not silently edited:** after the engine merges, VSA-110 regenerates the 30 `reading` and `ipa` pairs and records each change in `docs/review-queue/vsn.md` (VSA-120); the readings change in the same PR as `vsn-romanisation.yaml`, since the validator starts checking them then.

### 2.7 Tests (behavioural, few)

In `tools/test_transcribe.py`, class `VedicTest`. Each test pins behaviour, not a table:

1. **No inherent-a deletion, final a kept**: `transcribe("वदामि", "vsn").reading == "vadāmi"`; `transcribe("न", "vsn").reading == "na"` (and `ipa == "nɐ"`).
2. **Accents never leak and are reported**: `transcribe("अ॒ग्निः", "vsn")` has the reading and `ipa` of `"अग्निः"`, and `notes` names an anudātta; same for `"अ॑ग्निः"` and a string with U+1CDA (an accent) inside a word.
3. **Anusvara per the repo's rule**: `"संतः"` reading `santaḥ` (n before a dental stop); `"संशयः"` reading `saṁśayaḥ` with a nasalised first vowel; word-final `"अहं"` reading `ahaṁ`.
4. **Letters of the validator**: for a handful of words (ऋ ॠ ऌ ळ ळ्ह ज्ञ and a visarga word), every reading `fullmatch`es `validate_decks.ISO_ROMAN_RE` and every `ipa` `IPA_RE` (the test imports the two constants; it does not run the validator). This ties the engine to the validator's letters, so `ṃ` or a stray accent fails here.
5. **ळ and ळ्ह**: `"ईळे"` gives `īḷē`, `iːɭeː`; `"ळ्ह्"` gives `ḷh`, `ɭʱ` (a letter sequence, no word claimed).
6. **jihvāmūlīya and upadhmānīya**: `"ᳵक"` gives IPA starting `x`, `"ᳶप"` starting `ɸ`.
7. **Variety delta**: `ऐ` is `aːi` for `vsn` and `ɑi` for `sa`.
8. **CannotRead, never a wrong reading**: a nukta letter, ॐ, ऑ and a Latin letter inside the word each raise `CannotRead`.

No test reproduces the 30 cards (they disagree on purpose, 2.6).

### 2.8 Registry entry for `tools/phonetic_languages.yaml`

Measured on the first 60 MB of the kaikki.org Sanskrit dump (5,676 entries, 2026-11-16): 524 narrow `[ ]` forms, **282 tagged `Classical-Sanskrit`, 239 tagged `Vedic` (168 words)**, 1 noted `Early Rigvedic`. So the data to import exists and is tagged, but the forms use conventions the course's broad `ipa` does not: syllable dots (`[it̚.t͡ɕʰɐ́.ti]`), unreleased stops (`d̚`), a tie bar (`t͡ɕ`), `ɕ`, an acute on the stressed vowel (`ɐ́`; Wiktionary's marker, not a Vedic pitch) and syllabic `r̩`. As with Assamese and Kannada (`phonetic_languages.yaml` comments), the entry is therefore **rules only** in the first PR:

```yaml
"vsn":
  dump: "Sanskrit"
  variety:
    # Measured on the kaikki.org Sanskrit dump (first 60 MB, 2026-11-16): of 524
    # narrow forms, 239 are tagged "Vedic" (168 words) and 282 "Classical-Sanskrit".
    # The Vedic forms write syllable dots, unreleased stops (d̚), t͡ɕ, ɕ and an
    # acute (ɐ́) where the course's `ipa` writes none of them, so the form is NOT
    # taken (untagged: false, no tags): nothing is imported, and every Vedic card
    # gets its narrow form from decks/vsn/vsn-phonetics.yaml. Flip to
    # tags: ["Vedic"] only after a `normalise` list for dots, d̚, ties, ɕ and the
    # acute exists and tools/test_phonetic.py is widened past its Spanish-only test.
    name: "Vedic Sanskrit; no Wiktionary form is taken (rules only)"
    untagged: false
```

`sa` gets the same entry with `"Classical-Sanskrit"` in its comment, written by the `sa` session. (This entry mirrors `"as"` and `"kn"` in the same file; `tools/test_phonetic.py` reads the registry, so the PR checks that it loads.)

### 2.9 Shape of `decks/vsn/vsn-phonetics.yaml`

Keys are fixed by `PHONETICS_KEYS` and `PHONETIC_RULE_KEYS` (`validate_decks.py:165-166`): `schema`, `kind`, `id`, `language`, `variety`, `description`, `rules`; each rule `id` (starts `vsn-`), `pattern` (a regular expression), `replace`, `source` (a work, author and year). The file is on `decks-live`, as `decks/te/te-phonetics.yaml` and `decks/hi/hi-phonetics.yaml` are, and is read only by `tools/derive_phonetic.py`. It applies to the broad `ipa` the engine writes, in order. Rules proposed for the first version, each only if VSA-001 attests it; any rule not attested is left out, not guessed:

```yaml
schema: 1
kind: "phonetics"
id: "vsn-phonetics"
language: "vsn"
variety: "Reconstructed Vedic Sanskrit (Rigveda), as the course's broad ipa writes it"
description: "Rules that turn a card's broad ipa into its narrow [ ] form, in order. Written for tools/derive_phonetic.py, never read by the app. ..."
rules:
  - id: "vsn-sh-palatal"          # ś is a palatal sibilant: ʃ becomes ɕ
    pattern: 'ʃ'
    replace: 'ɕ'
    source: '<Macdonell, A Vedic Grammar for Students (1916), the sibilants; Wikipedia, Sanskrit, "Consonants" (CC BY-SA 4.0)>'
  - id: "vsn-n-velar"             # a nasal before a stop is homorganic (catches what the engine left)
    pattern: 'n(?=ˈ?[kɡ])'
    replace: 'ŋ'
    source: '<Whitney, Sanskrit Grammar (1879), the nasals>'
  - id: "vsn-n-palatal"           # n(?=ˈ?(?:tʃ|dʒ)) -> ɲ
  - id: "vsn-n-retroflex"         # n(?=ˈ?[ʈɖ]) -> ɳ
  - id: "vsn-n-bilabial"          # n(?=ˈ?[pb]) -> m
```

(the bracketed sources are placeholders for VSA-001's pinned pages; the three omitted `pattern` and `replace` lines are those of `te-n-palatal`, `te-n-retroflex`, `te-n-bilabial`). `vsn-sh-palatal` is why the broad `ipa` keeps `ʃ`, the course-wide convention of every Indic course, while the narrow form says `ɕ`. A `vsn-romanisation.yaml` is written in the same PR as the engine (the keys of `ROMANISATION_KEYS`, `validate_decks.py:118`): `standard: "ISO 15919"`, `typed` pairs that say how a learner types the letters the keyboard lacks (`r̥` as `ri` or `ru`, `ṁ` as `m`, `ḥ` as `h`, `ḷ` as `l`, `ē ō` as `e o`, `ś ṣ` as `sh`, `ṭ ṭh ḍ ḍh ṇ` as `t th d dh n`), and `equivalents` for the spellings people type for one sound (the `hi` and `te` files are the models).

## 3. Decisions made with a default, recorded

The owner's rule is to decide what has a sensible default and to say what was decided. All five are reversible by changing one table row.

| # | Decision | Default | Alternative |
|---|---|---|---|
| D1 | Anusvara letter | `ṁ` (repo, validator, ISO 15919) | `ṃ` (the 30 cards; IAST): needs `ISO15919_LETTERS` extended in `validate_decks.py`, a tools change |
| D2 | ऋ | `r̥` (ISO 15919, U+0325, accepted today) | `ṛ` (the 30 cards): collides with the nukta flap letter of Hindi |
| D3 | ए ओ | `ē ō` (ISO 15919; Hindi's rule: a language with no short e o) | `e o` (the cards; Marathi's rule) |
| D4 | ś, broad `ipa` | `ʃ` (every Indic course), narrow `ɕ` by rule | `ɕ` already in `ipa` |
| D5 | Vedic ai au | `aːi aːu` (long diphthongs; Wikipedia citing Macdonell) | `ɐi ɐu` as Classical |

Open for a Vedicist, never a default: whether Vedic e and o are the diphthongs `ai` and `au` (Wikipedia, citing Macdonell 1916, pp. 4-5, says they were), Whitney's m-like and gemination anusvara values before r ś ṣ s h and y l v, the `visarga_allophones` setting, pitch marks in the narrow IPA, and the value of ॐ.

## 4. GitHub issue for the parent to file

**Title:** `Sanskrit transcription engine in tools/transcribe.py for sa and vsn (VSA-110)`

**Body:**

```
Vedic Sanskrit (`vsn`) and Classical Sanskrit (`sa`) have no engine in `tools/transcribe.py`, so every reading and broad `ipa` of both was written by hand, and the narrow `phonetic` is blocked. `vsn` words are today read with Hindi's rules by `tools/import_wiktionary.py` (`SCRIPT_LANG["devanagari"]`, `:406`), which deletes schwas Sanskrit keeps. One shared Devanagari engine serves both. Tracker: #1206 (vsn), #356 (sa). Plan and evidence: wiki/Plan-Vedic-Engine.md. No branch or PR for a Sanskrit engine exists (checked 2026-11-16).

Build (`tools/transcribe.py`, `tools/test_transcribe.py` only):
- `"vsn": 0x0900, "sa": 0x0900` in `BLOCKS`; `transcribe()` sends both to `vedic(text, variety)`, no hint, `fitted` True (as `tamil()`, `:2202`).
- `parse()`, gated by `lang in ("vsn", "sa")`: read ऌ ॡ ॢ ॣ (today `te` only, `:179`), turn the avagraha ऽ into `'` (today dropped, `:200`). Accents (U+0951, U+0952, U+1CD0-U+1CF9 marks, U+A8E0-U+A8F1) are stripped BEFORE `parse`, which would otherwise return them as `P` units that leak into the reading; each is reported in `Transcription.notes`.
- Reading in ISO 15919's letters, no inherent-a deletion, anusvara homorganic before a stop and `ṁ` elsewhere (never `ṃ`: `ISO15919_LETTERS`, `validate_decks.py:123`, has no `ṃ`), visarga `ḥ`, ऋ `r̥`, ळ `ḷ`, ळ्ह `ḷh`, ज्ञ `jñ`, jihvamuliya and upadhmaniya `ḥ`; broad IPA from `_IPA` plus a Sanskrit vowel table (a ɐ, ā aː, ṛ r̩, ळ ɭ, ळ्ह ɭʱ, visarga h, nasalised vowel for anusvara, ᳵ x, ᳶ ɸ); variety delta: `ai au` are `aːi aːu` for vsn and `ɑi ɑu` for sa. `CannotRead` for nukta letters, ॐ, ऑ-type vowels and unknown characters, never a pass-through.
- Eight behavioural tests (wiki, 2.7), including that every output fullmatches `validate_decks.ISO_ROMAN_RE` and `IPA_RE` (imported, validator not run).
- Registry entry `"vsn"` (rules only, `untagged: false`, as `as` and `kn`) in `tools/phonetic_languages.yaml`; `sa` the same, by the sa session. `decks/vsn/vsn-phonetics.yaml` and `vsn-romanisation.yaml` follow (deck PRs on decks-live).
- When it lands, remove `"sa"` from `OWN_RULES` in `tools/import_wiktionary.py` (`:375`).

Evidence (VSA-100, all on main f8d59607 / decks-live d05ac818):
- Validator: `target` is not script-checked; U+0951 and U+0952 pass everywhere; Vedic Extensions marks are rejected only in `target_scripts.devanagari` and character-kind texts (`SCRIPT_BLOCKS["devanagari"]` = U+0900-097F, U+A8E0-A8FF, `:103`, `_letters_in` `:958`) and cut a word in two in a layer's prose (`_SCRIPT` = U+0900-0DFF, `:2786`).
- Font: `decks/fonts/devanagari/NotoSansDevanagari.ttf` (v2.007, same blob on main and decks-live) covers U+0951, U+0952, all of U+A8E0-U+A8FF and U+1CD0-U+1CF9 except U+1CF7.
- Grader: `foldDiacritics` (`lib/core/grading/diacritics.dart:86-98`) does not drop U+0951, U+0952 or the Vedic marks, so typed Devanagari must match accents; A1 cards carry none in `target`, and `alt_target` holds an unmarked spelling.
- Measured on the 30 cards and 20 examples (scratch prototype): 50 items, 20 readings differ (ṃ to ṁ, e o to ē ō, ṛ to r̥), 48 `ipa` differ (ə to ɐ, ɪ to i, rɯ to r̩, ʰ to ʱ, dentals). Nothing is edited silently: the changes go to docs/review-queue/vsn.md.

Not in this issue (separate, small, tools/lib): extend `_SCRIPT` and `SCRIPT_BLOCKS["devanagari"]` to U+1CD0-U+1CFF and U+A8E0-U+A8FF; add the Vedic accent marks to the grader's dropped-mark group; decide D1 to D5 (wiki, section 3) if the owner prefers the other letter.
```

## 5. Order of work

1. VSA-001 pins the pages for the **to pin** values (alphabet and sounds in Whitney, Macdonell).
2. The issue of section 4 is filed; VSA-110 builds the engine on `tools/vsn-transcribe` (a PR to main, CI only), after checking with the `sa` session that it is not building its own.
3. Then `vsn-romanisation.yaml` and `vsn-phonetics.yaml` on `decks-live`, the 30 cards regenerated with review-queue rows (VSA-120), and the script decks VSA-070 to VSA-075 (the accent-marks deck with its rendered check).
