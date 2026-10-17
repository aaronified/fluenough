import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/features/decks/broken_deck_tile.dart';
import 'package:fluenough/features/decks/course_card.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/import_page.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/decks/path_model.dart';
import 'package:fluenough/features/decks/path_parts.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';
import 'package:fluenough/ui/widgets/incoming.dart';

import '../../support/harness.dart';

Future<AppState> pumpDecks(
  WidgetTester tester, {
  AppState? state,
  DecksPage page = const DecksPage(),
}) => pumpScreen(tester, page, state: state);

/// The frozen deck copy that the ask pin (#568) also reads, shared so that
/// no second copy is kept: [teluguLearner] reads it where a test pins a
/// number from Telugu's path (a unit's number, "N units to go"), which every
/// deck pull request that adds a unit would otherwise change (#567). It is
/// refreshed only on purpose, with tools/snapshot_ask_pin.py, and then these
/// numbers are updated with it. The other tests read the live decks.
final DeckSource frozenDecks = RepositoryDeckSource('test/fixtures/ask_pin');

/// The design's Telugu learner, with Family up next. With [decks] the frozen
/// copy, the path is the one that copy holds.
Future<AppState> teluguLearner({
  String upTo = PathFixtures.familyDeck,
  DeckSource? decks,
}) async {
  final app = AppState.test(decks: decks);
  await app.load();
  return PathFixtures.state(app, upTo: upTo);
}

/// Whether [finder]'s first widget is on the phone's screen.
bool onScreen(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder.first);
  return rect.bottom > 0 && rect.top < 844;
}

/// The page's scrolling list, not the chips' row.
final Finder downward = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// A floating button, with its label or, where two do not fit, without.
Finder fab(String heroTag) => find.byWidgetPredicate(
  (w) => w is FloatingActionButton && w.heroTag == heroTag,
);

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

/// A valid deck and a broken one, in memory.
MemoryDeckSource withBrokenDeck() => MemoryDeckSource(const <String, String>{
  'decks/xx/xx-fixture-ok.yaml': '''
schema: 1
id: xx-fixture-ok
name: Fixture deck
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: xx-fixture-ok-0001
    target: "sí"
    native: "yes"
''',
  'decks/xx/xx-fixture-broken.yaml': '''
schema: 1
id: xx-fixture-broken
name: Broken fixture
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: xx-fixture-broken-0001
    target: "verdadero"
    native: true
''',
});

