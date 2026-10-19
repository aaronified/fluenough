import 'dart:math' as math;

import 'package:flutter/widgets.dart' show StringCharacters;

import 'canonical.dart';
import 'diacritics.dart';
import 'meaning_rules.dart';

export 'diacritics.dart' show foldDiacritics;

/// How close a typed answer was to the expected one.
///
/// Deliberately not a boolean: the distinction drives both what the UI says
/// ("right, but watch the accent") and the grade, and it keeps that policy
/// decision out of the comparison code itself.
enum AnswerOutcome {
  /// Matched after case, whitespace and punctuation normalisation.
  exact,

  /// Matched only once diacritics were stripped. The word was right, the
  /// accents were not.
  closeDiacritics,

  /// Within the edit-distance threshold. Offered for self-assessment rather
  /// than marked wrong outright.
  closeTypo,

  wrong;

  bool get isCorrect => this != AnswerOutcome.wrong;

  /// Maps an outcome to a grade (0–5) for a machine-graded drill.
  ///
  /// A typo is deliberately not treated as a failure — forgetting a word and
  /// mistyping it are different events, and conflating them makes the
  /// scheduler over-drill words the learner actually knows.
  int toGrade() => switch (this) {
    AnswerOutcome.exact => 5,
    AnswerOutcome.closeDiacritics => 4,
    AnswerOutcome.closeTypo => 3,
    AnswerOutcome.wrong => 1,
  };
}

class GradedAnswer {
  const GradedAnswer(
    this.outcome, {
    required this.matched,
    this.droppedArticle = false,
    this.foldedDiacritics = false,
  });

  final AnswerOutcome outcome;

  /// Which accepted answer was matched, for showing the learner what was
  /// expected. Null when nothing matched.
  final String? matched;

  /// For [AnswerOutcome.closeDiacritics]: the leading article was missing,
  /// added or different, and was dropped for the comparison. `el niño` for
  /// `niño`, or `la niño` for `el niño`. False for every other outcome.
  ///
  /// The outcome and its grade do not change; this only tells the interface
  /// which of "mind the accent" and "keep the article" to say.
  final bool droppedArticle;

  /// For [AnswerOutcome.closeDiacritics]: the diacritics differed and were
  /// folded for the comparison. `nino` for `niño`. False for every other
  /// outcome.
  ///
  /// Both flags are set when both differed, as in `nino` for `el niño`.
  final bool foldedDiacritics;
}

/// Compares a typed answer against the accepted ones.
///
/// Normalisation is specified in `docs/DECK-FORMAT.md`.
class AnswerGrader {
  const AnswerGrader({
    this.articles = const <String>[],
    this.typoDistance = 1,
    this.longTypoDistance = 2,
    this.longThreshold = 8,
    this.shortThreshold = 3,
    this.meaning = false,
  });

  /// Leading articles ignored when comparing, e.g. `['el', 'la', 'los', 'las']`
  /// for Spanish. This is per-language data rather than code; a language
  /// without articles supplies an empty list and the pass becomes a no-op.
  final List<String> articles;

  final int typoDistance;
  final int longTypoDistance;

  /// Answers at least this long, in letters as written (grapheme
  /// clusters: है is one), get the more generous typo allowance.
  final int longThreshold;

  /// Answers shorter than this, in letters as written, allow no typo: one
  /// slip in あ or है is a different answer altogether.
  final int shortThreshold;

  /// Grade an English meaning answer by the rules in `meaning_rules.dart`:
  /// contractions, bracketed qualifiers, `;` alternatives, a leading "to",
  /// ok/okay. Matches by them are [AnswerOutcome.exact]; what still differs
  /// goes through the diacritic and typo passes as before.
  final bool meaning;

