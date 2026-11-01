/// The script a query is written in, for the offers of other scripts
/// (#527, mockup section 7). Free of Flutter.
library;

/// The deck files' script names, with the letters each is written in.
/// `han` stands for every Chinese variant (`han_simplified`,
/// `han_traditional`) and `kana` for Japanese's two syllabaries; `arabic`
/// stands for every script written in Arabic letters (`perso_arabic`,
/// `shahmukhi`), which the letters alone cannot tell apart.
final Map<String, RegExp> _scriptLetters = <String, RegExp>{
  'latin': RegExp(r'\p{Script=Latin}', unicode: true),
  'devanagari': RegExp(r'\p{Script=Devanagari}', unicode: true),
  'bengali': RegExp(r'\p{Script=Bengali}', unicode: true),
  'telugu': RegExp(r'\p{Script=Telugu}', unicode: true),
  'kannada': RegExp(r'\p{Script=Kannada}', unicode: true),
  'gujarati': RegExp(r'\p{Script=Gujarati}', unicode: true),
  'gurmukhi': RegExp(r'\p{Script=Gurmukhi}', unicode: true),
  'tamil': RegExp(r'\p{Script=Tamil}', unicode: true),
  'malayalam': RegExp(r'\p{Script=Malayalam}', unicode: true),
  'odia': RegExp(r'\p{Script=Oriya}', unicode: true),
  'arabic': RegExp(r'\p{Script=Arabic}', unicode: true),
  'hangul': RegExp(r'\p{Script=Hangul}', unicode: true),
  'kana': RegExp(r'[\p{Script=Hiragana}\p{Script=Katakana}]', unicode: true),
  'han': RegExp(r'\p{Script=Han}', unicode: true),
  'cyrillic': RegExp(r'\p{Script=Cyrillic}', unicode: true),
  'greek': RegExp(r'\p{Script=Greek}', unicode: true),
  'hebrew': RegExp(r'\p{Script=Hebrew}', unicode: true),
  'thai': RegExp(r'\p{Script=Thai}', unicode: true),
  'linear_b': RegExp(r'\p{Script=Linear_B}', unicode: true),
  'cuneiform': RegExp(r'\p{Script=Cuneiform}', unicode: true),
  'egyptian_hieroglyphs': RegExp(
    r'\p{Script=Egyptian_Hieroglyphs}',
    unicode: true,
  ),
};

/// The script most of [text]'s letters are in, or null when it has none
/// (digits and punctuation have no script and are ignored). The names are
/// the ones deck files use; Chinese variants and the Han letters of a
/// Japanese query all read as `han`.
String? scriptOf(String text) {
  String? best;
  var most = 0;
  for (final MapEntry(:key, :value) in _scriptLetters.entries) {
    final n = value.allMatches(text).length;
    if (n > most) {
      most = n;
      best = key;
    }
  }
  return best;
}

/// Whether a course written in [courseScripts] reads a query in [script]:
/// the Chinese variants and Han are one script to the reader, and so are
/// Arabic, the Perso-Arabic of Urdu and the Shahmukhi of Punjabi.
bool scriptBelongsTo(String script, Iterable<String> courseScripts) =>
    courseScripts.any(
      (s) =>
          s == script ||
          (script == 'han' && s.startsWith('han')) ||
          (script == 'arabic' && _arabicLetters.contains(s)),
    );

const Set<String> _arabicLetters = <String>{
  'arabic',
  'perso_arabic',
  'shahmukhi',
};