void main() {
  testWidgets('shows the course of the language the bar shows, with no '
      'course chips (#528)', (tester) async {
    usePhone(tester);
    final state = await pumpDecks(tester, state: await teluguLearner());
    expect(state.shownLanguage, 'te');
    expect(find.byType(FilterChip), findsNothing);
    expect(
      tester.widget<CourseCard>(find.byType(CourseCard)).view.language.code,
      'te',
    );
    state.showLanguage('hi');
    await tester.pumpAndSettle();
    expect(
      tester.widget<CourseCard>(find.byType(CourseCard)).view.language.code,
      'hi',
    );
  });

  testWidgets('the path opens at the unit up next, after the units done', (
    tester,
  ) async {
    usePhone(tester);
    await pumpDecks(tester, state: await teluguLearner(decks: frozenDecks));
    final l10n = l10nOf(tester);
    // Scrolled to where the learner is: Family, up next.
    expect(onScreen(tester, find.text(l10n.pathUpNext)), isTrue);
    expect(onScreen(tester, find.text('Family')), isTrue);
    expect(
      find.bySemanticsLabel(RegExp('^Family, unit 5, ${l10n.pathUpNext}')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('^Addressing people, unit 4, ${l10n.pathUnitDone}'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('^Work, unit 22, ${l10n.pathUnitAhead}')),
      findsOneWidget,
    );
    // Milestones: the first deck finished, words learned, the script.
    expect(find.text(l10n.pathFirstDeck), findsOneWidget);
    expect(find.text(l10n.pathWordsLearned(50)), findsOneWidget);
    expect(find.text(l10n.pathScriptLearned), findsOneWidget);
    expect(find.text(l10n.pathScriptToGo(2)), findsOneWidget);
    // Telugu's path marks A1, A2 and B1 (ADR-0036), so each level is
    // drawn, with its achievement, the learner's own, A1, current.
    expect(find.byType(LevelHeader), findsNWidgets(3));
    expect(find.byType(AchievementMark), findsNWidgets(3));
    expect(
      tester
          .widgetList<LevelHeader>(find.byType(LevelHeader))
          .map((h) => (h.step.level, h.step.current)),
      [(CefrLevel.a1, true), (CefrLevel.a2, false), (CefrLevel.b1, false)],
    );
  });

  testWidgets('further down: rules known and the first passage read, '
      'each with what is left', (tester) async {
    usePhone(tester);
    // Past the units that hold the rules, so that some are known.
    final state = await pumpDecks(
      tester,
      state: await teluguLearner(upTo: 'te-en-work', decks: frozenDecks),
    );
    final l10n = l10nOf(tester);
    final rules = courseView(state, 'te')!.steps
        .whereType<MilestoneStep>()
        .singleWhere((m) => m.kind == MilestoneKind.rules);
    // Some of the rules of the units done are known already.
    expect(rules.toGo, inExclusiveRange(0, 10));
    for (final (title, line) in <(String, String)>[
      (l10n.pathRulesKnown(10), l10n.pathRulesToGo(rules.toGo)),
      (l10n.pathFirstPassage, l10n.pathFirstPassageToGo),
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        300,
        scrollable: downward.first,
      );
      expect(find.text(line), findsOneWidget);
    }
  });

  testWidgets('Where I am scrolls back to the unit up next', (tester) async {
    usePhone(tester);
    await pumpDecks(tester, state: await teluguLearner());
    final l10n = l10nOf(tester);
    await tester.drag(downward.first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.text(l10n.pathUpNext)), isFalse);
    await tester.tap(fab('where-i-am'));
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.text(l10n.pathUpNext)), isTrue);
  });

  for (final (upTo, level, scale) in <(String, String, double)>[
    (PathFixtures.familyDeck, 'A1', 1.0),
    ('te-en-help', 'A2', 1.0),
    ('te-en-help', 'A2', 1.4),
  ]) {
    testWidgets('Where I am unfolds the level holding the unit up next '
        '($upTo at ${scale}x) and leaves it fully visible, clear of the '
        'floating buttons (#488)', (tester) async {
      usePhone(tester, textScale: scale);
      final app = await teluguLearner(upTo: upTo);
      await pumpDecks(tester, state: app);
      final l10n = l10nOf(tester);
      // Opens on the unit; the learner folds its level and scrolls off.
      final header = find.ancestor(
        of: find.text(level),
        matching: find.byType(LevelHeader),
      );
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(app.settings.isLevelCollapsed('te', level), isTrue);
      await tester.drag(downward.first, const Offset(0, 8000));
      await tester.pumpAndSettle();

      await tester.tap(fab('where-i-am'));
      await tester.pumpAndSettle();
      expect(app.settings.isLevelCollapsed('te', level), isFalse);
      final unit = tester.getRect(
        find.ancestor(
          of: find.text(l10n.pathUpNext),
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_UnitNode',
          ),
        ),
      );
      final fabTop = tester.getRect(fab('add-deck')).top;
      final listTop = tester.getRect(downward.first).top;
      expect(unit.top, greaterThanOrEqualTo(listTop));
      expect(unit.bottom, lessThanOrEqualTo(fabTop));
    });
  }

  testWidgets('Where I am goes to the up next unit of the language the bar '
      'shows (#488)', (tester) async {
    usePhone(tester);
    final app = await teluguLearner();
    await pumpDecks(tester, state: app);
    final l10n = l10nOf(tester);
    app.showLanguage('hi');
    await tester.pumpAndSettle();
    await tester.drag(downward.first, const Offset(0, -4000));
    await tester.pumpAndSettle();
    await tester.tap(fab('where-i-am'));
    await tester.pumpAndSettle();
    final unit = tester.getRect(find.text(l10n.pathUpNext));
    expect(unit.top, greaterThan(tester.getRect(downward.first).top));
    expect(unit.bottom, lessThan(tester.getRect(fab('add-deck')).top));
  });

  testWidgets('a unit opens its screen; the language bar switches the path', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpDecks(tester, state: await teluguLearner());
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<UnitPage>(find.byType(UnitPage)).deckId,
      'te-en-family',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    state.showLanguage('hi');
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    expect(
      find.text(l10n.decksCourseHeading('Hindi', 'English')),
      findsOneWidget,
    );
  });

  testWidgets('a deck outside any path opens its own screen, as before', (
    tester,
  ) async {
    usePhone(tester);
    await pumpDecks(tester, state: AppState.test(decks: withBrokenDeck()));
    await tester.tap(find.text('Fixture deck'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DeckDetailPage>(find.byType(DeckDetailPage)).deckId,
      'xx-fixture-ok',
    );
  });

  testWidgets('learned without the alphabet, the script decks are listed '
      'under the path, and open their own screens', (tester) async {
    usePhone(tester);
    final base = AppState.test();
    await base.load();
    final state = PathFixtures.state(base);
    state.settings.setLearnsAlphabet('te', false);
    await pumpDecks(tester, state: state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.pathOtherDecks), findsOneWidget);
    final vowels = state.deckById('te-en-script-vowels')!;
    final tile = find.byWidgetPredicate(
      (w) => w is DeckTile && w.entry.id == vowels.id,
    );
    await tester.scrollUntilVisible(tile, 300, scrollable: downward.first);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DeckDetailPage>(find.byType(DeckDetailPage)).deckId,
      vowels.id,
    );
  });

  testWidgets('where a plan marks them, each level starts with its header '
      'and ends in its achievement; units still being written are coming', (
    tester,
  ) async {
    usePhone(tester);
    await pumpDecks(
      tester,
      state: await teluguLearner(decks: frozenDecks),
      page: const DecksPage(planOf: PathFixtures.planOf),
    );
    final l10n = l10nOf(tester);
    expect(find.byType(LevelHeader), findsNWidgets(3));
    expect(find.text(l10n.pathLevelA1), findsOneWidget);
    expect(find.text(l10n.pathLevelB1), findsOneWidget);
    expect(find.byType(AchievementMark), findsNWidgets(3));
    expect(find.text(l10n.pathAchievement('A1')), findsOneWidget);
    expect(find.text(l10n.pathUnitsToGo(19)), findsOneWidget);
    expect(find.text(l10n.pathUnitsToGoComing(13, 7)), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text(l10n.pathComingWords(60)), findsWidgets);
    // A coming unit cannot be opened.
    await tester.scrollUntilVisible(
      find.text('Health'),
      300,
      scrollable: downward.first,
    );
    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    expect(find.byType(UnitPage), findsNothing);
  });

  testWidgets('a level reached is an achievement, earned', (tester) async {
    usePhone(tester);
    await pumpDecks(
      tester,
      state: await teluguLearner(upTo: 'te-en-market', decks: frozenDecks),
      page: const DecksPage(planOf: PathFixtures.planOf),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.pathLevelReached('A1')), findsOneWidget);
    expect(find.text(l10n.pathAchievement('A2')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Market, unit 26, ${l10n.pathUpNext}')),
      findsOneWidget,
    );
  });

  testWidgets('Beyond the course shows as incoming; deck updates and hours '
      'left are on (#464, #227)', (tester) async {
    usePhone(tester);
    await pumpDecks(tester, state: await teluguLearner());
    final l10n = l10nOf(tester);
    expect(find.byType(IncomingBadge), findsOneWidget);
    expect(find.text(l10n.pathUpdatesTitle), findsOneWidget);
    expect(find.text(l10n.pathUpdatesUpToDate), findsOneWidget);
    expect(find.text(l10n.pathUpdatesButton), findsNothing);
    for (final label in <String>[l10n.pathUpdatesTitle, l10n.pathHoursTitle]) {
      expect(
        find.bySemanticsLabel(l10n.incomingSemanticsLabel(label)),
        findsNothing,
        reason: label,
      );
    }
    for (final label in <String>[l10n.pathBeyondTitle]) {
      expect(
        find.bySemanticsLabel(l10n.incomingSemanticsLabel(label)),
        findsOneWidget,
        reason: label,
      );
    }
  });

  testWidgets('search finds units in the bar\'s course alone, by name, '
      'deck or language, and opens them (#527, #528)', (tester) async {
    usePhone(tester);
    await pumpDecks(
      tester,
      state: await teluguLearner(decks: frozenDecks),
      page: const DecksPage(planOf: PathFixtures.planOf),
    );
    final l10n = l10nOf(tester);

    // Only Telugu's Family, though other courses have one too.
    await search(tester, 'family');
    expect(find.text('Family'), findsOneWidget);
    expect(find.textContaining('Telugu · A1 · '), findsOneWidget);

    await search(tester, 'telugu health');
    expect(find.text('Health'), findsOneWidget);
    expect(find.text(l10n.pathComing), findsOneWidget);

    await search(tester, 'no unit is called this');
    expect(find.text(l10n.decksEmptySearch), findsOneWidget);

    await search(tester, 'family');
    await tester.tap(find.textContaining('Telugu · A1 · '));
    await tester.pumpAndSettle();
    expect(
      tester.widget<UnitPage>(find.byType(UnitPage)).deckId,
      'te-en-family',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('search looks in the course of the language the bar shows, '
      'and clearing it shows the path again (#528)', (tester) async {
    usePhone(tester);
    final state = await pumpDecks(tester, state: await teluguLearner());
    final l10n = l10nOf(tester);
    expect(state.shownLanguage, 'te');
    await search(tester, 'family');
    expect(find.textContaining('Telugu · A1 · '), findsOneWidget);

    // A Hindi deck is not found while the bar shows Telugu.
    await search(tester, 'parmesh');
    expect(find.text(l10n.decksEmptySearch), findsOneWidget);

    // With the bar on Hindi, the search looks in Hindi's course.
    state.showLanguage('hi');
    await search(tester, 'parmesh');
    expect(
      find.text(state.deckById('hi-en-reading-panch-parmeshwar')!.deck.name),
      findsOneWidget,
    );
    expect(find.textContaining('Telugu · '), findsNothing);

    // Clearing the search shows the path again, under the field.
    await tester.tap(find.byTooltip(l10n.decksSearchClose));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text(l10n.pathUpNext), findsOneWidget);
  });

  testWidgets('Decks shows only the languages the learner learns (owner, '
      '2026-10-16: "No, only my languages")', (tester) async {
    usePhone(tester);
    // Mira learns Marathi alone.
    final state = await pumpDecks(
      tester,
      state: AppState.test(profiles: const [GalleryFixtures.mira]),
      page: const DecksPage(initialQuery: 'family'),
    );
    expect(state.languageChoices.map((l) => l.code), <String>['mr']);
    expect(find.textContaining('Marathi · '), findsWidgets);
    for (final language in state.languages) {
      if (language.code == 'mr') continue;
      expect(
        find.textContaining('${language.name} · '),
        findsNothing,
        reason: language.name,
      );
    }
    expect(find.text(l10nOf(tester).commonStartBadge), findsNothing);
  });

  testWidgets('a broken file is a row with its file, line and message, '
      'under the path and in search', (tester) async {
    usePhone(tester);
    final state = await pumpDecks(
      tester,
      state: AppState.test(decks: withBrokenDeck()),
    );
    final l10n = l10nOf(tester);
    final broken = state.brokenDecks.single;
    expect(find.text(l10n.pathBrokenFiles), findsOneWidget);
    expect(find.byType(BrokenDeckTile), findsOneWidget);
    expect(find.text(l10n.decksBrokenTitle(broken.fileName)), findsOneWidget);
    expect(
      find.text(l10n.decksBrokenAt(broken.error.line!, broken.error.message)),
      findsOneWidget,
    );

    await search(tester, 'broken');
    expect(find.byType(BrokenDeckTile), findsOneWidget);
  });

  testWidgets('Add deck opens import', (tester) async {
    usePhone(tester);
    await pumpDecks(tester);
    await tester.tap(fab('add-deck'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportPage), findsOneWidget);
  });

  testWidgets('at a large text size the floating buttons keep their names '
      'as tooltips', (tester) async {
    usePhone(tester, textScale: 2.0);
    await pumpDecks(tester, state: await teluguLearner());
    final l10n = l10nOf(tester);
    expect(find.byTooltip(l10n.decksWhereIAm), findsOneWidget);
    expect(find.byTooltip(l10n.decksAdd), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a catalog that failed offers Try again, which reloads it', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const DecksPage(),
      state: AppState.test(decks: FailOnceDeckSource()),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.commonDecksFailed), findsOneWidget);
    expect(find.byType(CourseCard), findsNothing);

    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(state.status, CatalogStatus.ready);
    expect(find.text(l10n.commonDecksFailed), findsNothing);
    expect(find.byType(CourseCard), findsOneWidget);
  });
}
