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

/// Diacritic folding for Latin and Cyrillic-adjacent scripts, and for the
/// letters ISO 15919 adds, which the Indic readings use (ADR-0025).
///
/// Dart's core library has no Unicode normalisation, so this is an explicit
/// table rather than an NFD decomposition. It covers Latin-1 Supplement and
/// Latin Extended-A, which is every language Fluenough currently ships a deck
/// for. Scripts needing real NFD handling will need a normalisation package;
/// tracked in the roadmap.
final Map<String, String> _diacriticFolding = _buildFolding({
  'a': 'áàâäãåāăą',
  'c': 'çćĉċč',
  'd': 'ďđḍ',
  'e': 'éèêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħḥ',
  'i': 'íìîïĩīĭįı',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľłŀḷḻ',
  'm': 'ṁ',
  'n': 'ñńņňŉṇṅṉ',
  'o': 'óòôöõōŏőø',
  'r': 'ŕŗřṛṟ',
  's': 'śŝşšṣ',
  't': 'ţťŧṭ',
  'u': 'úùûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷẏ',
  'z': 'źżž',
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
      '\u0304\u0323\u0310\u0325\u0303\u035F',
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
