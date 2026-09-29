/// Text that looks the same, spelled the same way, before any comparison
/// (#28).
///
/// The same visible letter can be typed as different code points, depending
/// on the keyboard: Devanagari क़ is U+0958, or क followed by the nukta
/// U+093C. Compared as strings they differ, and a learner who typed the
/// right answer would be told it is wrong. This replaces each precomposed
/// form below with its canonical decomposition, on both sides, so that the
/// two spellings compare equal, as Unicode says they are.
///
/// Dart's core library has no Unicode normalisation, and full NFC needs a
/// package (AGENTS.md rule 6). This table covers the scripts the app ships
/// decks for: Devanagari, Bengali and Telugu. It is data, and a new script
/// adds its rows. It also reads the Indic digits as 0–9 and ignores the
/// zero-width joiner and non-joiner, which change a conjunct's shape and
/// never its letters.
String canonical(String input) {
  if (!_mayChange(input)) return input;
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune == _zwnj || rune == _zwj) continue;
    final digit = _digit(rune);
    if (digit != null) {
      buffer.writeCharCode(0x30 + digit);
      continue;
    }
    final decomposed = _decompositions[rune];
    if (decomposed != null) {
      buffer.write(decomposed);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

const int _zwnj = 0x200C;
const int _zwj = 0x200D;

/// The first code point of each script's run of ten digits.
const List<int> _zeros = <int>[
  0x0966, // Devanagari ०
  0x09E6, // Bengali ০
  0x0C66, // Telugu ౦
];

int? _digit(int rune) {
  for (final zero in _zeros) {
    if (rune >= zero && rune < zero + 10) return rune - zero;
  }
  return null;
}

/// Whether [input] has anything this could change, so that Latin text, the
/// common case, is returned as it is.
bool _mayChange(String input) {
  for (final unit in input.codeUnits) {
    if (unit >= 0x0900 || unit == _zwnj || unit == _zwj) return true;
  }
  return false;
}

/// Precomposed letters and their canonical decompositions, from the Unicode
/// Character Database.
const Map<int, String> _decompositions = <int, String>{
  // Devanagari: letters with nukta.
  0x0929: 'ऩ', // ऩ
  0x0931: 'ऱ', // ऱ
  0x0934: 'ऴ', // ऴ
  0x0958: 'क़', // क़
  0x0959: 'ख़', // ख़
  0x095A: 'ग़', // ग़
  0x095B: 'ज़', // ज़
  0x095C: 'ड़', // ड़
  0x095D: 'ढ़', // ढ़
  0x095E: 'फ़', // फ़
  0x095F: 'य़', // य़
  // Bengali: letters with nukta, and the two-part vowel signs.
  0x09DC: 'ড়', // ড়
  0x09DD: 'ঢ়', // ঢ়
  0x09DF: 'য়', // য়
  0x09CB: 'ো', // ো
  0x09CC: 'ৌ', // ৌ
  // Telugu: the two-part vowel sign.
  0x0C48: 'ై', // ై
};
