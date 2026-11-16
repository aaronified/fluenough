import 'dart:math' as math;

import '../models/card.dart';
import '../search/fuzzy.dart' show editDistance;
import 'distractors.dart';
import 'look_alike.dart';

// Wrong options for a choice question in a review, made by code from the
// cards that exist (no option is written by hand): the cards that look most
// like the right one come first, so that no surface cue (length, word class,
// the odd one out) can give it away. Pure Dart.

/// The most edit distance told apart; further than this, options are equally
/// far from the right one.
const int _kFar = 8;

/// The cards of [pool] ranked as wrong options for [card], the likeliest
/// first: those in one length band as the right option's [textOf] (and about
/// as many words, [inOneBand]) before the rest; within each, a word of the
/// card's family, then one of its word class ([Card.pos]), then the more tags
/// it shares, then the nearer by edit distance; equal cards in the order
/// [random] gives.
///
/// The result holds exactly the cards of [pool] that are not [card] and whose
/// text differs from the right option's: none is added, and a pool never
/// gets smaller for the ranking. The caller takes the first it needs.
List<Card> rankLookAlikes(
  Card card,
  Iterable<Card> pool, {
  required String Function(Card) textOf,
  math.Random? random,
}) {
  final rng = random ?? math.Random(0);
  final answer = textOf(card);
  final answerKey = answer.toLowerCase();
  final entries = <_Entry>[];
  for (final other in pool) {
    if (other.id == card.id) continue;
    final text = textOf(other);
    if (text.isEmpty || text.toLowerCase() == answerKey) continue;
    final sources = distractorSources(card, other);
    entries.add(
      _Entry(
        other,
        inBand: inOneBand(answer, text),
        family: sources.contains(DistractorSource.base),
        pos: sources.contains(DistractorSource.pos),
        tags: card.tags.where(other.tags.contains).length,
        distance: editDistance(answerKey, text.toLowerCase(), max: _kFar),
        tie: rng.nextDouble(),
      ),
    );
  }
  entries.sort((a, b) => a.compareTo(b));
  return <Card>[for (final e in entries) e.card];
}

class _Entry implements Comparable<_Entry> {
  _Entry(
    this.card, {
    required this.inBand,
    required this.family,
    required this.pos,
    required this.tags,
    required this.distance,
    required this.tie,
  });

  final Card card;
  final bool inBand;
  final bool family;
  final bool pos;
  final int tags;
  final int distance;
  final double tie;

  @override
  int compareTo(_Entry other) {
    var c = _flag(other.inBand).compareTo(_flag(inBand));
    if (c != 0) return c;
    c = _flag(other.family).compareTo(_flag(family));
    if (c != 0) return c;
    c = _flag(other.pos).compareTo(_flag(pos));
    if (c != 0) return c;
    c = other.tags.compareTo(tags);
    if (c != 0) return c;
    c = distance.compareTo(other.distance);
    if (c != 0) return c;
    return tie.compareTo(other.tie);
  }

  static int _flag(bool v) => v ? 1 : 0;
}
