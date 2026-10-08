import 'dart:math' as math;

import 'package:flutter/widgets.dart' show StringCharacters;

import 'canonical.dart';

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

    // Pass 1: exact after normalisation.
    for (final candidate in candidates) {
      if (normalisedGiven == _normalise(candidate)) {
        return GradedAnswer(AnswerOutcome.exact, matched: candidate);
      }
    }

    // Pass 2: also fold diacritics and drop a leading article.
    final foldedGiven = _fold(normalisedGiven);
    for (final candidate in candidates) {
      final normalisedCandidate = _normalise(candidate);
      if (foldedGiven == _fold(normalisedCandidate)) {
        // Exact failed, so at least one of the two folds did the work. If the
        // answers still differ with only diacritics folded, the article did.
        final droppedArticle =
            _foldDiacritics(normalisedGiven) !=
            _foldDiacritics(normalisedCandidate);
        // With the article left alone, the diacritics must be what differed;
        // with it dropped, they may have differed as well.
        final foldedDiacritics =
            !droppedArticle ||
            _dropArticle(normalisedGiven) != _dropArticle(normalisedCandidate);
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
    for (final candidate in candidates) {
      final foldedCandidate = _fold(_normalise(candidate));
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

/// [input] with each Latin letter's diacritics stripped, by the table below:
/// `niño` is `nino`, `kitnā` is `kitna`.
String foldDiacritics(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticFolding[char] ?? char);
  }
  return buffer.toString();
}

/// Diacritic folding for Latin and Cyrillic-adjacent scripts, and for the
/// letters ISO 15919 adds, which the Indic readings use (ADR-0025).
///
/// Dart's core library has no Unicode normalisation, so this is an explicit
/// table rather than an NFD decomposition. It covers Latin-1 Supplement and
/// Latin Extended-A, which is every language Fluenough currently ships a deck
/// for. Scripts needing real NFD handling will need a normalisation package;
/// tracked in the roadmap.
final Map<String, String> _diacriticFolding = _buildFolding({
  'a': 'áàâäãåāăą',
  'c': 'çćĉċč',
  'd': 'ďđḍ',
  'e': 'éèêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħḥ',
  'i': 'íìîïĩīĭįı',
  'j': 'ĵ',
  'k': 'ķ',
  'l': 'ĺļľłŀḷḻ',
  'm': 'ṁ',
  'n': 'ñńņňŉṇṅṉ',
  'o': 'óòôöõōŏőø',
  'r': 'ŕŗřṛṟ',
  's': 'śŝşšṣ',
  't': 'ţťŧṭ',
  'u': 'úùûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷẏ',
  'z': 'źżž',
  'ae': 'æ',
  'oe': 'œ',
  'ss': 'ß',
  // The nukta, which Devanagari and Bengali writers often leave off: ज for
  // ज़. After [canonical] it is always a mark of its own, so dropping it is
  // "right, but watch the nukta", not a miss.
  '':
      '\u093C\u09BC'
      // And the combining marks a letter may carry in place of a composed
      // one: macron, dot below, candrabindu, ring below, tilde, and the
      // double macron below of k͟h.
      '\u0304\u0323\u0310\u0325\u0303\u035F',
});

Map<String, String> _buildFolding(Map<String, String> groups) {
  final folding = <String, String>{};
  groups.forEach((plain, accented) {
    for (final rune in accented.runes) {
      folding[String.fromCharCode(rune)] = plain;
    }
  });
  return folding;
}
