import '../review/fix_text.dart' show nfc;

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
/// Dart's core library has no Unicode normalisation: [nfc] (the app's own,
/// in `review/fix_text.dart`) puts Latin, the IPA and Hangul in one form,
/// and this table covers the scripts the app ships
/// decks for: Devanagari, Bengali, Gujarati, Telugu and Kannada. It is data, and a new script
/// adds its rows. It also reads the Indic digits as 0–9 and ignores the
/// zero-width joiner and non-joiner, which change a conjunct's shape and
/// never its letters.
String canonical(String input) {
  // Latin and the IPA too (#1221): é typed as e and a combining acute is the
  // é of the deck, and a Korean syllable typed as jamo is the syllable. NFC
  // first; the rows below then take apart what they need to, the same on
  // both sides.
  input = nfc(input);
  if (!_mayChange(input)) return input;
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune == _zwnj || rune == _zwj) continue;
    final digit = _digit(rune);
    if (digit != null) {
      buffer.writeCharCode(0x30 + digit);
      continue;
    }
    final variant = _letterVariants[rune];
    if (variant != null) {
      buffer.writeCharCode(variant);
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

/// The IPA's single-storey g, U+0261: the IPA says it and the ASCII g are
/// the same letter, and the keyboard's key is one the learner cannot tell
/// from the other.
const int _ipaG = 0x0261;

const int _zwnj = 0x200C;
const int _zwj = 0x200D;

/// The first code point of each script's run of ten digits.
const List<int> _zeros = <int>[
  0x0966, // Devanagari ०
  0x09E6, // Bengali ০
  0x0AE6, // Gujarati ૦
  0x0C66, // Telugu ౦
  0x0CE6, // Kannada ೦
  0x0660, // Arabic-Indic ٠
  0x06F0, // Persian and Urdu ۰
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
    if (unit >= 0x0600 || unit == _zwnj || unit == _zwj || unit == _ipaG) {
      return true;
    }
  }
  return false;
}

/// Arabic letters that keyboards give in place of the Urdu and Persian ones
/// that look the same: ي for ی, ك for ک, ه for ہ. One spelling, on both
/// sides; not part of [composed], which only puts decomposed letters back.
const Map<int, int> _letterVariants = <int, int>{
  0x064A: 0x06CC, // ي to ی
  0x0643: 0x06A9, // ك to ک
  0x0647: 0x06C1, // ه to ہ
  _ipaG: 0x0067, // ɡ to g (IPA)
};

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
  // Kannada: the two-part vowel signs. ೋ before ೊ, whose spelling begins
  // it, so that [composed] puts ೋ back whole.
  0x0CCB: 'ೋ', // ೋ
  0x0CCA: 'ೊ', // ೊ
  0x0CC0: 'ೀ', // ೀ
  0x0CC7: 'ೇ', // ೇ
  0x0CC8: 'ೈ', // ೈ
};

/// [input] as [canonical] spells it, with each decomposed letter put back
/// together: ে then া is ো again, ড then the nukta is ড়. For comparisons
/// that must see whole letters, such as which sound a word differs by
/// (#89): taken apart, ো would look like ে with an া added.
String composed(String input) {
  var out = canonical(input);
  for (final MapEntry(:key, :value) in _decompositions.entries) {
    out = out.replaceAll(value, String.fromCharCode(key));
  }
  return out;
}
