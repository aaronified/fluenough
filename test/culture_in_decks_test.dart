// Culture in the Decks screen (docs/mockups/culture-in-decks.md, owner,
// 2026-11-16): the course card's Culture button swaps the deck path for the
// culture list and back; the list is grouped (culture decks, then the
// recommended works by kind) with a count each; the one Decks search filters
// whichever list shows; nothing is hidden or locked by level, and a work opens
// and can be marked completed at any level. Also the covers of the completed works on
// Today, which open the list, and the questions of a completed work.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/culture_list.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/features/culture/completed_works_card.dart';
import 'package:fluenough/features/culture/work_questions_page.dart';
import 'package:fluenough/features/decks/culture_list.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_view.dart';
import 'package:fluenough/features/decks/search_tabs.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart';
import 'support/culture_world.dart';
import 'support/harness.dart';

final AppLocalizationsEn _l10n = AppLocalizationsEn();

const String _book = 'Campos de prueba';
const String _film = 'Una película de prueba';
const String _novel = 'Una novela de prueba';
const String _briefing = 'A short book of verse about roads. Plain words.';

const Key _button = ValueKey<String>('course-culture-button');

const WorkQuestionsPage _questions = WorkQuestionsPage(
  request: WorkQuestionsRequest(
    language: 'zz',
    recommendationId: 'zz-rec-camino',
  ),
);

Future<void> _complete(AppState state, String id) async {
  final work = state.catalogView.recommendations['zz']!.byId(id)!;
  state.recommendationProgress.complete(work, 'zz', state.now());
}

/// The Decks screen on the culture world, showing the deck path.
Future<AppState> _decks(
  WidgetTester tester, {
  String reach = 'a1',
  ThemeMode mode = ThemeMode.light,
  AppState? state,
}) async {
  final app = state ?? await cultureApp(reach: reach);
  await pumpScreen(tester, const DecksPage(), state: app, themeMode: mode);
  await _toTop(tester);
  return app;
}

/// The path opens scrolled to the unit up next: bring the course card, the
/// search bar and their buttons back to the top.
Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
}

Future<void> _toCulture(WidgetTester tester) async {
  await _toTop(tester);
  await tester.tap(find.byKey(_button));
  await tester.pumpAndSettle();
}

/// Taps [target] once it is scrolled into view: the culture list sits under
/// the course card, so its rows start below the phone's fold.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

Finder _header(String name, int count) =>
    find.text(_l10n.decksCultureHeader(name, count));

/// The tab called [label] of the strip of tabs.
Finder _tab(String label) => find.descendant(
  of: find.byType(TabBar),
  matching: find.text(label),
);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.ensureVisible(_tab(label).first);
  await tester.pumpAndSettle();
  await tester.tap(_tab(label).first);
  await tester.pumpAndSettle();
}

