/// The review queue (ADR-0058, decision 10, work package W3): which cards a
/// reviewer is asked about next. Pure Dart.
///
/// A session is one unit's least-checked cards, [kSessionCards] of them, in
/// path order. After them the reviewer may go on through a pool of all the
/// course's cards, unit by unit, the unit with the least-checked card first,
/// and stops by closing the review. How checked a card is counts distinct
/// reviewers per facet ([scoreOf]); the reviewer's own answers count, so a
/// card answered drops back and the queue resumes where it stopped.
///
/// Nothing here is saved by the queue itself: an answer is recorded the
/// moment it is given (`Reviewing.answerFacet`), so closing at any time
/// loses nothing. Only the run, which cards the session holds, is kept
/// ([ReviewRun.toJson]), so that it resumes as it was and does not pick
/// another unit.
library;

import 'dart:convert';

import '../models/card.dart';
import 'deck_review.dart';
import 'facets.dart';
import 'flagged_queue.dart';
import 'review_pairs.dart';
import 'review_problems.dart';
import 'review_quorum.dart';

/// Cards in one session (owner, 2026-11-21).
const int kSessionCards = 20;

/// A card in a queue: the deck it is read from, and its id.
class QueueCardRef {
  const QueueCardRef({required this.deckId, required this.cardId});

  final String deckId;
  final String cardId;

  Map<String, Object?> toJson() => <String, Object?>{
    'deck': deckId,
    'card': cardId,
  };

  static QueueCardRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final deck = json['deck'];
    final card = json['card'];
    if (deck is! String || card is! String || deck.isEmpty || card.isEmpty) {
      return null;
    }
    return QueueCardRef(deckId: deck, cardId: card);
  }

  @override
  bool operator ==(Object other) =>
      other is QueueCardRef && other.deckId == deckId && other.cardId == cardId;

  @override
  int get hashCode => Object.hash(deckId, cardId);
}

/// One unit of a course's path as the queue reads it: its decks, in path
/// order. The decks hold only the cards a reviewer is asked about (no rude
/// word, no question card).
class QueueUnit {
  const QueueUnit({
    required this.number,
    required this.title,
    required this.decks,
  });

  /// Its place in the course, from 1.
  final int number;
  final String title;
  final List<FlaggedSourceDeck> decks;
}

/// A course's units, and a lookup of their cards.
class ReviewSource {
  ReviewSource({required this.pair, required Iterable<QueueUnit> units})
    : units = List<QueueUnit>.unmodifiable(units) {
    final seen = <String>{};
    for (final unit in this.units) {
      final refs = <QueueCardRef>[];
      for (final deck in unit.decks) {
        for (final card in deck.cards) {
          if (!seen.add(card.id)) continue;
          final ref = QueueCardRef(deckId: deck.deckId, cardId: card.id);
          refs.add(ref);
          _found[ref] = (deck: deck, card: card);
        }
      }
      _cards[unit.number] = List<QueueCardRef>.unmodifiable(refs);
    }
  }

  final ReviewPair pair;
  final List<QueueUnit> units;

  final Map<int, List<QueueCardRef>> _cards = <int, List<QueueCardRef>>{};
  final Map<QueueCardRef, ({FlaggedSourceDeck deck, Card card})> _found =
      <QueueCardRef, ({FlaggedSourceDeck deck, Card card})>{};

  /// The cards of unit [number], each course-wide once, in path order.
  List<QueueCardRef> cardsOf(int number) =>
      _cards[number] ?? const <QueueCardRef>[];

  /// The deck and card [ref] names, or null when the course has not got it.
  ({FlaggedSourceDeck deck, Card card})? find(QueueCardRef ref) => _found[ref];

  QueueUnit? unit(int number) {
    for (final unit in units) {
      if (unit.number == number) return unit;
    }
    return null;
  }

  /// The unit holding [ref], or null.
  QueueUnit? unitOf(QueueCardRef ref) {
    for (final entry in _cards.entries) {
      if (entry.value.contains(ref)) return unit(entry.key);
    }
    return null;
  }

