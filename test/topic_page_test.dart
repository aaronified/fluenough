// The topic page (wiki/Plan-Deck-Kinds-And-Topics.md, T19, the approved
// mockup docs/mockups/topic-page.html): a topic's name, language and level,
// how much of it the learner knows, its units, decks and cards each with
// their level and mastery, a "Drill this topic" button with a chooser, a
// script topic's characters, and an above-level topic read but never drilled.
// It is reached from the search's Topics tab and from the "Topics in this
// unit" chips of a unit.

import 'package:fluenough/app/app_state.dart';
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
      // A related topic above the level is listed, marked.
      expect(find.text('Library words'), findsOneWidget);
      expect(find.text(_l10n.topicAboveTitle.toUpperCase()), findsNothing);
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

  group('a topic above your level', () {
    testWidgets('is read, with a notice, and nothing of it is drilled', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(tester, _page('zz-library'), state: state);
      expect(find.text(_l10n.topicAboveTitle.toUpperCase()), findsOneWidget);
      expect(find.text(_l10n.topicAboveBody('B1', 'A1', 0)), findsOneWidget);
      expect(find.text(_l10n.searchAboveYourLevel('B1')), findsOneWidget);
      // No card of it is listed by its text; they are counted instead.
      expect(find.text('libro'), findsNothing);
      expect(find.text(_l10n.topicCardsAbove(3)), findsOneWidget);
      expect(find.text(_l10n.topicNothingToDrill), findsOneWidget);
      final drill = find.ancestor(
        of: find.text(_l10n.topicDrillCountLimited(0)),
        matching: find.bySubtype<FilledButton>(),
      );
      expect(tester.widget<FilledButton>(drill).onPressed, isNull);
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

    testWidgets('are left out when the setting hides what is above', (
      tester,
    ) async {
      usePhone(tester);
      state.settings.hideAboveLevel = true;
      await pumpScreen(
        tester,
        const UnitPage(deckId: 'zz-en-last'),
        state: state,
      );
      expect(find.text(_l10n.topicOnUnit), findsNothing);
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
    screen('a topic above your level', topic('zz-library'));
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
