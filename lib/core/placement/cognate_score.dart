import 'dart:math' as math;

import '../models/card.dart';

// The cognate score of an item of "Find my level" V3 (wiki/Plan-Placement-V3.md,
// "Adversarial review and required amendments", item generation 1): how much a
// word looks like its English meaning once both are respelled. A gamer that
// knows no word of the language still answers a near-cognate right, so the
// score is computed once, at bank build, and stored on every item.
//
// Pure Dart. The rules are generic sound-and-spelling folds plus a small
// table of suffix correspondences per language; no per-language word list.

/// The score at or above which a word counts as a near-cognate. Tuned so that
/// about a third of a Spanish course and about a tenth of a Hindi course are
/// near-cognates, as the adversary found.
const double kCognateThreshold = 0.58;

const String _foldFrom =
    'àáâãäåāăąçćčďḍèéêëēěęìíîïīıñṇṅńòóôõöōőøřṛśšṣşťṭùúûüūůýÿźžżṁṃḥłß';
const String _foldTo =
    'aaaaaaaaacccddeeeeeeeiiiiiinnnnooooooooorrsssstt'
    'uuuuuuyyzzzmmhls';

/// [text] lower-cased with accents, macrons and dots under letters removed,
/// and combining marks dropped: `śāla` becomes `sala`, `m̐` becomes `m`.
String foldAccents(String text) {
  final out = StringBuffer();
  for (final r in text.toLowerCase().runes) {
    if (r >= 0x300 && r <= 0x36f) continue;
    final ch = String.fromCharCode(r);
    final at = _foldFrom.indexOf(ch);
    if (at >= 0 && at < _foldTo.length) {
      out.write(_foldTo[at]);
    } else {
      out.write(ch);
    }
  }
  return out.toString();
}

/// The letters a to z of [text] after [foldAccents]; everything else (spaces,
/// marks, other scripts) is dropped.
String latinLetters(String text) =>
    foldAccents(text).replaceAll(RegExp('[^a-z]'), '');

/// Suffix correspondences from a language's spelling to English, applied
/// before the fold (`ción` to `tion`): the regular patterns that make
/// cognates look alike. Keys are language codes.
const Map<String, List<(String, String)>> cognateSuffixRules =
    <String, List<(String, String)>>{
      'es': <(String, String)>[
        ('cion', 'tion'),
        ('sion', 'sion'),
        ('dad', 'ty'),
        ('mente', 'ly'),
        ('ario', 'ary'),
        ('oso', 'ous'),
        ('osa', 'ous'),
        ('ico', 'ic'),
        ('ica', 'ic'),
        ('ivo', 'ive'),
        ('iva', 'ive'),
        ('ente', 'ent'),
        ('ante', 'ant'),
        ('ismo', 'ism'),
        ('ista', 'ist'),
        ('ura', 'ure'),
        ('ia', 'y'),
      ],
      'fr': <(String, String)>[
        ('tion', 'tion'),
        ('ment', 'ly'),
        ('ite', 'ity'),
        ('eux', 'ous'),
        ('ique', 'ic'),
        ('aire', 'ary'),
      ],
      'it': <(String, String)>[
        ('zione', 'tion'),
        ('ita', 'ity'),
        ('mente', 'ly'),
        ('oso', 'ous'),
        ('ico', 'ic'),
      ],
      'pt': <(String, String)>[
        ('cao', 'tion'),
        ('dade', 'ty'),
        ('mente', 'ly'),
        ('oso', 'ous'),
        ('ico', 'ic'),
      ],
    };

/// The sound-like form of a letter string: soft and hard c, ph, qu, z, x, w
/// and y folded together, doubled letters collapsed, and `h` dropped, so that
/// two spellings of one sound compare equal.
String soundForm(String letters) {
  var s = letters;
  s = s.replaceAll('ph', 'f').replaceAll('qu', 'k').replaceAll('ck', 'k');
  s = s.replaceAllMapped(RegExp('c(?=[eiy])'), (_) => 's');
  s = s.replaceAll('c', 'k').replaceAll('q', 'k');
  s = s.replaceAll('z', 's').replaceAll('x', 'ks');
  s = s.replaceAll('w', 'v').replaceAll('y', 'i').replaceAll('j', 'i');
  s = s.replaceAll('h', '');
  s = s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
  return s;
}

/// [letters] with every vowel dropped (the consonant skeleton).
String skeleton(String letters) => letters.replaceAll(RegExp('[aeiou]'), '');

/// The Levenshtein distance of [a] and [b].
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

