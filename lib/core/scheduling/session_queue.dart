import '../models/card.dart';
import '../models/drill_mode.dart';
import '../models/reading.dart';
import 'ask.dart';
import 'sm2.dart';

export 'ask.dart';

/// One card, drilled in one mode, in a session.
class SessionItem {
  const SessionItem({
    required this.card,
    required this.mode,
    required this.state,
    this.ask = Ask.own,
    this.group = const <SessionItem>[],
  });

  final Card card;
  final DrillMode mode;

  /// The scheduling state going in, or null for a `(card, mode)` pair that
  /// has never been reviewed.
  final Sm2State? state;

  /// How it is asked; whichever way, it records [mode] (ADR-0024).
  final Ask ask;

  /// For [Ask.matchPairs], the items matched together, this one first, each
  /// recorded on its own. Empty otherwise.
  final List<SessionItem> group;

  /// This item asked as [ask], with [group] for match pairs.
  SessionItem askedAs(
    Ask ask, {
    List<SessionItem> group = const <SessionItem>[],
  }) =>
      SessionItem(card: card, mode: mode, state: state, ask: ask, group: group);

  /// Whether this is the pair's first review. New items are what the daily
  /// new-card cap counts.
  bool get isNew => state == null;

  @override
  String toString() => ask == Ask.own
      ? 'SessionItem(${card.id}, ${mode.name})'
      : 'SessionItem(${card.id}, ${mode.name}, ${ask.name})';
}

/// Looks up the scheduling state of [card] in [mode], or null if that pair
/// has never been reviewed.
typedef StateLookup = Sm2State? Function(Card card, DrillMode mode);

/// Whether the device has a voice for [card]'s language, which decides whether
/// the card can be drilled by ear. See [Card.modesIn].
typedef VoiceLookup = bool Function(Card card);

/// Whether one `(card, mode)` pair is left out, such as a leech the learner
/// has set aside (#19). Its history stays; it just is not drilled.
typedef PairFilter = bool Function(Card card, DrillMode mode);

/// What one session drills: the reviews that are due, then new material up to
/// the day's allowance.
///
/// This is the pure half of the scheduler (#6). It reads scheduling state
/// through a [StateLookup] rather than from a store, so it runs with no
/// database, no clock and no Flutter.
///
/// Three rules:
///
/// - **Due first.** Every `(card, mode)` pair whose state is due goes in,
///   most overdue first. Reviews are never held back by the new-card cap.
/// - **One mode per card per session.** A card due in two modes is drilled in
///   its most overdue one; drilling the same word twice in a sitting tests
///   short-term memory, not the schedule. A card with a due mode contributes
///   no new mode either.
/// - **New pairs up to the cap.** A pair with no state is new. They are taken
///   in the order [SessionQueue.build] was given the cards, one per card, in
///   [DrillMode] declaration order, which puts recognising a word before
///   producing it. The cap counts new pairs rather than new cards, because
///   scheduling is per pair (ADR-0005): a word learned by sight and never
///   typed has a new production pair.
///
/// A mode is only ever offered where [Card.modesIn] allows it, so a card is
/// never drilled by ear on a device without a voice for its language.
///
/// A passage's questions (#98, ADR-0019) keep together. Its new ones are
/// introduced all at once or not at all: when its first fits under the cap,
/// the rest come with it, which can pass the cap by up to three. And in
/// [items], every question of a passage follows its first.
///
/// "Again" is not re-queued: a failed card is due tomorrow, as SM-2 says, and
/// is not drilled a second time in the same session.
class SessionQueue {
  const SessionQueue._(this.due, this.fresh);

  /// An empty session.
  static const SessionQueue empty = SessionQueue._(
    <SessionItem>[],
    <SessionItem>[],
  );

  /// A session of [due] reviews and then [fresh] new pairs, put together by
  /// the caller, as Today does from several courses' queues.
  SessionQueue.of({
    required List<SessionItem> due,
    required List<SessionItem> fresh,
  }) : due = List<SessionItem>.unmodifiable(due),
       fresh = List<SessionItem>.unmodifiable(fresh);

