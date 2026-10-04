import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/summary/gallery_entries.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/ui/widgets/bar_row.dart';
import 'package:fluenough/ui/widgets/stat_tile.dart';

import '../../support/harness.dart';

final DateTime now = DateTime(2026, 9, 28, 19);

/// Five answers over three minutes, four of them correct.
final SessionResult fiveAnswers = SessionResult(
  answers: const <SessionAnswer>[
    SessionAnswer(skill: Skill.recognition, grade: 4),
    SessionAnswer(skill: Skill.recognition, grade: 5),
    SessionAnswer(skill: Skill.production, grade: 4),
    SessionAnswer(skill: Skill.production, grade: 1),
    SessionAnswer(skill: Skill.listening, grade: 3),
  ],
  startedAt: now.subtract(const Duration(minutes: 3)),
  endedAt: now,
);

final SessionResult noAnswers = SessionResult(
  answers: const <SessionAnswer>[],
  startedAt: now,
  endedAt: now,
);

Future<AppState> fixtureState() async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(app);
}

/// Scrolls [finder] into view, building it first if the list is lazy (the
/// buttons sit in the last sliver), then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The value a [StatTile] with [label] shows.
String statFor(WidgetTester tester, String label) => tester
    .widget<StatTile>(
      find.byWidgetPredicate((w) => w is StatTile && w.label == label),
    )
    .value;

void main() {
  testWidgets('the line, totals and scores come from the result', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, SummaryPage(result: fiveAnswers));
    final l10n = l10nOf(tester);

    expect(find.text(l10n.summaryTitle), findsOneWidget);
    expect(find.text(l10n.summaryLine(5, 4)), findsOneWidget);
    expect(statFor(tester, l10n.summaryCorrect), l10n.commonPercent(0.8));
    expect(statFor(tester, l10n.summaryMinutes(3)), '3');
    // No history before this session in AppState.test.
    expect(statFor(tester, l10n.summaryStreak(0)), '0');

    for (final (label, correct, total) in <(String, int, int)>[
      (l10n.skillRecognition, 2, 2),
      (l10n.skillProduction, 1, 2),
      (l10n.skillListening, 1, 1),
    ]) {
      expect(
        find.bySemanticsLabel(
          l10n.summaryScoreSemantics(label, correct, total),
        ),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.byType(BarRow), findsNWidgets(3));
    expect(find.text(l10n.summaryNextDue(0)), findsOneWidget);
  });

  testWidgets('the streak and next due come from the review history', (
    tester,
  ) async {
    usePhone(tester);
    final state = await fixtureState();
    await pumpScreen(tester, SummaryPage(result: fiveAnswers), state: state);
    final l10n = l10nOf(tester);

    final streak = state.progress.streakAt(state.now());
    expect(streak, 12);
    expect(statFor(tester, l10n.summaryStreak(streak)), '12');
    final tomorrow = state.progress.dueTomorrow(state.now());
    expect(find.text(l10n.summaryNextDue(tomorrow)), findsOneWidget);
  });

  testWidgets('an empty session says so and shows no numbers', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, SummaryPage(result: noAnswers));
    final l10n = l10nOf(tester);
    expect(find.text(l10n.summaryEmpty), findsOneWidget);
    expect(find.byType(StatTile), findsNothing);
    expect(find.byType(BarRow), findsNothing);
    expect(find.text(l10n.commonDone), findsOneWidget);
  });

  testWidgets('Done returns to the shell on Today', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester);
    state.shellTab.value = ShellTab.decks;
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AppShell)))
        .pushNamed(AppRoutes.summary, arguments: fiveAnswers);
    await tester.pumpAndSettle();
    expect(find.byType(SummaryPage), findsOneWidget);

    await tapVisible(tester, find.text(l10nOf(tester).commonDone));
    expect(find.byType(SummaryPage), findsNothing);
    expect(state.shellTab.value, ShellTab.today);
  });

  testWidgets('after a language\'s session, the summary offers its lesson '
      '(ADR-0024): today\'s, then another', (tester) async {
    usePhone(tester);
    final state = AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['es'],
      ),
    );
    await state.load();
    final spanish = fiveAnswers.inLanguage('es');
    await pumpScreen(tester, SummaryPage(result: spanish), state: state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.summaryLesson), findsOneWidget);

    state.settings.markLessonDone('es', state.now());
    await pumpScreen(tester, SummaryPage(result: spanish), state: state);
    await tapVisible(tester, find.text(l10n.summaryAnotherLesson));
    final request = tester.widget<DrillPage>(find.byType(DrillPage)).request;
    expect(request.lesson, isTrue);
    expect(request.language, 'es');
  });

  testWidgets('a session in no one language offers no lesson', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, SummaryPage(result: fiveAnswers));
    // Only Done is left.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text(l10nOf(tester).commonDone), findsOneWidget);
  });

  for (final (name, result) in <(String, SessionResult)>[
    ('the design\'s session', GalleryFixtures.sessionResult(now)),
    ('an empty session', noAnswers),
  ]) {
    for (final dark in <bool>[false, true]) {
      testWidgets('$name at text scale 2.0${dark ? ', dark' : ''}', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        await pumpScreen(
          tester,
          SummaryPage(result: result),
          state: await fixtureState(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.text(l10nOf(tester).commonDone));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the gallery\'s summary states build, light and dark', (
    tester,
  ) async {
    usePhone(tester);
    final app = AppState.test();
    await app.load();
    for (final GalleryEntry entry in <GalleryEntry>[
      ...summaryGalleryEntries,
      ...summaryGalleryStates,
    ]) {
      for (final dark in <bool>[false, true]) {
        await pumpScreen(
          tester,
          GalleryPreview(key: UniqueKey(), entry: entry, dark: dark),
          state: app,
        );
        expect(tester.takeException(), isNull, reason: '${entry.id} $dark');
      }
    }
  });
}
