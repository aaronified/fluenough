/// Folding a Latin letter's diacritics away, for comparing answers and for
/// searching names. Free of Flutter, so that `lib/core` can use it
/// anywhere.
library;

/// [input] with each Latin letter's diacritics stripped, by the table below:
/// `niño` is `nino`, `kitnā` is `kitna`.
String foldDiacritics(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticFolding[char] ?? char);
  }
  return buffer.toString();
}

/// [char], one character, with its diacritics folded away as
/// [foldDiacritics] folds them: itself when it has none, and possibly
/// empty or two letters long.
String foldCharacter(String char) => _diacriticFolding[char] ?? char;

/// Diacritic folding for Latin and Cyrillic-adjacent scripts, for the
/// letters ISO 15919 adds, which the Indic readings use (ADR-0025), for
/// pinyin's caron vowels, and for the transliteration letters of Egyptian
/// (ꜣ ꜥ ḫ ẖ ṯ ḏ ḳ) and of Proto-Indo-European and Sumerian (ʰ ʷ, subscripts).
/// The raised letters of Sumerian determinatives (ᵈ ᵏⁱ) are not here:
/// [RomanisedSpelling] reads them as optional.
/// The apostrophe-like letters ʾ ʿ ʼ ʻ are not here: [RomanisedSpelling.key]
/// drops everything but letters and digits, so they cost nothing to leave off.
///
/// Dart's core library has no Unicode normalisation, so this is an explicit
/// table rather than an NFD decomposition. It covers Latin-1 Supplement and
/// Latin Extended-A, which is every language Fluenough currently ships a deck
/// for. Scripts needing real NFD handling will need a normalisation package;
/// tracked in the roadmap.
final Map<String, String> _diacriticFolding = _buildFolding({
  'a': 'áàâäãåāăąǎǻꜥ',
  'c': 'çćĉċč',
  'd': 'ďđḍ',
  'e': 'éèêëēĕėęěḗẽ',
  'g': 'ĝğġģǵ',
  'h': 'ĥħḥʰ',
  'i': 'íìîïĩīĭįıǐ',
  'j': 'ĵ',
  'k': 'ķḵḱ',
  'l': 'ĺļľłŀḷḻḹ',
  'm': 'ṁṃḿ',
  'n': 'ñńņňŉṇṅṉ',
  'o': 'óòôöõōŏőøǒṓ',
  'r': 'ŕŗřṛṟṝ',
  's': 'śŝşšṣ',
  't': 'ţťŧṭ',
  'u': 'úùûüũūŭůűųǔǖǘǚǜ',
  'w': 'ŵʷ',
  'y': 'ýÿŷẏ',
  'z': 'źżž',
  // Subscript digits, for the sign indices of cuneiform (du₃) and the
  // laryngeals of Proto-Indo-European (h₂): typed as plain digits. The 3
  // is also Egyptian ꜣ, as ASCII Egyptology types it.
  '0': '₀',
  '1': '₁',
  '2': '₂',
  '3': '₃ꜣ',
  '4': '₄',
  '5': '₅',
  '6': '₆',
  '7': '₇',
  '8': '₈',
  '9': '₉',
  // Egyptian letters, each kept apart from the plain one it is not: a
  // folded ꜣ ꜥ ḫ ẖ ṯ ḏ ḳ would let ḫrw (voice) pass for hrw (day) and Rꜥ
  // for Rꜣ. ꜥ is typed a, ꜣ as the 3 of ASCII Egyptology, ḫ ṯ ḏ as kh th dh,
  // ẖ as ch and ḳ as q (the course writes q). ḥ still folds to h, as it does
  // for the Indic readings.
  'kh': 'ḫ',
  'ch': 'ẖ',
  'th': 'ṯ',
  'dh': 'ḏ',
  'q': 'ḳ',
  'ae': 'æ',
  'oe': 'œ',
  'ss': 'ß',
  // The nukta, which Devanagari and Bengali writers often leave off: ज for
  // ज़. After [canonical] it is always a mark of its own, so dropping it is
  // "right, but watch the nukta", not a miss.
  '':
      '\u093C\u09BC'
      // And the combining marks a letter may carry in place of a composed
      // one: macron, dot below, candrabindu, ring below, tilde, and the
      // double macron below of k͟h.
      '\u0304\u0323\u0310\u0325\u0303\u035F'
      // Acute, grave, circumflex, dot above, diaeresis, caron and macron
      // below, as a tone mark or a letter's mark may be typed apart from it.
      '\u0300\u0301\u0302\u0307\u0308\u030C\u0311\u0331'
      // The Arabic-script vowel marks (harakat: fatha, damma, kasra, their
      // tanwin, shadda, sukun) and the dagger alif, and the tatweel, which a
      // learner leaves off as native writers do.
      '\u064B\u064C\u064D\u064E\u064F\u0650\u0651\u0652\u0670\u0640',
});

Map<String, String> _buildFolding(Map<String, String> groups) {
  final folding = <String, String>{};
  groups.forEach((plain, accented) {
    for (final rune in accented.runes) {
      folding[String.fromCharCode(rune)] = plain;
    }
  });
  return folding;
}
