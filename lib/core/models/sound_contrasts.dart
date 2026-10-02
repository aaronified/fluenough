import '../grading/canonical.dart';

/// A pair of sounds a language tells apart and English doesn't, such as a
/// breath after a consonant (#89, ADR-0015).
class SoundContrast {
  const SoundContrast({
    required this.id,
    required this.name,
    required this.pairs,
    this.withinWord = false,
  });

  /// Stable, and the tag a sound-differences deck's cards carry.
  final String id;

  /// What the difference is, for "The difference is …": "a breath after
  /// the consonant".
  final String name;

  /// What is swapped, in writing: two letters or signs (क and ख), or one
  /// and nothing (a sign that is there or not).
  final List<(String, String)> pairs;

  /// A sign added or taken away (a pair with an empty side) counts only
  /// inside a word: adding a vowel sign at the end of a word adds a
  /// syllable, which is not this contrast. Swaps count anywhere.
  final bool withinWord;
}

/// A language's sound contrasts, read from `decks/<lang>/<lang>-sounds.yaml`.
class SoundContrasts {
  const SoundContrasts({required this.language, required this.contrasts});

  /// The language's code, such as `bn`.
  final String language;

  final List<SoundContrast> contrasts;

  /// The contrast [heard] differs from [expected] by, if it differs by
  /// exactly one swap of one contrast's pair, or null. Both are compared as
  /// the grader compares them: one spelling, one space, no final full stop.
  SoundContrast? between(String heard, String expected) {
    final a = normaliseForContrast(heard);
    final b = normaliseForContrast(expected);
    if (a.isEmpty || b.isEmpty || a == b) return null;
    for (final contrast in contrasts) {
      for (final (x, y) in contrast.pairs) {
        if (_oneSwap(b, x, y, a, contrast.withinWord) ||
            _oneSwap(b, y, x, a, contrast.withinWord)) {
          return contrast;
        }
      }
    }
    return null;
  }

  /// Whether replacing one [from] in [text] with [to] gives [goal].
  static bool _oneSwap(
    String text,
    String from,
    String to,
    String goal,
    bool withinWord,
  ) {
    if (text.length - from.length + to.length != goal.length) return false;
    bool atWordEnd(int at) =>
        at + from.length >= text.length || text[at + from.length] == ' ';
    if (from.isEmpty) {
      // Insert [to] at some place inside the text: never before its first
      // letter, since a sign follows a letter.
      for (var at = 1; at <= text.length; at++) {
        if (withinWord && atWordEnd(at)) continue;
        if (text.substring(0, at) + to + text.substring(at) == goal) {
          return true;
        }
      }
      return false;
    }
    for (
      var at = text.indexOf(from);
      at >= 0;
      at = text.indexOf(from, at + 1)
    ) {
      if (withinWord && to.isEmpty && atWordEnd(at)) continue;
      if (text.substring(0, at) + to + text.substring(at + from.length) ==
          goal) {
        return true;
      }
    }
    return false;
  }
}

/// [text] as the contrast check compares it: one spelling for what looks
/// the same, lower case, one space, and no sentence-final mark.
String normaliseForContrast(String text) {
  var out = canonical(text).trim().toLowerCase();
  out = out.replaceAll(RegExp(r'\s+'), ' ');
  out = out.replaceAll(RegExp(r'[.,!?;:।॥。．，！？；：]+$'), '');
  return out.trim();
}