  /// Every card of the course, in path order.
  Iterable<QueueCardRef> get allCards sync* {
    for (final unit in units) {
      yield* cardsOf(unit.number);
    }
  }
}

/// How checked a card is: the fewest distinct reviewers on any of its
/// facets ([least]), and across all its facets ([total]). Lower is checked
/// less; sorted by [least] first.
class CheckScore implements Comparable<CheckScore> {
  const CheckScore(this.least, this.total);

  final int least;
  final int total;

  @override
  int compareTo(CheckScore other) {
    final byLeast = least.compareTo(other.least);
    return byLeast != 0 ? byLeast : total.compareTo(other.total);
  }

  @override
  bool operator ==(Object other) =>
      other is CheckScore && other.least == least && other.total == total;

  @override
  int get hashCode => Object.hash(least, total);

  @override
  String toString() => 'CheckScore($least, $total)';
}

/// How checked [card] of [deck] is: for each facet that applies to it, the
/// distinct reviewers among the other reviewers' checks
/// ([FlaggedSourceDeck.others]) and the reviewer's own answer ([ownCode]).
/// A card with no applicable facet counts as fully unchecked.
CheckScore scoreOf(
  Card card,
  FlaggedSourceDeck deck,
  Reviews reviews,
  String? ownCode,
) {
  try {
    final applicable = facetsOf(card, inUnit: deck.inUnit);
    if (applicable.isEmpty) return const CheckScore(0, 0);
    final own = reviews.card(deck.deckId, card.id)?.facets;
    final ownKey = ownCode?.trim().toUpperCase();
    final others = deck.others[card.id];
    var least = -1;
    var total = 0;
    for (final facet in applicable) {
      final raters = <String>{
        for (final check in others?[facet] ?? const <ReviewCheck>[])
          if (check.key.isNotEmpty) check.key,
        if (ownKey != null && ownKey.isNotEmpty && own?[facet] != null) ownKey,
      };
      total += raters.length;
      if (least < 0 || raters.length < least) least = raters.length;
    }
    return CheckScore(least, total);
  } on Object catch (e) {
    ReviewProblems.report('review queue: score of card ${card.id}: $e');
    return const CheckScore(0, 0);
  }
}

/// Which stretch of the queue a run is in.
enum ReviewPhase {
  /// The session of [kSessionCards] cards.
  session,

  /// The pool of all the course's cards, after the session.
  pool,
}

/// What the queue holds now: one group of cards of one unit, the course it
/// is in, and how far it has gone through the course. Kept on the phone so
/// that a closed review resumes ([toJson]).
class ReviewRun {
  const ReviewRun({
    required this.course,
    required this.phase,
    required this.unit,
    required this.title,
    required this.cards,
    required this.visited,
  });

  /// The course, as [ReviewPair.key] writes it.
  final String course;
  final ReviewPhase phase;

  /// The unit the group is from.
  final int unit;
  final String title;

  /// The group's cards, in the order they are asked.
  final List<QueueCardRef> cards;

  /// The units already gone through or going through, including [unit]: the
  /// pool does not return to them.
  final List<int> visited;

  Map<String, Object?> toJson() => <String, Object?>{
    'course': course,
    'phase': phase.name,
    'unit': unit,
    'title': title,
    'visited': visited,
    'cards': <Object?>[for (final c in cards) c.toJson()],
  };

  String encode() => jsonEncode(toJson());

  /// The run [text] holds, or null for anything else (reported, never
  /// thrown).
  static ReviewRun? decode(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      final course = json['course'];
      final unit = json['unit'];
      final title = json['title'];
      final cards = json['cards'];
      final visited = json['visited'];
      final phase = ReviewPhase.values.asNameMap()[json['phase']];
      if (course is! String ||
          ReviewPair.parse(course) == null ||
          unit is! int ||
          title is! String ||
          cards is! List ||
          phase == null) {
        ReviewProblems.report('review run is not a run');
        return null;
      }
      final refs = <QueueCardRef>[
        for (final c in cards) ?QueueCardRef.fromJson(c),
      ];
      if (refs.isEmpty) return null;
      return ReviewRun(
        course: course,
        phase: phase,
        unit: unit,
        title: title,
        cards: List<QueueCardRef>.unmodifiable(refs),
        visited: List<int>.unmodifiable(<int>{
          if (visited is List)
            for (final v in visited)
              if (v is int) v,
          unit,
        }),
      );
    } on Object catch (e) {
      ReviewProblems.report('review run unreadable: $e');
      return null;
    }
  }
}

