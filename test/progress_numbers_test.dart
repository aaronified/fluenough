// Progress's numbers off the UI isolate (#857): the mastery and the weakest
// tags come from a job of plain data, read without waiting, and the same on
// an isolate as in place.

import 'dart:async';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/progress/mastery.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/stats/progress_numbers.dart';
import 'package:fluenough/features/stats/skill_star.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// A runner that waits to be told: every job it is given, and a way to
/// finish each.
class _Waiting {
  final List<ProgressJob> jobs = <ProgressJob>[];
  final List<Completer<ProgressNumbers>> done = <Completer<ProgressNumbers>>[];

  Future<ProgressNumbers> call(ProgressJob job) {
    jobs.add(job);
    final c = Completer<ProgressNumbers>();
    done.add(c);
    return c.future;
  }

  /// Finishes job [i] with what working it out gives.
  void finish(int i) => done[i].complete(computeProgress(jobs[i]));
}

Future<AppState> _fixture() async {
  final app = AppState.test();
  await app.load();
  final state = GalleryFixtures.state(app, features: FeatureRegistry.all());
  await state.load();
  return state;
}

void _answer(AppState state, int fromEnd) {
  final deck = state.decks.firstWhere((e) => e.id == 'es-en-core-100');
  state.progress.record(
    deckId: deck.id,
    cardId: deck.cards[deck.cards.length - 1 - fromEnd].id,
    mode: DrillMode.recognition,
    grade: 4,
    now: state.now(),
  );
}

/// Everything a [ProgressNumbers] shows, as plain values to compare.
List<Object?> _shown(ProgressNumbers n) => <Object?>[
  n.none,
  n.mastery.words,
  n.mastery.level,
  n.mastery.started,
  [for (final d in n.mastery.week) (d.day, d.spent, d.mark)],
  for (final m in <Mastery>[n.mastery.now, ...n.mastery.overTime()])
    [
      for (final s in MasterySkill.values)
        (m[s].known, m[s].taught, m[s].total),
    ],
  [
    for (final e in n.weakestTags.entries)
      (e.key, e.value.correct, e.value.total),
  ],
];

void main() {
  group('Progress numbers', () {
    test('on an isolate they are what working them out in place gives, for '
        'a language and for All', () async {
      final state = await _fixture();
      for (final language in <String?>['es', 'mr', null]) {
        final waiting = _Waiting();
        final holder = ProgressNumbersHolder(
          state: state,
          runner: waiting.call,
        );
        addTearDown(holder.dispose);
        expect(holder.of(language), isNull);
        final job = waiting.jobs.single;
        final onIsolate = await progressInIsolate(job);
        final inPlace = state.progressNumbers.of(language)!;
        expect(_shown(onIsolate), _shown(inPlace), reason: '$language');
        // The fixture answers tagged words in Spanish only: Marathi's
        // answers are script letters, which carry no tags.
        if (language != 'mr') {
          expect(
            inPlace.weakestTags,
            isNotEmpty,
            reason: 'the fixture has tagged cards answered in $language',
          );
        }
      }
    });

    test('the first read is neutral, a change is worked out once however '
        'many answers come in, and the old numbers stay until it is', () async {
      final state = await _fixture();
      final waiting = _Waiting();
      final holder = ProgressNumbersHolder(state: state, runner: waiting.call);
      addTearDown(holder.dispose);
      var notified = 0;
      holder.addListener(() => notified++);

      expect(holder.of('es'), isNull, reason: 'a first visit has nothing yet');
      expect(holder.of('es'), isNull);
      expect(waiting.jobs, hasLength(1), reason: 'asked twice, one job');
      waiting.finish(0);
      await pumpEventQueue();
      expect(notified, 1);
      final first = holder.of('es')!;
      expect(waiting.jobs, hasLength(1), reason: 'nothing changed');

      _answer(state, 0);
      _answer(state, 1);
      expect(
        holder.of('es'),
        same(first),
        reason: 'the last numbers show while the new are worked out',
      );
      expect(waiting.jobs, hasLength(2));
      _answer(state, 2);
      expect(holder.of('es'), same(first));
      expect(
        waiting.jobs,
        hasLength(2),
        reason: 'one job at a time: the third answer waits',
      );

      waiting.finish(1);
      await pumpEventQueue();
      expect(
        waiting.jobs,
        hasLength(3),
        reason: 'then one more, from the log as it is by then',
      );
      waiting.finish(2);
      await pumpEventQueue();
      final latest = holder.of('es')!;
      expect(
        latest.mastery.now[MasterySkill.read].taught,
        first.mastery.now[MasterySkill.read].taught + 3,
      );
      expect(waiting.jobs, hasLength(3));
      expect(notified, 3);
    });

    test('an answer in another language leaves a language as it was', () async {
      final state = await _fixture();
      final waiting = _Waiting();
      final holder = ProgressNumbersHolder(state: state, runner: waiting.call);
      addTearDown(holder.dispose);
      holder.of('mr');
      waiting.finish(0);
      await pumpEventQueue();
      final before = holder.of('mr')!;
      _answer(state, 0);
      expect(holder.of('mr'), same(before));
      expect(waiting.jobs, hasLength(1), reason: 'Spanish is not Marathi');
    });

    test('with no answers there is nothing to wait for', () async {
      final app = AppState.test();
      await app.load();
      final waiting = _Waiting();
      final holder = ProgressNumbersHolder(state: app, runner: waiting.call);
      addTearDown(holder.dispose);
      expect(holder.of('es')!.none, isTrue);
      expect(holder.of(null)!.none, isTrue);
      expect(waiting.jobs, isEmpty);
    });

    test('a job that fails is reported and not tried again until something '
        'changes', () async {
      final state = await _fixture();
      var calls = 0;
      final holder = ProgressNumbersHolder(
        state: state,
        runner: (job) async {
          calls++;
          throw StateError('no isolate');
        },
      );
      addTearDown(holder.dispose);
      final reported = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = old);
      expect(holder.of('es'), isNull);
      await pumpEventQueue();
      expect(reported, hasLength(1));
      expect(holder.of('es'), isNull);
      await pumpEventQueue();
      expect(calls, 1);
    });
  });

  group('Progress tab', () {
    testWidgets('shows nothing but a wait on a first visit, then the tab '
        'when the numbers are back', (tester) async {
      usePhone(tester);
      final app = AppState.test();
      await app.load();
      final waiting = _Waiting();
      final state = GalleryFixtures.state(
        app,
        features: FeatureRegistry.all(),
        progressRunner: waiting.call,
      );
      await pumpScreen(tester, const StatsPage(), state: state, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SkillStarCard), findsNothing);

      expect(waiting.jobs, hasLength(1));
      waiting.finish(0);
      await tester.pump();
      await tester.pump();
      expect(find.byType(SkillStarCard), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
