import '../models/card.dart';

/// What a wrong option shares with the card it is a wrong option for, read
/// from the cards' data and not from their kind (ADR-0039). The more a wrong
/// option shares, the likelier a learner who does not know the card is to
/// take it for the card.
enum DistractorSource {
  /// The same word's family: one is a base of the other, or both name the
  /// same base ([Card.bases]).
  base,

  /// The same part of speech ([Card.pos]).
  pos,

  /// At least one tag in common ([Card.tags]).
  tag,

  /// Nothing in common; it is only another card of the pool.
  other,
}

/// The ids that tie [card] to its word family: its own and its bases'.
Set<String> _family(Card card) => <String>{
  card.id,
  for (final base in card.bases)
    if (base.ref case final id?) id,
};

/// What [other] shares with [card], as the sources it comes from.
Set<DistractorSource> distractorSources(Card card, Card other) {
  final sources = <DistractorSource>{};
  if (_family(card).intersection(_family(other)).isNotEmpty) {
    sources.add(DistractorSource.base);
  }
  if (card.pos != null && card.pos == other.pos)
    sources.add(DistractorSource.pos);
  if (card.tags.any(other.tags.contains)) sources.add(DistractorSource.tag);
  return sources.isEmpty ? <DistractorSource>{DistractorSource.other} : sources;
}

/// The cards of [pool] in groups, those that share the most with [card] first
/// (a word of its family, then one of its part of speech and tags, then one
/// of either, then the rest). The groups hold exactly the cards of [pool]:
/// none is added or dropped, so a pool never gets smaller. Within a group
/// nothing is better than another, and the caller picks among them at random.
List<List<Card>> rankDistractors(Card card, Iterable<Card> pool) {
  int rank(Card other) {
    final sources = distractorSources(card, other);
    return (sources.contains(DistractorSource.base) ? 4 : 0) +
        (sources.contains(DistractorSource.pos) ? 2 : 0) +
        (sources.contains(DistractorSource.tag) ? 1 : 0);
  }

  final groups = <int, List<Card>>{};
  for (final other in pool) {
    groups.putIfAbsent(rank(other), () => <Card>[]).add(other);
  }
  final ranks = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return <List<Card>>[for (final r in ranks) groups[r]!];
}
