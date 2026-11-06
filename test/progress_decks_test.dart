// Split out of progress_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: a deck's page, a walkthrough view, searching decks, searching cards, Decks, the path, the plan, the word sheet.

import 'dart:io';
import 'dart:math' as math;

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/unlocks.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart' show DeckKind, LanguageInfo;
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/skill_difficulty.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:fluenough/core/scheduling/study_hours.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/broken_deck_tile.dart';
import 'package:fluenough/features/decks/course_card.dart';
import 'package:fluenough/features/decks/deck_content.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/decks/path_model.dart';
import 'package:fluenough/features/decks/path_parts.dart';
import 'package:fluenough/features/decks/unit_search.dart';
import 'package:fluenough/features/decks/word_mastery.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/teach_card.dart';
import 'package:fluenough/features/drill/walkthrough_page.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/ipa_course.dart';
import 'support/progress_shared.dart';

/// A deck of three words: "gato" and "perro" tagged `pets`, "casa" tagged
/// `home`, for what a deck page does with its tag filter.
AppState taggedState({ProgressStore? progress}) => AppState.test(
  decks: MemoryDeckSource(<String, String>{
    'decks/es/es-en-tagged.yaml': '''
schema: 1
id: es-en-tagged
name: "Tagged"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: es-en-tagged-0001, target: "gato", native: "cat", tags: ["pets"] }
  - { id: es-en-tagged-0002, target: "perro", native: "dog", tags: ["pets"] }
  - { id: es-en-tagged-0003, target: "casa", native: "house", tags: ["home"] }
''',
  }),
  progress: progress,
);

/// Teaches every word of [deckId] that carries one of [tags], in every skill.
void learnTagged(AppState state, String deckId, Set<String> tags) {
  final request = DrillRequest(
    deckIds: <String>{deckId},
    untaught: true,
    tags: tags,
  );
  while (state.buildSession(request).fresh.isNotEmpty) {
    for (final item in state.buildSession(request).fresh) {
      state.record(item, 5);
    }
  }
}

Future<AppState> pumpDeck(
  WidgetTester tester,
  String deckId, {
  AppState? state,
  Set<String> tags = const <String>{},
}) => pumpScreen(
  tester,
  DeckDetailPage(deckId: deckId, initialTags: tags),
  state: state,
);

/// With a Spanish voice, and the deck's first six words taught three days
/// ago: its skills have something to drill (ADR-0024).
Future<AppState> withSpanishVoice() => withDeckTaught(
  (progress) => AppState.test(
    tts: FixedTtsEngine(const <String>{'es'}),
    progress: progress,
  ),
  spanish,
  count: 6,
);

/// Taps [finder] after scrolling it into view.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// From decks_page_test.dart.
Future<AppState> pumpDecks(
  WidgetTester tester, {
  AppState? state,
  DecksPage page = const DecksPage(),
}) => pumpScreen(tester, page, state: state);

/// The frozen deck copy that the ask pin (#568) also reads, shared so that
/// no second copy is kept: [teluguLearner] reads it where a test pins a
/// number from Telugu's path (a unit's number, "N units to go"), which every
/// deck pull request that adds a unit would otherwise change (#567). It is
/// refreshed only on purpose, with tools/snapshot_sample_decks.py, and then these
/// numbers are updated with it. The other tests read the live decks.
final DeckSource frozenDecks = RepositoryDeckSource('test/fixtures/sample-decks');

