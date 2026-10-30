/// Typo-tolerant matching for the Decks search (#527), free of Flutter.
///
/// The approved mockup (removed once built, #527) did it in two steps:
/// overlapping three-letter pieces (trigrams), where a field matches when it
/// holds at least half of the word's pieces, and, when that
/// finds nothing, an edit distance to the words the search knows (at most 1
/// for a word of up to 4 letters, 2 for a longer one, a swap of two letters
/// counting as one). This is the decision step, in Dart over the folded text,
/// and the whole search where there is no SQLite FTS5: with it, the FTS5
/// trigram index in `card_index.dart` retrieves the cards that could match
/// and this still decides which do (ADR-0049).
library;

/// How well a word was found in a field, best first. The search orders its
/// results by it.
enum MatchQuality {
  /// The word is a whole word of the field.
  whole,

  /// The word starts a word of the field.
  start,

  /// The word is inside the field.
  inside,

  /// Found despite a typo, by trigrams or by edit distance.
  close,
}

/// The overlapping three-letter pieces of [text].
Set<String> trigrams(String text) {
  final runes = text.runes.toList();
  final out = <String>{};
  for (var i = 0; i + 3 <= runes.length; i++) {
    out.add(String.fromCharCodes(runes.sublist(i, i + 3)));
  }
  return out;
}

/// The share, 0 to 1, of [word]'s trigrams that [field] holds. 0 when the
/// word is shorter than three letters.
double trigramShare(String word, String field) {
  final pieces = trigrams(word);
  if (pieces.isEmpty) return 0;
  final held = trigrams(field);
  return pieces.where(held.contains).length / pieces.length;
}

/// The Damerau-Levenshtein distance between [a] and [b] (insertions,
/// deletions, substitutions and swaps of two neighbouring letters, each
/// one), or `max + 1` as soon as it must exceed [max].
int editDistance(String a, String b, {int max = 3}) {
  if ((a.length - b.length).abs() > max) return max + 1;
  final x = a.runes.toList();
  final y = b.runes.toList();
  var previous2 = List<int>.filled(y.length + 1, 0);
  var previous = List<int>.generate(y.length + 1, (j) => j);
  for (var i = 1; i <= x.length; i++) {
    final row = List<int>.filled(y.length + 1, 0)..[0] = i;
    var best = row[0];
    for (var j = 1; j <= y.length; j++) {
      final cost = x[i - 1] == y[j - 1] ? 0 : 1;
      var d = previous[j - 1] + cost;
      if (previous[j] + 1 < d) d = previous[j] + 1;
      if (row[j - 1] + 1 < d) d = row[j - 1] + 1;
      if (i > 1 &&
          j > 1 &&
          x[i - 1] == y[j - 2] &&
          x[i - 2] == y[j - 1] &&
          previous2[j - 2] + 1 < d) {
        d = previous2[j - 2] + 1;
      }
      row[j] = d;
      if (d < best) best = d;
    }
    if (best > max) return max + 1;
    previous2 = previous;
    previous = row;
  }
  return previous[y.length];
}

/// The most typos a word of [length] letters may hold: one up to four
/// letters, two beyond.
int allowedTypos(int length) => length <= 4 ? 1 : 2;

/// Whether [text] is written in Latin letters (and digits), the only
/// writing typo tolerance is applied to: a vowel sign of another script is
/// part of its letter, so an edit would find another word.
bool isLatinText(String text) =>
    text.isNotEmpty && !_otherScriptLetter.hasMatch(text);

/// A letter that is not a Latin one.
final RegExp _otherScriptLetter = RegExp(
  r'(?!\p{Script=Latin})\p{L}',
  unicode: true,
);

final RegExp _wordBreak = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// The words of [text], lower case already.
List<String> wordsOf(String text) => <String>[
  for (final w in text.split(_wordBreak))
    if (w.isNotEmpty) w,
];

/// How well [word] is found in [fields], all folded to lower case, or null.
/// With [typos] a Latin word of three or more letters is also found
/// despite a typo.
MatchQuality? matchWord(
  String word,
  Iterable<String> fields, {
  bool typos = true,
}) {
  MatchQuality? best;
  for (final field in fields) {
    final q = _quality(word, field);
    if (q != null && (best == null || q.index < best.index)) best = q;
    if (best == MatchQuality.whole) return best;
  }
  if (best != null) return best;
  if (!typos || word.length < 3 || !isLatinText(word)) return null;
  for (final field in fields) {
    if (!isLatinText(field)) continue;
    if (trigramShare(word, field) >= 0.5) return MatchQuality.close;
    final limit = allowedTypos(word.length);
    for (final w in wordsOf(field)) {
      if (editDistance(word, w, max: limit) <= limit) {
        return MatchQuality.close;
      }
    }
  }
  return null;
}

MatchQuality? _quality(String word, String field) {
  final at = field.indexOf(word);
  if (at < 0) return null;
  for (final w in wordsOf(field)) {
    if (w == word) return MatchQuality.whole;
  }
  for (final w in wordsOf(field)) {
    if (w.startsWith(word)) return MatchQuality.start;
  }
  return MatchQuality.inside;
}

/// The known word closest to [word] by edit distance, for a "Close matches
/// for ..." line: among [vocabulary], the nearest within [allowedTypos],
/// the first of those given when several tie. Null for a word that is
/// itself known, or too short, or not Latin.
String? closestWord(String word, Iterable<String> vocabulary) {
  if (word.length < 3 || !isLatinText(word)) return null;
  final limit = allowedTypos(word.length);
  String? best;
  var bestDistance = limit + 1;
  for (final known in vocabulary) {
    if (known == word) return null;
    final d = editDistance(word, known, max: limit);
    if (d < bestDistance) {
      best = known;
      bestDistance = d;
    }
  }
  return best;
}
