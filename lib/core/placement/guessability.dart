import 'dart:math' as math;

import 'generated_question.dart';

// How guessable a pick is (wiki/Plan-Placement-V2.md, "Guess-proof
// questions", owner report 2026-11-06). A learner who knows no word of the
// language can still pick the option that is spelled like the prompt, or the
// one that is odd in shape. The distractors are chosen so that this does not
// work ([PlacementItemPicker.distractorsFor] with a lure); where the course
// data has too few similar candidates a question can still leak, and then its
// evidence is weakened here: the model is told the question is easier to guess
// than its kind says. Pure Dart.

const String _accented = 'áàäâãéèëêíìïîóòöôõúùüûñçß';
const String _unaccented = 'aaaaaeeeeiiiiooooouuuuncs';
final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// [text] as letters are compared: lower case, accents dropped, anything but
/// a letter or a digit turned into one space, single spaces.
String foldLetters(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    final at = _accented.indexOf(c);
    final plain = at < 0 ? c : _unaccented[at];
    out.write(_letterOrDigit.hasMatch(plain) ? plain : ' ');
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

Set<String> _bigrams(String folded) {
  final padded = ' $folded ';
  return <String>{
    for (var i = 0; i + 2 <= padded.length; i++) padded.substring(i, i + 2),
  };
}

/// How alike two texts are as letters, 0 to 1: the Dice coefficient of their
/// letter pairs, after [foldLetters]. What a guesser with no knowledge of the
/// language can see.
double surfaceSimilarity(String a, String b) {
  final x = _bigrams(foldLetters(a));
  final y = _bigrams(foldLetters(b));
  if (x.isEmpty || y.isEmpty) return 0;
  var shared = 0;
  for (final g in x) {
    if (y.contains(g)) shared++;
  }
  return 2 * shared / (x.length + y.length);
}

/// How much more like the prompt the right option has to be than every other
/// option for the question to count as leaking its answer.
const double leakMargin = 0.15;

/// The guess rate a leaking pick is given in the model, instead of its
/// kind's (0.25 for four options).
const double leakingGuessRate = 0.5;

/// Whether the right option of [question] is, alone, clearly the most like
/// the prompt.
bool leaksBySimilarity(GeneratedQuestion question) {
  final prompt = question.promptText;
  final right = question.correctIndex;
  if (question.mode != PlacementAnswerMode.pick ||
      prompt == null ||
      right == null ||
      question.options.length < 2) {
    return false;
  }
  var best = -1.0;
  for (final (i, option) in question.options.indexed) {
    if (i == right) continue;
    best = math.max(best, surfaceSimilarity(prompt, option));
  }
  return surfaceSimilarity(prompt, question.options[right]) - best >=
      leakMargin;
}

/// The guess rate to give [question] in the assurance model, or null where
/// its kind's own rate holds.
double? guessRateOf(GeneratedQuestion question) =>
    leaksBySimilarity(question) ? leakingGuessRate : null;

/// The shape of an option as a guesser sees it: a bracket, a dash label, and
/// whether it is one word or several.
String optionShape(String option) =>
    '${option.contains('(')}|${option.contains(' — ')}|'
    '${option.trim().split(RegExp(r'\s+')).length > 1}';

/// Whether the options of [question] do not all have one shape.
bool optionsDifferInShape(GeneratedQuestion question) =>
    question.options.map(optionShape).toSet().length > 1;

/// Whether the right option is the longest or the shortest by more than 30%
/// of the median length.
bool rightIsLengthOutlier(GeneratedQuestion question) {
  final right = question.correctIndex;
  if (right == null || question.options.length < 3) return false;
  final lengths = <int>[for (final o in question.options) o.length];
  final sorted = <int>[...lengths]..sort();
  final median = sorted[sorted.length ~/ 2];
  final mine = lengths[right];
  final others = <int>[
    for (final (i, n) in lengths.indexed)
      if (i != right) n,
  ];
  final longest = others.every((n) => mine > n);
  final shortest = others.every((n) => mine < n);
  return (longest || shortest) && (mine - median).abs() > 0.3 * median;
}

/// Whether the prompt is a cognate of the right option's English: as letters
/// they are alike by 0.5 or more (through the reading for another script).
bool rightIsCognate(GeneratedQuestion question) {
  final right = question.correctIndex;
  if (right == null || right >= question.options.length) return false;
  final texts = <String>[?question.promptText, ?question.promptReading];
  return texts.any((t) => surfaceSimilarity(t, question.options[right]) >= 0.5);
}

/// Whether a pick has a cue that lets it be guessed by what it shows (plan
/// section 13, point 4): its spelling, the shape or length of its options, a
/// cognate. Such a question counts for nothing in the credit posterior.
bool hasCue(GeneratedQuestion question) =>
    question.mode == PlacementAnswerMode.pick &&
    !question.optionsAreAudio &&
    (leaksBySimilarity(question) ||
        optionsDifferInShape(question) ||
        rightIsLengthOutlier(question) ||
        rightIsCognate(question));

/// The base guess a question gives the credit posterior: null where its
/// kind's own holds, 1 for a pick with a cue (no evidence), else `1/k`.
double? creditBaseOf(GeneratedQuestion question) {
  if (question.mode != PlacementAnswerMode.pick ||
      question.options.length < 2) {
    return null;
  }
  if (hasCue(question)) return 1;
  return 1 / question.options.length;
}
