// The topic page (wiki/Plan-Deck-Kinds-And-Topics.md, T19, the approved
// mockup docs/mockups/topic-page.html): a topic's name, language and level,
// how much of it the learner knows, its units, decks and cards each with
// their level and mastery, a "Drill this topic" button with a chooser, a
// script topic's characters. A higher-level topic is read and drilled like any.
// It is reached from the search's Topics tab and from the "Topics in this
// unit" chips of a unit.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/situations.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/topics/topic_drill_sheet.dart';
import 'package:fluenough/features/topics/topic_page.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart';
import 'support/deck_remote.dart';
import 'support/harness.dart';
import 'support/kinds_world.dart';

final AppLocalizationsEn _l10n = AppLocalizationsEn();

TopicPage _page(String id) => TopicPage(
  request: TopicRequest(language: 'zz', topicId: id),
);

void main() {
  late AppState state;

  setUp(() async {
    state = await kindsWorldApp();
  });

  group('a topic at your level', () {
    testWidgets('shows its name, level, coverage, units, decks and cards', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, _page('zz-house'), state: state);
      expect(find.text('House words'), findsWidgets);
      expect(find.text('A1'), findsWidgets);
      expect(find.text('Words for the house.'), findsOneWidget);
      expect(find.text(_l10n.topicKnownOf(0, 2)), findsOneWidget);
      expect(find.text(_l10n.topicUnits), findsOneWidget);
      expect(find.text(_l10n.topicDecks), findsOneWidget);
      expect(find.text('Unit 1: words'), findsOneWidget);
      expect(find.text(_l10n.topicDeckCards(2, 2)), findsOneWidget);
      expect(find.text(_l10n.topicCardsHeading(2, 2)), findsOneWidget);
      expect(find.text('casa'), findsOneWidget);
      // A related topic is listed (the page builds
      // its rows lazily, so scroll to the end first).
      await tester.scrollUntilVisible(
        find.text('Library words'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(TopicPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Library words'), findsOneWidget);
    });

    testWidgets('has a drill button, and a chooser with the skills', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, _page('zz-house'), state: state);
      expect(find.textContaining(_l10n.topicDrill), findsOneWidget);
      await tester.tap(find.text(_l10n.topicChoose));
      await tester.pumpAndSettle();
      expect(find.byType(TopicDrillSheet), findsOneWidget);
      expect(find.text(_l10n.topicSheetTitle('House words')), findsOneWidget);
      expect(find.text(_l10n.topicHowManyAll(2)), findsOneWidget);
      for (final skill in <String>[
        _l10n.topicSkillRead,
        _l10n.topicSkillHear,
        _l10n.topicSkillSay,
        _l10n.topicSkillWrite,
      ]) {
        expect(find.widgetWithText(FilterChip, skill), findsOneWidget);
      }
      expect(find.text(_l10n.topicStartDrill), findsOneWidget);
    });

    testWidgets('cannot be started with no skill chosen', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, _page('zz-house'), state: state);
      await tester.tap(find.text(_l10n.topicChoose));
      await tester.pumpAndSettle();
      FilledButton start() => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(_l10n.topicStartDrill),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      expect(start().onPressed, isNotNull);
      for (final skill in <String>[
        _l10n.topicSkillRead,
        _l10n.topicSkillHear,
      ]) {
        await tester.tap(find.widgetWithText(FilterChip, skill));
        await tester.pumpAndSettle();
      }
      expect(find.text(_l10n.topicChooseASkill), findsOneWidget);
      expect(start().onPressed, isNull);
    });

    testWidgets('does not list a hidden deck the learner has not added', (
      tester,
    ) async {
      usePhone(tester);
      final all = <String, String>{
        ...kindsWorld(),
        'decks/zz/zz-topics.yaml': kindsTopicsFile.replaceFirst(
          'decks: ["zz-words"]',
          'decks: ["zz-words", "zz-medicine-registro"]',
        ),
      };
      final visible = <String, String>{
        for (final e in all.entries)
          if (!e.key.contains('medicine-registro')) e.key: e.value,
      };
      final phone = MemoryDownloadedDecks();
      final downloads = DeckDownloads(
        fetcher: FakeDeckRemote(all),
        files: phone,
        clock: () => DateTime(2026, 11, 12),
      );
      final world = await kindsWorldApp(
        files: visible,
        build: (files, settings) => AppState.test(
          decks: DeckSources(<DeckSource>[MemoryDeckSource(files), phone]),
          deckDownloads: downloads,
          settings: settings,
        ),
      );
      await tester.runAsync(downloads.refreshIndex);
      await pumpScreen(tester, _page('zz-house'), state: world);
      expect(find.text('House words'), findsWidgets);
      expect(find.textContaining('medicine-registro'), findsNothing);
    });

    testWidgets('lists a script topic\'s characters', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, _page('zz-letters'), state: state);
      expect(find.text(_l10n.topicCharacters), findsOneWidget);
      for (final char in <String>['ab', 'cd', 'ef']) {
        expect(find.text(char), findsWidgets);
      }
      expect(find.text('joined'), findsWidgets);
    });
  });

  group('a topic at a higher level', () {
    testWidgets('is read and drilled like any other', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, _page('zz-library'), state: state);
      // Its cards are listed by their text and nothing is locked.
      expect(find.text('libro'), findsOneWidget);
      expect(find.text(_l10n.topicNothingToDrill), findsNothing);
    });
  });

  group('a topic that is not there', () {
    testWidgets('says so', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, _page('zz-nada'), state: state);
      expect(find.text(_l10n.topicNotFound), findsOneWidget);
    });
  });

  group('a topic drill', () {
    test('asks only the skills chosen, of at most the cards chosen', () {
      const request = DrillRequest.sheet(
        <String>{'zz-0001', 'zz-0002'},
        language: 'zz',
        skills: <Skill>{Skill.recognition},
        limit: 1,
      );
      expect(request.sheet, isTrue);
      expect(request.named, <Skill>{Skill.recognition});
      expect(request.limit, 1);
      final items = state.sheetSession(request);
      expect(
        <String>{for (final i in items) i.card.id}.length,
        lessThanOrEqualTo(1),
      );
    });
  });

  group('the topics in a unit', () {
    testWidgets('are chips that open their page', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-words'),
        state: state,
      );
      expect(find.text(_l10n.topicOnUnit), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, 'House words'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicPage), findsOneWidget);
    });
  });

  group('the topic page, at 1.4x text, light and dark', () {
    DrawScreen topic(String id) => (tester, mode) async {
      await pumpScreen(
        tester,
        _page(id),
        state: await kindsWorldApp(),
        themeMode: mode,
      );
    };

    screen('a topic at your level', topic('zz-house'));
    screen('a topic at a higher level', topic('zz-library'));
    screen('a script topic', topic('zz-letters'));
    screen('a unit with its topics', (tester, mode) async {
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-words'),
        state: await kindsWorldApp(),
        themeMode: mode,
      );
    });
    screen('the drill chooser', (tester, mode) async {
      await pumpScreen(
        tester,
        _page('zz-house'),
        state: await kindsWorldApp(),
        themeMode: mode,
      );
      await tester.tap(find.text(_l10n.topicChoose));
      await tester.pumpAndSettle();
    }, onTop: find.byType(BottomSheet));
  });
}
