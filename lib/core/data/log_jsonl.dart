import 'dart:convert';

import '../models/completed_work.dart';
import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import '../models/review_event.dart';
import '../scheduling/ask.dart';
import '../scheduling/fsrs.dart';
import '../scheduling/fsrs_fit.dart';
import '../scheduling/placement_withdrawal.dart';
import '../scheduling/replay.dart';
import '../scheduling/skill_parameters.dart';

/// The review log as JSON Lines, the backup format (#20; docs/LOG-FORMAT.md).
///
/// One JSON object per line: a header, then every review and every leech
/// action, oldest first, then the placement credit the learner took back,
/// then FSRS's parameters fitted to the learner.
/// Plain text, so a backup outlives this app. Of scheduling state only the
/// fitted parameters are written, since they cannot be worked out again
/// from the log; an import rebuilds every other state from it.
abstract final class LogJsonl {
  static const String format = 'fluenough-review-log';
  static const int version = 1;

  /// [reviews], [leechActions] and the [fitted] parameters as JSONL.
  static String encode(
    Iterable<LoggedReview> reviews,
    Iterable<LeechAction> leechActions, {
    Map<SkillKey, FittedParameters> fitted =
        const <SkillKey, FittedParameters>{},
    Iterable<PlacementWithdrawal> withdrawals = const <PlacementWithdrawal>[],
    Iterable<CompletedWork> completedWorks = const <CompletedWork>[],
  }) {
    final lines = <String>[
      jsonEncode(<String, Object>{'format': format, 'version': version}),
      for (final r in reviews)
        jsonEncode(<String, Object?>{
          'type': 'review',
          'ts': r.at.toUtc().toIso8601String(),
          'deck': r.deckId,
          'card': r.key.cardId,
          'mode': r.key.mode.name,
          'grade': r.grade,
          'elapsed_ms': r.elapsed.inMilliseconds,
          if (r.answerGiven != null) 'answer': r.answerGiven,
          if (r.script != null) 'script': r.script,
          if (r.asked != null) 'asked': r.asked!.name,
        }),
      for (final a in leechActions)
        jsonEncode(<String, Object>{
          'type': 'leech',
          'ts': a.at.toUtc().toIso8601String(),
          'card': a.key.cardId,
          'mode': a.key.mode.name,
          'kind': a.kind.name,
        }),
      // A line of a type an older app does not know, which skips it: no
      // version bump (wiki, Plan-Placement-V2, point 17.1).
      for (final w in withdrawals)
        jsonEncode(<String, Object?>{
          'type': 'withdrawal',
          'at': w.at.toUtc().toIso8601String(),
          'language': w.language,
          'credit_at': w.creditAt,
          'modes': w.modeNames,
          'script': w.script,
          'decks': w.sortedDeckIds,
        }),
      // The recommended works the learner marked completed (deck-kinds plan,
      // D13): a line of a type an older app skips, so no version bump.
      for (final w in completedWorks)
        jsonEncode(<String, Object?>{
          'type': 'completed',
          'recommendation': w.recommendationId,
          'language': w.language,
          'at': w.completedAt.toUtc().toIso8601String(),
        }),
      for (final MapEntry(:key, :value) in _sorted(fitted))
        jsonEncode(<String, Object?>{
          'type': 'parameters',
          'ts': value.fittedAt.toUtc().toIso8601String(),
          'language': key.language,
          'mode': key.mode.name,
          'w': value.values,
          'reviews': value.reviewCount,
          if (value.lossBefore != null) 'loss_before': value.lossBefore,
          if (value.lossAfter != null) 'loss_after': value.lossAfter,
        }),
    ];
    return '${lines.join('\n')}\n';
  }

