// Find my level's screens (wiki/Plan-Placement-V2.md, steps 3 and 4): the
// declaration question, the run page with its checkpoint and result, and
// pausing. The decks are a small fixture, the voice and the recogniser are
// the app's null engines.
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/placement_session.dart';
import 'package:fluenough/features/placement/find_level_declaration.dart';
import 'package:fluenough/features/placement/find_level_run_page.dart';
import 'package:fluenough/features/placement/find_level_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/find_level_fixture.dart';
import 'support/harness.dart';

const LanguageInfo _language = LanguageInfo(
  code: 'xx',
  iso639_3: 'xxx',
  name: 'Xish',
  script: 'devanagari',
);
const LanguageInfo _native = LanguageInfo(
  code: 'en',
  iso639_3: 'eng',
  name: 'English',
);

/// Opens [page] from a button, as the sheet does, and says what it popped
/// with in [popped].
Future<void> _open(
  WidgetTester tester,
  Widget Function() page,
  List<Object?> popped,
) async {
  usePhone(tester);
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const ValueKey<String>('open'),
            onPressed: () async {
              final result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute<Object?>(builder: (_) => page()),
              );
              popped.add(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey<String>('open')));
  await tester.pumpAndSettle();
}

FindLevelRunPage _runPage(
  PlacementSession session, {
  List<List<String>>? progress,
  List<PlacementSession>? finished,
}) => FindLevelRunPage(
  session: session,
  languageName: 'Xish',
  language: _language,
  native: _native,
  onProgress: (s) => progress?.add(s.events),
  onFinish: (s) => finished?.add(s),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('the declaration screen', () {
    Future<List<Object?>> pump(
      WidgetTester tester,
      List<PlacementDeclaration> options,
    ) async {
      final popped = <Object?>[];
      await _open(
        tester,
        () => FindLevelDeclarationPage(language: 'Bengali', options: options),
        popped,
      );
      return popped;
    }

    testWidgets('asks "How well do you know it?" with the labels as decided, '
        'and no Skip', (tester) async {
      await pump(tester, PlacementDeclaration.values);
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.findLevelDeclarationTitle('Bengali')),
        findsOneWidget,
      );
      expect(find.text('Expert'), findsOneWidget);
      expect(find.text('I use it easily'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(
        find.text('I follow most of it and can say what I need'),
        findsOneWidget,
      );
      expect(find.text('Amateur'), findsOneWidget);
      expect(find.text('I know some words and phrases'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('I am starting from nothing'), findsOneWidget);
      expect(find.text(l10n.placementStartAtBeginning), findsNothing);
      expect(find.textContaining('Skip'), findsNothing);
    });

    testWidgets('offers only the options it is given', (tester) async {
      await pump(tester, const <PlacementDeclaration>[
        PlacementDeclaration.amateur,
        PlacementDeclaration.beginner,
      ]);
      expect(find.text('Amateur'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Advanced'), findsNothing);
      expect(find.text('Expert'), findsNothing);
    });

    testWidgets('an answer is handed back', (tester) async {
      final popped = await pump(tester, PlacementDeclaration.values);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-advanced')),
      );
      expect(popped, <Object?>[PlacementDeclaration.advanced]);
    });

    testWidgets('Back leaves with no answer', (tester) async {
      final popped = await pump(tester, PlacementDeclaration.values);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(popped, <Object?>[null]);
    });
  });

  group('the run page', () {
    testWidgets('shows question 1 with no total, and each answer is told to '
        'the host so that the run can be saved', (tester) async {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      final progress = <List<String>>[];
      final finished = <PlacementSession>[];
      await _open(
        tester,
        () => _runPage(session, progress: progress, finished: finished),
        <Object?>[],
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.placementQuestionNumber(1)), findsOneWidget);
      expect(find.text('1/', findRichText: true), findsNothing);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-dont-know')),
      );
      expect(find.text(l10n.placementQuestionNumber(2)), findsOneWidget);
      expect(progress, <List<String>>[
        <String>['a0'],
      ]);
      expect(finished, isEmpty, reason: 'nothing is written while it runs');
    });

    testWidgets('closing pauses: nothing is written and the host is told', (
      tester,
    ) async {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      final finished = <PlacementSession>[];
      final popped = <Object?>[];
      await _open(tester, () => _runPage(session, finished: finished), popped);
      await _tap(tester, find.byTooltip(l10nOf(tester).drillEndSession));
      expect(popped, <Object?>[false]);
      expect(finished, isEmpty);
    });

    testWidgets('a run that ends writes once and shows where the learner '
        'starts', (tester) async {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      final finished = <PlacementSession>[];
      final popped = <Object?>[];
      await _open(tester, () => _runPage(session, finished: finished), popped);
      final l10n = l10nOf(tester);
      final done = find.byKey(const ValueKey<String>('find-level-done'));
      final keep = find.byKey(const ValueKey<String>('find-level-keep-going'));
      var taps = 0;
      while (done.evaluate().isEmpty && taps++ < 400) {
        await _tap(
          tester,
          keep.evaluate().isNotEmpty
              ? keep
              : find.byKey(const ValueKey<String>('find-level-dont-know')),
        );
      }
      expect(done, findsOneWidget);
      expect(finished, hasLength(1));
      expect(find.text(l10n.findLevelSummaryTitle), findsOneWidget);
      // Not one right answer: every skill starts from the beginning.
      expect(
        find.textContaining('${l10n.findLevelSkillRead}: from the beginning'),
        findsOneWidget,
      );
      await _tap(tester, done);
      expect(popped, <Object?>[true]);
    });

    testWidgets('a checkpoint says where the learner stands and offers '
        'Keep going and Stop here', (tester) async {
      var kept = 0;
      var stopped = 0;
      usePhone(tester);
      await pumpScreen(
        tester,
        FindLevelCheckpoint(
          count: 25,
          lines: const <String>['Read: unit 80 · Very sure'],
          onKeepGoing: () => kept++,
          onStop: () => stopped++,
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.findLevelCheckpointTitle(25)), findsOneWidget);
      expect(find.text(l10n.findLevelCheckpointBody), findsOneWidget);
      expect(find.text('Read: unit 80 · Very sure'), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-keep-going')),
      );
      expect(kept, 1);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-stop-here')),
      );
      expect(stopped, 1);
    });
  });

  group('the result lists each skill in play', () {
    testWidgets('as a unit and a name, in the plan\'s words', (tester) async {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      while (!session.isDone) {
        if (session.atCheckpoint) {
          session.keepGoing();
        } else {
          session.answer(true);
        }
      }
      usePhone(tester);
      await pumpScreen(
        tester,
        FindLevelSummary(run: session.run, onDone: () {}),
      );
      final l10n = l10nOf(tester);
      for (final name in <String>[
        l10n.findLevelSkillRead,
        l10n.findLevelSkillHear,
        l10n.findLevelSkillWrite,
      ]) {
        expect(
          find.textContaining('$name: unit 6 · '),
          findsOneWidget,
          reason: name,
        );
      }
      // Say and Script were not marked: they are not listed at all.
      expect(find.textContaining(l10n.findLevelSkillSay), findsNothing);
      expect(find.textContaining(l10n.findLevelSkillScript), findsNothing);
    });
  });
}
