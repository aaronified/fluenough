// Progress: numbers for 7 days, 30 days and all time; streaks per language
// and across daylight saving; a word in two decks learned once; Known,
// Learning and New; Done decks and Revise; the path's up-next unit and A1
// reached; completeness and stage toward B1; Read and Write per script;
// hours spent and left; How you learn and the pace strip after a fit;
// leeches append and never delete.

import 'dart:io';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/pacing.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/course_path.dart'
    show CoursePath, Milestone, PlanUnit;
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/models/deck.dart' show LanguageInfo;
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/skill_difficulty.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
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
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/decks/unit_search.dart';
import 'package:fluenough/features/decks/word_mastery.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/teach_card.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/leeches_page.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/l10n/app_localizations_en.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';
import 'package:fluenough/ui/widgets/pace_parts.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/ipa_course.dart';
import 'support/paced_learner.dart';

// From stats_numbers_test.dart.
/// A known log on real cards of `es-en-core-100`, whose tags are `people`
/// (0001) and `home` (0006–0009). The clock is Mon 28 Sep 2026, 19:00.
///
/// | day | card, mode, grade |
/// | --- | --- |
/// | −100 | 0009 recognition 4 (outside the grid) |
/// | −40 | 0001 recognition 4 |
/// | −20 | 0001 production 1, 0006 recognition 5 |
/// | −3 | 0006 production 2, 0007 recognition 4 |
/// | −2 | 0007 recognition 4 |
/// | −1 | 0008 recognition 4 |
/// | 0 | 0001 recognition 3 |
MemoryProgress knownLog(DateTime now) {
  final progress = MemoryProgress();
  final today = dateOnly(now);
  void at(int day, String card, DrillMode mode, int grade) => progress.record(
    deckId: 'es-en-core-100',
    cardId: 'es-$card',
    mode: mode,
    grade: grade,
    now: addDays(today, day).add(const Duration(hours: 9)),
  );
  const r = DrillMode.recognition;
  const p = DrillMode.production;
  at(-100, '0009', r, 4);
  at(-40, '0001', r, 4);
  at(-20, '0001', p, 1);
  at(-20, '0006', r, 5);
  at(-3, '0006', p, 2);
  at(-3, '0007', r, 4);
  at(-2, '0007', r, 4);
  at(-1, '0008', r, 4);
  at(0, '0001', r, 3);
  return progress;
}

// From stats_page_test.dart.
/// The gallery's history: twelve days ending yesterday, 22 reviews in each
/// of es-en-core-100 and mr-en-script-consonants (12 recognition, all
/// remembered; 10 production on one leech, half remembered).
Future<AppState> fixture({FeatureRegistry? features}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(
    app,
    features: features ?? FeatureRegistry.all(),
  );
}

// From word_mastery_test.dart.
/// [grades] for [card], a day apart from [start], in alternating skills.
void answer(
  MemoryProgress progress,
  String card,
  List<int> grades, {
  DateTime? start,
}) {
  final from = start ?? DateTime(2026, 9, 1);
  for (final (i, grade) in grades.indexed) {
    progress.record(
      deckId: 'xx-deck',
      cardId: card,
      mode: i.isEven ? DrillMode.recognition : DrillMode.production,
      grade: grade,
      now: from.add(Duration(days: i)),
    );
  }
}

/// [grades] for [card] in [mode], a minute apart, so that each right answer
/// is at nearly full recall.
void minutesApart(
  MemoryProgress progress,
  String card,
  List<int> grades, {
  DrillMode mode = DrillMode.recognition,
}) {
  for (final (i, grade) in grades.indexed) {
    progress.record(
      deckId: 'xx-deck',
      cardId: card,
      mode: mode,
      grade: grade,
      now: DateTime(2026, 9, 1).add(Duration(minutes: i)),
    );
  }
}

// From unit_page_test.dart.
/// The design's Telugu learner, with Family under way.
Future<AppState> teluguLearner({String upTo = PathFixtures.familyDeck}) async {
  final app = AppState.test();
  await app.load();
  return PathFixtures.state(app, upTo: upTo);
}

/// The same learner, who also knows Telugu and reads its script, and
/// reviews it (#525): the one who is offered Review.
Future<AppState> teluguReviewer() async {
  final app = await teluguLearner();
  app.settings
    ..spokenLanguages = const <String>['en', 'te']
    ..scriptsRead = const <String, bool>{'en': true, 'te': true}
    ..reviewLanguages = const <String>{'te'};
  return app;
}

/// A phone tall enough for the unit's lazy list to build every row.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
}

final Finder downward = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// A course of one unit: a word whose partner sounds almost the same and
/// is rude, the partner, and a phrase.
MemoryDeckSource tinyCourse() => MemoryDeckSource(const <String, String>{
  'decks/es/es-en-tiny.yaml': '''
schema: 1
id: es-en-tiny
name: Tiny
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-9001
    target: "gato"
    native: "cat"
    ipa: "ˈɡato"
    notes: "A plain note."
    pair: "es-9002"
  - id: es-9002
    target: "gatu"
    native: "a rude word"
    tags: ["offensive"]
  - id: es-9003
    target: "buenos días a todos"
    native: "good morning, everyone"
    pos: "phrase"
''',
  'decks/es/es-path.yaml': '''
schema: 1
kind: path
id: es-path
language: es
units:
  - [es-tiny]
''',
});

// From deck_status_test.dart.
const String tiny = 'es-en-tiny';

/// Two cards, drilled by sight and typed: no voice in tests.
AppState tinyState({
  SettingsNotifier? settings,
  ProgressStore? progress,
  DateTime? now,
}) => AppState.test(
  decks: MemoryDeckSource(<String, String>{
    'decks/es/$tiny.yaml':
        '''
schema: 1
id: $tiny
name: "Tiny"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: $tiny-0001, target: "hola", native: "hello" }
  - { id: $tiny-0002, target: "adiós", native: "goodbye" }
''',
  }),
  settings: settings,
  progress: progress,
  now: now,
);

/// Learns every word in [deckId], in every skill.
void learnAll(AppState state, String deckId) {
  final request = DrillRequest.untaught(deckId);
  while (state.buildSession(request).fresh.isNotEmpty) {
    for (final item in state.buildSession(request).fresh) {
      state.record(item, 5);
    }
  }
}

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

DeckBadgeKind badgeOf(AppState state, String deckId) =>
    DeckBadge.forEntry(state, state.deckById(deckId)!).kind;