  /// The reviews, leech actions and fitted parameters in [text]. Throws
  /// [FormatException], naming the line, for a file that is not a
  /// Fluenough log or has a malformed line. A line of a type this version
  /// does not know is skipped, so an older app can read a newer backup's
  /// reviews. A backup from before fitting has no parameters.
  static ({
    List<LoggedReview> reviews,
    List<LeechAction> leechActions,
    Map<SkillKey, FittedParameters> fitted,
    List<PlacementWithdrawal> withdrawals,
  })
  decode(String text) {
    final reviews = <LoggedReview>[];
    final taken = <PlacementWithdrawal>[];
    final actions = <LeechAction>[];
    final fitted = <SkillKey, FittedParameters>{};
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
            deckId: _deck(decoded, n),
            at: _time(decoded, n),
            grade: _grade(decoded, n),
            elapsed: Duration(milliseconds: _elapsed(decoded, n)),
            answerGiven: _answer(decoded, n),
            script: _script(decoded, n),
            asked: Ask.values.asNameMap()[decoded['asked']],
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
        case 'withdrawal':
          // Tolerant: a withdrawal that does not read is skipped, and the
          // credit it named stays (and is flagged again), never a failed
          // restore.
          if (_withdrawal(decoded) case final w?) taken.add(w);
        case 'parameters':
          final (key, value) = _fitted(decoded, n);
          final before = fitted[key];
          if (before == null || value.fittedAt.isAfter(before.fittedAt)) {
            fitted[key] = value;
          }
        default:
          continue;
      }
    }
    if (!sawHeader) throw const FormatException('not a Fluenough review log');
    return (
      reviews: reviews,
      leechActions: actions,
      fitted: fitted,
      withdrawals: taken,
    );
  }

  /// The completed recommended works in [text], a backup: the lines of type
  /// `completed`, read tolerantly (a line that does not read is skipped, never
  /// a failed restore) and the earliest mark of a work kept. A text that is
  /// not a log has none; [decode] is what refuses it.
  static List<CompletedWork> decodeCompletedWorks(String text) {
    final found = <String, CompletedWork>{};
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || !line.contains('"completed"')) continue;
      try {
        final o = jsonDecode(line);
        if (o is! Map<String, Object?> || o['type'] != 'completed') continue;
        final id = o['recommendation'];
        final language = o['language'];
        final at = o['at'] is String
            ? DateTime.tryParse(o['at']! as String)
            : null;
        if (id is! String ||
            id.isEmpty ||
            language is! String ||
            language.isEmpty ||
            at == null) {
          continue;
        }
        final work = CompletedWork(
          recommendationId: id,
          language: language,
          completedAt: at.toLocal(),
        );
        final before = found[id];
        if (before == null || work.completedAt.isBefore(before.completedAt)) {
          found[id] = work;
        }
      } on FormatException {
        continue;
      }
    }
    return found.values.toList()..sort((a, b) {
      final byTime = a.completedAt.compareTo(b.completedAt);
      return byTime != 0
          ? byTime
          : a.recommendationId.compareTo(b.recommendationId);
    });
  }

  /// The withdrawal [o] holds, or null when it is not one.
  static PlacementWithdrawal? _withdrawal(Map<String, Object?> o) {
    final at = o['at'] is String ? DateTime.tryParse(o['at']! as String) : null;
    final language = o['language'];
    final creditAt = o['credit_at'];
    final modes = o['modes'];
    final decks = o['decks'];
    final script = o['script'];
    if (at == null ||
        language is! String ||
        language.isEmpty ||
        creditAt is! int ||
        modes is! List ||
        decks is! List ||
        (script != null && script is! String)) {
      return null;
    }
    return PlacementWithdrawal(
      at: at.toLocal(),
      language: language,
      creditAt: creditAt,
      modes: <DrillMode>[
        for (final m in modes) ?(m is String ? DrillMode.tryParse(m) : null),
      ],
      script: script as String?,
      deckIds: <String>[
        for (final d in decks)
          if (d is String && d.isNotEmpty) d,
      ],
    );
  }

  /// [fitted] in a stable order: by language, then mode.
  static List<MapEntry<SkillKey, FittedParameters>> _sorted(
    Map<SkillKey, FittedParameters> fitted,
  ) => fitted.entries.toList()
    ..sort((a, b) {
      final byLanguage = a.key.language.compareTo(b.key.language);
      return byLanguage != 0
          ? byLanguage
          : a.key.mode.index.compareTo(b.key.mode.index);
    });

  static (SkillKey, FittedParameters) _fitted(Map<String, Object?> o, int n) {
    final language = o['language'];
    final mode = DrillMode.tryParse('${o['mode']}');
    if (language is! String || language.isEmpty || mode == null) {
      throw FormatException('line $n: language or mode is missing');
    }
    final w = o['w'];
    if (w is! List ||
        w.length != Fsrs.w.length ||
        w.any((v) => v is! num || !v.toDouble().isFinite)) {
      throw FormatException('line $n: w is not ${Fsrs.w.length} numbers');
    }
    final values = <double>[for (final v in w) (v as num).toDouble()];
    if (!FsrsFit.isPlausible(values)) {
      throw FormatException('line $n: w is out of range');
    }
    final reviews = _int(o, 'reviews', n);
    if (reviews < 0) throw FormatException('line $n: reviews $reviews');
    return (
      (language: language, mode: mode),
      FittedParameters(
        values: values,
        fittedAt: _time(o, n),
        reviewCount: reviews,
        lossBefore: _loss(o, 'loss_before', n),
        lossAfter: _loss(o, 'loss_after', n),
      ),
    );
  }

  static double? _loss(Map<String, Object?> o, String key, int n) {
    final v = o[key];
    if (v == null) return null;
    if (v is! num || !v.toDouble().isFinite) {
      throw FormatException('line $n: $key is not a number');
    }
    return v.toDouble();
  }

  static ProgressKey _key(Map<String, Object?> o, int n) {
    final card = o['card'];
    final mode = DrillMode.tryParse('${o['mode']}');
    if (card is! String || mode == null) {
      throw FormatException('line $n: card or mode is missing');
    }
    // The script skills are worked out from the log, never logged (#556).
    if (mode.isScript) {
      throw FormatException('line $n: mode ${mode.name} is not a drill');
    }
    return (cardId: card, mode: mode);
  }

  /// The deck a review was answered in.
  static String _deck(Map<String, Object?> o, int n) {
    final deck = o['deck'];
    if (deck is! String) throw FormatException('line $n: deck is missing');
    return deck;
  }

  static DateTime _time(Map<String, Object?> o, int n) {
    final ts = o['ts'];
    final at = ts is String ? DateTime.tryParse(ts) : null;
    if (at == null) throw FormatException('line $n: ts is not a time');
    return at.toLocal();
  }

  static String? _answer(Map<String, Object?> o, int n) {
    final answer = o['answer'];
    if (answer != null && answer is! String) {
      throw FormatException('line $n: answer is not text');
    }
    return answer as String?;
  }

  /// The script a review was shown or typed in (#653); absent before it
  /// was kept, and for transliteration.
  static String? _script(Map<String, Object?> o, int n) {
    final script = o['script'];
    if (script != null && script is! String) {
      throw FormatException('line $n: script is not text');
    }
    return script as String?;
  }

  static int _elapsed(Map<String, Object?> o, int n) {
    final ms = _int(o, 'elapsed_ms', n);
    if (ms < 0) throw FormatException('line $n: elapsed_ms $ms');
    return ms;
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
    '${r.key.cardId}|${r.key.mode.name}|${r.at.millisecondsSinceEpoch}';

/// The same, for a leech action.
String leechIdentity(LeechAction a) =>
    '${a.key.cardId}|${a.key.mode.name}|'
    '${a.at.millisecondsSinceEpoch}|${a.kind.name}';
