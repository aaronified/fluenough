import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/sm2.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';

import '../../support/harness.dart';

/// Quick revision (ADR-0029): words already taught, picked at random; a
/// miss is recorded, a right answer is not.

Future<AppState> knowing(int count) async {
  final state = await withDeckTaught(
    (progress) => AppState.test(
      progress: progress,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['hi'],
      ),
    ),
    'hi-en-first-words',
    count: count,
  );
  await state.load();
  return state;
}

/// Every word [items] asks, a match's words each.
List<SessionItem> asked(List<SessionItem> items) => <SessionItem>[
  for (final item in items)
    ...item.group.isEmpty ? <SessionItem>[item] : item.group,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('5 words revise 5 known words, each once', () async {
    final state = await knowing(8);
    expect(state.revisableCount, 8);
    final items = asked(state.sessionItems(const DrillRequest.revision(5)));
    expect(<String>{for (final item in items) item.card.id}, hasLength(5));
    for (final item in items) {
      expect(state.isTaught(item.card), isTrue);
    }
  });

  test('asking for more than are known revises all of them', () async {
    final state = await knowing(3);
    final items = asked(state.sessionItems(const DrillRequest.revision(20)));
    expect(<String>{for (final item in items) item.card.id}, hasLength(3));
  });

  test('nothing known, nothing to revise', () async {
    final state = await knowing(0);
    expect(state.revisableCount, 0);
    expect(state.sessionItems(const DrillRequest.revision(5)), isEmpty);
  });

  test('a right answer is not recorded and leaves the date alone; a wrong '
      'one is recorded as a lapse', () async {
    final state = await knowing(8);
    final items = <SessionItem>[
      for (final item
          in state.buildSession(const DrillRequest.revision(5)).items.take(2))
        item.askedAs(Ask.chooseMeaning),
    ];
    final session = DrillSession(
      state: state,
      items: items,
      recorded: false,
      revising: true,
      recordsMisses: true,
    );
    final first = items[0];
    final before = state.progress.log.length;
    final due = state.progress.stateOf(first.card.id, first.mode)!.dueAt;
    session.pick(
      session.options.firstWhere((option) => option.id == first.card.id),
    );
    expect(state.progress.log, hasLength(before));
    expect(state.progress.stateOf(first.card.id, first.mode)!.dueAt, due);

    session.next();
    final second = items[1];
    session.pick(
      session.options.firstWhere((option) => option.id != second.card.id),
    );
    expect(state.progress.log, hasLength(before + 1));
    final miss = state.progress.log.last;
    expect(miss.cardId, second.card.id);
    expect(miss.grade, lessThan(Sm2.passingGrade));
  });

  testWidgets('from the page, a miss is recorded and ending part-way says '
      'the misses are kept', (tester) async {
    usePhone(tester);
    final state = await knowing(8);
    await pumpScreen(
      tester,
      const DrillPage(request: DrillRequest.revision(5)),
      state: state,
    );
    final l10n = l10nOf(tester);
    final before = state.progress.log.length;
    // Miss the first word, whichever way it is asked.
    switch (tester.widget(
      find.byWidgetPredicate(
        (w) => w is RecognitionDrill || w is ChoiceDrill || w is MatchDrill,
      ),
    )) {
      case MatchDrill(:final session):
        final target = session.matchTargets.first;
        session
          ..match(
            target,
            session.matchMeanings.firstWhere(
              (meaning) => meaning.card.id != target.card.id,
            ),
          )
          ..match(
            target,
            session.matchMeanings.firstWhere(
              (meaning) => meaning.card.id == target.card.id,
            ),
          );
      case ChoiceDrill(:final session):
        session.pick(
          session.options.firstWhere(
            (option) => option.id != session.item.card.id,
          ),
        );
      default:
        await tester.tap(find.text(l10n.drillShowAnswer));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.rateAgain));
    }
    await tester.pumpAndSettle();
    expect(state.progress.log, hasLength(before + 1));
    expect(state.progress.log.last.grade, lessThan(Sm2.passingGrade));

    await tester.tap(find.byTooltip(l10n.drillEndSession));
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillEndBodyMisses), findsOneWidget);
    expect(find.text(l10n.drillEndBodyNotRecorded), findsNothing);
  });
}
