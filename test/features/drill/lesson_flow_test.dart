import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/grammar_drill.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart';
import 'package:fluenough/features/drill/teach_drill.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/features/today/lesson_card.dart';
import 'package:fluenough/features/today/today_page.dart';

import '../../support/harness.dart';

/// A day's lesson (ADR-0024), from Today to the summary and back.

AppState spanishLearner() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['es'],
  ),
);

/// The session the drill page is running.
DrillSession sessionOf(WidgetTester tester) {
  for (final widget in <Widget>[
    ...tester.widgetList(find.byType(GrammarDrill)),
    ...tester.widgetList(find.byType(TeachDrill)),
    ...tester.widgetList(find.byType(ChoiceDrill)),
    ...tester.widgetList(find.byType(MatchDrill)),
    ...tester.widgetList(find.byType(RearrangeDrill)),
  ]) {
    return switch (widget) {
      GrammarDrill(:final session?) => session,
      TeachDrill(:final session) => session,
      ChoiceDrill(:final session) => session,
      MatchDrill(:final session) => session,
      RearrangeDrill(:final session) => session,
      _ => throw StateError('$widget'),
    };
  }
  throw StateError('no lesson screen');
}

/// Answers every question of the lesson right, through the session.
Future<void> finishLesson(WidgetTester tester) async {
  while (find.byType(DrillPage).evaluate().isNotEmpty) {
    final session = sessionOf(tester);
    final card = session.item.card;
    switch (session.ask) {
      case Ask.teach:
        session.learnt();
      case Ask.chooseMeaning || Ask.chooseWord || Ask.hearAndChoose:
        session.pick(session.options.firstWhere((o) => o.id == card.id));
        session.next();
      case Ask.matchPairs:
        for (final entry in session.item.group) {
          session.match(entry, entry);
        }
        session.next();
      case Ask.rearrange:
        final words = wordsOf(
          session.rearrangesReading ? card.reading! : card.target,
        );
        final tiles = session.tiles;
        final used = <int>{};
        for (final word in words) {
          final i = List<int>.generate(
            tiles.length,
            (i) => i,
          ).firstWhere((i) => tiles[i] == word && !used.contains(i));
          used.add(i);
          session.place(i);
        }
        session.checkOrder();
        session.next();
      case Ask.own:
        // A grammar cell, typed.
        session.check(card.target);
        session.next();
    }
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('Today offers the lesson; it teaches each word, then asks it, '
      'and once done offers another', (tester) async {
    usePhone(tester);
    final state = spanishLearner();
    await pumpScreen(tester, const TodayPage(), state: state);
    final l10n = l10nOf(tester);
    expect(find.byType(LessonCard), findsOneWidget);
    expect(find.text(l10n.todayLessonTitle), findsOneWidget);
    expect(find.text(l10n.todayLessonWords(9)), findsOneWidget);
    // Nothing to review yet: new words come in lessons.
    expect(find.text(l10n.todayAllDoneTitle), findsOneWidget);

    final planned = <SessionItem>[
      for (final item in state.lessonFor(DrillRequest.lesson(language: 'es')))
        if (item.ask != Ask.teach)
          ...item.group.isEmpty ? <SessionItem>[item] : item.group,
    ].length;
    await tester.tap(find.text(l10n.todayLessonStart));
    await tester.pumpAndSettle();
    // The first word is taught before it is asked, and nothing is recorded.
    expect(find.byType(TeachDrill), findsOneWidget);
    expect(find.text(l10n.drillTeachTitle), findsOneWidget);
    final first = sessionOf(tester).item.card;
    expect(find.text(first.native), findsOneWidget);
    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceDrill), findsOneWidget);
    expect(sessionOf(tester).item.card.id, first.id);
    expect(state.progress.log, isEmpty);

    await finishLesson(tester);
    expect(find.byType(SummaryPage), findsOneWidget);
    // Nine words, each recorded in two skills but a grammar cell, which has
    // one, all right.
    final log = state.progress.log;
    expect(log.map((e) => e.cardId).toSet(), hasLength(9));
    expect(log, hasLength(planned));
    expect(log.every((e) => e.grade >= 4), isTrue);
    expect(state.lessonDoneToday('es'), isTrue);

    // The summary offers another; back on Today, so does its card.
    expect(find.text(l10n.summaryAnotherLesson), findsOneWidget);
    Navigator.of(tester.element(find.byType(SummaryPage)))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(find.text(l10n.todayLessonDoneTitle), findsOneWidget);
    expect(find.text(l10n.todayAnotherLesson), findsOneWidget);
    expect(find.text(l10n.todayNewWords(9)), findsOneWidget);
  });

  testWidgets('another lesson teaches the next words', (tester) async {
    usePhone(tester);
    final state = spanishLearner();
    await state.load();
    final first = state.lessonFor(DrillRequest.lesson(language: 'es'));
    for (final item in first) {
      if (item.ask != Ask.teach) state.record(item, 5);
    }
    final next = state.lessonFor(DrillRequest.lesson(language: 'es'));
    final taught = <String>{for (final i in first) i.card.id};
    expect(next, isNotEmpty);
    expect(next.map((i) => i.card.id), everyElement(isNot(isIn(taught))));
  });

  testWidgets('Start review asks the words taught in their other skills', (
    tester,
  ) async {
    usePhone(tester);
    final state = AppState.test(
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['es'],
      ),
      tts: FixedTtsEngine(<String>{'es'}),
    );
    await state.load();
    final lesson = state.lessonFor(DrillRequest.lesson(language: 'es'));
    final recorded = <(String, DrillMode)>{};
    for (final item in lesson) {
      if (item.ask == Ask.teach) continue;
      for (final entry
          in item.group.isEmpty ? <SessionItem>[item] : item.group) {
        state.record(entry, 5);
        recorded.add((entry.card.id, entry.mode));
      }
    }
    final review = state.buildSession(const DrillRequest.today());
    expect(review.due, isEmpty);
    expect(review.fresh, isNotEmpty);
    for (final item in review.fresh) {
      expect(state.isTaught(item.card), isTrue);
      expect(recorded, isNot(contains((item.card.id, item.mode))));
    }
  });

  test('a word is never taught twice in one lesson', () async {
    final state = spanishLearner();
    await state.load();
    final teach = <Card>[
      for (final item in state.lessonFor(DrillRequest.lesson(language: 'es')))
        if (item.ask == Ask.teach) item.card,
    ];
    expect(teach.map((c) => c.id).toSet(), hasLength(teach.length));
  });
}