// From deck_detail_page_test.dart.
const String spanish = 'es-en-core-100';
const String vowels = 'hi-en-script-vowels';
const String grammar = 'es-en-grammar-present-ar';

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
/// refreshed only on purpose, with tools/snapshot_ask_pin.py, and then these
/// numbers are updated with it. The other tests read the live decks.
final DeckSource frozenDecks = RepositoryDeckSource('test/fixtures/ask_pin');

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

// From path_model_test.dart.
/// What the Decks tab reads out of a course's path: units and their status,
/// what each teaches, milestones, and levels where a plan marks them.

Future<AppState> loaded([AppState? state]) async {
  final s = state ?? AppState.test();
  await s.load();
  return s;
}

/// The Telugu learner of the design, on the bundled decks.
Future<AppState> telugu({String upTo = PathFixtures.familyDeck}) async {
  final app = await loaded();
  return loaded(PathFixtures.state(app, upTo: upTo));
}

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

// From language_catalog_test.dart.
/// The language picker's catalog (#211, `docs/plans/language-picker.md`):
/// completeness toward B1 from a path's plan, the Alpha and Beta stages,
/// search, and the picker's order. No Flutter: these run in milliseconds.

B1Unit written(int has, {int? words, Milestone? milestone, List<String>? g}) =>
    B1Unit(
      has: has,
      words: words,
      milestone: milestone,
      grammar: g ?? const <String>[],
    );

B1Unit planned(int words, {Milestone? milestone, List<String>? g}) => B1Unit(
  planned: true,
  words: words,
  milestone: milestone,
  grammar: g ?? const <String>[],
);

CatalogLanguage language(
  String code,
  String name, {
  String? own,
  List<String> natives = const <String>['en'],
}) => CatalogLanguage(
  code: code,
  name: name,
  ownName: own,
  natives: <CatalogNative>[
    for (final n in natives)
      (code: n, name: n, progress: B1Progress.of(const <B1Unit>[])),
  ],
);

// From script_skills_test.dart.
/// Reading and writing the script are skills of their own (#556; owner,
/// 2026-10-17: "Both" and "Rebuild from the log"): the answers to the script
/// decks count for the word skills as today and, in full, for Read script and
/// Write script, which are worked out from the log.

// From script_skills_per_script_test.dart.
/// Each script a course is learned in has a Read and a Write of its own
/// (#653; owner, 2026-10-19: "Yes, per script."): Hindustani has Devanagari
/// and Perso-Arabic Read and Write. Read is fed by the script decks'
/// Recognition, by choosing script text, and by reading a word for its
/// meaning; Write by the script decks' Write and by typing in the script.
/// Outside the script decks an answer counts for half a review; shown or
/// typed in transliteration, it feeds none.

// From study_hours_test.dart.
final DateTime t0 = DateTime.utc(2026, 10, 1);

FsrsState stateWith(int intervalDays, {double stability = 2}) => FsrsState(
  stability: stability,
  difficulty: 5,
  intervalDays: intervalDays,
  dueAt: t0.add(Duration(days: intervalDays)),
  lastReviewAt: t0,
);

// From how_you_learn_page_test.dart.
/// The pace How you learn shows for Hindi [mode].
SkillPace paceOf(AppState state, DrillMode mode) =>
    state.pacing.paces![(language: 'hi', mode: mode)]!;

/// The verdict label's background, around [text].
Color? verdictColour(WidgetTester tester, String text) {
  final box = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color;
}

