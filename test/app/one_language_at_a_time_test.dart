import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/summary/summary_page.dart';

import '../support/harness.dart';

/// Today with several languages, one at a time, with a break between: each
/// language's part is a session of its own, and the summary after one offers
/// the next.

AppState learning(List<String> languages) => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: languages,
  ),
);

Set<String> languagesIn(AppState state, DrillRequest request) => <String>{
  for (final item in state.buildSession(request).items)
    state.deckOf(item.card)!.language.code,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each language\'s part holds only that language, and the parts make '
      'up the day', () async {
    final state = learning(const <String>['bn', 'hi']);
    addTearDown(state.dispose);
    await state.load();
    expect(state.todayLanguages.map((l) => l.code), <String>['bn', 'hi']);
    final bengali = const DrillRequest.today(language: 'bn');
    final hindi = const DrillRequest.today(language: 'hi');
    expect(languagesIn(state, bengali), <String>{'bn'});
    expect(languagesIn(state, hindi), <String>{'hi'});
    expect(
      state.buildSession(bengali).length + state.buildSession(hindi).length,
      state.buildSession(const DrillRequest.today()).length,
    );
  });

  test(
    'finishing one language first leaves the next its whole share',
    () async {
      final state = learning(const <String>['bn', 'hi']);
      addTearDown(state.dispose);
      await state.load();
      final hindi = const DrillRequest.today(language: 'hi');
      final before = state.buildSession(hindi).fresh.length;
      expect(before, greaterThan(0));
      for (final item
          in state
              .buildSession(const DrillRequest.today(language: 'bn'))
              .items) {
        state.record(item, 5);
      }
      expect(state.buildSession(hindi).fresh.length, before);
      expect(state.todayLanguages.map((l) => l.code), <String>['hi']);
    },
  );

  testWidgets('after one language, the summary says it is done and offers '
      'the next', (tester) async {
    usePhone(tester);
    final state = learning(const <String>['bn', 'hi']);
    await state.load();
    final now = state.now();
    await pumpScreen(
      tester,
      SummaryPage(
        result: SessionResult(
          answers: const <SessionAnswer>[],
          startedAt: now,
          endedAt: now,
          language: 'bn',
        ),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.summaryLanguageDone('Bengali')), findsOneWidget);
    expect(find.text(l10n.summaryNextLanguage), findsOneWidget);
    final next = state
        .buildSession(const DrillRequest.today(language: 'hi'))
        .length;
    final start = find.text(l10n.summaryStartLanguage('Hindi', next));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DrillPage>(find.byType(DrillPage)).request.language,
      'hi',
    );
    expect(
      find.byType(SummaryPage),
      findsNothing,
      reason: 'replaced, not stacked',
    );
  });

  testWidgets('a session over every language keeps the plain summary', (
    tester,
  ) async {
    usePhone(tester);
    final state = learning(const <String>['bn', 'hi']);
    await state.load();
    final now = state.now();
    await pumpScreen(
      tester,
      SummaryPage(
        result: SessionResult(
          answers: const <SessionAnswer>[],
          startedAt: now,
          endedAt: now,
        ),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.summaryTitle), findsOneWidget);
    expect(find.text(l10n.summaryNextLanguage), findsNothing);
    expect(find.byType(FilledButton), findsWidgets);
  });
}
