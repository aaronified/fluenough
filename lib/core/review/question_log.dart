/// What a reviewer answered to the daily questions (#519), kept on the
/// phone until it is sent, and the day's count.
///
/// Stored as JSON in the profile's settings ([QuestionLog.toJson]).
library;

import 'dart:convert';

import 'review_question.dart';

/// The most a reviewer can ask for in a day, and the choices the screens
/// offer. 0 turns the questions off.
const List<int> questionsPerDayChoices = <int>[0, 5, 10, 15, 20, 30];

/// What a reviewer gets until they choose (owner, 2026-10-13: "default 10").
const int defaultQuestionsPerDay = 10;

/// One answer, with the question it was to.
class LoggedAnswer {
  const LoggedAnswer({
    required this.language,
    required this.card,
    required this.point,
    required this.kind,
    required this.answer,
    required this.on,
    this.reason,
    this.why = '',
    this.sentAt,
  });

  final String language;
  final String card;
  final String point;
  final QuestionKind kind;
  final QuestionAnswer answer;

  /// The day it was answered, `YYYY-MM-DD`: the day it counts for.
  final String on;

  /// One of [QuestionKind.reasons] for an answer that is not Yes, or null.
  final String? reason;

  /// What the reviewer wrote, for the owner reading the mail. Never read
  /// by the bot, never kept in the decks.
  final String why;

  /// When it was sent, or null while it waits.
  final DateTime? sentAt;

  String get id => '$card|$point';

  LoggedAnswer sent(DateTime at) => LoggedAnswer(
    language: language,
    card: card,
    point: point,
    kind: kind,
    answer: answer,
    on: on,
    reason: reason,
    why: why,
    sentAt: at,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'language': language,
    'card': card,
    'point': point,
    'kind': kind.wire,
    'answer': answer.wire,
    'on': on,
    'reason': ?reason,
    if (why.isNotEmpty) 'why': why,
    'sent': ?sentAt?.toUtc().toIso8601String(),
  };

  static LoggedAnswer? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = QuestionKind.parse(json['kind']);
    final answer = QuestionAnswer.parse(json['answer']);
    final language = json['language'];
    final card = json['card'];
    final point = json['point'];
    final on = json['on'];
    if (kind == null ||
        answer == null ||
        language is! String ||
        card is! String ||
        point is! String ||
        on is! String) {
      return null;
    }
    final reason = json['reason'];
    final why = json['why'];
    final sent = json['sent'];
    return LoggedAnswer(
      language: language,
      card: card,
      point: point,
      kind: kind,
      answer: answer,
      on: on,
      reason: reason is String ? reason : null,
      why: why is String ? why : '',
      sentAt: sent is String ? DateTime.tryParse(sent) : null,
    );
  }
}

/// Every question this reviewer answered, and those put off today. Immutable:
/// each change returns a new one.
class QuestionLog {
  const QuestionLog({
    this.answers = const <String, LoggedAnswer>{},
    this.skipped = const <String, String>{},
  });

  /// By question id. One answer to a question: answering again replaces it.
  final Map<String, LoggedAnswer> answers;

  /// The questions put off, by id, with the day they were put off: they come
  /// back the next day.
  final Map<String, String> skipped;

  bool get isEmpty => answers.isEmpty && skipped.isEmpty;

  /// The ids never to ask again: everything answered.
  Set<String> get answered => answers.keys.toSet();

  /// The ids not to ask on [day]: answered, or put off that day.
  Set<String> hiddenOn(String day) => <String>{
    ...answers.keys,
    for (final MapEntry(:key, :value) in skipped.entries)
      if (value == day) key,
  };

  /// How many were answered on [day].
  int answeredOn(String day) => answers.values.where((a) => a.on == day).length;

  /// How many are left to ask on [day] of the [perDay] chosen: what
  /// was not answered waits for the next day, never adds up.
  int leftOn(String day, int perDay) {
    final left = perDay - answeredOn(day);
    return left < 0 ? 0 : left;
  }

  /// The answers not sent yet, in the order they were given.
  List<LoggedAnswer> get unsent => <LoggedAnswer>[
    for (final a in answers.values)
      if (a.sentAt == null) a,
  ];

  /// [question] answered [answer] on [day].
  QuestionLog answer(
    ReviewQuestion question,
    QuestionAnswer answer,
    String day, {
    String? reason,
    String why = '',
  }) {
    final given = LoggedAnswer(
      language: question.language,
      card: question.card,
      point: question.point,
      kind: question.kind,
      answer: answer,
      on: day,
      // A Yes has no reason; any other is one the kind knows.
      reason:
          answer != QuestionAnswer.yes &&
              reason != null &&
              question.kind.reasons.contains(reason)
          ? reason
          : null,
      why: answer == QuestionAnswer.yes ? '' : why.trim(),
    );
    return QuestionLog(
      answers: Map<String, LoggedAnswer>.unmodifiable(<String, LoggedAnswer>{
        ...answers,
        question.id: given,
      }),
      skipped: skipped,
    );
  }

  /// [question] put off on [day].
  QuestionLog skip(ReviewQuestion question, String day) => QuestionLog(
    answers: answers,
    skipped: Map<String, String>.unmodifiable(<String, String>{
      ...skipped,
      question.id: day,
    }),
  );

  /// The answer to [question] taken back, before it is sent.
  QuestionLog undo(ReviewQuestion question) {
    final was = answers[question.id];
    if (was == null || was.sentAt != null) return this;
    return QuestionLog(
      answers: Map<String, LoggedAnswer>.unmodifiable(<String, LoggedAnswer>{
        for (final MapEntry(:key, :value) in answers.entries)
          if (key != question.id) key: value,
      }),
      skipped: skipped,
    );
  }

  /// Marks every answer in [ids] sent at [at].
  QuestionLog sentAt(Iterable<String> ids, DateTime at) {
    final which = ids.toSet();
    return QuestionLog(
      answers: Map<String, LoggedAnswer>.unmodifiable(<String, LoggedAnswer>{
        for (final MapEntry(:key, :value) in answers.entries)
          key: which.contains(key) && value.sentAt == null
              ? value.sent(at)
              : value,
      }),
      skipped: skipped,
    );
  }

  /// Drops what was put off before [day]: a skip lasts a day.
  QuestionLog since(String day) {
    if (skipped.values.every((d) => d == day)) return this;
    return QuestionLog(
      answers: answers,
      skipped: Map<String, String>.unmodifiable(<String, String>{
        for (final MapEntry(:key, :value) in skipped.entries)
          if (value == day) key: value,
      }),
    );
  }

  String toJson() => jsonEncode(<String, Object?>{
    'answers': <Object?>[for (final a in answers.values) a.toJson()],
    'skipped': skipped,
  });

  /// Reads [toJson]'s text; an empty log for anything it cannot read.
  static QuestionLog fromJson(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map) return const QuestionLog();
      final list = json['answers'];
      final skips = json['skipped'];
      final answers = <String, LoggedAnswer>{};
      if (list is List) {
        for (final item in list) {
          final answer = LoggedAnswer.fromJson(item);
          if (answer != null) answers[answer.id] = answer;
        }
      }
      return QuestionLog(
        answers: Map<String, LoggedAnswer>.unmodifiable(answers),
        skipped: Map<String, String>.unmodifiable(<String, String>{
          if (skips is Map)
            for (final MapEntry(:key, :value) in skips.entries)
              if (key is String && value is String) key: value,
        }),
      );
    } on FormatException {
      return const QuestionLog();
    }
  }
}
