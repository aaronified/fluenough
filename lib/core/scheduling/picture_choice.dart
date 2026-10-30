import 'dart:math';

import '../models/card.dart';
import '../models/reading.dart';
import 'distractors.dart';

/// The picture choice (#91, owner 2026-10-30: "A form of Recognition"): the
/// word shown or heard, and the learner picks the picture of it from four.
/// Pure Dart, so it is tested in milliseconds. The pool is the cards of the
/// one deck; this file never reaches outside it.

/// How many pictures a picture choice offers.
const int pictureOptionCount = 4;

/// The picture [card] can be offered as, or null where it cannot be: a card
/// needs a Noto Emoji `picture` that means exactly its word. A question
/// word's picture only asks ([Card.pictureAsk]), a rules table's cell and a
/// reading question are no concrete word, and a card's own `image` is not
/// used: it is a file that may not be on the phone.
String? choosablePicture(Card card) {
  if (card is QuestionCard || card.rule != null || card.pictureAsk) return null;
  final picture = card.picture;
  return picture == null || picture.isEmpty ? null : picture;
}

/// What makes two pictures near-duplicates: the emoji without its variation
/// selector and skin tone, and without what a zero-width joiner adds, so 👍,
/// 👍🏽 and 🧑 beside 🧑‍🍳 count as one. Conservative: a near miss that
/// is left out costs an option, never a wrong answer.
String pictureFamily(String picture) {
  final runes = picture.runes
      .where((r) => r != 0xFE0F && !(r >= 0x1F3FB && r <= 0x1F3FF))
      .toList();
  return runes.isEmpty ? picture : String.fromCharCode(runes.first);
}

String _norm(String s) => s.trim().toLowerCase();

/// Whether showing [a]'s and [b]'s pictures together could make two answers
/// right, or one of them a giveaway: the same picture or a near-duplicate
/// ([pictureFamily]), the same target or a shared meaning, a synonym, or a
/// word of the same family ([Card.bases]).
bool picturesConflict(Card a, Card b) {
  if (a.id == b.id) return true;
  final pa = a.picture;
  final pb = b.picture;
  if (pa != null && pb != null && pictureFamily(pa) == pictureFamily(pb)) {
    return true;
  }
  if (_norm(a.target) == _norm(b.target)) return true;
  final meaningsA = <String>{for (final m in a.meanings) _norm(m)};
  if (b.meanings.any((m) => meaningsA.contains(_norm(m)))) return true;
  bool names(Card x, Card y) => x.synonyms.any((s) => s.ref == y.id);
  if (names(a, b) || names(b, a)) return true;
  return distractorSources(a, b).contains(DistractorSource.base);
}

/// The cards of [deckCards] that may be offered as a wrong picture for
/// [card], grouped so that no two cards of one group may be offered together:
/// a group is a set of cards joined by [picturesConflict]. Offering one card
/// per group is always safe, whichever are picked. Empty where [card] has no
/// choosable picture.
List<List<Card>> pictureGroups(Card card, Iterable<Card> deckCards) {
  if (choosablePicture(card) == null) return const <List<Card>>[];
  final pool = <Card>[
    for (final other in deckCards)
      if (choosablePicture(other) != null && !picturesConflict(card, other))
        other,
  ];
  // Union-find over the pool by conflict.
  final parent = List<int>.generate(pool.length, (i) => i);
  int find(int i) => parent[i] == i ? i : parent[i] = find(parent[i]);
  for (var i = 0; i < pool.length; i++) {
    for (var j = i + 1; j < pool.length; j++) {
      if (picturesConflict(pool[i], pool[j])) parent[find(i)] = find(j);
    }
  }
  final groups = <int, List<Card>>{};
  for (var i = 0; i < pool.length; i++) {
    groups.putIfAbsent(find(i), () => <Card>[]).add(pool[i]);
  }
  return groups.values.toList();
}

/// Whether [card] can be asked as a picture choice among [deckCards]: it has
/// a choosable picture, and the deck has three more, none of which may be
/// taken for it.
bool canChoosePicture(Card card, Iterable<Card> deckCards) =>
    pictureGroups(card, deckCards).length >= pictureOptionCount - 1;

/// The four pictures of a picture choice for [card], its own among them, in
/// the order shown, or null where it cannot be asked ([canChoosePicture]).
/// The other three come from [deckCards], the deck's, never twice the same
/// picture, nor a near-duplicate, nor a card meaning the same. Those that
/// share most with [card] (its part of speech, its tags) are preferred, as
/// wrong options of other questions are ([rankDistractors]). Deterministic:
/// the same arguments and [seed] give the same options in the same order.
List<Card>? pictureOptions(
  Card card,
  Iterable<Card> deckCards, {
  int seed = 0,
}) {
  final groups = pictureGroups(card, deckCards);
  if (groups.length < pictureOptionCount - 1) return null;
  final random = Random(seed);
  // Offering any one card per group is safe; the group's own order is only
  // its deck order, so each is ranked and shuffled as a card of its own.
  final ranked = <Card>[
    for (final rank in rankDistractors(card, groups.expand((g) => g)))
      ...(<Card>[...rank]..shuffle(random)),
  ];
  final used = <int>{};
  final picked = <Card>[card];
  for (final other in ranked) {
    if (picked.length == pictureOptionCount) break;
    final group = groups.indexWhere((g) => g.contains(other));
    if (used.add(group)) picked.add(other);
  }
  return picked..shuffle(random);
}

/// A number from [text] that does not change between runs or phones (FNV-1a,
/// 32 bits), for choosing among forms of a question from a card's id.
int stableHash(String text) {
  var hash = 0x811C9DC5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// How a review turns a word it has asked before into a picture choice,
/// from the card and how often the pair was reviewed, so that it holds after
/// a restart and needs no random number: a pair is asked as a picture on
/// every other review, from the first after its lesson; the shown word and
/// the heard word take turns. Null where it is asked as it was.
({bool hear})? pictureTurn(
  Card card,
  int repetitions, {
  required bool canHear,
}) {
  if (repetitions <= 0) return null;
  final h = stableHash(card.id);
  if ((h + repetitions).isOdd) return null;
  return (hear: canHear && ((h + repetitions) ~/ 2).isOdd);
}