  GradedAnswer grade(
    String given,
    String expected, {
    List<String> alternates = const <String>[],
  }) {
    final candidates = <String>[expected, ...alternates];

    final normalisedGiven = _normalise(given);
    if (normalisedGiven.isEmpty) {
      return const GradedAnswer(AnswerOutcome.wrong, matched: null);
    }

    // Each candidate with the normalised forms it accepts: one, or with the
    // meaning rules, one per `;` part.
    final forms = <(String, String)>[
      for (final candidate in candidates)
        for (final form in _forms(candidate)) (candidate, form),
    ];
    final givenKey = meaning ? meaningKey(given) : normalisedGiven;

    // Pass 1: exact after normalisation.
    for (final (candidate, form) in forms) {
      if (givenKey == form) {
        return GradedAnswer(AnswerOutcome.exact, matched: candidate);
      }
    }

    // Pass 2: also fold diacritics and drop a leading article.
    final foldedGiven = _fold(givenKey);
    for (final (candidate, form) in forms) {
      if (foldedGiven == _fold(form)) {
        // Exact failed, so at least one of the two folds did the work. If the
        // answers still differ with only diacritics folded, the article did.
        final droppedArticle =
            _foldDiacritics(givenKey) != _foldDiacritics(form);
        // With the article left alone, the diacritics must be what differed;
        // with it dropped, they may have differed as well.
        final foldedDiacritics =
            !droppedArticle || _dropArticle(givenKey) != _dropArticle(form);
        return GradedAnswer(
          AnswerOutcome.closeDiacritics,
          matched: candidate,
          droppedArticle: droppedArticle,
          foldedDiacritics: foldedDiacritics,
        );
      }
    }

    // Pass 3: edit distance, against the folded forms so that a missing accent
    // does not also consume the typo budget.
    for (final (candidate, form) in forms) {
      final foldedCandidate = _fold(form);
      final letters = foldedCandidate.characters.length;
      final allowed = letters < shortThreshold
          ? 0
          : letters >= longThreshold
          ? longTypoDistance
          : typoDistance;
      if (levenshtein(foldedGiven, foldedCandidate, cutoff: allowed) <=
          allowed) {
        return GradedAnswer(AnswerOutcome.closeTypo, matched: candidate);
      }
    }

    return const GradedAnswer(AnswerOutcome.wrong, matched: null);
  }

  /// The forms a candidate accepts, normalised.
  Iterable<String> _forms(String candidate) {
    if (!meaning) return [_normalise(candidate)];
    final keys = meaningKeys(candidate);
    return keys.isEmpty ? [_normalise(candidate)] : keys;
  }

  /// One spelling for text that looks the same ([canonical]), case folding,
  /// whitespace collapsing and terminal punctuation removal.
  String _normalise(String input) {
    var text = canonical(input).trim().toLowerCase();
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    // The danda । and ॥ end Bengali and Hindi sentences; the full-width
    // marks end Japanese ones. A recogniser writes none of them (#130).
    text = text.replaceAll(
      RegExp(r'''^[¿¡"'(\[]+|[.,!?;:"')\]।॥。．，！？；：]+$'''),
      '',
    );
    return text.trim();
  }

  /// Strips diacritics and any leading article.
  String _fold(String input) => _dropArticle(_foldDiacritics(input));

  String _foldDiacritics(String input) => foldDiacritics(input);

  String _dropArticle(String text) {
    for (final article in articles) {
      final prefix = '${article.toLowerCase()} ';
      if (text.startsWith(prefix) && text.length > prefix.length) {
        return text.substring(prefix.length);
      }
    }
    return text;
  }
}

/// Levenshtein distance, abandoning early once [cutoff] is exceeded.
///
/// Returns [cutoff] + 1 when the true distance is greater, which is all the
/// caller needs and lets long mismatches bail out cheaply.
int levenshtein(String a, String b, {int cutoff = 1 << 30}) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > cutoff) return cutoff + 1;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
      rowMin = math.min(rowMin, current[j]);
    }
    if (rowMin > cutoff) return cutoff + 1;
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}
