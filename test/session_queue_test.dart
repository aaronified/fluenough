import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/sm2.dart';

final now = DateTime(2026, 9, 28, 19);

Card card(String id, {Set<DrillMode> modes = const {}}) => Card(
  id: id,
  deckId: 'test',
  target: 'target $id',
  native: 'native $id',
  modes: modes,
);

/// A state due [daysAgo] days before [now]; negative means in the future.
Sm2State dueDaysAgo(int daysAgo) => Sm2State(
  repetitions: 2,
  easeFactor: Sm2.defaultEase,
  intervalDays: 6,
  dueAt: now.subtract(Duration(days: daysAgo)),
);

SessionQueue build(
  List<Card> cards, {
  Map<(String, DrillMode), Sm2State> states = const {},
  bool voice = true,
  int newCardLimit = 20,
  Set<DrillMode>? modes,
}) {
  Sm2State? lookup(Card c, DrillMode m) => states[(c.id, m)];
  bool hasVoice(Card _) => voice;
  return modes == null
      ? SessionQueue.build(
          cards: cards,
          stateOf: lookup,
          hasVoice: hasVoice,
          now: now,
          newCardLimit: newCardLimit,
        )
      : SessionQueue.build(
          cards: cards,
          stateOf: lookup,
          hasVoice: hasVoice,
          now: now,
          newCardLimit: newCardLimit,
          modes: modes,
        );
}

List<String> ids(List<SessionItem> items) => [
  for (final i in items) '${i.card.id}:${i.mode.name}',
];

void main() {
  group('new cards', () {
    test('a new card starts with recognition', () {
      final queue = build([card('a'), card('b')]);
      expect(ids(queue.fresh), ['a:recognition', 'b:recognition']);
      expect(queue.due, isEmpty);
      expect(queue.items.every((i) => i.isNew), isTrue);
    });

    test('the cap limits new pairs and keeps the cards in order', () {
      final queue = build([
        for (final id in ['a', 'b', 'c', 'd']) card(id),
      ], newCardLimit: 2);
      expect(ids(queue.fresh), ['a:recognition', 'b:recognition']);
    });

    test('a cap of zero, or less, adds nothing new', () {
      expect(build([card('a')], newCardLimit: 0).isEmpty, isTrue);
      expect(build([card('a')], newCardLimit: -3).isEmpty, isTrue);
    });

    test('the cap counts pairs: a card known by sight is new to type', () {
      final queue = build(
        [card('a')],
        states: {('a', DrillMode.recognition): dueDaysAgo(-3)},
      );
      expect(ids(queue.fresh), ['a:production']);
    });
  });

  group('due cards', () {
    test('due reviews come first, most overdue first', () {
      final queue = build(
        [card('a'), card('b'), card('c'), card('new')],
        states: {
          ('a', DrillMode.recognition): dueDaysAgo(1),
          ('b', DrillMode.recognition): dueDaysAgo(5),
          ('c', DrillMode.recognition): dueDaysAgo(3),
        },
      );
      expect(ids(queue.items), [
        'b:recognition',
        'c:recognition',
        'a:recognition',
        'new:recognition',
      ]);
      expect(queue.due.every((i) => !i.isNew), isTrue);
    });

    test('equally overdue cards keep the order they were given in', () {
      final queue = build(
        [card('z'), card('y')],
        states: {
          ('z', DrillMode.recognition): dueDaysAgo(2),
          ('y', DrillMode.recognition): dueDaysAgo(2),
        },
      );
      expect(ids(queue.due), ['z:recognition', 'y:recognition']);
    });

    test('reviews are never held back by the new-card cap', () {
      final queue = build(
        [card('a'), card('b')],
        states: {
          ('a', DrillMode.recognition): dueDaysAgo(1),
          ('b', DrillMode.recognition): dueDaysAgo(1),
        },
        newCardLimit: 0,
      );
      expect(queue.due, hasLength(2));
    });

    test('a card not yet due is left out', () {
      final queue = build(
        [card('a')],
        states: {for (final m in DrillMode.values) ('a', m): dueDaysAgo(-1)},
      );
      expect(queue.isEmpty, isTrue);
    });
  });

  group('one mode per card per session', () {
    test('a card due in two modes is drilled in the more overdue one', () {
      final queue = build(
        [card('a')],
        states: {
          ('a', DrillMode.recognition): dueDaysAgo(1),
          ('a', DrillMode.production): dueDaysAgo(4),
        },
      );
      expect(ids(queue.items), ['a:production']);
    });

    test('a card with a due mode adds no new mode as well', () {
      final queue = build(
        [card('a')],
        states: {('a', DrillMode.recognition): dueDaysAgo(1)},
      );
      expect(ids(queue.items), ['a:recognition']);
    });

    test('no card appears twice', () {
      final cards = [for (var i = 0; i < 10; i++) card('c$i')];
      final queue = build(
        cards,
        states: {
          for (final c in cards)
            for (final m in DrillMode.values) (c.id, m): dueDaysAgo(1),
        },
      );
      final seen = queue.items.map((i) => i.card.id).toList();
      expect(seen.toSet(), hasLength(seen.length));
    });
  });

  group('modes', () {
    test('only the modes the card declares are offered', () {
      final queue = build([
        card('a', modes: {DrillMode.listening}),
      ]);
      expect(ids(queue.items), ['a:listening']);
    });

    test('with no voice, listening is never offered', () {
      final queue = build(
        [
          card('a', modes: {DrillMode.listening}),
          card('b'),
        ],
        states: {
          ('b', DrillMode.recognition): dueDaysAgo(-2),
          ('b', DrillMode.production): dueDaysAgo(-2),
          ('b', DrillMode.listening): dueDaysAgo(1),
        },
        voice: false,
      );
      expect(queue.isEmpty, isTrue);
    });

    test('a mode the learner switched off is never offered', () {
      final queue = build(
        [card('a')],
        states: {('a', DrillMode.recognition): dueDaysAgo(1)},
        modes: {DrillMode.production},
      );
      expect(ids(queue.items), ['a:production']);
    });

    test('grammar is offered only to cards that declare it', () {
      final queue = build([
        card('verb', modes: {DrillMode.grammar}),
        card('word'),
      ]);
      expect(ids(queue.items), ['verb:grammar', 'word:recognition']);
    });

    test('counts items per mode', () {
      final queue = build(
        [card('a'), card('b'), card('c')],
        states: {('c', DrillMode.production): dueDaysAgo(1)},
      );
      expect(queue.countByMode(), {
        DrillMode.production: 1,
        DrillMode.recognition: 2,
      });
      expect(queue.length, 3);
    });
  });

  test('the empty queue is empty', () {
    expect(SessionQueue.empty.isEmpty, isTrue);
    expect(SessionQueue.empty.items, isEmpty);
  });
}
