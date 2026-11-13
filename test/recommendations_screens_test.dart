// The recommendations area (wiki/Plan-Deck-Kinds-And-Topics.md, T26, the
// approved mockup docs/mockups/culture-recommendations.html, default variants):
// the browse list with kind chips and a briefing per row, the open row with
// "I've completed this", the badge on a public-domain work a culture deck
// quotes, works above the level counted and not listed, the completed works on
// Today as a cover strip, and the questions of a completed work.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/culture/completed_works_card.dart';
import 'package:fluenough/features/culture/recommendations_page.dart';
import 'package:fluenough/features/culture/work_questions_page.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart';
import 'support/culture_world.dart';
import 'support/harness.dart';

final AppLocalizationsEn _l10n = AppLocalizationsEn();

const String _book = 'Campos de prueba';
const String _film = 'Una película de prueba';
const String _briefing = 'A short book of verse about roads. Plain words.';

const RecommendationsPage _page = RecommendationsPage(
  request: RecommendationsRequest(language: 'zz'),
);

const WorkQuestionsPage _questions = WorkQuestionsPage(
  request: WorkQuestionsRequest(
    language: 'zz',
    recommendationId: 'zz-rec-camino',
  ),
);

Future<void> _complete(AppState state, String id) async {
  final work = state.catalogWithAboveLevel.recommendations['zz']!.byId(id)!;
  state.recommendationProgress.complete(work, 'zz', state.now());
}