Future<void> scrollToHowYouLearnPage(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

/// What How you learn says of an adjusted skill: its sentence, its
/// verdict and its 30 days, worked out from [pace] as the page words it.
void expectAdjusted(
  WidgetTester tester,
  AppLocalizations l10n,
  SkillPace pace,
  String verdict,
) {
  final mode = pace.key.mode.name;
  final start = pace.start;
  final now = pace.now;
  expect(
    find.text(
      now.days == start.days
          ? l10n.paceComesBackSame(mode, now.days)
          : l10n.paceComesBack(mode, now.days, start.days),
    ),
    findsOneWidget,
  );
  expect(find.text(verdict), findsOneWidget);
  expect(
    find.text(
      now.reviews == start.reviews
          ? l10n.paceReviewsSteady(now.reviews)
          : l10n.paceReviews(now.reviews, start.reviews),
    ),
    findsOneWidget,
  );
}

// From pace_test.dart.
/// [skill]'s name on its tile.
Finder nameOf(WidgetTester tester, Skill skill) => find.descendant(
  of: find.byType(DueCard),
  matching: find.text(skill.label(l10nOf(tester))),
);

/// The mark on [skill]'s tile, if any.
Finder markOn(WidgetTester tester, Skill skill) => find.descendant(
  of: find
      .ancestor(of: nameOf(tester, skill), matching: find.byType(Material))
      .first,
  matching: find.byType(PaceMark),
);

Future<AppState> onToday(
  WidgetTester tester,
  Paced paced, {
  Set<Paced> also = const <Paced>{},
  double textScale = 1.0,
  PaceRunner paceRunner = paceInPlace,
}) async {
  usePhone(tester, textScale: textScale);
  final state = await pacedLearner(paced, also: also, paceRunner: paceRunner);
  await pumpScreen(tester, const TodayPage(), state: state);
  await tester.ensureVisible(find.byType(DueCard));
  await tester.pumpAndSettle();
  return state;
}

// From leeches_page_test.dart.
Future<AppState> fixtureLeechesPage({
  FeatureRegistry? features,
  bool history = true,
}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(
    app,
    features: features ?? FeatureRegistry.all(),
    history: history,
  );
}

/// The first fixture leech: la leche, es-en-core-100, production, 5 lapses.
Finder firstCard() => find.byType(LeechCard).first;

Finder inFirst(Finder f) => find.descendant(of: firstCard(), matching: f);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the numbers', () {
    late AppState app;
    late CardLookup cardOf;
    late MemoryProgress progress;
    setUpAll(() async {
      app = AppState.test();
      await app.load();
      cardOf = cardLookupOf(app);
    });
    setUp(() => progress = knownLog(app.now()));

    StatsNumbers numbers(StatsRange range) =>
        StatsNumbers.of(progress, now: app.now(), range: range, cardOf: cardOf);

    test('7 days, 30 days and all time: each widens every number', () {
      final n = numbers(StatsRange.week);
      expect(n.reviews, 5);
      expect(n.remembered, 4 / 5);
      expect(n.streak, 4);
      expect(n.learned, 2, reason: '0011 and 0012 were first remembered');
      expect(n.bySkill.keys, <Skill>[Skill.recognition, Skill.production]);
      expect(n.bySkill[Skill.recognition]!.ratio, 1.0);
      expect(n.bySkill[Skill.production]!.ratio, 0.0);
      // Weakest tags are of what is known now, whatever the range: of the
      // five home pairs only 0007 (two days running) is known; neither
      // people pair is.
      expect(n.weakestTags.keys, <String>['people', 'home']);
      expect(n.weakestTags['home']!.correct, 1);
      expect(n.weakestTags['home']!.total, 5);
      expect(n.weakestTags['people']!.ratio, 0.0);

      final month = numbers(StatsRange.month);
      expect(month.reviews, 7);
      expect(month.remembered, 5 / 7);
      expect(month.learned, 3);

      final all = numbers(StatsRange.all);
      expect(all.reviews, 9);
      expect(all.remembered, 7 / 9);
      expect(all.learned, 5);
      expect(all.longestStreak, 4);
      expect(all.bySkill[Skill.production]!.ratio, 0.0);
      expect(all.weakestTags.keys, n.weakestTags.keys);
      expect(all.weakestTags['home']!.ratio, 1 / 5);
    });

    test('a card remembered in two decks is learned once; one language counts '
        'its own reviews and streak', () {
      final progress = MemoryProgress();
      for (final (i, deck) in <String>[
        'es-en-core-100',
        'es-en-other',
      ].indexed) {
        progress.record(
          deckId: deck,
          cardId: 'es-0001',
          mode: DrillMode.values[i],
          grade: 5,
          now: addDays(app.now(), -1 - i),
        );
      }
      final n = StatsNumbers.of(
        progress,
        now: app.now(),
        range: StatsRange.week,
        cardOf: cardOf,
      );
      expect(n.reviews, 2);
      expect(n.learned, 1);

      {
        // The group's log of known Spanish reviews, beside which Hindi goes.
        final progress = knownLog(app.now());
        final languageOf = languageLookupOf(app);

        /// A Hindi review on each of [days], counted from today, beside the
        /// Spanish log.
        void addHindi(MemoryProgress progress, List<int> days) {
          final deck = app.deckById('hi-en-script-vowels')!;
          for (final day in days) {
            progress.record(
              deckId: deck.id,
              cardId: deck.cards.first.id,
              mode: DrillMode.recognition,
              grade: 4,
              now: addDays(
                dateOnly(app.now()),
                day,
              ).add(const Duration(hours: 9)),
            );
          }
        }

        StatsNumbers numbersIn(String? code) => StatsNumbers.of(
          progress,
          now: app.now(),
          range: StatsRange.week,
          cardOf: cardOf,
          deckFilter: code == null ? null : (deck) => languageOf(deck) == code,
        );

        addHindi(progress, <int>[-6, -5]);
        final spanish = numbersIn('es');
        expect(spanish.reviews, 5);
        expect(spanish.streak, 4);
        expect(spanish.heatmapReviews, 8);

        final hindi = numbersIn('hi');
        expect(hindi.reviews, 2);
        expect(hindi.remembered, 1.0);
        expect(hindi.streak, 0, reason: 'nothing since five days ago');
        expect(hindi.learned, 1);
        expect(hindi.weakestTags.keys, isNot(contains('home')));
        expect(hindi.heatmapReviews, 2);

        final all = numbersIn(null);
        expect(all.reviews, 7);
        expect(all.streak, 4);
        expect(all.heatmapReviews, 10);
      }
    });

    test('a leech is a pair at or over the threshold, found in the states', () {
      for (var i = 0; i < kLeechThreshold; i++) {
        progress
          ..record(
            deckId: 'es-en-core-100',
            cardId: 'es-0002',
            mode: DrillMode.production,
            grade: 4,
            now: app.now(),
          )
          ..record(
            deckId: 'es-en-core-100',
            cardId: 'es-0002',
            mode: DrillMode.production,
            grade: 1,
            now: app.now(),
          );
      }
      final leeches = findLeeches(progress, cardOf: cardOf);
      expect(leeches.map((l) => l.card.id), <String>['es-0002']);
      expect(leeches.single.lapses, kLeechThreshold);
      expect(
        findLeeches(progress, cardOf: cardOf, threshold: kLeechThreshold + 1),
        isEmpty,
      );
    });
  });

  group('Progress', () {
    testWidgets('with no reviews it says so', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const StatsPage(),
        state: AppState.test(features: FeatureRegistry.all()),
      );
      expect(find.text(l10nOf(tester).statsNoReviews), findsOneWidget);
    });
  });

  group('streaks and words learned', () {
    final monday = DateTime(2026, 9, 28, 19);

    ReviewEvent answer(
      MemoryProgress progress,
      String card,
      int grade, {
      DateTime? at,
      DrillMode mode = DrillMode.recognition,
      String deck = 'es-en-core-100',
    }) => progress.record(
      deckId: deck,
      cardId: card,
      mode: mode,
      grade: grade,
      now: at ?? monday,
    );

    group('streak', () {
      MemoryProgress onDays(List<int> daysAgo) {
        final progress = MemoryProgress();
        for (final d in daysAgo) {
          answer(progress, 'c$d', 5, at: monday.subtract(Duration(days: d)));
        }
        return progress;
      }

      test('a streak counts consecutive days ending today, across a daylight '
          'saving change', () {
        expect(onDays([0, 1, 2]).streakAt(monday), 3);

        expect(addDays(DateTime(2026, 10, 24, 12), 1), DateTime(2026, 10, 25));
        expect(dateOnly(DateTime(2026, 9, 28, 23, 59)), DateTime(2026, 9, 28));
        expect(
          isSameDay(DateTime(2026, 9, 28), DateTime(2026, 9, 28, 23)),
          isTrue,
        );
      });
    });

    test('learned counts distinct cards remembered at least once', () {
      final progress = MemoryProgress();
      answer(progress, 'a', 5);
      answer(progress, 'a', 5, mode: DrillMode.production);
      answer(progress, 'b', 1);
      answer(progress, 'c', 4, deck: 'hi-en-script-vowels');
      expect(progress.learnedIn(<String>['a', 'b']), 1);
      expect(progress.learnedIn(<String>['c']), 1);
      // A card is learned in every deck that lists it (ADR-0018).
      expect(progress.learnedIn(<String>['c', 'd']), 1);
    });
  });

  group('Known, Learning and New', () {
    test('known is the Progress star\'s known: the last review in every skill '
        'was right and FSRS gave it 85% recall; a later miss makes it '
        'learning again', () {
      final progress = MemoryProgress();
      // Right every time, a minute apart: recall is near certain.
      minutesApart(progress, 'xx-0001', [1, 1, 1, 4, 4, 4]);
      // Right in one skill, missed in the other: not known.
      minutesApart(progress, 'xx-0002', [4, 4], mode: DrillMode.recognition);
      minutesApart(progress, 'xx-0002', [4, 1], mode: DrillMode.production);
      // Right, but 400 days after the last review: recall has gone.
      progress.record(
        deckId: 'xx-deck',
        cardId: 'xx-0003',
        mode: DrillMode.recognition,
        grade: 4,
        now: DateTime(2026, 9, 1),
      );
      progress.record(
        deckId: 'xx-deck',
        cardId: 'xx-0003',
        mode: DrillMode.recognition,
        grade: 4,
        now: DateTime(2027, 10, 5),
      );
      // One review is no recall to measure yet.
      minutesApart(progress, 'xx-0004', [4]);
      final answers = RecentAnswers(progress.log);
      expect(answers.of('xx-0001').level, MasteryLevel.known);
      expect(answers.of('xx-0001').share, 1.0);
      expect(answers.of('xx-0002').level, MasteryLevel.learning);
      expect(answers.of('xx-0002').share, closeTo(0.5, 1e-9));
      expect(answers.of('xx-0003').level, MasteryLevel.learning);
      expect(answers.of('xx-0004').level, MasteryLevel.learning);
      expect(answers.of('xx-0005').level, MasteryLevel.fresh);
      // The first right answer, not the first answer.
      expect(answers.firstPassed('xx-0001'), DateTime(2026, 9, 1, 0, 3));
    });
  });

  group('a unit', () {
    testWidgets(
      'each word is Known, Learning or New; Review with reviewing off says '
      'to turn it on',
      (tester) async {
        useTallPhone(tester);
        final state = await pumpScreen(
          tester,
          const UnitPage(deckId: 'te-en-directions'),
          state: await teluguLearner(upTo: 'te-en-directions'),
        );
        final l10n = l10nOf(tester);
        final content = UnitContent(
          unitOfDeck(state, 'te-en-directions')!.decks,
        );
        final answers = RecentAnswers(state.progress.log);
        final known = content.words
            .where((c) => answers.of(c.id).level == MasteryLevel.known)
            .length;
        expect(known, greaterThan(0));
        expect(
          find.text(l10n.unitFraction('$known', '${content.words.length}')),
          findsOneWidget,
        );
        expect(find.text(l10n.unitWordsKnown), findsOneWidget);
        expect(find.text(l10n.unitRulesKnown), findsOneWidget);
        expect(find.text(l10n.unitSentencesOpen), findsOneWidget);
        expect(find.text(l10n.unitKnownMeans(85)), findsOneWidget);

        // The first six words, then all of them.
        final chips = find.byType(MasteryChip);
        final shownFirst = tester.widgetList(chips).length;
        expect(
          tester
              .widgetList<MasteryChip>(chips)
              .take(6)
              .map((c) => c.mastery.level),
          [for (final c in content.words.take(6)) answers.of(c.id).level],
        );
        await tester.scrollUntilVisible(
          find.text(l10n.unitShowAll(content.words.length)),
          200,
          scrollable: downward.first,
        );
        await tester.tap(find.text(l10n.unitShowAll(content.words.length)));
        await tester.pumpAndSettle();
        expect(tester.widgetList(chips).length, greaterThan(shownFirst));
        expect(find.text(l10n.unitShowFewer), findsOneWidget);
        // Some are still being learned, and some are new.
        final levels = <MasteryLevel>{
          for (final c in content.words) answers.of(c.id).level,
        };
        expect(levels, containsAll(MasteryLevel.values));
        expect(find.textContaining(RegExp(r'^Learning \d+%$')), findsWidgets);

        {
          usePhone(tester);
          final state = await pumpScreen(
            tester,
            const UnitPage(deckId: 'te-en-family'),
            state: await teluguReviewer(),
          );
          final l10n = l10nOf(tester);
          await tester.tap(find.text(l10n.unitReview));
          await tester.pumpAndSettle();
          expect(find.text(l10n.reviewFirstTitle), findsOneWidget);
          expect(find.text(l10n.reviewFirstBody('Telugu')), findsOneWidget);
          await tester.tap(find.text(l10n.reviewFirstNotNow));
          await tester.pumpAndSettle();
          expect(find.text(l10n.reviewFirstTitle), findsNothing);
          expect(state.shellTab.value, isNot(ShellTab.settings));

          await tester.tap(find.text(l10n.unitReview));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.reviewFirstOpenSettings));
          await tester.pumpAndSettle();
          expect(state.shellTab.value, ShellTab.settings);
        }
      },
    );

    testWidgets(
      'Continue reviews what is due, else teaches the next words, else is '
      'off',
      (tester) async {
        usePhone(tester);
        final state = await pumpScreen(
          tester,
          const UnitPage(deckId: 'te-en-family'),
          state: await teluguLearner(),
        );
        final l10n = l10nOf(tester);
        final ids = <String>{'te-en-family'};
        final due = state.buildSession(DrillRequest(deckIds: ids)).due.length;
        expect(due, greaterThan(0));
        final fresh = state
            .lessonFor(
              DrillRequest.lesson(language: 'te', deckId: 'te-en-family'),
            )
            .where((item) => item.ask == Ask.teach)
            .length;
        expect(fresh, greaterThan(0));
        final continueButton = find.text(l10n.unitContinue(fresh, due));
        expect(continueButton, findsOneWidget);
        await tester.tap(continueButton);
        await tester.pumpAndSettle();
        final drill = tester.widget<DrillPage>(find.byType(DrillPage));
        expect(drill.request.deckIds, <String>{'te-en-family'});
        expect(drill.request.lesson, isFalse);

        {
          usePhone(tester);
          await pumpScreen(
            tester,
            const UnitPage(deckId: 'te-en-family'),
            state: AppState.test(),
          );
          final l10n = l10nOf(tester);
          final label = tester
              .widget<Text>(find.textContaining(RegExp(r'^Continue')))
              .data!;
          expect(label, endsWith(l10n.unitContinue(0, 0).split(', ').last));
          await tester.tap(find.textContaining(RegExp(r'^Continue')));
          await tester.pumpAndSettle();
          final drill = tester.widget<DrillPage>(find.byType(DrillPage));
          expect(drill.request.lesson, isTrue);
          expect(drill.request.deckIds, <String>{'te-en-family'});
        }

        {
          usePhone(tester);
          final progress = MemoryProgress();
          final state = AppState.test(decks: tinyCourse(), progress: progress);
          await state.load();
          for (final card in state.deckById('es-en-tiny')!.cards) {
            for (final mode in card.modesIn(ttsAvailable: false)) {
              progress.record(
                deckId: 'es-en-tiny',
                cardId: card.id,
                mode: mode,
                grade: 4,
                now: state.now(),
              );
            }
          }
          await pumpScreen(
            tester,
            const UnitPage(deckId: 'es-en-tiny'),
            state: state,
          );
          final l10n = l10nOf(tester);
          expect(find.text(l10n.unitNothingLeft), findsOneWidget);
          final button = tester.widget<FilledButton>(
            find.ancestor(
              of: find.text(l10n.unitNothingLeft),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            ),
          );
          expect(button.onPressed, isNull);
        }
      },
    );
  });

  group('a deck\'s status', () {
    test('a deck is Done once every card is learned in every skill on, and '
        'says how many are due again when they are', () async {
      final state = tinyState();
      addTearDown(state.dispose);
      await state.load();
      final entry = state.deckById(tiny)!;
      expect(state.notStudiedIn(entry), 2);

      // Learned by sight only: production is still to learn. Its course's only
      // deck, so it is the unit Today teaches.
      for (final item in state.buildSession(DrillRequest.deck(tiny)).items) {
        state.record(item, 5);
      }
      expect(badgeOf(state, tiny), DeckBadgeKind.pending);

      learnAll(state, tiny);
      expect(state.notStudiedIn(entry), 0);
      expect(badgeOf(state, tiny), DeckBadgeKind.done);

      final later = tinyState(
        progress: state.progress,
        now: state.now().add(const Duration(days: 8)),
      );
      addTearDown(later.dispose);
      await later.load();
      final badge = DeckBadge.forEntry(later, later.deckById(tiny)!);
      expect(badge.kind, DeckBadgeKind.due);
      expect(badge.count, 2);
    });

    testWidgets(
      'a finished deck offers Relearn, and Practice records every answer',
      (tester) async {
        usePhone(tester);
        final state = tinyState();
        await state.load();
        learnAll(state, tiny);
        await pumpScreen(
          tester,
          const DeckDetailPage(deckId: tiny),
          state: state,
        );
        final l10n = l10nOf(tester);

        // Every word is taught: + Learn has become Relearn, with no badge.
        expect(find.text(l10n.deckLearn), findsNothing);
        expect(find.text(l10n.deckRelearn), findsOneWidget);
        expect(find.byType(Badge), findsNothing);
        await tester.tap(find.text(l10n.deckPractice));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.deckPracticeStart));
        await tester.pumpAndSettle();
        expect(find.byType(DrillPage), findsOneWidget);
        // Titled with the deck, not as number practice.
        expect(find.text('Tiny'), findsOneWidget);

        final logged = state.progress.log.length;
        final states = Map.of(state.progress.states);
        // Recognition comes first (ADR-0034), rated with only two cards to
        // choose among.
        await tester.tap(find.text(l10n.drillShowAnswer));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.rateGood));
        await tester.pumpAndSettle();
        expect(state.progress.log, hasLength(logged + 1));
        expect(state.progress.states, isNot(states));

        // Ending part-way says the answers so far are recorded (ADR-0033).
        await tester.tap(find.byTooltip(l10n.drillEndSession));
        await tester.pumpAndSettle();
        expect(find.text(l10n.drillEndBody), findsOneWidget);
        expect(find.text(l10n.drillEndBodyNotRecorded), findsNothing);
      },
    );
  });

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
      'Relearn waits for every card of the deck, not just those in view',
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

        // The words in view are taught, but "casa" is not: + Learn stays,
        // with nothing in view left to teach.
        expect(find.text(l10n.deckRelearn), findsNothing);
        expect(find.text(l10n.deckLearn), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text(l10n.deckLearn),
                  matching: find.byWidgetPredicate((w) => w is FilledButton),
                ),
              )
              .onPressed,
          isNull,
        );

        learnTagged(state, 'es-en-tagged', const <String>{'home'});
        await tester.pumpAndSettle();
        expect(find.text(l10n.deckRelearn), findsOneWidget);
        expect(find.text(l10n.deckLearn), findsNothing);
        expect(find.byType(Badge), findsNothing);
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
      '+ Learn counts the words in view not taught, and teaches those',
      (tester) async {
        usePhone(tester);
        final state = await pumpDeck(tester, spanish);
        final l10n = l10nOf(tester);
        final all = state.untaughtCards('es', deckId: spanish).length;
        Finder badge(int n) =>
            find.descendant(of: find.byType(Badge), matching: find.text('$n'));
        expect(all, greaterThan(2));
        expect(badge(all), findsOneWidget);

        await tapVisible(tester, find.widgetWithText(FilterChip, 'food'));
        final food = state
            .untaughtCards('es', deckId: spanish, tags: const {'food'})
            .length;
        expect(food, inExclusiveRange(0, all));
        expect(badge(food), findsOneWidget);

        await tester.tap(find.text(l10n.deckLearn));
        await tester.pumpAndSettle();
        final request = tester
            .widget<DrillPage>(find.byType(DrillPage))
            .request;
        expect(request.lesson, isTrue);
        expect(request.deckIds, <String>{spanish});
        expect(request.tags, <String>{'food'});
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
        expect(
          find.bySemanticsLabel(
            RegExp('^Work, unit 22, ${l10n.pathUnitAhead}'),
          ),
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

        {
          usePhone(tester);
          await pumpDecks(tester, state: await teluguLearnerDecksPage());
          final l10n = l10nOf(tester);
          await tester.drag(downward.first, const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(onScreen(tester, find.text(l10n.pathUpNext)), isFalse);
          await tester.tap(fab('where-i-am'));
          await tester.pumpAndSettle();
          expect(onScreen(tester, find.text(l10n.pathUpNext)), isTrue);
        }
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
      'lists each sound of the word\'s IPA, in order, from the IPA course, '
      'each with its practice',
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
        expect(find.text(l10n.cardIpaHeading), findsOneWidget);
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

  group('toward B1', () {
    test('a path\'s own words per level are the words B1 holds, else the sum '
        'of its units up to B1', () {
      const units = <PlanUnit>[
        PlanUnit(words: 5, milestone: Milestone.a1),
        PlanUnit(words: 5, milestone: Milestone.a2),
        PlanUnit(words: 5, milestone: Milestone.b1),
        PlanUnit(words: 500),
      ];
      CoursePath path(Map<Milestone, int>? levels) => CoursePath(
        id: 'zz-path',
        language: 'zz',
        native: 'en',
        units: const <List<String>>[],
        plan: units,
        levels: levels,
      );
      expect(path(null).plannedWords, 15);
      expect(
        path(<Milestone, int>{
          Milestone.a1: 120,
          Milestone.a2: 60,
          Milestone.b1: 80,
        }).plannedWords,
        260,
      );
    });

    group('completeness toward B1', () {
      test(
        'completeness is the words written over the words planned, up to B1, '
        'and the stage is Alpha, Beta, then Complete',
        () {
          final p = B1Progress.of(<B1Unit>[
            written(30, words: 40, milestone: Milestone.a1),
            written(20, words: 20, milestone: Milestone.a2),
            planned(40, milestone: Milestone.b1),
            // After B1: not counted.
            written(500, words: 500),
          ]);
          expect(p.hasPlan, isTrue);
          expect(p.plannedWords, 100);
          expect(p.writtenWords, 50);
          expect(p.percent, 50);

          {
            final p = B1Progress.of(<B1Unit>[
              written(10, words: 10),
              planned(10, milestone: Milestone.a1),
              planned(10, milestone: Milestone.b1),
            ]);
            expect(p.stage, CourseStage.alpha);
          }

          {
            final p = B1Progress.of(<B1Unit>[
              written(10, words: 10, milestone: Milestone.a1),
              planned(10, milestone: Milestone.a2),
              planned(10, milestone: Milestone.b1),
            ]);
            expect(p.stage, CourseStage.beta);
          }

          expect(
            B1Progress.of(<B1Unit>[
              written(5),
              written(5),
            ], isNotation: true).stage,
            CourseStage.complete,
          );
          expect(
            B1Progress.of(<B1Unit>[
              written(5),
              planned(5),
            ], isNotation: true).stage,
            CourseStage.alpha,
          );
          // Braille's path: six units written and the open last one, for decks
          // a learner adds and the contractions to come (ADR-0043).
          expect(
            B1Progress.of(<B1Unit>[
              for (var i = 0; i < 6; i++) written(10),
              const B1Unit(),
            ], isNotation: true).stage,
            CourseStage.complete,
          );
          expect(B1Progress.of(<B1Unit>[written(5)]).stage, CourseStage.alpha);
        },
      );
    });

    group('search', () {
      final hindi = language('hi', 'Hindi', own: 'हिन्दी');
      final marathi = language('mr', 'Marathi', own: 'मराठी');
      final spanish = language('es', 'Spanish', own: 'Español');
      final telugu = language('te', 'Telugu', own: 'తెలుగు');
      final all = <CatalogLanguage>[hindi, marathi, spanish, telugu];
      List<String> codes(String q) => <String>[
        for (final l in all)
          if (LanguageSearch.matches(l, q)) l.code,
      ];

      test(
        'search matches English names, and own names with accents ignored',
        () {
          expect(codes('hi'), <String>['hi', 'mr']);
          expect(codes('TELU'), <String>['te']);

          expect(codes('espanol'), <String>['es']);
          expect(codes('Español'), <String>['es']);
          expect(codes('తెలు'), <String>['te']);
        },
      );
    });
  });

  group('the script skills', () {
    final day = DateTime(2026, 10, 1, 9);
    const script = 'hi-script-vowels';
    const words = 'hi-first-words';
    const map = SkillMap(
      formHeardIn: <String>{script},
      scriptDecks: <String>{script},
      primaryScripts: <String, String>{'hi': 'devanagari'},
    );

    // Script-deck answers from before the script was kept per answer count
    // for the course's primary script (#653).
    const read = (
      cardId: 'hi-0001',
      mode: DrillMode.readScript,
      script: 'devanagari',
    );
    const write = (
      cardId: 'hi-0001',
      mode: DrillMode.writeScript,
      script: 'devanagari',
    );
    const recognition = (cardId: 'hi-0001', mode: DrillMode.recognition);

    LoggedReview review(
      DrillMode mode,
      int grade,
      DateTime at, {
      String deck = script,
      String card = 'hi-0001',
    }) => (
      key: (cardId: card, mode: mode),
      deckId: deck,
      at: at,
      grade: grade,
      elapsed: Duration.zero,
      answerGiven: mode == DrillMode.recognition ? null : 'x',
      script: null,
      asked: null,
    );

    group('rebuilt from the log', () {
      final log = <LoggedReview>[
        review(DrillMode.recognition, 4, day),
        review(DrillMode.production, 3, day.add(const Duration(hours: 1))),
        review(DrillMode.recognition, 5, day.add(const Duration(days: 3))),
        review(DrillMode.recognition, 3, day, deck: words, card: 'hi-0002'),
      ];

      test(
        'script-deck answers give Read and Write states of their own; a word '
        'deck feeds no script skill',
        () {
          final replayed = replayReviews(log, skills: map);
          expect(replayed.scriptStates.keys.toSet(), {read, write});
          expect(replayed.scriptStates[read]!.repetitions, 2);
          expect(replayed.scriptStates[write]!.repetitions, 1);
          expect(replayed.scriptEvents, hasLength(3));
          expect(replayed.scriptEvents.first.mode, DrillMode.readScript);
          expect(replayed.scriptEvents.first.wasNew, isTrue);
          expect(replayed.scriptEvents.last.before, isNotNull);

          {
            final replayed = replayReviews(<LoggedReview>[
              review(DrillMode.recognition, 4, day, deck: words),
            ], skills: map);
            expect(replayed.scriptStates, isEmpty);
          }
        },
      );

      test('each skill is scheduled with its own fit', () {
        final fitted = FittedParameters(
          values: <double>[
            for (final (i, w) in Fsrs.w.indexed) i == 8 ? w + 0.6 : w,
          ],
          fittedAt: day,
          reviewCount: 30,
        );
        final parameters = SkillParameters(
          fitted: <SkillKey, FittedParameters>{
            (language: 'hi', mode: DrillMode.readScript): fitted,
          },
        );
        final replayed = replayReviews(
          log,
          skills: map,
          parameters: parameters,
        );
        final plain = replayReviews(log, skills: map);
        expect(
          replayed.scriptStates[read]!.stability,
          isNot(plain.scriptStates[read]!.stability),
        );
        expect(
          replayed.scriptStates[write]!.stability,
          plain.scriptStates[write]!.stability,
        );
        expect(
          replayed.states[recognition]!.stability,
          plain.states[recognition]!.stability,
        );
      });
    });
  });

  group('the script skills per script', () {
    const devanagari = 'devanagari';
    const persoArabic = 'perso_arabic';
    const letters = 'hi-en-letters';
    const words = 'hi-en-words';
    const map = SkillMap(
      formHeardIn: <String>{letters},
      scriptDecks: <String>{letters},
      primaryScripts: <String, String>{'hi': devanagari},
    );
    final day = DateTime(2026, 10, 1, 9);

    LoggedReview review(
      DrillMode mode, {
      String deck = words,
      String card = 'hi-0001',
      int grade = 4,
      DateTime? at,
      String? script,
      Ask? asked,
    }) => (
      key: (cardId: card, mode: mode),
      deckId: deck,
      at: at ?? day,
      grade: grade,
      elapsed: Duration.zero,
      answerGiven: mode == DrillMode.recognition ? null : 'x',
      script: script,
      asked: asked,
    );

    group('replayed per script', () {
      test(
        'one word read in both scripts has a Read of each; an answer elsewhere '
        'is half a review, one in a script deck a whole one',
        () {
          final replayed = replayReviews(<LoggedReview>[
            review(DrillMode.recognition, script: devanagari, asked: Ask.own),
            review(
              DrillMode.recognition,
              script: persoArabic,
              asked: Ask.own,
              at: day.add(const Duration(days: 1)),
            ),
            review(
              DrillMode.production,
              script: persoArabic,
              asked: Ask.own,
              at: day.add(const Duration(days: 2)),
            ),
          ], skills: map);
          expect(replayed.scriptStates.keys.toSet(), <ScriptKey>{
            (cardId: 'hi-0001', mode: DrillMode.readScript, script: devanagari),
            (
              cardId: 'hi-0001',
              mode: DrillMode.readScript,
              script: persoArabic,
            ),
            (
              cardId: 'hi-0001',
              mode: DrillMode.writeScript,
              script: persoArabic,
            ),
          });
          expect(replayed.scriptEvents.map((e) => e.share), <double>[
            0.5,
            0.5,
            0.5,
          ]);
          expect(replayed.scriptEvents.map((e) => e.script), <String>[
            devanagari,
            persoArabic,
            persoArabic,
          ]);

          final half = replayReviews(<LoggedReview>[
            review(DrillMode.recognition, script: devanagari, asked: Ask.own),
          ], skills: map);
          final whole = replayReviews(<LoggedReview>[
            review(
              DrillMode.recognition,
              deck: letters,
              script: devanagari,
              asked: Ask.own,
            ),
          ], skills: map);
          const key = (
            cardId: 'hi-0001',
            mode: DrillMode.readScript,
            script: devanagari,
          );
          expect(
            half.scriptStates[key]!.stability,
            closeTo(whole.scriptStates[key]!.stability / 2, 1e-9),
          );
        },
      );
    });

    group('kept in the log', () {
      test(
        'a backup keeps the script an answer was in, and Progress shows Read '
        'and Write per script',
        () {
          final text = LogJsonl.encode(<LoggedReview>[
            review(
              DrillMode.production,
              script: persoArabic,
              asked: Ask.rearrange,
            ),
            review(DrillMode.recognition),
          ], const []);
          final back = LogJsonl.decode(text).reviews;
          expect(back.first.script, persoArabic);
          expect(back.first.asked, Ask.rearrange);
          expect(back.last.script, isNull);
          expect(back.last.asked, isNull);

          final progress = MemoryProgress()..skills = map;
          void answer(DrillMode mode, String script, int hours) =>
              progress.record(
                deckId: words,
                cardId: 'hi-0001',
                mode: mode,
                grade: 4,
                now: day.add(Duration(hours: hours)),
                answerGiven: mode == DrillMode.recognition ? null : 'x',
                script: script,
                asked: Ask.own,
              );
          answer(DrillMode.production, persoArabic, 0);
          answer(DrillMode.recognition, devanagari, 1);
          answer(DrillMode.recognition, persoArabic, 2);
          final n = StatsNumbers.of(
            progress,
            now: day.add(const Duration(days: 1)),
            range: StatsRange.all,
            cardOf: (id, {deckId}) => null,
          );
          expect(n.scriptSkills.keys, <ScriptSkill>[
            (script: persoArabic, mode: DrillMode.readScript),
            (script: persoArabic, mode: DrillMode.writeScript),
            (script: devanagari, mode: DrillMode.readScript),
          ]);
          expect(n.reviews, 3);
        },
      );
    });
  });

  group('hours', () {
    group('hours spent', () {
      test('hours spent count each answer for at most a minute; hours left are '
          'the reviews still needed times each skill\'s time', () {
        expect(StudyHours.capped(const Duration(seconds: 45)).inSeconds, 45);
        expect(StudyHours.capped(const Duration(minutes: 30)).inSeconds, 60);
        expect(StudyHours.capped(const Duration(seconds: -3)), Duration.zero);

        final right = StudyHours.rightAnswersToRemember(null);
        final left = StudyHours.left(
          <(DrillMode, FsrsState?)>[
            (DrillMode.recognition, null),
            (DrillMode.production, null),
            // Remembered: counts for nothing.
            (DrillMode.recognition, stateWith(40)),
          ],
          times: const <DrillMode, Duration>{
            DrillMode.recognition: Duration(seconds: 10),
          },
        );
        // Production has no time of its own, so takes the default 20 s.
        expect(left, Duration(seconds: right * (10 + 20)));
      });
    });
  });

  group('How you learn', () {
    group('How you learn', () {
      testWidgets(
        'before any fit it says what will happen; after one, slower or faster '
        'per skill',
        (tester) async {
          usePhone(tester);
          final state = await pacedLearner(Paced.none);
          await pumpScreen(tester, const HowYouLearnPage(), state: state);
          final l10n = l10nOf(tester);

          expect(find.text(l10n.howYouLearnTitle), findsOneWidget);
          expect(find.text(l10n.howYouLearnIntro), findsOneWidget);
          expect(find.text(l10n.howYouLearnNone), findsOneWidget);
          expect(find.text(l10n.howYouLearnLegendYou), findsNothing);
          await tester.tap(find.text(l10n.howYouLearnOpenSettings));
          await tester.pumpAndSettle();
          expect(state.shellTab.value, ShellTab.settings);
          // Every skill with answers, not adjusted yet, with its count.
          for (final mode in <String>[
            'recognition',
            'listening',
            'production',
          ]) {
            await scrollToHowYouLearnPage(
              tester,
              find.text(l10n.adjustedNotYet(mode)),
            );
            expect(find.text(l10n.adjustedNotYet(mode)), findsOneWidget);
          }
          expect(find.text(l10n.paceNotYet(8)), findsNWidgets(3));
          expect(state.progress.parameters.fitted, isEmpty);
          expect(find.text(l10n.paceAdjustedToday(24)), findsNothing);

          {
            usePhone(tester);
            final state = await pacedLearner(Paced.fewer);
            await pumpScreen(tester, const HowYouLearnPage(), state: state);
            final l10n = l10nOf(tester);
            final hear = paceOf(state, DrillMode.listening);
            expect(hear.adjusted, isTrue);
            expect(hear.now.days, greaterThan(hear.start.days));
            expect(SkillFit.direction(hear.start, hear.now), -1);

            expect(find.text(l10n.howYouLearnLegendYou), findsOneWidget);
            expect(find.text(l10n.howYouLearnLegendStart), findsOneWidget);
            final verdict = l10n.adjustedFewer('listening');
            await scrollToHowYouLearnPage(tester, find.text(verdict));
            expectAdjusted(tester, l10n, hear, verdict);
            expect(
              find.text(
                l10n.paceComesBack('listening', hear.now.days, hear.start.days),
              ),
              findsOneWidget,
            );
            final scheme = Theme.of(tester.element(find.text(verdict)))
                .colorScheme;
            expect(verdictColour(tester, verdict), scheme.primaryContainer);
            // The others are not adjusted yet.
            expect(
              find.text(l10n.adjustedNotYet('production')),
              findsOneWidget,
            );

            await scrollToHowYouLearnPage(
              tester,
              find.text(l10n.adjustedPrivacy),
            );
            expect(find.text(l10n.paceAdjustedToday(8)), findsOneWidget);
          }
        },
      );
    });
  });

  group('the pace strip', () {
    testWidgets(
      'before any fit there is no strip; after a slower fit, the skill is '
      'marked Fewer reviews',
      (tester) async {
        var runs = 0;
        await onToday(
          tester,
          Paced.none,
          paceRunner: (job) {
            runs++;
            return paceInPlace(job);
          },
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.adjustedTitle), findsNothing);
        expect(find.byType(PaceStrip), findsNothing);
        expect(find.byType(PaceMark), findsNothing);
        expect(runs, 0, reason: 'only stored fits are read before a fit');

        {
          final state = await onToday(tester, Paced.fewer);
          final l10n = l10nOf(tester);
          final pace = TodayNumbers.of(state).pace!;
          final totals = pace.totals!;

          expect(find.text(l10n.adjustedTitle), findsOneWidget);
          expect(
            find.text(
              totals.reviews == totals.was
                  ? l10n.paceReviewsSteady(totals.reviews)
                  : l10n.paceReviews(totals.reviews, totals.was),
            ),
            findsOneWidget,
          );
          expect(pace.marks, {Skill.listening: PaceDirection.fewer});
          expect(
            find.descendant(
              of: markOn(tester, Skill.listening),
              matching: find.text(l10n.paceFewer),
            ),
            findsOneWidget,
          );
          expect(markOn(tester, Skill.recognition), findsNothing);
          expect(markOn(tester, Skill.production), findsNothing);
          // The screen reader hears it too.
          expect(
            find.bySemanticsLabel(
              l10n.todaySkillAdjustedSemantics(
                Skill.listening.label(l10n),
                TodayNumbers.of(state).bySkill[Skill.listening]!,
                'fewer',
              ),
            ),
            findsOneWidget,
          );

          await tester.tap(find.text(l10n.adjustedTitle));
          await tester.pumpAndSettle();
          expect(find.byType(HowYouLearnPage), findsOneWidget);
        }
      },
    );
  });

  group('leeches', () {
    testWidgets('Reset, Undo, Set aside and Bring back append, never delete', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const LeechesPage(),
        state: await fixtureLeechesPage(),
      );
      final l10n = l10nOf(tester);
      final deck = state.deckById('es-en-core-100')!.deck.name;
      final skill = l10n.skillProduction;
      final before = List<ReviewEvent>.of(state.progress.log);
      Map<ProgressKey, String> byValue() => {
        for (final MapEntry(:key, :value) in state.progress.states.entries)
          key:
              '${value.stability} ${value.difficulty} ${value.intervalDays} '
              '${value.dueAt} ${value.lapses}',
      };
      final statesBefore = byValue();
      final actions = LeechActions.of(state.progress);

      Future<void> tap(String label) async {
        await tester.tap(inFirst(find.text(label)));
        await tester.pumpAndSettle();
      }

      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: firstCard(),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      await tap(l10n.leechesReset);
      expect(
        inFirst(find.text(l10n.leechesMetaReset(deck, skill))),
        findsOneWidget,
      );
      expect(inFirst(find.text(l10n.commonUndo)), findsOneWidget);
      expect(opacity(), lessThan(1));

      await tap(l10n.commonUndo);
      expect(inFirst(find.text(l10n.leechesMeta(deck, skill))), findsOneWidget);
      expect(opacity(), 1);

      await tap(l10n.leechesSetAside);
      expect(
        inFirst(find.text(l10n.leechesMetaSetAside(deck, skill))),
        findsOneWidget,
      );
      expect(inFirst(find.text(l10n.leechesReset)), findsOneWidget);

      await tap(l10n.leechesBringBack);
      expect(inFirst(find.text(l10n.leechesSetAside)), findsOneWidget);

      expect(actions.log.map((a) => a.kind), <LeechActionKind>[
        LeechActionKind.reset,
        LeechActionKind.undoReset,
        LeechActionKind.setAside,
        LeechActionKind.bringBack,
      ]);
      expect(state.progress.log, orderedEquals(before), reason: 'rule 9');
      expect(byValue(), statesBefore, reason: 'undone and brought back');
    });
  });
}
