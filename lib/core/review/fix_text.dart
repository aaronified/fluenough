/// Text of a proposed fix, put in one form so that two reviewers who typed
/// the same fix on different keyboards agree (ADR-0058, decision 7).
///
/// Pure Dart. Dart has no Unicode normalisation and the app takes no package
/// for it, so [nfc] is written here from the Unicode data in `nfc_data.dart`
/// (made by `tools/gen_nfc_tables.py`).
///
/// **What is normalised today:** Unicode Normalization Form C, and
/// whitespace: any run of white space (a no-break space, an ideographic
/// space, a tab, a line break) becomes one space, and the ends are trimmed.
/// Nothing else: letter case, punctuation, digits and the zero-width joiner
/// and non-joiner are left as typed, because dropping one can change a word.
///
/// TODO(per-script rules, not invented yet; each needs a speaker's or the
/// owner's decision before it is written here):
/// - Devanagari, Bengali, Gujarati, Telugu, Kannada, Malayalam, Tamil: when a
///   zero-width joiner or non-joiner is only a stray typing artefact (after
///   a vowel sign, at the end of a word) and when it picks a conjunct's
///   shape (which changes the spelling).
/// - Malayalam: chillu letters written as a consonant, virama and ZWJ
///   against the atomic chillu code points.
/// - Perso-Arabic (Hindustani's Urdu script, Persian, Pashto): Arabic yeh
///   and kaf against Persian yeh and kaf, heh forms, digits; the app's
///   `canonical` in `lib/core/grading` already folds some for answers.
/// - Japanese: full-width and half-width forms, the long-vowel mark,
///   kana against kanji spellings (never merged).
/// - Korean: nothing beyond NFC planned.
/// - Latin: curly against straight apostrophes in readings and IPA.
/// - IPA and readings: which tie bars, length marks and diacritic orders a
///   reviewer may treat as the same.
library;

import 'nfc_data.dart';

/// [text] in the form two fixes are compared in: [nfc], then white space
/// collapsed and trimmed. See the library comment for what is not done.
String normalizeFixText(String text) {
  final composed = nfc(text);
  return composed.replaceAll(_whitespaceRun, ' ').replaceAll(_edgeSpace, '');
}

/// Whether [a] and [b] are the same fix after [normalizeFixText].
bool sameFixText(String a, String b) =>
    normalizeFixText(a) == normalizeFixText(b);

// White space as Unicode defines it, without U+FEFF (a byte order mark that
// is not a space) and without the zero-width characters.
final RegExp _whitespaceRun = RegExp(r'[\t\n\u000B\f\r \u0085   -     　]+');
final RegExp _edgeSpace = RegExp(r'^ | $');

/// [input] in Normalization Form C (Unicode canonical decomposition, the
/// canonical order of combining marks, then canonical composition), Hangul
/// included. Text with no code unit above U+00BF is returned as it is.
String nfc(String input) {
  if (_plain(input)) return input;
  final runes = _decompose(input.runes);
  _order(runes);
  return String.fromCharCodes(_compose(runes));
}

bool _plain(String input) {
  for (final unit in input.codeUnits) {
    if (unit >= 0xC0) return false;
  }
  return true;
}

// Hangul syllable arithmetic (Unicode 3.12).
const int _sBase = 0xAC00;
const int _lBase = 0x1100;
const int _vBase = 0x1161;
const int _tBase = 0x11A7;
const int _lCount = 19;
const int _vCount = 21;
const int _tCount = 28;
const int _nCount = _vCount * _tCount;
const int _sCount = _lCount * _nCount;

final Map<int, List<int>> _decompositions = _parseDecompositions();
final Map<int, int> _classes = _parseClasses();
final Map<int, int> _compositions = _parseCompositions();

List<int> _hex(String text) => <int>[
  for (final part in text.split(' ')) int.parse(part, radix: 16),
];

Map<int, List<int>> _parseDecompositions() => <int, List<int>>{
  for (final entry in nfcDecompositions.split(';'))
    int.parse(entry.substring(0, entry.indexOf(':')), radix: 16): _hex(
      entry.substring(entry.indexOf(':') + 1),
    ),
};

Map<int, int> _parseClasses() => <int, int>{
  for (final entry in nfcCombiningClasses.split(';'))
    int.parse(entry.substring(0, entry.indexOf(':')), radix: 16): int.parse(
      entry.substring(entry.indexOf(':') + 1),
    ),
};

// Keyed by first * 0x110000 + second.
Map<int, int> _parseCompositions() => <int, int>{
  for (final entry in nfcCompositions.split(';'))
    _pair(
      _hex(entry.substring(0, entry.indexOf(':')))[0],
      _hex(entry.substring(0, entry.indexOf(':')))[1],
    ): int.parse(
      entry.substring(entry.indexOf(':') + 1),
      radix: 16,
    ),
};

int _pair(int first, int second) => first * 0x110000 + second;

List<int> _decompose(Iterable<int> runes) {
  final out = <int>[];
  for (final rune in runes) {
    final s = rune - _sBase;
    if (s >= 0 && s < _sCount) {
      out.add(_lBase + s ~/ _nCount);
      out.add(_vBase + (s % _nCount) ~/ _tCount);
      final t = _tBase + s % _tCount;
      if (t != _tBase) out.add(t);
      continue;
    }
    final parts = _decompositions[rune];
    if (parts == null) {
      out.add(rune);
    } else {
      out.addAll(parts);
    }
  }
  return out;
}

int _class(int rune) => _classes[rune] ?? 0;

/// Canonical ordering: a run of marks with a class is put in order of class,
/// marks of one class keeping their order (an insertion sort is stable).
void _order(List<int> runes) {
  for (var i = 1; i < runes.length; i++) {
    final c = _class(runes[i]);
    if (c == 0) continue;
    var j = i;
    while (j > 0 && _class(runes[j - 1]) > c) {
      final held = runes[j - 1];
      runes[j - 1] = runes[j];
      runes[j] = held;
      j--;
    }
  }
}

int? _composePair(int first, int second) {
  // Hangul: a leading consonant with a vowel, then an LV syllable with a
  // trailing consonant.
  final l = first - _lBase;
  final v = second - _vBase;
  if (l >= 0 && l < _lCount && v >= 0 && v < _vCount) {
    return _sBase + (l * _vCount + v) * _tCount;
  }
  final s = first - _sBase;
  final t = second - _tBase;
  if (s >= 0 && s < _sCount && s % _tCount == 0 && t > 0 && t < _tCount) {
    return first + t;
  }
  return _compositions[_pair(first, second)];
}

List<int> _compose(List<int> runes) {
  if (runes.isEmpty) return runes;
  final out = <int>[];
  var starter = -1;
  var lastClass = 0;
  for (final rune in runes) {
    final c = _class(rune);
    if (starter >= 0) {
      // Blocked when a mark between the starter and this one has a class not
      // lower than this one's.
      final blocked = out.length - 1 != starter && lastClass >= c;
      if (!blocked) {
        final joined = _composePair(out[starter], rune);
        if (joined != null) {
          out[starter] = joined;
          continue;
        }
      }
    }
    if (c == 0) starter = out.length;
    out.add(rune);
    lastClass = c;
  }
  return out;
}