void main() {
  group('the list', () {
    testWidgets('offers the works at the level, with the rest counted', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, _page, state: await cultureApp());
      expect(find.text(_book), findsOneWidget);
      expect(find.text(_film), findsNothing);
      expect(find.text(_l10n.recChipAll(1)), findsOneWidget);
      expect(
        find.text(_l10n.recChipKind(_l10n.recMediumBook, 1)),
        findsOneWidget,
      );
      expect(find.text(_l10n.recHiddenAbove(2, 'A2')), findsOneWidget);
      expect(find.text(_l10n.recIntro), findsOneWidget);
    });

    testWidgets(
      'opens a row with its briefing, where to get it, and the action',
      (tester) async {
        usePhone(tester);
        await pumpScreen(tester, _page, state: await cultureApp());
        expect(find.text(_briefing), findsOneWidget);
        expect(find.text(_l10n.recNotIncluded), findsOneWidget);
        expect(
          find.text(
            _l10n.recLegalLine(_l10n.recLegalLibrary, 'Free: public domain'),
          ),
          findsOneWidget,
        );
        expect(find.text(_l10n.recIComplete), findsOneWidget);
      },
    );

    testWidgets('badges a public-domain work and the deck that quotes it', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, _page, state: await cultureApp());
      expect(find.text(_l10n.recPublicDomain), findsOneWidget);
      final prefix = _l10n.recAlsoInDeck('\u0000').replaceAll('\u0000', '');
      expect(find.textContaining(prefix), findsOneWidget);
    });

    testWidgets(
      'lists every work once the learner is at B1, and filters by kind',
      (tester) async {
        usePhone(tester);
        await pumpScreen(tester, _page, state: await cultureApp(reach: 'b1'));
        expect(find.text(_l10n.recChipAll(3)), findsOneWidget);
        await tester.tap(find.text(_l10n.recChipKind(_l10n.recMediumFilm, 1)));
        await tester.pumpAndSettle();
        expect(find.text(_film), findsOneWidget);
        expect(find.text(_book), findsNothing);
        await tester.tap(find.text(_l10n.recChipAll(3)));
        await tester.pumpAndSettle();
        expect(find.text(_book), findsOneWidget);
      },
    );

    testWidgets('has a close and an open row, one open at a time', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, _page, state: await cultureApp(reach: 'b1'));
      expect(find.text(_briefing), findsOneWidget);
      await tester.tap(find.text(_film));
      await tester.pumpAndSettle();
      expect(find.text('A made-up film about a poet.'), findsOneWidget);
      // The first row closed: its briefing is down to its first sentence.
      expect(find.text(_briefing), findsNothing);
      expect(find.text('A short book of verse about roads.'), findsOneWidget);
    });

    testWidgets('says so when the course has no recommendations', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(
        files: <String, String>{
          for (final e in cultureWorld().entries)
            if (!e.key.contains('recommendations/')) e.key: e.value,
        },
      );
      await pumpScreen(tester, _page, state: state);
      expect(find.text(_l10n.recEmpty), findsOneWidget);
    });
  });

  group('I\'ve completed this', () {
    testWidgets('marks the work, shows the tick and the questions button', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await pumpScreen(tester, _page, state: state);
      await tester.tap(find.text(_l10n.recIComplete));
      await tester.pumpAndSettle();
      expect(state.recommendationProgress.isCompleted('zz-rec-camino'), isTrue);
      expect(find.text(_l10n.recCompleted), findsOneWidget);
      expect(find.text(_l10n.recQuestions), findsOneWidget);
      expect(find.text(_l10n.recIComplete), findsNothing);
    });

    testWidgets('takes the mark away, with an undo', (tester) async {
      usePhone(tester);
      final state = await cultureApp();
      await _complete(state, 'zz-rec-camino');
      final first = state.recommendationProgress.completed.single.completedAt;
      await pumpScreen(tester, _page, state: state);
      await tester.tap(find.text(_l10n.recCompleted));
      await tester.pumpAndSettle();
      expect(
        state.recommendationProgress.isCompleted('zz-rec-camino'),
        isFalse,
      );
      expect(find.text(_l10n.recNotCompleted), findsOneWidget);
      await tester.tap(find.text(_l10n.commonUndo));
      await tester.pumpAndSettle();
      expect(state.recommendationProgress.isCompleted('zz-rec-camino'), isTrue);
      expect(state.recommendationProgress.completed.single.completedAt, first);
    });
  });

  group('on Today', () {
    Widget card() => const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: CompletedWorksCard(),
      ),
    );

    testWidgets('offers the list when nothing is completed yet', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, card(), state: await cultureApp());
      expect(find.text(_l10n.recHomeTitle), findsOneWidget);
      expect(find.text(_l10n.recHomeNone), findsOneWidget);
      await tester.tap(find.text(_l10n.recHomeSeeAll));
      await tester.pumpAndSettle();
      expect(find.byType(RecommendationsPage), findsOneWidget);
    });

    testWidgets('lists the completed works as covers, with a count', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await _complete(state, 'zz-rec-camino');
      await pumpScreen(tester, card(), state: state);
      expect(find.text(_l10n.recHomeCount(1, 1)), findsOneWidget);
      expect(find.text(_book), findsOneWidget);
      await tester.tap(find.text(_book));
      await tester.pumpAndSettle();
      expect(find.byType(RecommendationsPage), findsOneWidget);
    });

    testWidgets('is not drawn for a language with no recommended work', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp(
        files: <String, String>{
          for (final e in cultureWorld().entries)
            if (!e.key.contains('recommendations/')) e.key: e.value,
        },
      );
      await pumpScreen(tester, card(), state: state);
      expect(find.text(_l10n.recHomeTitle), findsNothing);
    });
  });

  group('the questions of a completed work', () {
    testWidgets('are locked until the work is completed', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, _questions, state: await cultureApp());
      expect(find.text(_l10n.recQuestionsLocked), findsOneWidget);
    });

    testWidgets('are asked one at a time, a miss showing what to re-read', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await _complete(state, 'zz-rec-camino');
      await pumpScreen(tester, _questions, state: state);
      expect(find.text(_l10n.recQuestionOf(1, 3)), findsOneWidget);
      expect(find.text('What is the book about?'), findsOneWidget);
      await tester.tap(find.text('Ships'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.recFeedbackWrong), findsOneWidget);
      expect(
        find.text(_l10n.recReread('A short book of verse about roads.')),
        findsOneWidget,
      );
      await tester.tap(find.text(_l10n.recQuestionsNext));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.recQuestionOf(2, 3)), findsOneWidget);
      await tester.tap(find.text('A poet'));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.recFeedbackRight), findsOneWidget);
      await tester.tap(find.text(_l10n.recQuestionsNext));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.recQuestionsFinish));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.recQuestionsDone), findsOneWidget);
      expect(find.text(_l10n.recQuestionsScore(2, 3)), findsOneWidget);
    });

    testWidgets('are not in the log: nothing is recorded by this screen', (
      tester,
    ) async {
      usePhone(tester);
      final state = await cultureApp();
      await _complete(state, 'zz-rec-camino');
      final before = state.progress.log.length;
      await pumpScreen(tester, _questions, state: state);
      await tester.tap(find.text('Roads'));
      await tester.pumpAndSettle();
      expect(state.progress.log.length, before);
    });
  });

  group('layout', () {
    DrawScreen on(Widget page, {String reach = 'a1', bool done = false}) =>
        (tester, mode) async {
          final state = await cultureApp(reach: reach);
          if (done) await _complete(state, 'zz-rec-camino');
          await pumpScreen(tester, page, state: state, themeMode: mode);
        };

    screen('the list at A1', on(_page));
    screen('the list at B1', on(_page, reach: 'b1'));
    screen('the list with a completed work', on(_page, done: true));
    screen(
      'the completed works on Today',
      on(
        const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: CompletedWorksCard(),
            ),
          ),
        ),
        done: true,
      ),
    );
    screen(
      'the completed works on Today, none yet',
      on(
        const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: CompletedWorksCard(),
            ),
          ),
        ),
      ),
    );
    screen('the questions', on(_questions, done: true));
    screen('the questions, locked', on(_questions));
    screen('no recommendations', (tester, mode) async {
      final state = await cultureApp(
        files: <String, String>{
          for (final e in cultureWorld().entries)
            if (!e.key.contains('recommendations/')) e.key: e.value,
        },
      );
      await pumpScreen(tester, _page, state: state, themeMode: mode);
    });
  });
}
