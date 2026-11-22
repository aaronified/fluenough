/// A mail of reviews the reviewer sent, kept on the phone so that "Reviews
/// to send" can list it under Sent and offer "Send again".
///
/// The phone cannot know whether a mail went: it records that the mail app
/// opened with the files. Each mail is its own record (when, which decks,
/// which daily-question answers), so what one mail can do again never
/// depends on another mail's.
library;

/// One mail the mail app was opened with.
class SentMail {
  SentMail({
    required this.at,
    Map<String, DateTime?> decks = const <String, DateTime?>{},
    List<String> answers = const <String>[],
  }) : decks = Map<String, DateTime?>.unmodifiable(decks),
       answers = List<String>.unmodifiable(answers);

  /// When the mail was made: the time its decks and answers were marked
  /// sent, which is also what ties the mail to them.
  final DateTime at;

  /// The decks it carried, by deck id, each with when the deck was last sent
  /// before this mail (null if never): what "Send again" puts back.
  final Map<String, DateTime?> decks;

  /// The ids of the daily-question answers it carried.
  final List<String> answers;

  bool get isEmpty => decks.isEmpty && answers.isEmpty;

  /// The decks of this mail whose changes the deck data does not show yet:
  /// those not in [acknowledged]. They are what "Send again" puts back.
  Set<String> unacknowledged(Set<String> acknowledged) => <String>{
    for (final id in decks.keys)
      if (!acknowledged.contains(id)) id,
  };

  /// Whether "Send again" is offered: while a deck of the mail is not
  /// acknowledged by the deck data. A mail of daily-question answers only
  /// has nothing the data could show, so it can always be sent again.
  bool canSendAgain(Set<String> acknowledged) => decks.isEmpty
      ? answers.isNotEmpty
      : unacknowledged(acknowledged).isNotEmpty;

  /// This mail without [deckIds], and without its answers when
  /// [withAnswers]: what was put back to send again.
  SentMail without(Set<String> deckIds, {required bool withAnswers}) =>
      SentMail(
        at: at,
        decks: <String, DateTime?>{
          for (final MapEntry(:key, :value) in decks.entries)
            if (!deckIds.contains(key)) key: value,
        },
        answers: withAnswers ? const <String>[] : answers,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.toUtc().toIso8601String(),
    'decks': <String, Object?>{
      for (final MapEntry(:key, :value) in decks.entries)
        key: value?.toUtc().toIso8601String(),
    },
    if (answers.isNotEmpty) 'answers': answers,
  };

  /// The mail [json] holds, or null when it is not one.
  static SentMail? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    if (at == null) return null;
    final decks = json['decks'];
    final answers = json['answers'];
    return SentMail(
      at: at,
      decks: <String, DateTime?>{
        if (decks is Map)
          for (final MapEntry(:key, :value) in decks.entries)
            if (key is String)
              key: value is String ? DateTime.tryParse(value) : null,
      },
      answers: <String>[
        if (answers is List)
          for (final a in answers)
            if (a is String) a,
      ],
    );
  }
}