/// Builds the queue's groups.
abstract final class ReviewQueueBuilder {
  /// The best (lowest) score among the cards of unit [number], or null for
  /// a unit with no card. Only cards not in [skip] count.
  static CheckScore? _best(
    ReviewSource source,
    int number,
    Reviews reviews,
    String? ownCode, {
    Set<QueueCardRef> skip = const <QueueCardRef>{},
  }) {
    CheckScore? best;
    for (final ref in source.cardsOf(number)) {
      if (skip.contains(ref)) continue;
      final found = source.find(ref);
      if (found == null) continue;
      final score = scoreOf(found.card, found.deck, reviews, ownCode);
      if (best == null || score.compareTo(best) < 0) best = score;
    }
    return best;
  }

  /// The unit, among those with a card not in [exclude] units, whose
  /// least-checked card is the least checked; the earlier unit on a tie.
  static int? _leastChecked(
    ReviewSource source,
    Reviews reviews,
    String? ownCode, {
    Set<int> exclude = const <int>{},
  }) {
    int? chosen;
    CheckScore? chosenScore;
    for (final unit in source.units) {
      if (exclude.contains(unit.number)) continue;
      final best = _best(source, unit.number, reviews, ownCode);
      if (best == null) continue;
      if (chosenScore == null || best.compareTo(chosenScore) < 0) {
        chosen = unit.number;
        chosenScore = best;
      }
    }
    return chosen;
  }

