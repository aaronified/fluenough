/// Comparison folds: per-script rules for deciding whether two typed fixes
/// are the same fix (ADR-0058, decision 7, work package W5). Pure Dart.
///
/// **A fold is for comparing, never for storing or showing.** The text a
/// reviewer typed, the text a deck holds and the text a learner sees are
/// never changed by anything here. [comparisonKey] is only the key two fixes
/// are compared by: equal keys mean "the same fix, no human step".
///
/// **The rule for a fold.** It may merge only spellings that native writers
/// treat as the same letter written with a different code point, or an
/// invisible difference. It may never merge two different words. A false
/// "different" costs one extra human step (a pick among rival fixes); a false
/// "same" hides a real disagreement. So a fold stays out unless it is clearly
/// safe, and every fold left out is listed below as a TODO with its reason.
///
/// Every key starts with [normalizeFixText] (NFC and white space, see
/// `fix_text.dart`) and ends with it again. The folds in between apply to the
/// languages that name them only. `tools/review_facets.py` has the same
/// registry (`COMPARISON_FOLDS`); `test/support/comparison_fold_cases.json` is
/// read by both sides' tests so they stay equal.
///
/// ## Folds included
///
/// - `arabic-script-tatweel` (ur, fa, ps, sd, ks, hi): U+0640 ARABIC TATWEEL
///   (kashida) is dropped. It is a typographic elongation with no sound or
///   spelling of its own (Unicode Standard, ch. 9 "Arabic": "used to
///   lengthen... has no semantic value"; UAX #15 leaves it alone, so NFC does
///   not remove it).
/// - `persian-urdu-yeh` (fa, ur, hi): U+064A ARABIC LETTER YEH and U+0649
///   ARABIC LETTER ALEF MAKSURA are read as U+06CC ARABIC LETTER FARSI YEH.
///   Persian and Urdu write one letter yeh, and Arabic keyboards and legacy
///   text supply U+064A (and U+0649, which looks the same as a final Farsi
///   yeh) for it. Sources: Unicode Standard ch. 9, on Farsi yeh being the
///   Persian/Urdu form; the Persian Wikipedia and the Urdu Wikipedia
///   orthography guides, which both name the Arabic yeh and kaf as encoding
///   errors to be corrected. `hi` is in the list because the Hindustani course
///   offers the Urdu script; the fold does nothing to Devanagari text.
/// - `persian-urdu-pashto-kaf` (fa, ur, ps, hi): U+0643 ARABIC LETTER KAF is
///   read as U+06A9 ARABIC LETTER KEHEH (the Persian, Urdu and Pashto kaf),
///   same sources as above; Pashto's alphabet has the one kaf, U+06A9, and a
///   separate gaf.
/// - `arabic-script-digits` (ur, fa, ps, sd, ks, hi): the Arabic-Indic digits
///   U+0660..U+0669 are read as the Extended Arabic-Indic digits
///   U+06F0..U+06F9. Same numbers, written with different code points
///   (Unicode ch. 9, "Arabic-Indic digits"; the two sets differ in shape only
///   for 4, 5 and 6, and 7 in some fonts, and a writer of these languages
///   reads both as the digit).
///
/// ## Case (Latin and the Latin-1 letters)
///
/// [comparisonKey] folds case only when the caller says the facet is
/// case-insensitive (`caseInsensitive: true`). Nothing in the card data says
/// so today, so every caller leaves it off and a fix is case-sensitive. When
/// on, only A to Z and the Latin-1 capitals U+00C0..U+00DE (not U+00D7) are
/// lower-cased: a fixed table, so that Dart and Python agree. A capital
/// beyond that is left alone (a false "different", safe).
///
/// ## Left out, and why (each is a TODO until a speaker or the owner decides)
///
/// - Devanagari, Bengali, Assamese, Gujarati, Gurmukhi, Odia, Telugu, Kannada,
///   Malayalam, Tamil, Sinhala: **nothing beyond NFC.** NFC already merges
///   the nukta forms (for example U+0958 with U+0915 U+093C, and the Bengali
///   U+09DC, U+09DD, U+09DF), which Unicode lists as composition exclusions.
///   The zero-width joiner (U+200D) and non-joiner (U+200C) pick a conjunct's
///   shape or a chillu and so change the spelling: they are kept.
/// - Malayalam chillu letters written as consonant, virama and ZWJ against the
///   atomic chillu code points: Unicode 5.1 recommends the atomic form but does
///   not call the old sequence canonically equal. Not merged.
/// - Persian and Urdu heh: U+06BE (Urdu aspirate, a different letter: the
///   contrast between U+06A9 U+06BE and U+06A9 U+06C1 is the word), U+06C1 (Urdu
///   goal heh), U+0647 (Arabic heh), U+06D5 and U+06C0. Which one stands for
///   which depends on the language and the position in the word, and the
///   medial shapes differ, so a native writer sees a different spelling. Not
///   merged.
/// - Pashto, Sindhi and Kashmiri yeh: Pashto keeps U+064A, U+06CC, U+06D0,
///   U+06CD and U+0626 as separate letters; Sindhi and Kashmiri use more yeh
///   forms. Only fa, ur and hi merge yeh.
/// - Sindhi and Kashmiri kaf: Sindhi U+06AA (kaf) and U+06A9 (khe) are two
///   letters. Kashmiri is unconfirmed. Only fa, ur, ps and hi merge kaf.
/// - Arabic vowel marks (U+064B..U+0652, U+0670) and the hamza marks:
///   optional in running text, but dropping one can merge two words.
/// - Western digits against the Arabic-Indic and Extended sets: the same
///   number, but a different code point in a fix for a word or a reading is a
///   judgement call (a numeral in a reading or IPA is not a digit at all).
/// - Persian zero-width non-joiner (the half space of mi-ravam against
///   miravam): meaningful, kept.
/// - Japanese: half-width katakana (U+FF61..U+FF9F, with the dakuten that
///   must be composed) and full-width Latin letters and digits (U+FF01..U+FF5E)
///   are documented compatibility forms (Unicode `<narrow>`/`<wide>`), but the
///   fold needs its own table and a speaker's confirmation. Kana against kanji
///   spellings, the long-vowel mark and small kana are never merged.
/// - Korean (Hangul): NFC only; nothing else is planned.
/// - Latin: curly against straight apostrophes in readings and IPA, accents
///   against none, and case beyond Latin-1.
/// - IPA and readings: tie bars, length marks and the order of diacritics.
library;