void main() {
  group('the Culture button', () {
    testWidgets('swaps the deck path for the culture list and back', (
      tester,
    ) async {
      usePhone(tester);
      await _decks(tester);
      expect(find.byType(CoursePathSliver), findsOneWidget);
      expect(find.byType(CultureList), findsNothing);
      expect(find.text(_l10n.decksCultureButton), findsOneWidget);
      await _toCulture(tester);
      expect(find.byType(CoursePathSliver), findsNothing);
      expect(find.byType(CultureList), findsOneWidget);
      // The card stays, its button now reads "Deck path".
      expect(find.text(_l10n.decksPathButton), findsOneWidget);
      expect(find.text(_l10n.decksCultureButton), findsNothing);
      await _toCulture(tester);
      expect(find.byType(CoursePathSliver), findsOneWidget);
      expect(find.byType(CultureList), findsNothing);
    });

    testWidgets('is not a new page: the Decks screen stays', (tester) async {
      usePhone(tester);
      await _decks(tester);
      await _toCulture(tester);
      expect(find.byType(DecksPage), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });
  });

  group('the culture list', () {
    testWidgets('groups the decks, then the works by kind, with counts', (
      tester,
    ) async {
      usePhone(tester);
      final state = await _decks(tester);
      await _toCulture(tester);
      final decks = state.cultureDecksIn('zz').length;
      expect(decks, greaterThan(0));
      final deckHeader = _header(_l10n.decksCultureDecksHeader, decks);
      final books = _header(_l10n.recKindBooks, 2);
      final films = _header(_l10n.recKindFilms, 1);
      expect(deckHeader, findsOneWidget);
      expect(books, findsOneWidget);
      expect(films, findsOneWidget);
      // Only the kinds the data has.
      expect(find.textContaining(_l10n.recKindSongs), findsNothing);
      expect(find.textContaining(_l10n.recKindPodcasts), findsNothing);
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(deckHeader), lessThan(top(books)));
      expect(top(books), lessThan(top(films)));
    });

    testWidgets('lists every work whatever the learner level, none locked', (
      tester,
    ) async {
      usePhone(tester);
      await _decks(tester);
      await _toCulture(tester);
      expect(find.text(_book), findsOneWidget);
      expect(find.text(_film), findsOneWidget);
      // A B1 work for an A1 learner is there, with its level.
      await tester.scrollUntilVisible(
        find.text(_novel),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_novel), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byIcon(Icons.lock), findsNothing);
    });

    testWidgets('a culture deck row opens its deck at any level', (
      tester,
    ) async {
      usePhone(tester);
      final state = await _decks(tester);
      await _toCulture(tester);
      final deck = state.cultureDecksIn('zz').last;
      await tester.ensureVisible(
        find.byKey(ValueKey<String>('culture-deck-${deck.id}')),
      );
      await tester.tap(find.byKey(ValueKey<String>('culture-deck-${deck.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(DeckDetailPage), findsOneWidget);
    });

    testWidgets('badges a public-domain work and the deck that quotes it', (
      tester,
    ) async {
      usePhone(tester);
      await _decks(tester);
      await _toCulture(tester);
      expect(find.text(_l10n.recPublicDomain), findsOneWidget);
      final prefix = _l10n.recAlsoInDeck('\u0000').replaceAll('\u0000', '');
      expect(find.textContaining(prefix), findsOneWidget);
    });

    testWidgets('says so when the course has nothing cultural', (tester) async {
      usePhone(tester);
      final state = await cultureApp(
        files: <String, String>{
          for (final e in cultureWorld().entries)
            if (!e.key.contains('recommendations/') &&
                !e.key.contains('culture') &&
                !e.key.contains('proverbs'))
              e.key: e.value,
        },
      );
      await _decks(tester, state: state);
      await _toCulture(tester);
      expect(find.text(_l10n.decksCultureNone('Testlang')), findsOneWidget);
    });
  });

  group('the one search', () {
    for (final inCulture in <bool>[false, true]) {
      final where = inCulture ? 'in the culture list' : 'on the deck path';

      Future<void> open(WidgetTester tester) async {
        usePhone(tester);
        await _decks(tester);
        if (inCulture) await _toCulture(tester);
      }

      testWidgets('finds a film $where, ignoring accents', (tester) async {
        await open(tester);
        await _search(tester, 'pelicula');
        // One strip of tabs holds the deck results and the culture kinds.
        expect(find.byType(TabBar), findsOneWidget);
        await _openTab(tester, _l10n.recKindFilms);
        expect(find.text(_film), findsOneWidget);
        expect(find.text(_book), findsNothing);
        // A kind with no match has no tab.
        expect(_tab(_l10n.recKindBooks), findsNothing);
        expect(find.byType(CoursePathSliver), findsNothing);
      });

      testWidgets('finds a culture deck $where by its name', (tester) async {
        await open(tester);
        await _search(tester, 'verse');
        expect(find.text('Culture: verse'), findsWidgets);
        expect(find.text(_film), findsNothing);
      });

      testWidgets('finds decks and cards $where as well', (tester) async {
        await open(tester);
        await _search(tester, 'tarde');
        expect(find.byType(TypedSearchResults), findsOneWidget);
        expect(find.text(_l10n.searchNothing('tarde')), findsNothing);
      });

      testWidgets('says so once $where when nothing matches', (tester) async {
        await open(tester);
        await _search(tester, 'zzq');
        expect(find.text(_l10n.searchNothing('zzq')), findsOneWidget);
        expect(find.text(_l10n.decksEmptySearch), findsNothing);
        expect(find.textContaining(_l10n.recKindFilms), findsNothing);
      });

      testWidgets('clearing the search returns to the mode $where', (
        tester,
      ) async {
        await open(tester);
        await _search(tester, 'pelicula');
        await _toTop(tester);
        await tester.tap(find.byTooltip(_l10n.decksSearchClear));
        await tester.pumpAndSettle();
        expect(find.byType(CultureList), findsNWidgets(inCulture ? 1 : 0));
        expect(find.byType(CoursePathSliver), findsNWidgets(inCulture ? 0 : 1));
      });
    }

    testWidgets('puts the culture kinds in the one strip, with counts', (
      tester,
    ) async {
      usePhone(tester);
      await _decks(tester);
      await _search(tester, 'prueba');
      expect(find.byType(TabBar), findsOneWidget);
      expect(_tab(_l10n.recKindBooks), findsOneWidget);
      expect(_tab(_l10n.recKindFilms), findsOneWidget);
      await _openTab(tester, _l10n.recKindBooks);
      expect(find.text(_book), findsOneWidget);
      expect(find.text(_novel), findsOneWidget);
      expect(find.text(_film), findsNothing);
    });

    testWidgets('a chip narrows the deck part and leaves out culture', (
      tester,
    ) async {
      usePhone(tester);
      await _decks(tester);
      await _search(tester, 'kind:grammar pelicula');
      expect(find.text(_film), findsNothing);
    });

    group('the culture tokens', () {
      Future<void> chip(WidgetTester tester, String text) async {
        usePhone(tester);
        await _decks(tester);
        await _search(tester, text);
      }

      testWidgets('kind:film lists films only, without deck results', (
        tester,
      ) async {
        await chip(tester, 'kind:film ');
        expect(find.byType(TypedSearchResults), findsNothing);
        expect(find.text(_film), findsOneWidget);
        expect(find.text(_book), findsNothing);
        expect(_header(_l10n.recKindFilms, 1), findsOneWidget);
      });

      testWidgets('kind:proverb lists the proverbs decks only', (
        tester,
      ) async {
        await chip(tester, 'kind:proverb ');
        expect(find.text('Proverbs: place'), findsOneWidget);
        expect(find.text('Culture: verse'), findsNothing);
        expect(find.text(_film), findsNothing);
      });

      testWidgets('creator: matches a name, ignoring accents and case', (
        tester,
      ) async {
        await chip(tester, 'creator:MACHADO ');
        expect(find.text(_book), findsOneWidget);
        expect(find.text(_film), findsOneWidget);
        expect(find.text(_novel), findsNothing);
      });

      testWidgets('year: takes a year or a range', (tester) async {
        await chip(tester, 'year:1900-1990 ');
        expect(find.text(_book), findsOneWidget);
        expect(find.text(_film), findsOneWidget);
        expect(find.text(_novel), findsNothing);
      });

      for (final done in <bool>[true, false]) {
        testWidgets('status:${done ? 'done' : 'todo'} splits the works', (
          tester,
        ) async {
          usePhone(tester);
          final state = await cultureApp();
          await _complete(state, 'zz-rec-camino');
          await _decks(tester, state: state);
          await _search(tester, done ? 'status:done ' : 'status:todo ');
          expect(find.text(_book), done ? findsOneWidget : findsNothing);
          expect(find.text(_film), done ? findsNothing : findsOneWidget);
        });
      }

      testWidgets('the token menu offers creator: and year:', (tester) async {
        usePhone(tester);
        await _decks(tester);
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(find.text('creator:'), findsOneWidget);
        expect(find.text('year:'), findsOneWidget);
      });

      testWidgets('kind: offers the culture kinds', (tester) async {
        usePhone(tester);
        await _decks(tester);
        await tester.enterText(find.byType(TextField), 'kind:');
        await tester.pumpAndSettle();
        expect(find.text(_l10n.recMediumFilm), findsOneWidget);
        expect(find.text(_l10n.recMediumBook), findsOneWidget);
      });
    });

    testWidgets('the culture list has a strip of tabs, All first', (
      tester,
    ) async {
      usePhone(tester);
      await _decks(tester);
      await _toCulture(tester);
      expect(find.byType(TabBar), findsOneWidget);
      expect(_tab(_l10n.decksCultureAll), findsOneWidget);
      expect(_tab(_l10n.recKindBooks), findsOneWidget);
      expect(_tab(_l10n.recKindFilms), findsOneWidget);
      await _openTab(tester, _l10n.recKindFilms);
      expect(find.text(_film), findsOneWidget);
      expect(find.text(_book), findsNothing);
    });

    testWidgets('sections are computed from the catalog', (tester) async {
      final state = await cultureApp();
      final sections = state.cultureListOf(
        'zz',
        query: '1912',
        mediumName: (m) => m.name,
        decksName: 'Culture decks',
      );
      expect(sections, hasLength(1));
      expect(sections.single.works.single.id, 'zz-rec-camino');
      expect(sections.single.count, 1);
    });
  });

  group('I\'ve completed this', () {
    testWidgets('a row opens with its briefing, legal routes and action', (
      tester,
    ) async {
      usePhone(tester);
      await _decks(tester);
      await _toCulture(tester);
      expect(find.text(_briefing), findsNothing);
      await _tap(tester, find.text(_book));
      expect(find.text(_briefing), findsOneWidget);
      expect(find.text(_l10n.recNotIncluded), findsOneWidget);
      expect(
        find.text(
          _l10n.recLegalLine(_l10n.recLegalLibrary, 'Free: public domain'),
        ),
        findsOneWidget,
      );
      expect(find.text(_l10n.recIComplete), findsOneWidget);
    });

    testWidgets('marks a work above the level, shows the tick and questions', (
      tester,
    ) async {
      usePhone(tester);
      final state = await _decks(tester);
      await _toCulture(tester);
      await tester.scrollUntilVisible(
        find.text(_novel),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, find.text(_novel));
      await _tap(tester, find.text(_l10n.recIComplete));
      expect(state.recommendationProgress.isCompleted('zz-rec-novela'), isTrue);
      expect(find.text(_l10n.recCompleted), findsOneWidget);
      expect(find.text(_l10n.recQuestions), findsOneWidget);
    });

    testWidgets('takes the mark away, with an undo', (tester) async {
      usePhone(tester);
      final state = await cultureApp();
      await _complete(state, 'zz-rec-camino');
      final first = state.recommendationProgress.completed.single.completedAt;
      await _decks(tester, state: state);
      await _toCulture(tester);
      await _tap(tester, find.text(_book));
      await _tap(tester, find.text(_l10n.recCompleted));
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

    testWidgets('offers the culture list when nothing is completed yet', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(tester, card(), state: await cultureApp());
      expect(find.text(_l10n.recHomeTitle), findsOneWidget);
      expect(find.text(_l10n.recHomeNone), findsOneWidget);
      await tester.tap(find.text(_l10n.recHomeSeeAll));
      await tester.pumpAndSettle();
      expect(state.shellTab.value, ShellTab.decks);
      expect(state.decksCultureRequest.value?.language, 'zz');
      expect(state.decksCultureRequest.value?.openId, isNull);
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
      expect(state.shellTab.value, ShellTab.decks);
      expect(state.decksCultureRequest.value?.openId, 'zz-rec-camino');
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

    testWidgets('a cover request opens the list with that work open', (
      tester,
    ) async {
      usePhone(tester);
      final state = await _decks(tester);
      expect(find.byType(CultureList), findsNothing);
      state.decksCultureRequest.value = const CultureListRequest(
        language: 'zz',
        openId: 'zz-rec-camino',
      );
      await tester.pumpAndSettle();
      expect(find.byType(CultureList), findsOneWidget);
      expect(find.text(_briefing), findsOneWidget);
      expect(state.decksCultureRequest.value, isNull);
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
    DrawScreen on({String reach = 'a1', bool done = false, String? search}) =>
        (tester, mode) async {
          final state = await cultureApp(reach: reach);
          if (done) await _complete(state, 'zz-rec-camino');
          await _decks(tester, mode: mode, state: state);
          await _toCulture(tester);
          if (search != null) await _search(tester, search);
        };

    screen('the culture list', on());
    screen('the culture list at B1', on(reach: 'b1'));
    screen('the culture list with a completed work', on(done: true));
    screen('the culture list, nothing found', on(search: 'zzq'));
    screen('a search with culture results', on(search: 'pelicula'));
    screen('the completed works on Today', (tester, mode) async {
      final state = await cultureApp();
      await _complete(state, 'zz-rec-camino');
      await pumpScreen(
        tester,
        const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: CompletedWorksCard(),
            ),
          ),
        ),
        state: state,
        themeMode: mode,
      );
    });
    screen('the questions', (tester, mode) async {
      final state = await cultureApp();
      await _complete(state, 'zz-rec-camino');
      await pumpScreen(tester, _questions, state: state, themeMode: mode);
    });
    screen('the questions, locked', (tester, mode) async {
      await pumpScreen(
        tester,
        _questions,
        state: await cultureApp(),
        themeMode: mode,
      );
    });

    testWidgets('the culture list at 360 dp and 1.4x text, light and dark', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        tester.view
          ..physicalSize = const Size(360 * 3, 800 * 3)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _decks(tester, mode: mode);
        await _toCulture(tester);
        expect(find.byType(CultureList), findsOneWidget, reason: mode.name);
        expect(tester.takeException(), isNull, reason: mode.name);
        await _tap(tester, find.text(_book));
        expect(tester.takeException(), isNull, reason: mode.name);
        await meetsEveryGuideline(tester);
      }
      semantics.dispose();
    });
  });
}
