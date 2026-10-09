import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';

final now = DateTime(2026, 9, 28, 19);

Card card(String id, {Set<DrillMode> modes = const {}}) => Card(
  id: id,
  deckId: 'test',
  target: 'target $id',
  native: 'native $id',
  modes: modes,
);

/// A state due [daysAgo] days before [now]; negative means in the future.
FsrsState dueDaysAgo(int daysAgo) => FsrsState(
  stability: 6,
  difficulty: 5,
  repetitions: 2,
  intervalDays: 6,
  dueAt: now.subtract(Duration(days: daysAgo)),
  lastReviewAt: now.subtract(Duration(days: daysAgo + 6)),
);

SessionQueue build(
  List<Card> cards, {
  Map<(String, DrillMode), FsrsState> states = const {},
  bool voice = true,
  int newCardLimit = 20,
  Set<DrillMode>? modes,
}) {
  FsrsState? lookup(Card c, DrillMode m) => states[(c.id, m)];
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
    test('a card listed by two decks is one pair, taken once (ADR-0018)', () {
      const listed = Card(
        id: 'a',
        deckId: 'other',
        target: 'target a',
        native: 'native a, as the other deck glosses it',
      );
      final queue = build([card('a'), listed, card('b')]);
      expect(ids(queue.fresh), ['a:recognition', 'b:recognition']);
      expect(
        queue.fresh.first.card.deckId,
        'test',
        reason: 'the first listing',
      );
    });

    test('a new card starts with Recognition', () {
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

    test('only the cards canIntroduce accepts give new pairs; any card can '
        'be due (ADR-0013)', () {
      final queue = SessionQueue.build(
        cards: [card('a'), card('b'), card('c')],
        stateOf: (c, m) =>
            c.id == 'c' && m == DrillMode.recognition ? dueDaysAgo(1) : null,
        hasVoice: (_) => true,
        now: now,
        newCardLimit: 20,
        canIntroduce: (c) => c.id == 'b',
      );
      expect(ids(queue.fresh), ['b:recognition']);
      expect(ids(queue.due), ['c:recognition']);
    });

    test('fairShares splits new pairs equally, in blocks, and passes a short '
        "block's share on", () {
      List<SessionItem> block(String name, int n) => <SessionItem>[
        for (var i = 0; i < n; i++)
          SessionItem(
            card: card('$name$i'),
            mode: DrillMode.production,
            state: null,
          ),
      ];
      final shared = SessionQueue.fairShares(<List<SessionItem>>[
        block('a', 5),
        block('b', 1),
        block('c', 5),
      ], 7);
      expect(shared.map((i) => i.card.id), [
        'a0', 'a1', 'a2', //
        'b0',
        'c0', 'c1', 'c2',
      ]);
      expect(
        SessionQueue.fairShares(<List<SessionItem>>[block('a', 2)], 7),
        hasLength(2),
      );
      expect(SessionQueue.fairShares(<List<SessionItem>>[], 7), isEmpty);
    });

    test('the cap counts pairs: a card known by sight is new to type', () {
      final queue = build(
        [card('a')],
        states: {('a', DrillMode.recognition): dueDaysAgo(-3)},
      );
      expect(ids(queue.fresh), ['a:production']);
    });

    test('the cap counts pairs: a card known in writing is new to hear', () {
      final queue = build(
        [card('a')],
        states: {
          ('a', DrillMode.recognition): dueDaysAgo(-3),
          ('a', DrillMode.production): dueDaysAgo(-3),
        },
      );
      expect(ids(queue.fresh), ['a:listening']);
    });

    test('recognition is a schedule: a new pair, and due like the others '
        '(ADR-0034)', () {
      final queue = build(
        [
          card('a', modes: {DrillMode.recognition}),
          card('b', modes: {DrillMode.recognition}),
        ],
        states: {('b', DrillMode.recognition): dueDaysAgo(5)},
      );
      expect(ids(queue.due), ['b:recognition']);
      expect(ids(queue.fresh), ['a:recognition']);
      expect(ids(build([card('c')]).fresh), [
        'c:recognition',
      ], reason: 'a new word starts with Recognition');
    });
  });

  group('due cards', () {
    test('due reviews come first, most overdue first', () {
      final queue = build(
        [card('a'), card('b'), card('c'), card('new')],
        states: {
          ('a', DrillMode.production): dueDaysAgo(1),
          ('b', DrillMode.production): dueDaysAgo(5),
          ('c', DrillMode.production): dueDaysAgo(3),
        },
      );
      expect(ids(queue.items), [
        'b:production',
        'c:production',
        'a:production',
        'new:recognition',
      ]);
      expect(queue.due.every((i) => !i.isNew), isTrue);
    });

    test('equally overdue cards keep the order they were given in', () {
      final queue = build(
        [card('z'), card('y')],
        states: {
          ('z', DrillMode.production): dueDaysAgo(2),
          ('y', DrillMode.production): dueDaysAgo(2),
        },
      );
      expect(ids(queue.due), ['z:production', 'y:production']);
    });

    test('reviews are never held back by the new-card cap', () {
      final queue = build(
        [card('a'), card('b')],
        states: {
          ('a', DrillMode.production): dueDaysAgo(1),
          ('b', DrillMode.production): dueDaysAgo(1),
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
          ('a', DrillMode.listening): dueDaysAgo(1),
          ('a', DrillMode.production): dueDaysAgo(4),
        },
      );
      expect(ids(queue.items), ['a:production']);
    });

    test('a card with a due mode adds no new mode as well', () {
      final queue = build(
        [card('a')],
        states: {('a', DrillMode.production): dueDaysAgo(1)},
      );
      expect(ids(queue.items), ['a:production']);
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
        states: {('a', DrillMode.listening): dueDaysAgo(1)},
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
        states: {('c', DrillMode.listening): dueDaysAgo(1)},
      );
      expect(queue.countByMode(), {
        DrillMode.listening: 1,
        DrillMode.recognition: 2,
      });
      expect(queue.length, 3);
    });
  });

  test('reviseAll drills every reviewed card, due or not, and nothing new', () {
    final early = card('early');
    final later = card('later');
    final unseen = card('unseen');
    final queue = SessionQueue.build(
      cards: [early, later, unseen],
      stateOf: (c, m) => switch ((c.id, m)) {
        ('early', DrillMode.listening) => dueDaysAgo(-5),
        ('early', DrillMode.production) => dueDaysAgo(-2),
        ('later', DrillMode.listening) => dueDaysAgo(-9),
        _ => null,
      },
      hasVoice: (_) => true,
      now: now,
      newCardLimit: 0,
      reviseAll: true,
    );
    expect(queue.fresh, isEmpty);
    // One mode per card, the one due soonest; soonest card first.
    expect(queue.due.map((i) => (i.card.id, i.mode)), [
      ('early', DrillMode.production),
      ('later', DrillMode.listening),
    ]);
    // Without it, nothing is due yet.
    expect(
      SessionQueue.build(
        cards: [early, later, unseen],
        stateOf: (c, m) => c.id == 'unseen' ? null : dueDaysAgo(-5),
        hasVoice: (_) => true,
        now: now,
        newCardLimit: 0,
      ).isEmpty,
      isTrue,
    );
  });

  test('withoutDue keeps only the new pairs', () {
    final queue = build(
      [card('a'), card('b')],
      states: {('a', DrillMode.production): dueDaysAgo(1)},
    ).withoutDue();
    expect(ids(queue.items), ['b:recognition']);
    expect(queue.due, isEmpty);
  });

  test('the empty queue is empty', () {
    expect(SessionQueue.empty.isEmpty, isTrue);
    expect(SessionQueue.empty.items, isEmpty);
  });
}
