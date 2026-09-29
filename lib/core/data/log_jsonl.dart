import 'dart:convert';

import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import '../models/review_event.dart';
import '../scheduling/replay.dart';

/// The review log as JSON Lines, the backup format (#20; docs/LOG-FORMAT.md).
///
/// One JSON object per line: a header, then every review and every leech
/// action, oldest first. Plain text, so a backup outlives this app. Only
/// what happened is written, never scheduling state: an import rebuilds the
/// state from the log.
abstract final class LogJsonl {
  static const String format = 'fluenough-review-log';
  static const int version = 1;

  /// [reviews] and [leechActions] as JSONL.
  static String encode(
    Iterable<LoggedReview> reviews,
    Iterable<LeechAction> leechActions,
  ) {
    final lines = <String>[
      jsonEncode(<String, Object>{'format': format, 'version': version}),
      for (final r in reviews)
        jsonEncode(<String, Object?>{
          'type': 'review',
          'ts': r.at.toUtc().toIso8601String(),
          'deck': r.key.deckId,
          'card': r.key.cardId,
          'mode': r.key.mode.name,
          'grade': r.grade,
          'elapsed_ms': r.elapsed.inMilliseconds,
          if (r.answerGiven != null) 'answer': r.answerGiven,
        }),
      for (final a in leechActions)
        jsonEncode(<String, Object>{
          'type': 'leech',
          'ts': a.at.toUtc().toIso8601String(),
          'deck': a.key.deckId,
          'card': a.key.cardId,
          'mode': a.key.mode.name,
          'kind': a.kind.name,
        }),
    ];
    return '${lines.join('\n')}\n';
  }

  /// The reviews and leech actions in [text]. Throws [FormatException],
  /// naming the line, for a file that is not a Fluenough log or has a
  /// malformed line. A line of a type this version does not know is skipped,
  /// so an older app can read a newer backup's reviews.
  static ({List<LoggedReview> reviews, List<LeechAction> leechActions}) decode(
    String text,
  ) {
    final reviews = <LoggedReview>[];
    final actions = <LeechAction>[];
    var sawHeader = false;
    for (final (i, raw) in const LineSplitter().convert(text).indexed) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final n = i + 1;
      final Object? decoded;
      try {
        decoded = jsonDecode(line);
      } on FormatException {
        throw FormatException('line $n is not JSON');
      }
      if (decoded is! Map<String, Object?>) {
        throw FormatException('line $n is not a JSON object');
      }
      if (!sawHeader) {
        if (decoded['format'] != format) {
          throw const FormatException('not a Fluenough review log');
        }
        final v = decoded['version'];
        if (v is! int || v > version) {
          throw FormatException('log version $v is newer than this app reads');
        }
        sawHeader = true;
        continue;
      }
      switch (decoded['type']) {
        case 'review':
          reviews.add((
            key: _key(decoded, n),
            at: _time(decoded, n),
            grade: _grade(decoded, n),
            elapsed: Duration(milliseconds: _int(decoded, 'elapsed_ms', n)),
            answerGiven: decoded['answer'] as String?,
          ));
        case 'leech':
          final kind = LeechActionKind.values.asNameMap()[decoded['kind']];
          if (kind == null) throw FormatException('line $n: unknown kind');
          actions.add(
            LeechAction(
              at: _time(decoded, n),
              key: _key(decoded, n),
              kind: kind,
            ),
          );
        default:
          continue;
      }
    }
    if (!sawHeader) throw const FormatException('not a Fluenough review log');
    return (reviews: reviews, leechActions: actions);
  }

  static ProgressKey _key(Map<String, Object?> o, int n) {
    final deck = o['deck'];
    final card = o['card'];
    final mode = DrillMode.tryParse('${o['mode']}');
    if (deck is! String || card is! String || mode == null) {
      throw FormatException('line $n: deck, card or mode is missing');
    }
    return (deckId: deck, cardId: card, mode: mode);
  }

  static DateTime _time(Map<String, Object?> o, int n) {
    final ts = o['ts'];
    final at = ts is String ? DateTime.tryParse(ts) : null;
    if (at == null) throw FormatException('line $n: ts is not a time');
    return at.toLocal();
  }

  static int _grade(Map<String, Object?> o, int n) {
    final grade = _int(o, 'grade', n);
    if (grade < 0 || grade > 5) throw FormatException('line $n: grade $grade');
    return grade;
  }

  static int _int(Map<String, Object?> o, String key, int n) {
    final v = o[key];
    if (v is! int) throw FormatException('line $n: $key is not a whole number');
    return v;
  }
}

/// What makes two reviews the same review, for an import that must not
/// double the history: the pair and the moment, to the millisecond.
String reviewIdentity(LoggedReview r) =>
    '${r.key.deckId}|${r.key.cardId}|${r.key.mode.name}|'
    '${r.at.millisecondsSinceEpoch}';

/// The same, for a leech action.
String leechIdentity(LeechAction a) =>
    '${a.key.deckId}|${a.key.cardId}|${a.key.mode.name}|'
    '${a.at.millisecondsSinceEpoch}|${a.kind.name}';
