import 'dart:math' as math;

import 'look_alike.dart';

// The grammar item "pick the wrong one": a list of example sentences of which
// exactly one is wrong, and the learner picks it. In a review nothing is
// handcrafted, so the item is made only from what a deck already gives: its
// right examples, and the wrong ones where a deck provides them. A deck with
// no wrong example gets no item (never one made up by code: a sentence broken
// by a program is wrong in ways the language may not allow). Pure Dart.
//
// No deck key carries wrong examples yet (wiki/Deck-Format.md has none), so
// until one does, [wrongOneItem] returns null for every course; the item is
// ready for the day a deck format adds them.

/// What one deck entry gives: sentences that are right, and sentences it
/// marks as wrong (empty for nearly every deck).
class WrongOneSource {
  const WrongOneSource({
    required this.id,
    required this.right,
    this.wrong = const <String>[],
  });

  /// The card or rule the sentences belong to.
  final String id;

  final List<String> right;
  final List<String> wrong;
}

/// One item: [sentences] in the order shown, of which the one at
/// [wrongIndex] is wrong.
class WrongOneItem {
  const WrongOneItem({
    required this.sourceId,
    required this.sentences,
    required this.wrongIndex,
  });

  /// The source whose wrong example is the answer.
  final String sourceId;
  final List<String> sentences;
  final int wrongIndex;

  String get wrong => sentences[wrongIndex];

  /// Whether picking [index] is right.
  bool isRight(int index) => index == wrongIndex;
}

/// An item for [source] of [count] sentences (default four), or null where
/// the deck gives none: the source has no wrong example, or [pool] (the right
/// examples of the course, [source]'s own included) holds fewer than
/// `count - 1` right sentences that look like the wrong one (one length band,
/// about as many words, [inOneBand]). The right sentences are the source's
/// own first, then others of the pool; a wrong example of the pool's sources
/// is never shown as a right one.
WrongOneItem? wrongOneItem(
  WrongOneSource source,
  Iterable<WrongOneSource> pool, {
  int count = 4,
  math.Random? random,
}) {
  if (count < 2) return null;
  final rng = random ?? math.Random(0);
  final wrongs = <String>[
    for (final w in source.wrong)
      if (w.trim().isNotEmpty) w,
  ];
  if (wrongs.isEmpty) return null;
  final wrong = wrongs[rng.nextInt(wrongs.length)];
  final known = <String>{
    for (final s in pool) ...s.wrong.map((w) => w.trim().toLowerCase()),
    ...source.wrong.map((w) => w.trim().toLowerCase()),
  };
  final seen = <String>{wrong.trim().toLowerCase()};
  final own = <String>[];
  final others = <String>[];
  void take(Iterable<String> from, List<String> into) {
    for (final r in from) {
      final key = r.trim().toLowerCase();
      if (key.isEmpty || known.contains(key) || !inOneBand(wrong, r)) continue;
      if (seen.add(key)) into.add(r);
    }
  }

  take(source.right, own);
  for (final s in pool) {
    if (s.id != source.id) take(s.right, others);
  }
  own.shuffle(rng);
  others.shuffle(rng);
  final right = <String>[...own, ...others];
  if (right.length < count - 1) return null;
  final sentences = <String>[...right.take(count - 1), wrong]..shuffle(rng);
  return WrongOneItem(
    sourceId: source.id,
    sentences: sentences,
    wrongIndex: sentences.indexOf(wrong),
  );
}

/// Whether the item can be offered for [source] at all: it has a wrong
/// example. The check a screen makes before it plans the question.
bool offersWrongOne(WrongOneSource source) =>
    source.wrong.any((w) => w.trim().isNotEmpty);