  /// Up to [limit] new pairs from [blocks], shared equally and kept in
  /// blocks: as many from the first as from the second, and so on, each
  /// block's in its own order, one block after another. A block with fewer
  /// than its share gives the rest to the others. Today shares a day's new
  /// cards between the languages being learned this way, so that none is
  /// starved and the script does not change on every card.
  static List<SessionItem> fairShares(
    List<List<SessionItem>> blocks,
    int limit,
  ) {
    final shares = shareCounts(<int>[for (final b in blocks) b.length], limit);
    return <SessionItem>[
      for (final (i, block) in blocks.indexed) ...takeWhole(block, shares[i]),
    ];
  }

  /// How [fairShares] divides [limit] between blocks that hold [sizes]: one
  /// each in turn, a block that runs out giving the rest to the others.
  static List<int> shareCounts(List<int> sizes, int limit) {
    final shares = List<int>.filled(sizes.length, 0);
    var left = limit;
    var gave = true;
    while (left > 0 && gave) {
      gave = false;
      for (var i = 0; i < sizes.length && left > 0; i++) {
        if (shares[i] < sizes[i]) {
          shares[i]++;
          left--;
          gave = true;
        }
      }
    }
    return shares;
  }

  /// The first [count] of [block]. A passage's new questions come together,
  /// so a count that ends inside one runs on to its end.
  static List<SessionItem> takeWhole(List<SessionItem> block, int count) {
    var n = count < 0 ? 0 : count;
    while (n > 0 &&
        n < block.length &&
        _samePassage(block[n - 1].card, block[n].card)) {
      n++;
    }
    return block.take(n).toList();
  }

  /// Builds the session for [cards].
  ///
  /// [modes] limits the session to the modes the learner has switched on, or
  /// to one mode for "practise one skill". [newCardLimit] is how many new
  /// pairs may still be introduced today: the daily cap less those already
  /// introduced. A negative limit counts as zero. [canHear] says whether the
  /// phone can recognise speech in a card's language; without it, nothing is
  /// drilled by speaking.
  ///
  /// Cards from several decks may be mixed. A card listed in more than one
  /// of them has one schedule (ADR-0018), so it is taken once, as the first
  /// to list it does.
  ///
  /// With [reviseAll], every pair already reviewed counts as due, whatever
  /// its date: revising a finished deck. One mode per card still holds, the
  /// one due soonest.
  ///
  /// A card gives either its most overdue pair or its first new one, unless
  /// [newEvenIfDue]: then its first new pair is offered as well, for a
  /// session of new cards only, which drops the due ones.
  ///
  /// [canIntroduce], when given, limits new pairs to the cards it accepts:
  /// Today teaches only a course's pending units (ADR-0013). Due reviews come
  /// from every card. New pairs are taken in the order of [cards].
  factory SessionQueue.build({
    required Iterable<Card> cards,
    required StateLookup stateOf,
    required VoiceLookup hasVoice,
    required DateTime now,
    required int newCardLimit,
    VoiceLookup? canHear,
    PairFilter? isSetAside,
    bool Function(Card card)? canIntroduce,
    bool reviseAll = false,
    bool newEvenIfDue = false,
    Set<DrillMode> modes = const <DrillMode>{
      DrillMode.recognition,
      DrillMode.production,
      DrillMode.reading,
      DrillMode.listening,
      DrillMode.grammar,
      DrillMode.speaking,
    },
  }) {
    final due = <({SessionItem item, int order})>[];
    final fresh = <SessionItem>[];
    var newLeft = newCardLimit < 0 ? 0 : newCardLimit;

    // The pair [card] is most overdue in, or else its first new pair, or
    // neither.
    ({SessionItem? due, SessionItem? fresh}) pairsOf(Card card) {
      final allowed = card.modesIn(
        ttsAvailable: hasVoice(card),
        speechAvailable: canHear?.call(card) ?? false,
      );
      SessionItem? mostOverdue;
      SessionItem? firstNew;
      for (final mode in DrillMode.values) {
        if (!allowed.contains(mode) || !modes.contains(mode)) continue;
        if (isSetAside?.call(card, mode) ?? false) continue;
        final state = stateOf(card, mode);
        if (state == null) {
          firstNew ??= SessionItem(card: card, mode: mode, state: null);
        } else if ((reviseAll || state.isDue(now)) &&
            (mostOverdue == null ||
                state.dueAt.isBefore(mostOverdue.state!.dueAt))) {
          mostOverdue = SessionItem(card: card, mode: mode, state: state);
        }
      }
      return (
        due: mostOverdue,
        fresh: newEvenIfDue || mostOverdue == null ? firstNew : null,
      );
    }

    // A card listed by more than one of the decks is taken once.
    final seen = <String>{};
    final all = <Card>[
      for (final card in cards)
        if (seen.add(card.id)) card,
    ];
    final passages = <String, List<QuestionCard>>{};
    for (final card in all.whereType<QuestionCard>()) {
      (passages[_passageKey(card)] ??= <QuestionCard>[]).add(card);
    }

    var order = 0;
    for (final card in all) {
      if (card is QuestionCard) {
        // The whole passage, when its first question is reached.
        final questions = passages.remove(_passageKey(card));
        if (questions == null) continue;
        final news = <SessionItem>[];
        for (final question in questions) {
          final pairs = pairsOf(question);
          if (pairs.due case final item?) {
            due.add((item: item, order: order++));
          }
          if (pairs.fresh case final item?) news.add(item);
        }
        if (news.isNotEmpty &&
            newLeft > 0 &&
            (canIntroduce?.call(card) ?? true)) {
          fresh.addAll(news);
          newLeft = newLeft > news.length ? newLeft - news.length : 0;
        }
        continue;
      }
      final pairs = pairsOf(card);
      if (pairs.due case final item?) {
        due.add((item: item, order: order++));
      }
      if (pairs.fresh case final item?) {
        if (newLeft > 0 && (canIntroduce?.call(card) ?? true)) {
          fresh.add(item);
          newLeft--;
        }
      }
    }

    // Most overdue first; ties keep the order the cards were given in, so
    // the session is deterministic.
    due.sort((a, b) {
      final byDue = a.item.state!.dueAt.compareTo(b.item.state!.dueAt);
      return byDue != 0 ? byDue : a.order.compareTo(b.order);
    });

    return SessionQueue._(
      List<SessionItem>.unmodifiable(due.map((d) => d.item)),
      List<SessionItem>.unmodifiable(fresh),
    );
  }

