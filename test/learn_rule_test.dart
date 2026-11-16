// The learn rule (owner, 2026-11-16): an item is learned only when it was
// shown, then asked twice in two different types, the first question right
// after and the second after two other questions, both right the first time,
// all in one sitting. Only then does it reach FSRS.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/learn_sequence.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:flutter_test/flutter_test.dart';

Card _card(String id, {String? target}) => Card(
  id: id,
  deckId: 'test',
  target: target ?? 'sol $id',
  native: 'sun $id',
);

SessionItem _item(Card card, DrillMode mode, Ask ask) =>
    SessionItem(card: card, mode: mode, state: null, ask: ask);

LearnAttempt _attempt(String id) {
  final card = _card(id);
  return LearnAttempt(
    card: card,
    shows: <SessionItem>[_item(card, DrillMode.recognition, Ask.teach)],
    first: _item(card, DrillMode.recognition, Ask.chooseMeaning),
    second: _item(card, DrillMode.production, Ask.chooseWord),
  );
}

String _shape(SessionItem item) =>
    '${item.card.id}:${item.learn?.step.name ?? item.ask.name}';

void main() {
  group('the learn tracker', () {
    var clock = DateTime(2026, 11, 16, 10);
    LearnTracker<String> tracker() => LearnTracker<String>(now: () => clock);

    setUp(() => clock = DateTime(2026, 11, 16, 10));

    // One attempt as the session runs it: shown, Q1 right after, [between]
    // other questions, then the second answer.
    LearnResult<String> run(
      LearnTracker<String> t, {
      int between = learnGap,
      bool first = true,
      bool second = true,
    }) {
      t.shown('a');
      final one = t.answer('a', LearnStep.first, first, 'q1');
      if (one.outcome == LearnOutcome.failed) return one;
      t.left(id: 'a', step: LearnStep.first);
      for (var i = 0; i < between; i++) {
        t.left();
      }
      return t.answer('a', LearnStep.second, second, 'q2');
    }

    test('learns an item answered right twice, two questions apart', () {
      final result = run(tracker());
      expect(result.outcome, LearnOutcome.learned);
      expect(result.held, <String>['q1', 'q2']);
    });

    test('a wrong first answer ends the attempt and holds nothing', () {
      final t = tracker();
      final result = run(t, first: false);
      expect(result.outcome, LearnOutcome.failed);
      expect(t.phaseOf('a'), isNull);
      // The second question may still be asked, but it learns nothing.
      final late = t.answer('a', LearnStep.second, true, 'q2');
      expect(late.outcome, LearnOutcome.pending);
      expect(late.held, isEmpty);
    });

    test('a wrong second answer leaves the item unlearnt', () {
      final result = run(tracker(), second: false);
      expect(result.outcome, LearnOutcome.failed);
      expect(result.held, isEmpty);
    });

    test('a second question after more than two others learns nothing', () {
      final t = tracker();
      final result = run(t, between: learnGap + 1);
      expect(result.outcome, isNot(LearnOutcome.learned));
      expect(result.held, isEmpty);
      // The attempt ended as soon as its gap was broken.
      expect(t.open, isEmpty);
    });

    test('a second question after fewer than two others learns nothing', () {
      final result = run(tracker(), between: learnGap - 1);
      expect(result.outcome, LearnOutcome.dropped);
      expect(result.held, isEmpty);
    });

    test('a short lesson keeps exactly the gap it was laid out with', () {
      final t = tracker();
      t.shown('a', gap: 1);
      t.answer('a', LearnStep.first, true, 'q1');
      t.left(id: 'a', step: LearnStep.first);
      t.left();
      expect(
        t.answer('a', LearnStep.second, true, 'q2').outcome,
        LearnOutcome.learned,
      );
    });

    test('a first question not right after the show learns nothing', () {
      final t = tracker();
      t.shown('a');
      t.left();
      expect(t.open, isEmpty);
      expect(
        t.answer('a', LearnStep.first, true, 'q1').held,
        isEmpty,
      );
    });

    test('a question skipped unasked ends its attempt', () {
      final t = tracker();
      t.shown('a');
      t.answer('a', LearnStep.first, true, 'q1');
      t.dropAttempt('a');
      expect(t.open, isEmpty);
      expect(t.answer('a', LearnStep.second, true, 'q2').held, isEmpty);
    });

    test('an idle sitting drops the attempt', () {
      final t = tracker();
      t.shown('a');
      t.answer('a', LearnStep.first, true, 'q1');
      t.left(id: 'a', step: LearnStep.first);
      t.left();
      t.left();
      clock = clock.add(learnIdleLimit + const Duration(seconds: 1));
      final result = t.answer('a', LearnStep.second, true, 'q2');
      expect(result.outcome, LearnOutcome.dropped);
      expect(result.held, isEmpty);
    });

    test('a short pause keeps it', () {
      final t = tracker();
      t.shown('a');
      t.answer('a', LearnStep.first, true, 'q1');
      t.left(id: 'a', step: LearnStep.first);
      clock = clock.add(learnIdleLimit - const Duration(seconds: 1));
      t.left();
      t.left();
      expect(
        t.answer('a', LearnStep.second, true, 'q2').outcome,
        LearnOutcome.learned,
      );
    });

    test('leaving the drill drops every open attempt', () {
      final t = tracker();
      t.shown('a');
      t.answer('a', LearnStep.first, true, 'q1');
      t.end();
      expect(t.open, isEmpty);
      expect(
        t.answer('a', LearnStep.second, true, 'q2').held,
        isEmpty,
      );
    });

    test('a first question left unanswered ends its attempt', () {
      final t = tracker();
      t.shown('a');
      t.left(id: 'a', step: LearnStep.first);
      expect(t.phaseOf('a'), isNull);
    });

    test('three attempts at once keep the gap, and a fourth waits', () {
      final t = tracker();
      expect(t.shown('a'), isTrue);
      t.answer('a', LearnStep.first, true, 'a1');
      t.left(id: 'a', step: LearnStep.first);
      expect(t.shown('b'), isTrue);
      t.answer('b', LearnStep.first, true, 'b1');
      t.left(id: 'b', step: LearnStep.first);
      expect(t.shown('c'), isTrue);
      t.answer('c', LearnStep.first, true, 'c1');
      t.left(id: 'c', step: LearnStep.first);
      expect(t.shown('d'), isFalse);
      for (final id in <String>['a', 'b', 'c']) {
        final result = t.answer(id, LearnStep.second, true, '${id}2');
        expect(result.outcome, LearnOutcome.learned, reason: id);
        t.left(id: id, step: LearnStep.second);
      }
      expect(t.open, isEmpty);
    });
  });

  group('the learn sequence', () {
    test('three items run Q1 Q1 Q1 Q2 Q2 Q2, each shown before its Q1', () {
      final items = learnSequence(<LearnAttempt>[
        _attempt('a'),
        _attempt('b'),
        _attempt('c'),
      ]).items;
      expect(items.map(_shape).toList(), <String>[
        'a:show',
        'a:first',
        'b:show',
        'b:first',
        'c:show',
        'c:first',
        'a:second',
        'b:second',
        'c:second',
      ]);
    });

    test('every second question has exactly two others after its first', () {
      final items = learnSequence(<LearnAttempt>[
        for (var i = 0; i < 6; i++) _attempt('x$i'),
      ]).items;
      final questions = <SessionItem>[
        for (final item in items)
          if (!item.ask.onlyShows) item,
      ];
      for (var i = 0; i < 6; i++) {
        final id = 'x$i';
        final q1 = questions.indexWhere(
          (q) => q.learn!.id == id && q.learn!.step == LearnStep.first,
        );
        final q2 = questions.indexWhere(
          (q) => q.learn!.id == id && q.learn!.step == LearnStep.second,
        );
        expect(q2 - q1 - 1, learnGap, reason: id);
        // The show comes right before the first question.
        final at = items.indexOf(questions[q1]);
        expect(items[at - 1].learn!.step, LearnStep.show);
      }
    });

    test('a last group of one is spaced by two reviews where there are', () {
      final review = <SessionItem>[
        _item(_card('r1'), DrillMode.recognition, Ask.chooseMeaning),
        _item(_card('r2'), DrillMode.recognition, Ask.chooseMeaning),
      ];
      final items = learnSequence(<LearnAttempt>[
        _attempt('a'),
      ], fillers: review).items;
      expect(items.map(_shape).toList(), <String>[
        'a:show',
        'a:first',
        'r1:chooseMeaning',
        'r2:chooseMeaning',
        'a:second',
      ]);
    });

    test('a lesson of fewer than three, with no review to space it, is kept '
        'with the shorter gap it can have', () {
      final items = learnSequence(<LearnAttempt>[
        _attempt('a'),
        _attempt('b'),
      ]).items;
      expect(items.map(_shape).toList(), <String>[
        'a:show',
        'a:first',
        'b:show',
        'b:first',
        'a:second',
        'b:second',
      ]);
      expect(items.first.learn!.gap, 1);
    });

    test('a last group that cannot be spaced waits for another lesson', () {
      final items = learnSequence(<LearnAttempt>[
        for (var i = 0; i < 4; i++) _attempt('x$i'),
      ]).items;
      expect(
        items.map((i) => i.card.id).toSet(),
        <String>{'x0', 'x1', 'x2'},
      );
      expect(items.every((i) => i.learn!.gap == learnGap), isTrue);
    });

    test('an item already learned is asked plainly, never tracked', () {
      final card = _card('a');
      final items = learnSequence(<LearnAttempt>[
        LearnAttempt(
          card: card,
          shows: const <SessionItem>[],
          first: _item(card, DrillMode.recognition, Ask.chooseMeaning),
          second: _item(card, DrillMode.production, Ask.chooseWord),
          tracked: false,
        ),
      ]).items;
      expect(items.every((i) => i.learn == null), isTrue);
    });
  });

  group('the two types of an item', () {
    final card = _card('a');

    test('are different, in different skills where the card has them', () {
      final pair = learnPair(<SessionItem>[
        _item(card, DrillMode.recognition, Ask.chooseMeaning),
        _item(card, DrillMode.production, Ask.chooseWord),
      ])!;
      expect(pair.first.ask, Ask.chooseMeaning);
      expect(pair.second.ask, Ask.chooseWord);
      expect(pair.second.mode, isNot(pair.first.mode));
    });

    test('never count a recognition question the learner rates himself', () {
      expect(
        learnPair(<SessionItem>[
          _item(card, DrillMode.recognition, Ask.own),
          _item(card, DrillMode.production, Ask.chooseWord),
        ]),
        isNull,
      );
    });

    test('never count a match, which is a question of a group', () {
      expect(
        learnPair(<SessionItem>[
          _item(card, DrillMode.recognition, Ask.matchPairs),
        ]),
        isNull,
      );
    });

    test('are not found for a card with one type, unless a fallback is', () {
      final one = <SessionItem>[
        _item(card, DrillMode.recognition, Ask.chooseMeaning),
      ];
      expect(learnPair(one), isNull);
      final fallback = _item(card, DrillMode.recognition, Ask.chooseWord);
      final pair = learnPair(one, fallback: fallback)!;
      expect(pair.second.ask, Ask.chooseWord);
    });

    test('a card that cannot be asked two ways is left out, but never a card '
        'already learned, which is practised with one question', () {
      final one = _card('solo');
      LearnAttempt? attempt({required bool tracked}) => lessonAttempt(
        one,
        modesOf: (_) => <DrillMode>{DrillMode.recognition},
        // Nothing to choose from: recognition would only be rated.
        canChoose: (_, _) => false,
        tracked: (_) => tracked,
      );
      expect(attempt(tracked: true), isNull);
      final practised = attempt(tracked: false)!;
      expect(practised.second, isNull);
      expect(
        learnSequence(<LearnAttempt>[practised]).items.map((i) => i.ask),
        isNotEmpty,
      );
    });

    test('are found for a phrase of one word, which has no Write', () {
      const phrase = Card(
        id: 'p',
        deckId: 'test',
        target: 'gracias',
        native: 'thanks',
        pos: 'phrase',
      );
      final plan = lessonPlan(
        <Card>[phrase],
        modesOf: (_) => <DrillMode>{DrillMode.recognition},
        canChoose: (_, _) => true,
      );
      final asks = <Ask>[
        for (final item in plan)
          if (!item.ask.onlyShows) item.ask,
      ];
      expect(asks, <Ask>[Ask.chooseMeaning, Ask.chooseWord]);
    });
  });

  group('a lesson in a drill session', () {
    const deck = '''
schema: 1
id: es-en-learn
name: "Learn"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-en-learn-0001
    target: "sol"
    native: "sun"
  - id: es-en-learn-0002
    target: "mar"
    native: "sea"
  - id: es-en-learn-0003
    target: "luz"
    native: "light"
  - id: es-en-learn-0004
    target: "pan"
    native: "bread"
  - id: es-en-learn-0005
    target: "sal"
    native: "salt"
''';

    Future<({AppState state, DrillSession session, List<Card> cards})> start(
      int count,
    ) async {
      final state = AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/es/es-en-learn.yaml': deck,
        }),
      );
      addTearDown(state.dispose);
      await state.load();
      final cards = state.deckById('es-en-learn')!.cards.take(count).toList();
      final items = lessonPlan(
        cards,
        modesOf: (_) => <DrillMode>{
          DrillMode.recognition,
          DrillMode.production,
        },
        canChoose: (_, _) => true,
        typed: (_) => false,
      );
      final session = DrillSession(state: state, items: items);
      addTearDown(session.dispose);
      return (state: state, session: session, cards: cards);
    }

    // Answers the item showing: a teach card is gone on from, a question is
    // picked right or wrong and gone on from.
    void play(DrillSession session, {bool right = true}) {
      if (session.ask.onlyShows) {
        session.learnt();
        return;
      }
      final option = session.options.firstWhere(
        (o) => session.isRight(o) == right,
      );
      session.pick(option);
      session.next();
    }

    test('writes nothing until both answers of an item are right', () async {
      final run = await start(3);
      // show a, Q1 a, show b, Q1 b, show c, Q1 c: six steps, nothing written.
      for (var i = 0; i < 6; i++) {
        play(run.session);
      }
      expect(run.state.progress.log, isEmpty);
      for (final card in run.cards) {
        expect(run.state.isTaught(card), isFalse);
      }
      // Q2 of a, right: a is learned, in both skills, and b and c are not.
      play(run.session);
      expect(run.state.isTaught(run.cards[0]), isTrue);
      expect(
        run.state.progress.stateOf(run.cards[0].id, DrillMode.recognition),
        isNotNull,
      );
      expect(
        run.state.progress.stateOf(run.cards[0].id, DrillMode.production),
        isNotNull,
      );
      expect(run.state.progress.log, hasLength(2));
      // Both answers are written as one moment.
      expect(
        run.state.progress.log.first.at,
        run.state.progress.log.last.at,
      );
      expect(run.state.isTaught(run.cards[1]), isFalse);
      play(run.session);
      play(run.session);
      expect(run.session.finished, isTrue);
      for (final card in run.cards) {
        expect(run.state.isTaught(card), isTrue);
      }
      expect(run.session.takeLearnNotice(), LearnNotice.learned);
    });

    test('a wrong first answer leaves that item unlearnt', () async {
      final run = await start(3);
      play(run.session); // show a
      play(run.session, right: false); // Q1 a, wrong
      expect(run.session.takeLearnNotice(), LearnNotice.notYet);
      for (var i = 0; i < 4; i++) {
        play(run.session); // show b, Q1 b, show c, Q1 c
      }
      for (var i = 0; i < 3; i++) {
        play(run.session); // Q2 a (asked again, not recorded), Q2 b, Q2 c
      }
      expect(run.session.finished, isTrue);
      expect(run.state.isTaught(run.cards[0]), isFalse);
      expect(
        run.state.progress.log.where((e) => e.cardId == run.cards[0].id),
        isEmpty,
      );
      expect(run.state.isTaught(run.cards[1]), isTrue);
      expect(run.state.isTaught(run.cards[2]), isTrue);
    });

    test('a wrong second answer leaves the item unlearnt', () async {
      final run = await start(3);
      for (var i = 0; i < 6; i++) {
        play(run.session);
      }
      play(run.session, right: false); // Q2 a, wrong
      play(run.session);
      play(run.session);
      expect(run.state.isTaught(run.cards[0]), isFalse);
      expect(
        run.state.progress.log.where((e) => e.cardId == run.cards[0].id),
        isEmpty,
      );
    });

    test('a sitting left part-way has written nothing', () async {
      final run = await start(3);
      for (var i = 0; i < 6; i++) {
        play(run.session);
      }
      expect(run.state.progress.log, isEmpty);
    });
  });

  group('what is kept from before', () {
    LoggedReview review(String card, int grade, int day, {Ask? asked}) => (
      key: (cardId: card, mode: DrillMode.recognition),
      deckId: 'd',
      at: DateTime(2026, 11, day),
      grade: grade,
      elapsed: const Duration(seconds: 2),
      answerGiven: asked == Ask.teach ? null : 'x',
      script: null,
      asked: asked,
    );

    test('a card only ever looked at has no state, one answered keeps it', () {
      final log = <LoggedReview>[
        review('looked', 0, 1, asked: Ask.teach),
        review('known', 0, 1, asked: Ask.teach),
        review('known', 4, 2, asked: Ask.chooseMeaning),
      ];
      final once = replayReviews(log);
      expect(once.states.keys.map((k) => k.cardId), <String>['known']);
      // Idempotent: replaying again gives the same states.
      final again = replayReviews(log);
      expect(again.states.keys, once.states.keys);
      expect(
        again.states.values.single.dueAt,
        once.states.values.single.dueAt,
      );
      // The rows stay in the log, as events.
      expect(once.events, hasLength(3));
    });

    test('a backup with the removed settings keys restores without them', () {
      final settings = SettingsNotifier()
        ..restore(<String, String>{
          'hide_above_level': 'true',
          'culture_above_support': 'true',
          'culture_items': 'false',
        });
      expect(settings.cultureItems, isFalse);
      expect(settings.toStored().containsKey('hide_above_level'), isFalse);
      expect(settings.toStored().containsKey('culture_above_support'), isFalse);
    });
  });
}
