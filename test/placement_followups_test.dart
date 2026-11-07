// Two follow-ups to the placement repair (wiki/Plan-Placement-V2.md, 17.10):
// the older placement test's credit is stamped with its own model, and
// placement credit never enters a fit.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/placement_credit.dart';
import 'package:fluenough/app/placement_plan.dart';
import 'package:fluenough/app/placement_recheck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/placement_check.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/placement_withdrawal.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:flutter_test/flutter_test.dart';

LoggedReview _review({
  required int grade,
  required DateTime at,
  Duration elapsed = Duration.zero,
  String? answer,
  Ask? asked = Ask.own,
  String card = 'es-0001',
}) => (
  key: (cardId: card, mode: DrillMode.recognition),
  deckId: 'es-en-a',
  at: at,
  grade: grade,
  elapsed: elapsed,
  answerGiven: answer,
  script: null,
  asked: asked,
);

void main() {
  group('the model a credit is stamped with', () {
    late AppState state;

    setUp(() async {
      state = AppState.test();
      await state.load();
    });
    tearDown(() => state.dispose());

    Set<String> firstDeck() => <String>{state.walkDecks('hi').first.id};

    test('the older test stamps model 1, Find my level model 2', () {
      expect(kOlderPlacementModel, 1);
      expect(kOlderPlacementModel, isNot(kPlacementModel));

      expect(
        state.creditPlacement(
          'hi',
          placed: firstDeck(),
          model: kOlderPlacementModel,
        ),
        greaterThan(0),
      );
      final older = momentOf(state.now());
      expect(state.settings.placedByOf('hi'), contains(older));
      expect(
        state.unconfirmedMomentsOf('hi'),
        isEmpty,
        reason: 'the older test\'s credit is not flagged',
      );
    });

    test('credit without a model is still the default model, and a stamp of '
        'either model is never flagged', () {
      final second = state.walkDecks('hi').skip(1).first.id;
      state.creditPlacement('hi', placed: <String>{second});
      expect(state.settings.placedByOf('hi'), contains(momentOf(state.now())));
      expect(state.unconfirmedMomentsOf('hi'), isEmpty);
    });

    test('credit with no stamp at or after 0.9.0 is still flagged, and a '
        'stamp of model 1 or 2 clears it', () {
      final moment = kPlacementCheckFrom + 10;
      Set<int> flagged(Set<int> stamped) => unconfirmedMoments(
        placedAt: <int>{moment},
        stamped: stamped,
        kept: const <int>{},
        live: <int>{moment},
      );
      expect(flagged(const <int>{}), <int>{moment});
      expect(flagged(<int>{moment}), isEmpty);
    });
  });

  group('placement credit and fits', () {
    final t = DateTime.utc(2026, 11, 7, 12);

    test('credit is left out of the histories and the counts a fit reads', () {
      final histories = SkillFit.histories(<LoggedReview>[
        _review(grade: 5, at: t),
        _review(grade: 5, at: t, card: 'es-0002'),
      ]);
      expect(histories, isEmpty);
    });

    test('a real review of a credited card is the first review a fit reads, '
        'and every kind of real review stays', () {
      final reviews = <LoggedReview>[
        _review(grade: 5, at: t),
        // Real: has an elapsed time.
        _review(
          grade: 5,
          at: t.add(const Duration(days: 2)),
          elapsed: const Duration(seconds: 3),
        ),
        // Real: has an answer.
        _review(grade: 5, at: t.add(const Duration(days: 4)), answer: 'x'),
        // Real: not asked its own way.
        _review(
          grade: 5,
          at: t.add(const Duration(days: 6)),
          asked: Ask.chooseMeaning,
        ),
      ];
      final history = SkillFit.histories(reviews).values.single;
      expect(history.reviewCount, 3);
      expect(history.pairs.single, hasLength(3));
      expect(history.pairs.single.first.at, t.add(const Duration(days: 2)));
    });

    test('with its credit kept, as How you learn does, the history is the '
        'replay\'s', () {
      final reviews = <LoggedReview>[
        _review(grade: 5, at: t),
        _review(
          grade: 4,
          at: t.add(const Duration(days: 3)),
          elapsed: const Duration(seconds: 2),
        ),
      ];
      final kept = SkillFit.histories(
        reviews,
        withPlacementCredit: true,
      ).values.single;
      expect(kept.reviewCount, 2);
      expect(kept.pairs.single, hasLength(2));
    });

    test('the replay still schedules a credited card from its credit', () {
      final credit = _review(grade: 5, at: t);
      final replayed = replayReviews(<LoggedReview>[credit]);
      final state = replayed.states[credit.key];
      expect(state, isNotNull);
      expect(state!.dueAt.isAfter(t), isTrue);
    });
  });
}