import 'fix_text.dart';

/// One comparison fold: the code points it maps, for the languages it names.
class ComparisonFold {
  const ComparisonFold(this.id, this.languages, this.map);

  /// A stable name, the same in `tools/review_facets.py`.
  final String id;

  /// Primary language subtags (`ur`, `fa`) the fold applies to.
  final Set<String> languages;

  /// Code point to its replacement; null drops the code point.
  final Map<int, int?> map;
}

const Set<String> _arabicScript = <String>{'ur', 'fa', 'ps', 'sd', 'ks', 'hi'};

/// The registry, in the order the folds are applied.
final List<ComparisonFold> comparisonFolds = <ComparisonFold>[
  const ComparisonFold('arabic-script-tatweel', _arabicScript, <int, int?>{
    0x0640: null,
  }),
  const ComparisonFold(
    'persian-urdu-yeh',
    <String>{'fa', 'ur', 'hi'},
    <int, int?>{0x064A: 0x06CC, 0x0649: 0x06CC},
  ),
  const ComparisonFold(
    'persian-urdu-pashto-kaf',
    <String>{'fa', 'ur', 'ps', 'hi'},
    <int, int?>{0x0643: 0x06A9},
  ),
  ComparisonFold('arabic-script-digits', _arabicScript, <int, int?>{
    for (var i = 0; i < 10; i++) 0x0660 + i: 0x06F0 + i,
  }),
];

/// The primary language subtag of [language] (`ur-PK` is `ur`), lower case,
/// or null when there is none.
String? primaryLanguage(String? language) {
  if (language == null) return null;
  final head = language.trim().toLowerCase().split(RegExp('[-_]')).first;
  return head.isEmpty ? null : head;
}

/// The key [text] is compared by, for a fix in [language] (a course language
/// code, or null for text that has no script rules: readings, IPA).
/// [caseInsensitive] is for a facet the card data says is case-insensitive.
/// Never use the key as text.
String comparisonKey(
  String text, {
  String? language,
  bool caseInsensitive = false,
}) {
  var out = normalizeFixText(text);
  final code = primaryLanguage(language);
  if (code != null) {
    for (final fold in comparisonFolds) {
      if (fold.languages.contains(code)) out = _apply(fold, out);
    }
  }
  if (caseInsensitive) out = _lowerLatin(out);
  return normalizeFixText(out);
}

/// Whether [a] and [b] are the same fix: equal [comparisonKey]s.
bool sameFixIn(
  String a,
  String b, {
  String? language,
  bool caseInsensitive = false,
}) =>
    comparisonKey(a, language: language, caseInsensitive: caseInsensitive) ==
    comparisonKey(b, language: language, caseInsensitive: caseInsensitive);

String _apply(ComparisonFold fold, String text) {
  final out = <int>[];
  var changed = false;
  for (final rune in text.runes) {
    if (!fold.map.containsKey(rune)) {
      out.add(rune);
      continue;
    }
    changed = true;
    final to = fold.map[rune];
    if (to != null) out.add(to);
  }
  return changed ? String.fromCharCodes(out) : text;
}

String _lowerLatin(String text) {
  final out = <int>[];
  for (final rune in text.runes) {
    final upper =
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0xC0 && rune <= 0xDE && rune != 0xD7);
    out.add(upper ? rune + 0x20 : rune);
  }
  return String.fromCharCodes(out);
}