  /// Reviews that are due, most overdue first.
  final List<SessionItem> due;

  /// New pairs, within the day's allowance.
  final List<SessionItem> fresh;

  /// The whole session in the order it is drilled: [due], then [fresh],
  /// except that a passage's questions come together, where its first one
  /// was ([inPassages]).
  List<SessionItem> get items => inPassages(<SessionItem>[...due, ...fresh]);

  int get length => due.length + fresh.length;

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  /// The same session with the due reviews left out: only new material, as
  /// "Learn 5 new cards" drills.
  SessionQueue withoutDue() => SessionQueue._(const <SessionItem>[], fresh);

  /// How many items the session drills in each mode. Modes with none are
  /// absent.
  Map<DrillMode, int> countByMode() {
    final counts = <DrillMode, int>{};
    for (final item in items) {
      counts[item.mode] = (counts[item.mode] ?? 0) + 1;
    }
    return counts;
  }
}

/// [items] with each passage's questions together, where its first one was:
/// those to be heard, then those to be read, so that a passage is not seen
/// before it is heard (#98, ADR-0019). Every other item keeps its place.
List<SessionItem> inPassages(List<SessionItem> items) {
  final groups = <String, List<SessionItem>>{};
  for (final item in items) {
    final card = item.card;
    if (card is QuestionCard) {
      (groups[_passageKey(card)] ??= <SessionItem>[]).add(item);
    }
  }
  if (groups.isEmpty) return items;
  final ordered = <SessionItem>[];
  for (final item in items) {
    final card = item.card;
    if (card is! QuestionCard) {
      ordered.add(item);
      continue;
    }
    final group = groups.remove(_passageKey(card));
    if (group == null) continue;
    ordered
      ..addAll(group.where((i) => i.mode == DrillMode.listening))
      ..addAll(group.where((i) => i.mode != DrillMode.listening));
  }
  return ordered;
}

String _passageKey(QuestionCard card) => '${card.deckId}/${card.passage.id}';

bool _samePassage(Card a, Card b) => a is QuestionCard && a.sharesPassage(b);
