import 'answer_grader.dart';

/// Which word of a minimal pair a spoken reading matched.
enum PairSide { first, second }

/// One reading of what the learner said, and how sure the recogniser was:
/// what `SpeechAlternative` holds, kept free of the speech engine so that
/// this file stays plain Dart.
typedef HeardReading = ({String text, double? confidence});

/// What the phone heard when the learner said one word of a minimal pair
/// (#423): the reading taken as what was said, and which of the two words
/// it is, or null when it is neither.
class PairMatch {
  const PairMatch({required this.heard, this.side});

  /// The reading taken as said: the one that matched, else the best.
  final String heard;

  /// The word it matched, or null for neither.
  final PairSide? side;
}

/// The confidence a reading other than the recogniser's best needs to be
/// taken as what was said, as in the speaking drill. One with none given
/// (or 0, as Android gives every reading after the best) is not.
const double pairSpeechConfidence = 0.5;

/// Which of two words the learner said, from the recogniser's [readings],
/// best first, or null when there is none to read.
///
/// [first] and [second] are the spellings each word is accepted as. A
/// reading matches a word only when it is the same after the grader's
/// clean-up of case, spaces and punctuation: no near miss, no folded
/// diacritics, because the pair differs by one sound, and a reading that is
/// the other word with a mark changed is that other word. The best reading
/// is tried first, then any other the recogniser was fairly sure of.
PairMatch? matchPair(
  List<HeardReading> readings, {
  required List<String> first,
  required List<String> second,
  List<String> articles = const <String>[],
}) {
  if (readings.isEmpty) return null;
  final grader = AnswerGrader(
    articles: articles,
    typoDistance: 0,
    longTypoDistance: 0,
  );
  bool said(String text, List<String> accepted) =>
      grader
          .grade(text, accepted.first, alternates: accepted.sublist(1))
          .outcome ==
      AnswerOutcome.exact;
  for (final (i, reading) in readings.indexed) {
    final confidence = reading.confidence;
    if (i > 0 && (confidence == null || confidence < pairSpeechConfidence)) {
      continue;
    }
    if (first.isNotEmpty && said(reading.text, first)) {
      return PairMatch(heard: reading.text, side: PairSide.first);
    }
    if (second.isNotEmpty && said(reading.text, second)) {
      return PairMatch(heard: reading.text, side: PairSide.second);
    }
  }
  return PairMatch(heard: readings.first.text);
}
