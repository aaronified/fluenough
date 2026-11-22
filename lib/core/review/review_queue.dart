/// The deck builders' questions for a reviewer (owner, 2026-11-06, "go B"):
/// what a builder could not settle about a card, written in
/// `docs/review-queue/<lang>.md` and turned by `tools/review_queue.py` into
/// `decks/review-queue.json`, a file beside the decks and not part of any.
/// Pure Dart. A released app that does not know the file never asks for it.
library;

import 'dart:convert';
import 'dart:isolate';

import 'facets.dart';

/// A deck builder's doubt about one facet of one card (builder questions v2,
/// owner, 2026-11-22; wiki Plan-Builder-Questions-V2). It is not a question:
/// the app asks one fixed question per [facet], and [concern] is only the
/// context "The deck builder was unsure: ...".
class BuilderAsk {
  const BuilderAsk({
    required this.facet,
    this.ref,
    this.concern,
    this.by = '',
    this.date = '',
  });

  /// The facet doubted.
  final Facet facet;

  /// For [Facet.example], the 8 hex of the example's text (`pointHash`) when
  /// the builder doubts one example; null means the facet as a whole.
  final String? ref;

  /// A short plain statement, at most [ReviewQueue.maxConcern] characters, or
  /// null. Never turned into a question.
  final String? concern;

  /// Who raised it, and the day (`YYYY-MM-DD`), as written in the queue file.
  final String by;
  final String date;
}

/// The builder questions of every language, by card.
class ReviewQueue {
  const ReviewQueue._(this._cards, [this._asks = _noAsks]);

  static const Map<String, Map<String, List<BuilderAsk>>> _noAsks =
      <String, Map<String, List<BuilderAsk>>>{};

  /// No questions.
  static const ReviewQueue empty = ReviewQueue._(
    <String, Map<String, List<String>>>{},
  );

  /// The file's `format`, under `format`.
  static const String format = 'fluenough-review-queue';

  /// The newest file `version` this app reads. It stays 1 on purpose: a
  /// released app stops at a version it does not know and would lose every
  /// row, so the v2 facet asks (`asks`, under `asks_version` 2) are additive.
  static const int version = 1;

  /// The newest `asks_version` this app reads: the per-card `asks` of
  /// builder questions v2.
  static const int asksVersion = 2;

  /// The most characters of an ask's concern.
  static const int maxConcern = 140;

  /// The most characters of a question: longer is cut, with an ellipsis,
  /// as `tools/review_queue.py` cuts it.
  static const int maxLength = 400;

  /// The most a card's questions may be, so that a long queue never fills a
  /// screen.
  static const int maxPerCard = 3;

  final Map<String, Map<String, List<String>>> _cards;
  final Map<String, Map<String, List<BuilderAsk>>> _asks;

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
      final asked = <String, Map<String, List<BuilderAsk>>>{};
      final readAsks =
          json['asks_version'] is int &&
          (json['asks_version'] as int) <= asksVersion;
      languages.forEach((Object? code, Object? entry) {
        if (code is! String || entry is! Map) return;
        if (readAsks) {
          final found = _parseAsks(entry['asks']);
          if (found.isNotEmpty) asked[code] = found;
        }
        final cards = entry['cards'];
        if (cards is! Map) return;
        final byCard = <String, List<String>>{};
        cards.forEach((Object? id, Object? rows) {
          if (id is! String || rows is! List) return;
          final questions = <String>[
            for (final row in rows)
              if (row is Map &&
                  row['question'] is String &&
                  isAskable((row['question'] as String).trim()))
                _cut((row['question'] as String).trim(), maxLength),
          ];
          if (questions.isNotEmpty) {
            byCard[id] = questions.take(maxPerCard).toList(growable: false);
          }
        });
        if (byCard.isNotEmpty) out[code] = byCard;
      });
      return out.isEmpty && asked.isEmpty ? empty : ReviewQueue._(out, asked);
    } on FormatException {
      return empty;
    }
  }

  /// The asks of one language, by card id. Never throws: an ask with an
  /// unknown facet or no text keys is left out, a concern that is empty is
  /// null, and one longer than [maxConcern] is cut.
  static Map<String, List<BuilderAsk>> _parseAsks(Object? asks) {
    final out = <String, List<BuilderAsk>>{};
    if (asks is! Map) return out;
    asks.forEach((Object? id, Object? rows) {
      if (id is! String || rows is! List) return;
      final seen = <Facet>{};
      final list = <BuilderAsk>[];
      for (final row in rows) {
        if (row is! Map) continue;
        final facet = Facet.fromWire(row['facet']);
        // One ask a facet, as the checker enforces.
        if (facet == null || !seen.add(facet)) continue;
        final ref = row['ref'];
        final concern = row['concern'];
        final by = row['by'];
        final date = row['date'];
        list.add(
          BuilderAsk(
            facet: facet,
            ref: ref is String && ref.isNotEmpty ? ref : null,
            concern: concern is String && concern.trim().isNotEmpty
                ? _cut(concern.trim(), maxConcern)
                : null,
            by: by is String ? by : '',
            date: date is String ? date : '',
          ),
        );
      }
      if (list.isNotEmpty) out[id] = List<BuilderAsk>.unmodifiable(list);
    });
    return out;
  }

  /// Whether [question] can be put to a reader as a yes or no: it is a
  /// question, ending in a question mark (`?` or `\uFF1F`). A note such as
  /// "death year uncertain: 1890 or 1891" or "source unverified" is not
  /// one, and is never offered to a reviewer. The feed has no other marker,
  /// so this is the rule (wiki Plan-Reviewing-Scope, "Builder questions").
  /// Each row is keyed by a card id, so it always names an item to look at.
  static bool isAskable(String question) {
    final text = question.trim();
    return text.endsWith('?') || text.endsWith('\uFF1F');
  }

  static String _cut(String question, int limit) {
    if (question.length <= limit) return question;
    var end = limit - 1;
    // Never between the halves of a surrogate pair.
    if (question.codeUnitAt(end - 1) >= 0xD800 &&
        question.codeUnitAt(end - 1) <= 0xDBFF) {
      end--;
    }
    return '${question.substring(0, end).trimRight()}\u2026';
  }

  /// What the builder asks about [card] of [language], in the order written.
  List<String> forCard(String language, String card) =>
      _cards[language]?[card] ?? const <String>[];

  /// The facet doubts the builder raised about [card] of [language] (builder
  /// questions v2), at most one a facet, in the order written. Not shown by
  /// the app yet.
  List<BuilderAsk> asksFor(String language, String card) =>
      _asks[language]?[card] ?? const <BuilderAsk>[];

  /// Whether [card] has a builder question.
  bool has(String language, String card) => forCard(language, card).isNotEmpty;

  bool get isEmpty => _cards.isEmpty && _asks.isEmpty;
}

/// [ReviewQueue.parse] on an isolate of its own (#1699), in place where one
/// cannot run. Never throws, as [ReviewQueue.parse] never does.
Future<ReviewQueue> parseReviewQueueInIsolate(String text) async {
  try {
    return await Isolate.run(() => ReviewQueue.parse(text));
  } catch (_) {
    return ReviewQueue.parse(text);
  }
}