double _similarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return 1 - editDistance(a, b) / math.max(a.length, b.length);
}

/// The spelling variants of a word of [language] that an English reader
/// would try: the word, without its final vowel, and with the language's
/// suffix correspondences applied.
List<String> respellings(String letters, String language) {
  final out = <String>{letters};
  var ruled = letters;
  final rules = cognateSuffixRules[language] ?? const <(String, String)>[];
  for (final (from, to) in rules) {
    if (ruled.endsWith(from)) {
      ruled = ruled.substring(0, ruled.length - from.length) + to;
      break;
    }
  }
  out.add(ruled);
  for (final v in out.toList()) {
    if (v.length > 3 && 'aeiou'.contains(v[v.length - 1])) {
      out.add(v.substring(0, v.length - 1));
    }
  }
  return out.toList();
}

/// How much [word] of [language] looks like the English [english] (both as
/// letters): the best similarity of their sound forms, or of their consonant
/// skeletons for words of four letters or more, over the respellings.
double wordSimilarity(String word, String english, String language) {
  final w = latinLetters(word);
  final e = latinLetters(english);
  if (w.length < 3 || e.length < 3) return 0;
  final eSound = soundForm(e);
  final eSkel = skeleton(eSound);
  var best = 0.0;
  for (final r in respellings(w, language)) {
    final rSound = soundForm(r);
    best = math.max(best, _similarity(rSound, eSound));
    if (rSound.length >= 4 && eSound.length >= 4) {
      final rs = skeleton(rSound);
      if (rs.length >= 3 && eSkel.length >= 3) {
        best = math.max(best, 0.95 * _similarity(rs, eSkel));
      }
    }
  }
  return best;
}

/// The English words of a card's meaning: every word of every alternative
/// meaning (`to eat; to have lunch` gives eat, have, lunch), without the
/// parenthesised glosses, and without the function words `to`, `a`, `an` and
/// `the`.
List<String> glossWords(String native) {
  final plain = native.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  final out = <String>[];
  for (final w in plain.split(RegExp(r'[^A-Za-z]+'))) {
    final lower = w.toLowerCase();
    if (lower.length < 3) continue;
    if (const <String>{'the', 'and', 'for', 'you', 'your'}.contains(lower)) {
      continue;
    }
    out.add(lower);
  }
  return out;
}

/// The first alternative of a meaning, as a short answer option: `to eat`
/// from `to eat; to have lunch (formal)`, and `a heap` from
/// `a heap, a pile, a great deal`. A leading number is skipped (`thirty-three`
/// from `33, thirty-three`).
String shortGloss(String native) {
  var first = native.split(';').first;
  first = first.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  final parts = first.split(RegExp(r',\s+'));
  for (final p in parts) {
    if (RegExp('[A-Za-z]').hasMatch(p)) return p.trim();
  }
  return first;
}

/// The words of a target text as written, with their leading and trailing
/// marks removed (`¿Cómo` gives `Cómo`).
List<String> targetWords(String text) => <String>[
  for (final t in text.split(RegExp(r'\s+')))
    if (t
        .replaceAll(
          RegExp(r'^[^\p{L}\p{M}]+|[^\p{L}\p{M}]+$', unicode: true),
          '',
        )
        .isNotEmpty)
      t.replaceAll(
        RegExp(r'^[^\p{L}\p{M}]+|[^\p{L}\p{M}]+$', unicode: true),
        '',
      ),
];

/// Scores the cognate-likeness of cards of one language.
class CognateScorer {
  const CognateScorer(this.language, {this.threshold = kCognateThreshold});

  final String language;
  final double threshold;

  /// The text a card's word is compared in: its romanised reading where it
  /// has one (a Devanagari word compares by its transliteration, which is how
  /// English loanwords such as `skūl` are found), else its target.
  String romanised(Card card) => card.reading ?? card.target;

  /// The best similarity of any content word of [source] (a card's
  /// romanised text) to any word of the English [native], from 0 to 1.
  double score(String source, String native) {
    final english = <String>[...glossWords(native)];
    if (english.isEmpty) return 0;
    var best = 0.0;
    for (final w in targetWords(source)) {
      if (latinLetters(w).length < 4) continue;
      for (final e in english) {
        best = math.max(best, wordSimilarity(w, e, language));
      }
    }
    return best;
  }

  /// The cognate score of a card.
  double scoreCard(Card card) => score(romanised(card), card.native);

  /// Whether [card] is a near-cognate of its English meaning.
  bool isCognate(Card card) => scoreCard(card) >= threshold;
}
