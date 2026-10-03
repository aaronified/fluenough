import '../models/romanisation.dart';
import 'answer_grader.dart';

/// Romanised answers (#47): what a learner types in Latin letters, compared
/// with a card's reading in its language's scheme.
///
/// Both sides are first spelled one way, by [key]: lowercase, accents
/// stripped, letters and digits only, and each spelling the romanisation file
/// lists for a sound written as the decks write it. So `kitnaa`, `Kitnā` and
/// `kitna` are one answer, as `kem chho` and `kemchho` are.
class RomanisedSpelling {
  RomanisedSpelling(Romanisation? romanisation)
    : _canonical = <String, String>{
        for (final group in romanisation?.equivalents ?? const <List<String>>[])
          for (final spelling in group) spelling: group.first,
      } {
    _spellings = _canonical.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  /// Each spelling a learner may type, and the decks' own for its sound.
  final Map<String, String> _canonical;

  /// [_canonical]'s spellings, longest first, so that `chh` is read before
  /// `ch`.
  late final List<String> _spellings;

  /// [text] spelled one way, to compare.
  ///
  /// Spellings are read from the left, the longest first, and each is
  /// written once: what it is written as is never read again.
  String key(String text) {
    final letters = foldDiacritics(text.toLowerCase())
        .replaceAll(RegExp('[^a-z0-9]'), '');
    final out = StringBuffer();
    var i = 0;
    outer:
    while (i < letters.length) {
      for (final spelling in _spellings) {
        if (letters.startsWith(spelling, i)) {
          out.write(_canonical[spelling]);
          i += spelling.length;
          continue outer;
        }
      }
      out.write(letters[i]);
      i++;
    }
    return out.toString();
  }

  /// [given] against [readings], the canonical one first. Exact, a near
  /// miss to judge, or wrong, as [AnswerGrader] says of their [key]s;
  /// `matched` is the reading itself.
  GradedAnswer grade(String given, List<String> readings) {
    if (readings.isEmpty) {
      return const GradedAnswer(AnswerOutcome.wrong, matched: null);
    }
    final keys = <String>[for (final reading in readings) key(reading)];
    final graded = const AnswerGrader().grade(
      key(given),
      keys.first,
      alternates: keys.sublist(1),
    );
    final matched = graded.matched;
    return matched == null
        ? graded
        : GradedAnswer(
            graded.outcome,
            matched: readings[keys.indexOf(matched)],
          );
  }
}