/// The design's Telugu learner, with Family up next. With [decks] the frozen
/// copy, the path is the one that copy holds.
Future<AppState> teluguLearnerDecksPage({
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

/// A floating button, by its hero tag.
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

// From path_plan_test.dart.
/// The Decks path reads a course's plan from its language's path
/// (ADR-0036): where each level ends, and each unit coming, planned or
/// written with no deck in the course's native language yet. On the
/// B1 format's example set (appendix-a), whose path marks A1, A2 and B1 and
/// plans a Health unit, and a Bengali deck for its first unit only.

const String appendix = 'test/fixtures/b1/appendix-a';

/// Every file of the example set, keyed as the catalog keys bundled decks, with
/// [path] in place of its path where given.
Map<String, String> appendixFiles({String? path}) => <String, String>{
  for (final file in Directory(appendix).listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/${file.path.substring(appendix.length + 1)}':
          path != null && file.path.endsWith('zz-path.yaml')
          ? path
          : file.readAsStringSync(),
  // Testlang from Bengali: its first unit's deck only. A test-only card id.
  'decks/zz/bn/zz-bn-home.yaml': '''
schema: 1
id: "zz-bn-home"
name: "ঘর"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
native: { code: "bn", iso639_3: "ben", name: "Bengali" }
license: "CC0-1.0"
cards:
  - { id: "zz-9801", target: "ఇల్లు", reading: "illu", native: "ঘর" }
''',
};

/// A Testlang learner from [native].
Future<AppState> learner({String native = 'en', String? path}) async {
  final settings = SettingsNotifier(
    spokenLanguages: <String>[native],
    learningLanguages: const <String>['zz'],
  )..learningChosen = true;
  settings.setCourseNative('zz', native, offered: const <String>['en', 'bn']);
  final state = AppState.test(
    decks: MemoryDeckSource(appendixFiles(path: path)),
    settings: settings,
  );
  await state.load();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a deck\'s page', () {
    testWidgets(
      'lists every word, and a tag chip narrows the list as it is tapped',
      (tester) async {
        usePhone(tester);
        final state = await pumpDeck(tester, spanish);
        final l10n = l10nOf(tester);
        final cards = state.deckById(spanish)!.cards;
        final first = cards.first;
        expect(
          find.text(l10n.deckWordCount(cards.length, cards.length)),
          findsOneWidget,
        );
        expect(find.text(first.target), findsOneWidget);

        await tapVisible(tester, find.widgetWithText(FilterChip, 'food'));
        final food = cards.where((c) => c.tags.contains('food')).length;
        expect(food, inExclusiveRange(0, cards.length));
        expect(first.tags, isNot(contains('food')));
        expect(
          find.text(l10n.deckWordCount(food, cards.length)),
          findsOneWidget,
        );
        expect(find.text(first.target), findsNothing);

        await tapVisible(tester, find.widgetWithText(FilterChip, 'food'));
        expect(
          find.text(l10n.deckWordCount(cards.length, cards.length)),
          findsOneWidget,
        );
        expect(find.text(first.target), findsOneWidget);
      },
    );

    testWidgets('tapping a word opens its sheet', (tester) async {
      usePhone(tester);
      final state = await pumpDeck(tester, spanish);
      final first = state.deckById(spanish)!.cards.first;
      await tester.tap(find.text(first.target));
      await tester.pumpAndSettle();
      expect(find.byType(WordSheet), findsOneWidget);
      expect(find.text(first.native), findsWidgets);
    });

    testWidgets(
      'the label is Relearn only once every card of the deck is taught, not '
      'just those in view',
      (tester) async {
        usePhone(tester);
        final state = taggedState();
        await state.load();
        learnTagged(state, 'es-en-tagged', const <String>{'pets'});
        await pumpScreen(
          tester,
          const DeckDetailPage(
            deckId: 'es-en-tagged',
            initialTags: <String>{'pets'},
          ),
          state: state,
        );
        final l10n = l10nOf(tester);

        // The words in view are taught, but "casa" is not: the label stays
        // Learn, with no badge, and it still walks the words in view.
        expect(find.text(l10n.deckRelearn), findsNothing);
        expect(find.text(l10n.deckLearn), findsOneWidget);
        expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, false);
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text(l10n.deckLearn),
                  matching: find.byWidgetPredicate((w) => w is FilledButton),
                ),
              )
              .onPressed,
          isNotNull,
        );

        learnTagged(state, 'es-en-tagged', const <String>{'home'});
        await tester.pumpAndSettle();
        expect(find.text(l10n.deckRelearn), findsOneWidget);
        expect(find.text(l10n.deckLearn), findsNothing);
        expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, false);
      },
    );

    testWidgets(
      'Relearn walks through the words in view on the teach card, forward '
      'and back, and writes nothing',
      (tester) async {
        usePhone(tester);
        final state = taggedState();
        await state.load();
        learnAll(state, 'es-en-tagged');
        await pumpScreen(
          tester,
          const DeckDetailPage(
            deckId: 'es-en-tagged',
            initialTags: <String>{'pets'},
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        final logged = state.progress.log.length;
        final states = Map.of(state.progress.states);

        await tester.tap(find.text(l10n.deckRelearn));
        await tester.pumpAndSettle();
        expect(find.byType(TeachCard), findsOneWidget);
        expect(find.text('gato'), findsOneWidget);
        expect(find.text(l10n.drillPositionShort(1, 2)), findsOneWidget);

        // Toward the start edge goes on, to the second of the two in view;
        // "casa", which the filter leaves out, is never shown.
        await tester.fling(find.byType(TeachCard), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('perro'), findsOneWidget);
        expect(find.text(l10n.drillPositionShort(2, 2)), findsOneWidget);

        // And back again.
        await tester.fling(find.byType(TeachCard), const Offset(300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('gato'), findsOneWidget);
        await tester.fling(find.byType(TeachCard), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('casa'), findsNothing);

        // Going on from the last card ends the walk, back on the deck's page.
        await tester.fling(find.byType(TeachCard), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.byType(TeachCard), findsNothing);
        expect(find.byType(DeckDetailPage), findsOneWidget);
        expect(state.progress.log, hasLength(logged));
        expect(state.progress.states, states);
      },
    );

    testWidgets(
      'with no filter, Relearn walks through every card of the deck',
      (tester) async {
        usePhone(tester);
        final state = taggedState();
        await state.load();
        learnAll(state, 'es-en-tagged');
        await pumpScreen(
          tester,
          const DeckDetailPage(deckId: 'es-en-tagged'),
          state: state,
        );
        final l10n = l10nOf(tester);
        await tester.tap(find.text(l10n.deckRelearn));
        await tester.pumpAndSettle();
        expect(find.text(l10n.drillPositionShort(1, 3)), findsOneWidget);
      },
    );

    testWidgets(
      'the badge counts the words in view not taught, and Learn walks every '
      'word in view, taught or not',
      (tester) async {
        usePhone(tester);
        final state = await pumpDeck(tester, spanish);
        final l10n = l10nOf(tester);
        final cards = state.deckById(spanish)!.cards;
        final all = state.newToWalk(cards);
        Finder badge(int n) =>
            find.descendant(of: find.byType(Badge), matching: find.text('$n'));
        expect(all, greaterThan(2));
        expect(badge(all), findsOneWidget);

        await tapVisible(tester, find.widgetWithText(FilterChip, 'food'));
        final inView = <Card>[
          for (final c in cards)
            if (c.tags.contains('food')) c,
        ];
        final food = state.newToWalk(inView);
        expect(food, inExclusiveRange(0, all));
        expect(badge(food), findsOneWidget);

        await tester.tap(find.text(l10n.deckLearn));
        await tester.pumpAndSettle();
        expect(find.byType(DrillPage), findsNothing);
        expect(find.byType(TeachCard), findsOneWidget);
        expect(
          find.text(l10n.drillPositionShort(1, inView.length)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Learn on a part-taught deck walks all of it and writes only for the '
      'cards not taught',
      (tester) async {
        usePhone(tester);
        final state = taggedState();
        await state.load();
        learnTagged(state, 'es-en-tagged', const <String>{'pets'});
        await pumpScreen(
          tester,
          const DeckDetailPage(deckId: 'es-en-tagged'),
          state: state,
        );
        final l10n = l10nOf(tester);
        final logged = state.progress.log.length;
        await tester.tap(find.text(l10n.deckLearn));
        await tester.pumpAndSettle();
        expect(find.text(l10n.drillPositionShort(1, 3)), findsOneWidget);
        expect(find.text('gato'), findsOneWidget);
        expect(state.progress.log, hasLength(logged));
        for (var i = 0; i < 2; i++) {
          await tester.fling(
            find.byType(TeachCard),
            const Offset(-300, 0),
            1000,
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('casa'), findsOneWidget);
        expect(state.progress.log, hasLength(logged + 1));
        expect(state.progress.log.last.cardId, 'es-en-tagged-0003');
      },
    );

    testWidgets(
      '+ Learn walks the new words: each first view is one log row graded 0, '
      'a repeat view writes nothing, and the deck is then Relearn',
      (tester) async {
        usePhone(tester);
        final state = taggedState();
        await state.load();
        await pumpScreen(
          tester,
          const DeckDetailPage(deckId: 'es-en-tagged'),
          state: state,
        );
        final l10n = l10nOf(tester);
        const gato = 'es-en-tagged-0001';
        const recognition = DrillMode.recognition;

        await tester.tap(find.text(l10n.deckLearn));
        await tester.pumpAndSettle();
        expect(find.text('gato'), findsOneWidget);
        // The first card is taught on sight, in recognition only.
        expect(state.progress.log, hasLength(1));
        final row = state.progress.log.single;
        expect(row.cardId, gato);
        expect(row.mode, recognition);
        expect(row.asked, Ask.teach);
        expect(row.grade, 0);
        expect(row.answerGiven, isNull);
        expect(state.progress.stateOf(gato, recognition), isNotNull);
        expect(state.progress.stateOf(gato, DrillMode.production), isNull);
        expect(state.progress.stateOf(gato, recognition)!.repetitions, 0);
        expect(state.progress.stateOf(gato, recognition)!.lapses, 0);

        await tester.fling(find.byType(TeachCard), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('perro'), findsOneWidget);
        expect(state.progress.log, hasLength(2));

        // Back to a card seen: nothing more is written.
        await tester.fling(find.byType(TeachCard), const Offset(300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('gato'), findsOneWidget);
        expect(state.progress.log, hasLength(2));

        for (var i = 0; i < 3; i++) {
          await tester.fling(
            find.byType(TeachCard),
            const Offset(-300, 0),
            1000,
          );
          await tester.pumpAndSettle();
        }
        expect(state.progress.log, hasLength(3));
        expect(find.byType(DeckDetailPage), findsOneWidget);
        expect(find.text(l10n.deckRelearn), findsOneWidget);
        expect(find.text(l10n.deckLearn), findsNothing);
      },
    );

    testWidgets(
      'Practice drills the words in view in every skill, due or not, and '
      'every answer is recorded',
      (tester) async {
        usePhone(tester);
        await pumpDeck(tester, spanish, state: await withSpanishVoice());
        final l10n = l10nOf(tester);
        await tapVisible(tester, find.widgetWithText(FilterChip, 'people'));
        await tester.tap(find.text(l10n.deckPractice));
        await tester.pumpAndSettle();
        expect(find.text(l10n.deckPracticeBody), findsOneWidget);
        await tester.tap(find.text(l10n.deckPracticeStart));
        await tester.pumpAndSettle();
        final request = tester
            .widget<DrillPage>(find.byType(DrillPage))
            .request;
        expect(request.deckIds, <String>{spanish});
        expect(request.revise, isTrue);
        expect(request.recordsRevision, isTrue);
        expect(request.skills, isNull);
        expect(request.tags, <String>{'people'});
      },
    );

    testWidgets('Practice with some skills ticked names them', (tester) async {
      usePhone(tester);
      await pumpDeck(tester, spanish, state: await withSpanishVoice());
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.deckPractice));
      await tester.pumpAndSettle();
      // Unticking All clears every skill, and Start waits for one.
      await tester.tap(find.text(l10n.deckPracticeAll));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, l10n.deckPracticeStart),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text(Skill.production.label(l10n)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deckPracticeStart));
      await tester.pumpAndSettle();
      final request = tester.widget<DrillPage>(find.byType(DrillPage)).request;
      expect(request.skills, <Skill>{Skill.production});
      expect(request.revise, isTrue);
    });
  });

  group('a walkthrough view', () {
    test('of a sentence still waiting logs the usual row, and it counts as '
        'taught; seen again it writes nothing', () async {
      // A fresh Bengali learner: the clothes sentences wait for their words.
      final state = AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['bn'],
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      final decks = unitOfDeck(state, 'bn-en-clothes-sentences')!.decks;
      final walk = state.walkCards(decks);
      final waiting = <Card>[
        for (final w in walk)
          if (state.unlocks.isClosed(w.card) &&
              !state.isTaught(w.card) &&
              state.drillableModes(w.card).isNotEmpty)
            w.card,
      ];
      expect(waiting, isNotEmpty, reason: 'the fixture has a waiting sentence');
      final sentence = waiting.first;
      final fresh = state.newToWalk(<Card>[for (final w in walk) w.card]);
      final logged = state.progress.log.length;

      final view = state.viewCard(sentence)!;
      expect(view.isView, isTrue);
      expect(view.cardId, sentence.id);
      expect(view.grade, 0);
      expect(view.asked, Ask.teach);
      expect(state.progress.log, hasLength(logged + 1));
      expect(state.isTaught(sentence), isTrue);
      expect(state.newToWalk(<Card>[for (final w in walk) w.card]), fresh - 1);
      // A view is no answer (the stats skip it), so it does not open the
      // sentence: Unlocks.isOffered still waits for the words and rules.
      expect(state.unlocks.isOffered(sentence), isFalse);
      expect(state.viewCard(sentence), isNull);
      expect(state.progress.log, hasLength(logged + 1));
    });

    test('a card with no mode to drill writes nothing', () async {
      final state = taggedState();
      addTearDown(state.dispose);
      await state.load();
      final card = state.deckById('es-en-tagged')!.cards.first;
      for (final skill in Skill.values) {
        state.settings.setSkillEnabled(skill, false);
      }
      expect(state.drillableModes(card), isEmpty);
      expect(state.viewCard(card), isNull);
      expect(state.progress.log, isEmpty);
    });

    test('a walk covers every deck of the unit in deck order, each card once '
        'with its deck, taught or not', () async {
      final state = await teluguLearner();
      await state.load();
      // Addressing and Pronouns: a unit of two word decks.
      final decks = unitOfDeck(state, 'te-en-addressing')!.decks;
      expect(decks.length, greaterThan(1));
      final walk = state.walkCards(decks);
      final ids = <String>[for (final w in walk) w.card.id];
      expect(ids.toSet(), hasLength(ids.length));
      // Deck by deck, in the order the decks list, each deck's own order.
      var at = 0;
      for (final deck in decks.where((d) => d.deck.kind != DeckKind.reading)) {
        for (final card in deck.cards) {
          if (at < walk.length && walk[at].card.id == card.id) {
            expect(walk[at].entry.id, deck.id);
            at++;
          }
        }
      }
      expect(at, walk.length);
      expect(<String>{
        for (final w in walk) w.entry.id,
      }, hasLength(greaterThan(1)));
      // Taught cards stay in it.
      final taught = walk.where((w) => state.isTaught(w.card));
      expect(taught, isNotEmpty);
    });

    testWidgets('the walk shows each card\'s deck name, changing where it '
        'crosses into the next deck', (tester) async {
      usePhone(tester);
      final state = await teluguLearner();
      await state.load();
      final decks = unitOfDeck(state, 'te-en-addressing')!.decks;
      final walk = state.walkCards(decks);
      await pumpScreen(
        tester,
        WalkthroughPage(
          request: WalkthroughRequest(
            deckIds: <String>[for (final e in decks) e.id],
          ),
        ),
        state: state,
      );
      final boundary = walk.indexWhere(
        (w) => w.entry.id != walk.first.entry.id,
      );
      expect(boundary, greaterThan(0));
      expect(find.text(walk.first.entry.deck.name), findsOneWidget);
      for (var i = 0; i < boundary; i++) {
        await tester.fling(find.byType(TeachCard), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
      }
      expect(find.text(walk[boundary].entry.deck.name), findsOneWidget);
      expect(find.text(walk.first.entry.deck.name), findsNothing);
    });

    const gato = 'es-en-tagged-0001';
    const key = (cardId: gato, mode: DrillMode.recognition);

    test(
      'is no answer: accuracy, learned, streak, lapses, study time and '
      'the FSRS fit skip it, but a later answer still starts from it',
      () async {
        final state = taggedState();
        addTearDown(state.dispose);
        await state.load();
        final card = state.deckById('es-en-tagged')!.cards.first;
        final view = state.viewCard(card)!;
        expect(view.isView, isTrue);
        // A card seen already, or taught, is not recorded again.
        expect(state.viewCard(card), isNull);

        StatsNumbers numbers() => StatsNumbers.of(
          state.progress,
          now: state.now(),
          range: StatsRange.all,
          cardOf: cardLookupOf(state),
        );
        expect(numbers().reviews, 0);
        expect(numbers().remembered, isNull);
        expect(numbers().learned, 0);
        expect(numbers().streak, 0);
        expect(numbers().heatmapReviews, 0);
        expect(state.progress.index.reviewsIn('es'), 0);

        // Right, then missed: the miss is the pair's first lapse, whether or
        // not the view is counted, and the view hurts no accuracy.
        final item = SessionItem(
          card: card,
          mode: DrillMode.recognition,
          state: null,
        );
        state.record(item, 4);
        state.record(item, 1);
        expect(state.progress.stateOf(gato, DrillMode.recognition)!.lapses, 1);
        expect(state.progress.index.lapsesOf(key), 1);
        expect(numbers().reviews, 2);
        expect(numbers().remembered, 0.5);

        // The time and the fit leave it out too.
        final progress = MemoryProgress()
          ..record(
            deckId: 'es-en-tagged',
            cardId: gato,
            mode: DrillMode.recognition,
            grade: 0,
            now: DateTime(2026, 9, 1),
            elapsed: const Duration(seconds: 30),
            asked: Ask.teach,
          );
        expect(StudyHours.spent(progress.log), Duration.zero);
        expect(StudyHours.missShare(progress.log), 0);
        expect(
          SkillFit.histories(progress.log.map(logged)),
          isEmpty,
          reason: 'a view is not a first answer to fit from',
        );
      },
    );
  });

  group('searching decks', () {
    late AppState state;
    AppLocalizationsEn();

    setUpAll(() async {
      state = AppState.test();
      await state.load();
    });

    test('search matches a deck, its language, or its theme or unit', () {
      // Named "First words", in Hindi.
      final words = state.deckById('hi-en-first-words')!;
      expect(deckMatches(words, ''), isTrue);
      expect(deckMatches(words, 'FIRST'), isTrue);
      expect(deckMatches(words, 'hindustani'), isTrue);
      expect(deckMatches(words, 'spanish'), isFalse);

      final themes = state.themesByDeck;
      expect(themes['hi-en-market']?.id, 'market');
      // Grammar has no theme of its own: it takes its unit's on the path.
      // The noun table has a unit of its own in Hindi's B1 plan, with no theme
      // deck to lend one.
      expect(themes['hi-en-grammar-nouns'], isNull);
      expect(themes['hi-en-grammar-continuous']?.id, 'directions');
    });
  });

  group('searching cards', () {
    late AppState state;
    late List<LanguageInfo> telugu;

    setUpAll(() async {
      state = AppState.test();
      await state.load();
      telugu = <LanguageInfo>[
        for (final l in state.languages)
          if (l.code == 'te') l,
      ];
    });

    List<String> cardIds(String query) => <String>[
      for (final hit in searchCourses(
        state,
        AppLocalizationsEn(),
        query,
        telugu,
      ))
        if (hit is CardHit) hit.card.id,
    ];

    test('a meaning finds the Telugu word for it', () {
      expect(cardIds('why'), contains('te-0164'));
    });

    test('Telugu script finds the word', () {
      expect(cardIds('ఎందుకు'), contains('te-0164'));
    });

    test('a reading without its accents finds the word', () {
      expect(cardIds('namaskaram'), contains('te-0135'));
      expect(cardIds('NAMASKARAM'), contains('te-0135'));
    });
  });

  group('Decks', () {
    testWidgets(
      'the path opens at the unit up next, and Where I am scrolls back to it',
      (tester) async {
        usePhone(tester);
        await pumpDecks(
          tester,
          state: await teluguLearnerDecksPage(decks: frozenDecks),
        );
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
        // The path builds only the rows near the screen (#853), so the rest
        // of it is read by walking down it from the top.
        final position = tester.state<ScrollableState>(downward.first).position;
        final aheadWork = find.bySemanticsLabel(
          RegExp('^Work, unit 22, ${l10n.pathUnitAhead}'),
        );
        var sawWork = false;
        var sawFirstDeck = false;
        var sawWords = false;
        var sawScriptLearned = false;
        var sawScriptToGo = false;
        final headers = <(CefrLevel, bool)>{};
        final marks = <Object>{};
        position.jumpTo(0);
        await tester.pump();
        while (true) {
          sawWork |= aheadWork.evaluate().isNotEmpty;
          // Milestones: the first deck finished, words learned, the script.
          sawFirstDeck |= find.text(l10n.pathFirstDeck).evaluate().isNotEmpty;
          sawWords |= find
              .text(l10n.pathWordsLearned(50))
              .evaluate()
              .isNotEmpty;
          sawScriptLearned |= find
              .text(l10n.pathScriptLearned)
              .evaluate()
              .isNotEmpty;
          sawScriptToGo |= find
              .text(l10n.pathScriptToGo(2))
              .evaluate()
              .isNotEmpty;
          for (final h in tester.widgetList<LevelHeader>(
            find.byType(LevelHeader),
          )) {
            headers.add((h.step.level, h.step.current));
          }
          for (final m in tester.widgetList<AchievementMark>(
            find.byType(AchievementMark),
          )) {
            marks.add(m.step);
          }
          if (position.pixels >= position.maxScrollExtent) break;
          position.jumpTo(
            math.min(position.pixels + 400, position.maxScrollExtent),
          );
          await tester.pump();
        }
        expect(sawWork, isTrue);
        expect(sawFirstDeck, isTrue);
        expect(sawWords, isTrue);
        expect(sawScriptLearned, isTrue);
        expect(sawScriptToGo, isTrue);
        // Telugu's path marks A1, A2 and B1 (ADR-0036), so each level is
        // drawn, with its achievement, the learner's own, A1, current.
        expect(headers, {
          (CefrLevel.a1, true),
          (CefrLevel.a2, false),
          (CefrLevel.b1, false),
        });
        expect(marks, hasLength(3));

        {
          usePhone(tester);
          await pumpDecks(tester, state: await teluguLearnerDecksPage());
          final l10n = l10nOf(tester);
          await tester.drag(downward.first, const Offset(0, -3000));
          await tester.pumpAndSettle();
          // Scrolled away, the unit is off screen, and may not be built.
          final upNext = find.text(l10n.pathUpNext);
          expect(
            upNext.evaluate().isEmpty || !onScreen(tester, upNext),
            isTrue,
          );
          await tester.tap(fab('where-i-am'));
          await tester.pumpAndSettle();
          expect(onScreen(tester, find.text(l10n.pathUpNext)), isTrue);
        }
      },
    );

    testWidgets(
      'Where I am is one icon-only button on the right, named by its tooltip, '
      'and Add deck is not on the screen (#475)',
      (tester) async {
        usePhone(tester, textScale: 1.4);
        await pumpDecks(tester, state: await teluguLearnerDecksPage());
        final l10n = l10nOf(tester);
        final where = fab('where-i-am');
        expect(where, findsOneWidget);
        expect(
          find.descendant(of: where, matching: find.byType(Text)),
          findsNothing,
        );
        expect(find.byTooltip(l10n.decksWhereIAm), findsOneWidget);
        final rect = tester.getRect(where);
        expect(rect.center.dx, greaterThan(390 / 2));
        expect(rect.width, greaterThanOrEqualTo(40));
        // A screen reader says the tooltip (it is the button's name); Flutter
        // keeps it apart from the label, so either may carry it.
        final named = tester.getSemantics(where);
        expect('${named.label} ${named.tooltip}', contains(l10n.decksWhereIAm));
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );

    testWidgets(
      'a broken file is a row with its line; a catalog that failed offers '
      'Try again',
      (tester) async {
        usePhone(tester);
        final state = await pumpDecks(
          tester,
          state: AppState.test(decks: withBrokenDeck()),
        );
        final l10n = l10nOf(tester);
        final broken = state.brokenDecks.single;
        expect(find.text(l10n.pathBrokenFiles), findsOneWidget);
        expect(find.byType(BrokenDeckTile), findsOneWidget);
        expect(
          find.text(l10n.decksBrokenTitle(broken.fileName)),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.decksBrokenAt(broken.error.line!, broken.error.message),
          ),
          findsOneWidget,
        );

        await search(tester, 'broken');
        expect(find.byType(BrokenDeckTile), findsOneWidget);

        {
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
        }
      },
    );
  });

  group('the path', () {
    // The bundled decks are read as assets.

    test('a fresh course has its first unit up next; learned units are done, '
        'and the next is up next', () async {
      final state = await loaded();
      final view = courseView(state, 'te')!;
      final units = view.units.toList();
      expect(
        units.map((u) => u.decks.map((e) => e.id).toList()),
        state.courseUnits('te').map((u) => u.map((e) => e.id).toList()),
      );
      expect(units.first.status, UnitStatus.upNext);
      expect(
        units.skip(1).map((u) => u.status),
        everyElement(UnitStatus.ahead),
      );
      expect(units.map((u) => u.number), [
        for (var i = 1; i <= units.length; i++) i,
      ]);
      expect(view.doneCount, 0);
      expect(view.upNext, same(units.first));
      // Every unit is on the path, so each opens its screen.
      expect(units.map((u) => u.onPath), everyElement(isTrue));
      // Telugu's path marks A1, A2 and B1 (ADR-0036): each level is drawn,
      // from the first step, with its achievement, none earned yet.
      expect(view.levels, CefrLevel.values);
      expect(view.steps.first, isA<LevelStep>());
      expect(
        view.steps.whereType<AchievementStep>().map((a) => (a.level, a.earned)),
        [for (final level in CefrLevel.values) (level, false)],
      );
      // A course whose plan marks no level draws none.
      final unplanned = courseView(state, 'te', plan: CoursePlan.none)!;
      expect(unplanned.steps.whereType<LevelStep>(), isEmpty);
      expect(unplanned.steps.whereType<AchievementStep>(), isEmpty);
      expect(unplanned.units.map((u) => u.status), units.map((u) => u.status));

      {
        final state = await telugu();
        final view = courseView(state, 'te')!;
        final units = view.units.toList();
        final family = units.indexWhere(
          (u) => u.decks.any((e) => e.id == 'te-en-family'),
        );
        expect(
          units.take(family).map((u) => u.status),
          everyElement(UnitStatus.done),
        );
        expect(units[family].status, UnitStatus.upNext);
        expect(view.doneCount, family);

        final first = view.steps.whereType<MilestoneStep>().first;
        expect(first.kind, MilestoneKind.firstDeck);
        expect(first.earned, isTrue);
        expect(first.earnedAt, isNotNull);

        final fifty = view.steps.whereType<MilestoneStep>().firstWhere(
          (m) => m.kind == MilestoneKind.words && m.count == 50,
        );
        expect(fifty.earned, isTrue);
        // The 50th word's first right answer.
        final answers = RecentAnswers(state.progress.log);
        final words = <String>{
          for (final unit in units)
            for (final card in unit.content.words) card.id,
        };
        // Of the words learned now, as the Learned counts take them.
        final learned = <String>{
          for (final entry in state.progress.states.entries)
            if (entry.value.repetitions > 0) entry.key.cardId,
        };
        final passed =
            words
                .where(learned.contains)
                .map(answers.firstPassed)
                .nonNulls
                .toList()
              ..sort();
        expect(fifty.earnedAt, passed[49]);
        expect(fifty.toGo, 0);
      }
    });

    test('A1 is reached once its units are done', () async {
      final state = await telugu(upTo: 'te-en-market');
      final view = courseView(state, 'te', plan: PathFixtures.telugu)!;
      final a1 = view.steps.whereType<AchievementStep>().first;
      expect(a1.level, CefrLevel.a1);
      expect(a1.earned, isTrue);
      expect(a1.earnedAt, isNotNull);
      expect(view.upNext!.decks.first.id, 'te-en-market');
      expect(view.upNext!.level, CefrLevel.a2);
      expect(view.steps.whereType<LevelStep>().map((h) => h.current), [
        false,
        true,
        false,
      ]);
    });
  });

  group('the plan', () {
    test('a written unit with no deck in the course\'s language is coming, '
        'named from another course\'s deck for it', () async {
      final state = await learner(native: 'bn');
      expect(state.courseUnits('zz').map((u) => u.map((e) => e.id)), [
        ['zz-bn-home'],
      ]);
      final plan = coursePlanOf(state, 'zz');
      // A2 has no unit taught from Bengali, so nothing marks where it ends.
      expect(plan.levelEnds, <CefrLevel, String>{CefrLevel.a1: 'zz-bn-home'});
      expect(plan.coming, <ComingUnit>[
        (
          title: 'In, to, with, from: case endings',
          level: CefrLevel.a2,
          words: null,
        ),
        (title: 'Health', level: CefrLevel.b1, words: 60),
      ]);
    });
  });

  group('the word sheet', () {
    testWidgets(
      'shows what the card has, inline: its note under a title, its tags, '
      'its id with where the learner stands, and Report',
      (tester) async {
        usePhone(tester);
        final state = AppState.test();
        await state.load();
        final entry = state.deckById('hi-en-market')!;
        final card = entry.cards.firstWhere(
          (c) => c.tags.isNotEmpty && c.notes.isNotEmpty,
        );
        await pumpScreen(
          tester,
          Scaffold(
            body: WordSheet(card: card, language: entry.language),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text(card.native), findsWidgets);
        expect(find.text(card.notes.first.text), findsOneWidget);
        expect(find.text(l10n.cardNoteTitle), findsWidgets);
        for (final tag in card.tags) {
          expect(find.text(tag), findsOneWidget);
        }
        expect(find.textContaining(card.id), findsOneWidget);
        expect(find.text(l10n.cardReport), findsOneWidget);
        // Never answered: nothing to say of how hard it is.
        expect(find.text(l10n.cardDifficulty), findsNothing);
      },
    );

    testWidgets(
      'warns, with titles, of a word it looks like and of its other meanings, '
      'and shows its dictionary entry',
      (tester) async {
        usePhone(tester);
        final state = AppState.test(
          decks: MemoryDeckSource(<String, String>{
            'decks/es/es-words.yaml': '''
schema: 1
id: "es-words"
part: "core"
kind: "vocab"
language: { code: "es", iso639_3: "spa", name: "Spanish", script: "latin" }
license: "CC0-1.0"
cards:
  - id: "es-9001"
    target: "casa"
    notes:
      - { id: "mark", kind: "lookalike", ref: "es-9002" }
  - id: "es-9002"
    target: "caza"
''',
            'decks/es/en/es-en-words.yaml': '''
schema: 1
id: "es-en-words"
kind: "layer"
core: "es-words"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Words"
license: "CC0-1.0"
cards:
  "es-9001":
    native: "house"
    alt_native: ["home"]
    notes:
      "mark": "casa is spelled with an s; caza with a z."
    dictionary:
      senses: ["A building to live in."]
      etymology: "From Latin casa."
      source: "wiktionary.org/wiki/casa"
  "es-9002":
    native: "hunt"
''',
          }),
        );
        await state.load();
        expect(state.brokenDecks, isEmpty);
        final entry = state.deckById('es-en-words')!;
        final card = entry.cards.firstWhere((c) => c.id == 'es-9001');
        await pumpScreen(
          tester,
          Scaffold(
            body: WordSheet(card: card, language: entry.language),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.cardLooksLikeTitle), findsOneWidget);
        expect(
          find.text('casa is spelled with an s; caza with a z.'),
          findsOneWidget,
        );
        expect(find.text(l10n.cardOtherMeaningsTitle), findsOneWidget);
        expect(find.text(l10n.cardOtherMeaningsText('home')), findsOneWidget);
        expect(find.text(l10n.cardDictionaryHeading), findsOneWidget);
        expect(find.text('A building to live in.'), findsOneWidget);
        expect(
          find.text(l10n.cardDictionaryEtymology('From Latin casa.')),
          findsOneWidget,
        );
        expect(
          find.text(l10n.cardDictionaryCredit('wiktionary.org/wiki/casa')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps each sound of the word\'s IPA behind an info dot, in order, from '
      'the IPA course, each with its practice',
      (tester) async {
        usePhone(tester);
        final state = ipaApp(<String>['hi']);
        await state.load();
        final entry = state.deckById('hi-en-words')!;
        final card = entry.cards.first;
        await pumpScreen(
          tester,
          Scaffold(
            body: WordSheet(card: card, language: entry.language),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        // Nothing of the sounds is drawn until the dot beside the IPA is
        // tapped.
        expect(find.text('the sound pʰ'), findsNothing);
        expect(find.text(l10n.ipaSymbolPractise), findsNothing);
        await tester.tap(find.byTooltip(l10n.hintInfo));
        await tester.pumpAndSettle();
        final aspirated = find.text('the sound pʰ');
        final retroflex = find.text('the sound ɳ');
        expect(aspirated, findsOneWidget);
        expect(retroflex, findsOneWidget);
        expect(find.text(l10n.ipaSymbolPractise), findsNWidgets(2));
        // pʰəɳ: the aspirated p comes before the retroflex n.
        expect(
          tester.getTopLeft(aspirated).dy,
          lessThan(tester.getTopLeft(retroflex).dy),
        );
      },
    );

    testWidgets(
      'shows how hard the card has been in each skill answered, and nothing '
      'for a card never answered',
      (tester) async {
        final monday = DateTime(2026, 10, 5, 19);
        usePhone(tester);
        final progress = MemoryProgress();
        final state = AppState.test(progress: progress);
        await state.load();
        final entry = state.deckById('hi-en-market')!;
        final card = entry.cards.first;
        for (final (i, (mode, grade)) in const <(DrillMode, int)>[
          (DrillMode.listening, 1),
          (DrillMode.listening, 0),
          (DrillMode.listening, 1),
          (DrillMode.production, 4),
        ].indexed) {
          progress.record(
            deckId: 'hi-en-market',
            cardId: card.id,
            mode: mode,
            grade: grade,
            now: monday.add(Duration(days: i)),
            answerGiven: 'typed',
          );
        }
        await pumpScreen(
          tester,
          Scaffold(
            body: WordSheet(card: card, language: entry.language),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        final hear = SkillDifficulty(
          DrillMode.listening,
          progress.stateOf(card.id, DrillMode.listening)!.difficulty,
        );
        final write = SkillDifficulty(
          DrillMode.production,
          progress.stateOf(card.id, DrillMode.production)!.difficulty,
        );
        expect(hear.lean, DifficultyLean.harder);
        expect(write.lean, DifficultyLean.easier);
        String line(SkillDifficulty d) =>
            l10n.cardDifficultyIn(d.mode.name, d.shown, d.lean.name);

        expect(find.text(l10n.cardDifficulty), findsOneWidget);
        expect(find.text(line(hear)), findsOneWidget);
        expect(find.text(line(write)), findsOneWidget);
        expect(line(hear), contains('Hear: ${hear.shown} of 10, harder'));
        expect(line(write), contains('Write: ${write.shown} of 10, easier'));
        // Write is listed before Hear, as the skills are ordered.
        expect(
          tester.getTopLeft(find.text(line(write))).dy,
          lessThan(tester.getTopLeft(find.text(line(hear))).dy),
        );
        for (final mode in <DrillMode>[
          DrillMode.recognition,
          DrillMode.speaking,
          DrillMode.grammarUnderstood,
          DrillMode.grammar,
        ]) {
          final skill = l10n.cardDifficultyIn(mode.name, 1, 'easier');
          expect(
            find.textContaining(skill.substring(0, skill.indexOf(':') + 1)),
            findsNothing,
            reason: '${mode.name} was never answered',
          );
        }

        // Another card, never answered, shows no difficulty at all.
        final other = entry.cards.firstWhere((c) => c.id != card.id);
        await pumpScreen(
          tester,
          Scaffold(
            body: WordSheet(card: other, language: entry.language),
          ),
          state: state,
        );
        expect(find.text(l10n.cardDifficulty), findsNothing);
      },
    );
  });
}
