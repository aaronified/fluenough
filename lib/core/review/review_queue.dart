/// The deck builders' questions for a reviewer (owner, 2026-11-06, "go B"):
/// what a builder could not settle about a card, written in
/// `docs/review-queue/<lang>.md` and turned by `tools/review_queue.py` into
/// `decks/review-queue.json`, a file beside the decks and not part of any.
/// Pure Dart. A released app that does not know the file never asks for it.
library;

import 'dart:convert';

/// The builder questions of every language, by card.
class ReviewQueue {
  const ReviewQueue._(this._cards);

  /// No questions.
  static const ReviewQueue empty = ReviewQueue._(
    <String, Map<String, List<String>>>{},
  );

  /// The file's `format`, under `format`.
  static const String format = 'fluenough-review-queue';

  /// The newest file version this app reads.
  static const int version = 1;

  /// The most a card's questions may be, so that a long queue never fills a
  /// screen.
  static const int maxPerCard = 3;

  final Map<String, Map<String, List<String>>> _cards;

  /// Reads the file. Never throws: a file that is not this format, or a
  /// newer version, gives [empty], and an entry that is not a card with
  /// questions is left out. Keys this app does not know are ignored.
  static ReviewQueue parse(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map ||
          json['format'] != format ||
          json['version'] is! int ||
          (json['version'] as int) > version) {
        return empty;
      }
      final languages = json['languages'];
      if (languages is! Map) return empty;
      final out = <String, Map<String, List<String>>>{};
      languages.forEach((Object? code, Object? entry) {
        final cards = entry is Map ? entry['cards'] : null;
        if (code is! String || cards is! Map) return;
        final byCard = <String, List<String>>{};
        cards.forEach((Object? id, Object? rows) {
          if (id is! String || rows is! List) return;
          final questions = <String>[
            for (final row in rows)
              if (row is Map &&
                  row['question'] is String &&
                  (row['question'] as String).trim().isNotEmpty)
                (row['question'] as String).trim(),
          ];
          if (questions.isNotEmpty) {
            byCard[id] = questions.take(maxPerCard).toList(growable: false);
          }
        });
        if (byCard.isNotEmpty) out[code] = byCard;
      });
      return out.isEmpty ? empty : ReviewQueue._(out);
    } on FormatException {
      return empty;
    }
  }

  /// What the builder asks about [card] of [language], in the order written.
  List<String> forCard(String language, String card) =>
      _cards[language]?[card] ?? const <String>[];

  /// Whether [card] has a builder question.
  bool has(String language, String card) => forCard(language, card).isNotEmpty;

  bool get isEmpty => _cards.isEmpty;
}