  /// A new session: the unit with the least-checked card, and its [size]
  /// least-checked cards in path order. Null when the course has no card.
  static ReviewRun? startSession(
    ReviewSource source, {
    required Reviews reviews,
    required String? ownCode,
    int size = kSessionCards,
  }) {
    final number = _leastChecked(source, reviews, ownCode);
    if (number == null) return null;
    final refs = source.cardsOf(number);
    final scored = <(int, CheckScore, QueueCardRef)>[];
    for (final (i, ref) in refs.indexed) {
      final found = source.find(ref);
      if (found == null) continue;
      scored.add((i, scoreOf(found.card, found.deck, reviews, ownCode), ref));
    }
    // The least-checked first; a tie keeps path order.
    scored.sort((a, b) {
      final byScore = a.$2.compareTo(b.$2);
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
    final chosen = scored.take(size).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return ReviewRun(
      course: source.pair.key,
      phase: ReviewPhase.session,
      unit: number,
      title: source.unit(number)?.title ?? '',
      cards: List<QueueCardRef>.unmodifiable(<QueueCardRef>[
        for (final c in chosen) c.$3,
      ]),
      visited: <int>[number],
    );
  }

  /// The first group of the pool after [session]: the rest of the session's
  /// unit, if it has cards the session left out, else the next unit
  /// ([nextGroup]). Null when nothing is left.
  static ReviewRun? continuePool(
    ReviewSource source,
    ReviewRun session, {
    required Reviews reviews,
    required String? ownCode,
  }) {
    final rest = <QueueCardRef>[
      for (final ref in source.cardsOf(session.unit))
        if (!session.cards.contains(ref)) ref,
    ];
    if (rest.isNotEmpty) {
      return ReviewRun(
        course: session.course,
        phase: ReviewPhase.pool,
        unit: session.unit,
        title: source.unit(session.unit)?.title ?? session.title,
        cards: List<QueueCardRef>.unmodifiable(rest),
        visited: <int>[...session.visited],
      );
    }
    return nextGroup(source, session, reviews: reviews, ownCode: ownCode);
  }

  /// The pool's next group after [run]: all of the cards of the unit not
  /// gone through whose least-checked card is the least checked, in path
  /// order. Null when every unit has been gone through.
  static ReviewRun? nextGroup(
    ReviewSource source,
    ReviewRun run, {
    required Reviews reviews,
    required String? ownCode,
  }) {
    final visited = <int>{...run.visited, run.unit};
    final number = _leastChecked(source, reviews, ownCode, exclude: visited);
    if (number == null) return null;
    return ReviewRun(
      course: run.course,
      phase: ReviewPhase.pool,
      unit: number,
      title: source.unit(number)?.title ?? '',
      cards: source.cardsOf(number),
      visited: List<int>.unmodifiable(<int>[...visited, number]),
    );
  }

  /// The index of the first card of [cards] the reviewer has not finished:
  /// one whose every applicable facet has an own answer is finished
  /// ([isComplete]). [cards].length when all are. A card the course no
  /// longer has counts as finished.
  static int firstOpen(
    ReviewSource source,
    List<QueueCardRef> cards,
    Reviews reviews,
  ) {
    for (final (i, ref) in cards.indexed) {
      if (!isFinished(source, ref, reviews)) return i;
    }
    return cards.length;
  }

  /// Whether the reviewer has answered every applicable facet of [ref].
  static bool isFinished(
    ReviewSource source,
    QueueCardRef ref,
    Reviews reviews,
  ) {
    final found = source.find(ref);
    if (found == null) return true;
    final applicable = facetsOf(found.card, inUnit: found.deck.inUnit);
    final own =
        reviews.card(found.deck.deckId, found.card.id)?.facets ??
        const <Facet, FacetAnswer>{};
    return isComplete(applicable, own);
  }
}

/// The facets one tap of "All good" or "Done" answers right on the card
/// screen: every applicable facet with no answer yet except the three that
/// are confirmed separately (reading, IPA, audio). That is the plain facets
/// of [allGoodAnswers] and the three the screen shows as flag-only (note,
/// unit placement, offence rating), which a card needs before it counts as
/// reviewed ([isComplete]) and which a reviewer flags by exception.
Map<Facet, FacetAnswer> shortcutAnswers(
  Set<Facet> applicable,
  Map<Facet, FacetAnswer> answers,
) => <Facet, FacetAnswer>{
  for (final facet in Facet.values)
    if (applicable.contains(facet) &&
        !separatelyConfirmedFacets.contains(facet) &&
        !answers.containsKey(facet))
      facet: const FacetAnswer.right(),
};

/// Whether the card screen's one button is enabled: reading, IPA and audio,
/// where the card has them, have each an answer (decision 6).
bool canFinishCard(Set<Facet> applicable, Map<Facet, FacetAnswer> answers) =>
    separatelyConfirmedFacets
        .where(applicable.contains)
        .every(answers.containsKey);

/// Whether the button reads "Done" rather than "All good": a facet of the
/// card is flagged.
bool anyFlagged(Map<Facet, FacetAnswer> answers) =>
    answers.values.any((a) => a.isFlagged);

/// The queue for the flagged-only mode: the cards of [queue], one after the
/// other, as [QueueCardRef]s.
List<QueueCardRef> flaggedRefs(FlaggedQueue queue) => <QueueCardRef>[
  for (final card in queue.cards)
    QueueCardRef(deckId: card.deckId, cardId: card.cardId),
];

/// Whether a facet that other speakers have checked still needs another
/// speaker: some check exists and fewer distinct speakers than the quorum
/// made one. It depends only on how many speakers checked, never on what
/// they said, so that it does not reveal a first verdict to a blind second
/// speaker. The card screen then says so, in words and without a number.
bool needsAnotherSpeaker(Iterable<ReviewCheck> checks) {
  final raters = <String>{
    for (final check in checks)
      if (check.key.isNotEmpty) check.key,
  };
  return raters.isNotEmpty && raters.length < kReviewQuorum;
}
