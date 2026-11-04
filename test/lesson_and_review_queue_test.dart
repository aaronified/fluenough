// Split out of lesson_and_review_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: the session queue, passages in the queue, a day's session, the path teaches, the lesson, a lesson on screen, how a card is asked, sets, sets on screen, number practice, spelling numbers, a tag's practice, a deck's known cards come up a few at a time.

import 'dart:io';
import 'dart:math';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/number_rules_parser.dart';
import 'package:fluenough/core/models/aksharas.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/card_set.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/number_rules.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/numbers/number_speller.dart';
import 'package:fluenough/core/scheduling/deck_sampling.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/lesson_sets.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/grammar_drill.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/picture_choice_drill.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart';
import 'package:fluenough/features/drill/set_drill.dart';
import 'package:fluenough/features/drill/teach_card.dart';
import 'package:fluenough/features/drill/teach_drill.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/features/today/daily_card.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'support/harness.dart';
import 'support/lesson_and_review_shared.dart';

/// A state due [daysAgo] days before [now]; negative means in the future.
FsrsState dueDaysAgo(int daysAgo) => FsrsState(
  stability: 6,
  difficulty: 5,
  repetitions: 2,
  intervalDays: 6,
  dueAt: now.subtract(Duration(days: daysAgo)),
  lastReviewAt: now.subtract(Duration(days: daysAgo + 6)),
);

List<String> ids(List<SessionItem> items) => [
  for (final i in items) '${i.card.id}:${i.mode.name}',
];

// From session_queue_reading_test.dart.
/// Reading questions in a session (#98, ADR-0019): each scheduled like a
/// card, and a passage's questions kept together.

/// [questions] questions about passage [id], as the parser makes them.
List<QuestionCard> passage(String id, int questions) {
  final p = Passage(
    id: id,
    title: 'Passage $id',
    sentences: const <PassageSentence>[PassageSentence(text: 'বাক্য।')],
    questions: <ReadingQuestion>[
      for (var i = 1; i <= questions; i++)
        ReadingQuestion(id: '$id-q$i', prompt: {'en': 'Q$i'}, answer: 0),
    ],
  );
  return <QuestionCard>[
    for (final q in p.questions)
      QuestionCard(deckId: 'reading', passage: p, question: q),
  ];
}

SessionQueue buildSessionQueueReading(
  List<Card> cards, {
  Map<(String, DrillMode), FsrsState> states = const {},
  bool voice = true,
  int newCardLimit = 20,
}) => SessionQueue.build(
  cards: cards,
  stateOf: (c, m) => states[(c.id, m)],
  hasVoice: (_) => voice,
  now: now,
  newCardLimit: newCardLimit,
);

// From app_state_test.dart.

// From path_teaching_test.dart.
/// Today teaching along a course's path (#117, ADR-0013): new cards only from
/// the pending units, the current one and the next, mixed.

AppState learning(
  List<String> languages, {
  Set<String> placed = const <String>{},
  List<String> spoken = const <String>['en'],
  DeckSource? decks,
  MemoryProgress? progress,
}) => AppState.test(
  decks: decks,
  progress: progress,
  settings: SettingsNotifier(
    spokenLanguages: spoken,
    learningLanguages: languages,
    placedDecks: placed,
  ),
);

List<List<String>> unitIds(AppState state) => <List<String>>[
  for (final unit in state.pendingUnits) <String>[for (final e in unit) e.id],
];

DeckBadgeKind badgeOf(AppState state, String deckId) =>
    DeckBadge.forEntry(state, state.deckById(deckId)!).kind;

/// A tiny course: three single-card decks of Hindi from [native], and, with
/// [path], Hindi's path of three units, [first] first. The path is the
/// language's, every course's (ADR-0036), so a second course of Hindi
/// leaves it out.
Map<String, String> tinyCourse({
  String native = 'en',
  String first = 'a',
  bool path = true,
}) {
  String deck(String name) =>
      '''
schema: 1
id: hi-$native-$name
name: "$name"
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: $native, iso639_3: ${native == 'en' ? 'eng' : 'ben'}, name: ${native == 'en' ? 'English' : 'Bengali'} }
license: CC0-1.0
cards:
  - { id: hi-$native-$name-0001, target: "क", native: "k", reading: "k", modes: [recognition, listening, speaking] }
''';
  final order = <String>[
    first,
    ...<String>['a', 'b', 'c']..remove(first),
  ];
  return <String, String>{
    for (final name in <String>['a', 'b', 'c'])
      'decks/hi/hi-$native-$name.yaml': deck(name),
    if (path)
      'decks/hi/hi-path.yaml':
          '''
schema: 1
kind: path
id: hi-path
language: hi
units:
${[for (final name in order) '  - [hi-$name]'].join('\n')}
''',
  };
}

// From lesson_test.dart.
Card cardLesson(
  String id,
  String target, {
  String? reading,
  String? pos,
  Set<DrillMode> modes = const {},
}) => Card(
  id: id,
  deckId: 'test',
  target: target,
  native: 'native $id',
  reading: reading,
  pos: pos,
  modes: modes,
);

List<String> idsLesson(List<Card> cards) => <String>[
  for (final c in cards) c.id,
];

/// The session the drill page is running.
DrillSession sessionOf(WidgetTester tester) {
  for (final widget in <Widget>[
    ...tester.widgetList(find.byType(SetDrill)),
    ...tester.widgetList(find.byType(GrammarDrill)),
    ...tester.widgetList(find.byType(TeachDrill)),
    ...tester.widgetList(find.byType(ChoiceDrill)),
    ...tester.widgetList(find.byType(MatchDrill)),
    ...tester.widgetList(find.byType(RearrangeDrill)),
    ...tester.widgetList(find.byType(PictureChoiceDrill)),
  ]) {
    return switch (widget) {
      SetDrill(:final session) => session,
      GrammarDrill(:final session?) => session,
      TeachDrill(:final session) => session,
      ChoiceDrill(:final session) => session,
      MatchDrill(:final session) => session,
      RearrangeDrill(:final session) => session,
      PictureChoiceDrill(:final session) => session,
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
      case Ask.teach || Ask.showSet || Ask.teachRule:
        session.learnt();
      case Ask.chooseMeaning ||
          Ask.chooseWord ||
          Ask.hearAndChoose ||
          Ask.hearMeaning ||
          Ask.chooseFormMeaning ||
          Ask.chooseForm ||
          Ask.choosePicture ||
          Ask.hearPicture:
        session.pick(session.options.firstWhere((o) => o.id == card.id));
        session.next();
      case Ask.matchPairs:
        for (final entry in session.item.group) {
          session.match(entry, entry);
        }
        session.next();
      case Ask.rearrange:
        final words = tilesOf(
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
        // A grammar cell, typed, or a word heard and its meaning typed.
        session.check(session.acceptedAnswers.first);
        session.next();
    }
    await tester.pumpAndSettle();
  }
}

List<SessionItem> recognising(int count) => <SessionItem>[
  for (var i = 0; i < count; i++) item(cardAsk('r$i'), DrillMode.recognition),
];

FsrsState remembered(DateTime at) => FsrsState(
  stability: 5,
  difficulty: 5,
  intervalDays: 5,
  dueAt: at,
  lastReviewAt: at.subtract(const Duration(days: 5)),
  repetitions: 2,
);

FsrsState missed(DateTime at) => FsrsState(
  stability: 1,
  difficulty: 7,
  intervalDays: 1,
  dueAt: at,
  lastReviewAt: at.subtract(const Duration(days: 1)),
  lapses: 1,
);

// From set_cards_test.dart.
/// Three of the home deck's words, as one set.
const refSet = '''
  - id: "zz-9201"
    kind: "set"
    members: [{ ref: "zz-9001" }, { ref: "zz-9004" }, { ref: "zz-9006" }]
''';

/// One noun of the case table across its slots, and one slot across its
/// nouns, its card showing the rows the deck chose.
const ruleSets = '''
  - id: "zz-9202"
    kind: "set"
    members: { rule: "zz-grammar-case-endings", noun: "అమ్మ" }
  - id: "zz-9203"
    kind: "set"
    members: { rule: "zz-rule-lo", case: "lo" }
    shown: [{ ref: "zz-9004" }, { ref: "zz-9001" }]
''';

String coreWith(String sets) => '$homeCore$sets';

String layerWith(Map<String, (String, String)> texts) => homeLayer.replaceFirst(
  'cards:\n',
  <String>[
    'cards:',
    for (final MapEntry(key: id, value: (name, explanation))
        in texts.entries) ...<String>[
      '  "$id":',
      '    native: "$name"',
      '    explanation: "$explanation"',
    ],
    '',
  ].join('\n'),
);

const texts = <String, (String, String)>{
  'zz-9201': ('Three first words', 'Three words you meet first.'),
  'zz-9202': ('Mother: every case', 'One noun, అమ్మ (amma), in every case.'),
  'zz-9203': ('In: every noun', 'One ending, -లో (-lō), on every noun.'),
};

Matcher fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

Card wordSetCards(String id, String target, {String? reading}) => Card(
  id: id,
  deckId: 'xx-en-a',
  target: target,
  native: 'meaning of $target',
  reading: reading,
);

/// A rules cell of row [row], slot [slot], as the expander makes it.
Card cellSetCards(String row, String slot, String target) => Card(
  id: 'te-grammar-verb-present-$row-$slot',
  deckId: 'te-en-grammar-verb-present',
  target: target,
  native: '$row $slot',
  modes: DrillMode.vocabulary,
  rule: RuleCell(
    ruleId: 'te-rule-present',
    word: 'te-$row',
    wordTarget: row,
    slot: slot,
  ),
);

CardSet ruleSet(
  String id,
  String axis,
  String value, {
  String rule = 'te-grammar-verb-present',
  List<String> shown = const <String>[],
}) => CardSet(
  id: id,
  deckId: 'te-en-verbs',
  name: id,
  explanation: '',
  rule: SetRule(rule: rule, axis: axis, value: value),
  shown: shown,
);

/// The rules of the core te-grammar-verb-present: one, here.
Set<String> rulesOf(String core) => <String>{'te-rule-present'};

// From set_drill_test.dart.
/// Set cards in a lesson (#515), as the approved mockup
/// `docs/mockups/set-cards.html` draws them: the set first, its members
/// marked New or Known, a split set in parts with a Full list, and the Full
/// list on an answered question.

const homeSetDrill = 'zz-en-home';

/// The example set's files, with set cards added to its home deck: three
/// words, or five, split over two cards.
Map<String, String> files({bool split = false}) {
  final out = <String, String>{
    for (final file in Directory(appendix).listSync(recursive: true))
      if (file is File && file.path.endsWith('.yaml'))
        'decks/zz/${file.path.substring(appendix.length + 1)}': file
            .readAsStringSync(),
  };
  final members = split
      ? <String>['zz-9001', 'zz-9004', 'zz-9006', 'zz-9003', 'zz-9002']
      : <String>['zz-9001', 'zz-9004', 'zz-9006'];
  out['decks/zz/zz-home.yaml'] =
      '${out['decks/zz/zz-home.yaml']}'
      '  - id: "zz-9201"\n'
      '    kind: "set"\n'
      '    members: [${members.map((m) => '{ ref: "$m" }').join(', ')}]\n';
  out['decks/zz/en/zz-en-home.yaml'] = out['decks/zz/en/zz-en-home.yaml']!
      .replaceFirst(
        'cards:\n',
        'cards:\n'
            '  "zz-9201":\n'
            '    native: "First words"\n'
            '    explanation: "Words you meet first, together."\n',
      );
  return out;
}

AppState learner({bool split = false}) => AppState.test(
  decks: MemoryDeckSource(files(split: split)),
  progress: MemoryProgress(),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['zz'],
  ),
);

DrillSession sessionOfSetDrill(WidgetTester tester) {
  for (final widget in <Widget>[
    ...tester.widgetList(find.byType(SetDrill)),
    ...tester.widgetList(find.byType(TeachDrill)),
    ...tester.widgetList(find.byType(ChoiceDrill)),
    ...tester.widgetList(find.byType(MatchDrill)),
    ...tester.widgetList(find.byType(PictureChoiceDrill)),
  ]) {
    return switch (widget) {
      SetDrill(:final session) => session,
      TeachDrill(:final session) => session,
      ChoiceDrill(:final session) => session,
      MatchDrill(:final session) => session,
      PictureChoiceDrill(:final session) => session,
      _ => throw StateError('$widget'),
    };
  }
  throw StateError('no drill');
}

Future<void> openLesson(WidgetTester tester, AppState state) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.lesson(language: 'zz', deckId: homeSetDrill),
  ),
  state: state,
);

// From number_practice_test.dart.
NumberRules bundled(String code) => parseNumberRules(
  File('decks/$code/$code-numbers.yaml').readAsStringSync(),
  source: '$code-numbers.yaml',
);

// From number_speller_test.dart.
Matcher refusedWith(String message) => throwsA(
  isA<DeckParseException>().having(
    (e) => e.message,
    'message',
    contains(message),
  ),
);

// From quick_revision_test.dart.
/// A tag's practice: words already taught, picked at random. Every answer
/// is recorded (ADR-0033).

Future<AppState> knowing(int count) async {
  final state = await withDeckTaught(
    (progress) => AppState.test(
      progress: progress,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['hi'],
      ),
    ),
    'hi-en-phrasebook',
    count: count,
    // Known in Write, one of the schedules (ADR-0034).
    mode: DrillMode.production,
  );
  await state.load();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the session queue', () {
    group('new cards', () {
      test(
        'the new-card cap limits new pairs, and never holds back reviews',
        () {
          final queue = build([
            for (final id in ['a', 'b', 'c', 'd']) card(id),
          ], newCardLimit: 2);
          expect(ids(queue.fresh), ['a:recognition', 'b:recognition']);

          {
            final queue = build(
              [card('a'), card('b')],
              states: {
                ('a', DrillMode.production): dueDaysAgo(1),
                ('b', DrillMode.production): dueDaysAgo(1),
              },
              newCardLimit: 0,
            );
            expect(queue.due, hasLength(2));
          }
        },
      );
    });

    group('due cards', () {
      test('due reviews come first, most overdue first', () {
        final queue = build(
          [card('a'), card('b'), card('c'), card('new')],
          states: {
            ('a', DrillMode.production): dueDaysAgo(1),
            ('b', DrillMode.production): dueDaysAgo(5),
            ('c', DrillMode.production): dueDaysAgo(3),
          },
        );
        expect(ids(queue.items), [
          'b:production',
          'c:production',
          'a:production',
          'new:recognition',
        ]);
        expect(queue.due.every((i) => !i.isNew), isTrue);
      });
    });

    group('one mode per card per session', () {
      test(
        'a card due in two modes is drilled once, in the more overdue one',
        () {
          final queue = build(
            [card('a')],
            states: {
              ('a', DrillMode.listening): dueDaysAgo(1),
              ('a', DrillMode.production): dueDaysAgo(4),
            },
          );
          expect(ids(queue.items), ['a:production']);

          {
            final queue = build(
              [card('a')],
              states: {('a', DrillMode.production): dueDaysAgo(1)},
            );
            expect(ids(queue.items), ['a:production']);
          }
        },
      );
    });

    group('modes', () {
      test(
        'a voiceless or switched-off mode is never offered; reviseAll drills '
        'every reviewed card',
        () {
          final queue = build(
            [
              card(
                'a',
                modes: {
                  DrillMode.recognition,
                  DrillMode.production,
                  DrillMode.speaking,
                },
              ),
              card('b'),
            ],
            states: {
              ('b', DrillMode.recognition): dueDaysAgo(-2),
              ('b', DrillMode.production): dueDaysAgo(-2),
              ('b', DrillMode.listening): dueDaysAgo(1),
            },
            voice: false,
          );
          expect(queue.isEmpty, isTrue);

          {
            final queue = build(
              [card('a')],
              states: {('a', DrillMode.listening): dueDaysAgo(1)},
              modes: {DrillMode.production},
            );
            expect(ids(queue.items), ['a:production']);
          }

          {
            final early = card('early');
            final later = card('later');
            final unseen = card('unseen');
            final queue = SessionQueue.build(
              cards: [early, later, unseen],
              stateOf: (c, m) => switch ((c.id, m)) {
                ('early', DrillMode.listening) => dueDaysAgo(-5),
                ('early', DrillMode.production) => dueDaysAgo(-2),
                ('later', DrillMode.listening) => dueDaysAgo(-9),
                _ => null,
              },
              hasVoice: (_) => true,
              now: now,
              newCardLimit: 0,
              reviseAll: true,
            );
            expect(queue.fresh, isEmpty);
            // One mode per card, the one due soonest; soonest card first.
            expect(queue.due.map((i) => (i.card.id, i.mode)), [
              ('early', DrillMode.production),
              ('later', DrillMode.listening),
            ]);
            // Without it, nothing is due yet.
            expect(
              SessionQueue.build(
                cards: [early, later, unseen],
                stateOf: (c, m) => c.id == 'unseen' ? null : dueDaysAgo(-5),
                hasVoice: (_) => true,
                now: now,
                newCardLimit: 0,
              ).isEmpty,
              isTrue,
            );
          }
        },
      );
    });
  });

  group('passages in the queue', () {
    test('a new question is read before it is heard', () {
      final queue = buildSessionQueueReading(passage('p', 2));
      expect(ids(queue.items), ['p-q1:reading', 'p-q2:reading']);
    });
  });

  group('a day\'s session', () {
    Future<AppState> loaded({
      FixedTtsEngine? tts,
      FeatureRegistry features = const FeatureRegistry.shipped(),
      SettingsNotifier? settings,
      List<Profile> profiles = const [Profile.defaultProfile],
    }) async {
      final state = AppState.test(
        tts: tts ?? FixedTtsEngine(const {}),
        features: features,
        settings: settings,
        profiles: profiles,
      );
      await state.load();
      return state;
    }

    group('sessions', () {
      // Grammar cards enter in their own mode. These tests are about
      // vocabulary, so the grammar drill is off in them.
      final vocabOnly = FeatureRegistry.only(
        Feature.available.difference({Feature.drillGrammar}),
      );

      test('a fresh day teaches a lesson, and taught words join the reviews in '
          'their other skills', () async {
        final state = await loaded(features: vocabOnly);
        expect(state.buildSession(const DrillRequest.today()).isEmpty, isTrue);
        final lesson = state.lessonFor(DrillRequest.lesson(language: 'es'));
        // Nine words, and more when a set one of them belongs to comes whole
        // (the lesson's cap does not hold back a set's members).
        expect(
          lesson.where((i) => i.ask == Ask.teach),
          hasLength(greaterThanOrEqualTo(9)),
        );

        {
          final state = await loaded(features: vocabOnly)
            ..showLanguage('es');
          final lesson = DrillRequest.lesson(language: 'es');
          // The set cards come first and record nothing; the first question
          // is the first item that is neither a teaching card nor a set.
          final check = state
              .lessonFor(lesson)
              .firstWhere((i) => i.ask != Ask.teach && i.ask != Ask.showSet);
          state.record(check, 4);
          expect(state.isTaught(check.card), isTrue);
          final today = state.buildSession(const DrillRequest.today());
          expect(today.fresh.map((i) => i.card.id), <String>[check.card.id]);
          expect(today.fresh.single.mode, isNot(check.mode));
          // A set card still shows a taught member, marked Known; it is not
          // taught or asked again.
          expect(
            state
                .lessonFor(lesson)
                .where((i) => i.ask != Ask.showSet)
                .map((i) => i.card.id),
            isNot(contains(check.card.id)),
          );
        }
      });

      test(
        'listening joins only with a voice, and a switched-off skill is left '
        'out',
        () async {
          final state = await loaded(tts: FixedTtsEngine({'es'}));
          final spanish = state.buildSession(
            DrillRequest.untaught('es-en-core-100', skill: Skill.listening),
          );
          final hindi = state.buildSession(
            DrillRequest.untaught(
              'hi-en-script-vowels',
              skill: Skill.listening,
            ),
          );
          expect(spanish.isNotEmpty, isTrue);
          expect(hindi.isEmpty, isTrue);

          {
            final settings = SettingsNotifier();
            final state = await loaded(
              tts: FixedTtsEngine({'es'}),
              settings: settings,
              features: vocabOnly,
            );
            state.showLanguage('es');
            // A taught word's other skills join the reviews, Write first; with
            // Write switched off, Hear comes in its place.
            state.record(
              state.lessonFor(DrillRequest.lesson(language: 'es'))[1],
              4,
            );
            settings.setSkillEnabled(Skill.production, false);
            final queue = state.buildSession(const DrillRequest.today());
            expect(queue.isNotEmpty, isTrue);
            expect(
              queue.items.every((i) => i.mode != DrillMode.production),
              isTrue,
            );
          }
        },
      );

      test('a profile sees only its own languages', () async {
        final state = await loaded(
          profiles: const [
            Profile(id: 'mira', name: 'Mira', languages: {'hi'}),
          ],
        );
        final hindi = <String>{
          for (final d in state.decks)
            if (d.language.code == 'hi') d.id,
        };
        expect(state.profileDecks.map((d) => d.id).toSet(), hindi);
        final lesson = state.lessonFor(DrillRequest.lesson(language: 'hi'));
        expect(lesson, isNotEmpty);
        expect(lesson.every((i) => hindi.contains(i.card.deckId)), isTrue);
        expect(state.lessonFor(DrillRequest.lesson(language: 'es')), isEmpty);
      });
    });
  });

  group('the path teaches', () {
    test('A lesson takes new words only from the first two units of the '
        'path, one from each in turn', () async {
      final state = learning(<String>['hi']);
      addTearDown(state.dispose);
      await state.load();
      // Hindi starts with words and basic sentences, not its script.
      expect(unitIds(state), <List<String>>[
        <String>['hi-en-phrasebook', 'hi-en-first-words'],
        <String>['hi-en-sound-differences'],
      ]);
      final untaught = state.untaughtCards('hi');
      final unitOf = <String, int>{
        for (final (i, unit) in unitIds(state).indexed)
          for (final id in unit) id: i,
      };
      expect(untaught.map((c) => unitOf[c.deckId]), everyElement(isNotNull));
      expect(untaught.take(4).map((c) => unitOf[c.deckId]), [0, 1, 0, 1]);
      // The lesson draws on the same units.
      expect(
        state
            .lessonFor(DrillRequest.lesson(language: 'hi'))
            .map((i) => i.card.deckId),
        everyElement(isIn(unitOf.keys)),
      );
      // And Start review has no new words.
      expect(state.buildSession(const DrillRequest.today()).isEmpty, isTrue);
    });

    test('a placed unit is skipped, and a finished one passed', () async {
      final state = learning(
        <String>['hi'],
        placed: <String>{'hi-en-phrasebook', 'hi-en-first-words'},
      );
      addTearDown(state.dispose);
      await state.load();
      expect(unitIds(state).first, <String>['hi-en-sound-differences']);
      expect(unitIds(state).last.first, 'hi-en-questions');
      expect(badgeOf(state, 'hi-en-first-words'), DeckBadgeKind.done);
      expect(badgeOf(state, 'hi-en-sound-differences'), DeckBadgeKind.pending);
      expect(badgeOf(state, 'hi-en-questions'), DeckBadgeKind.pending);
      expect(badgeOf(state, 'hi-en-market'), DeckBadgeKind.notDone);
      // A placed deck can still be studied, in a lesson of its own.
      expect(
        state.lessonFor(
          DrillRequest.lesson(language: 'hi', deckId: 'hi-en-first-words'),
        ),
        isNotEmpty,
      );

      // Placement is a setting: changing it moves the window at once.
      state.settings.placedDecks = const <String>{};
      expect(unitIds(state).first.first, 'hi-en-phrasebook');

      {
        final state = learning(<String>[
          'hi',
        ], decks: MemoryDeckSource(tinyCourse()));
        addTearDown(state.dispose);
        await state.load();
        expect(unitIds(state), <List<String>>[
          <String>['hi-en-a'],
          <String>['hi-en-b'],
        ]);
        // Nothing past the pending units.
        expect(state.untaughtCards('hi').map((c) => c.deckId), <String>[
          'hi-en-a',
          'hi-en-b',
        ]);
        final first = state
            .buildSession(DrillRequest.untaught('hi-en-a'))
            .items
            .single;
        state.record(first, 5);
        expect(unitIds(state), <List<String>>[
          <String>['hi-en-b'],
          <String>['hi-en-c'],
        ]);
        expect(badgeOf(state, 'hi-en-a'), DeckBadgeKind.done);
      }
    });

    test('reviews come from every deck, pending or not', () async {
      final base = learning(<String>['hi']);
      await base.load();
      final market = base.deckById('hi-en-market')!;
      final progress = MemoryProgress()
        ..record(
          deckId: market.id,
          cardId: market.cards.first.id,
          mode: DrillMode.production,
          grade: 4,
          now: base.now().subtract(const Duration(days: 3)),
        );
      base.dispose();
      final state = learning(<String>['hi'], progress: progress);
      addTearDown(state.dispose);
      await state.load();
      final today = state.buildSession(const DrillRequest.today());
      expect(today.due.map((i) => i.card.deckId), <String>['hi-en-market']);
      expect(
        today.fresh.map((i) => i.card.deckId),
        isNot(contains('hi-en-market')),
      );
    });
  });

  group('the lesson', () {
    group('lessonItems', () {
      final easy = [for (var i = 0; i < 5; i++) cardLesson('e$i', 'sí')];
      final medium = [for (var i = 0; i < 5; i++) cardLesson('m$i', 'gracias')];
      final hard = [
        for (var i = 0; i < 5; i++) cardLesson('h$i', 'hola', pos: 'phrase'),
      ];

      test('takes the next nine in path order, easy first, with no quota of '
          'each difficulty', () {
        final mixed = <Card>[
          hard[0],
          medium[0],
          easy[0],
          hard[1],
          easy[1],
          medium[1],
          easy[2],
          easy[3],
          hard[2],
          medium[2],
          hard[3],
          medium[3],
        ];
        expect(idsLesson(lessonItems(mixed)), <String>[
          'e0',
          'e1',
          'e2',
          'e3',
          'm0',
          'm1',
          'h0',
          'h1',
          'h2',
        ]);
      });

      test('a lesson takes fewer new items while words in progress have not '
          'reached the bar, never fewer than two', () {
        expect(lessonRoom(0), 9);
        expect(lessonRoom(3), 6);
        expect(lessonRoom(20), 2);
        expect(idsLesson(lessonItems(easy, room: lessonRoom(3))), <String>[
          'e0',
          'e1',
          'e2',
          'e3',
          'e4',
        ]);
        expect(idsLesson(lessonItems(easy, room: lessonRoom(20))), <String>[
          'e0',
          'e1',
        ]);
      });
    });

    group('lessonPlan', () {
      final easy = [for (var i = 0; i < 3; i++) cardLesson('e$i', 'sí$i')];
      final medium = [
        for (var i = 0; i < 3; i++) cardLesson('m$i', 'gracias$i'),
      ];
      final hard = [
        for (var i = 0; i < 3; i++) cardLesson('h$i', 'me llamo Ana$i'),
      ];
      final nine = <Card>[...easy, ...medium, ...hard];

      String shape(SessionItem item) => item.ask == Ask.matchPairs
          ? 'match(${item.group.map((g) => g.card.id).join(',')})'
          : '${item.card.id}:${item.mode.name}:${item.ask.name}';

      List<String> plan(
        List<Card> cards, {
        bool voice = true,
        bool speech = true,
        bool choose = true,
      }) => lessonPlan(
        cards,
        modesOf: (c) => c.modesIn(ttsAvailable: voice, speechAvailable: speech),
        canChoose: (_, _) => choose,
      ).map(shape).toList();

      test(
        'teaches and checks each card, then asks it once more; a grammar cell '
        'is taught and typed',
        () {
          expect(plan(nine), <String>[
            'e0:recognition:teach',
            'e0:recognition:chooseMeaning',
            'e1:recognition:teach',
            'e1:recognition:chooseMeaning',
            'e2:recognition:teach',
            'e2:recognition:chooseMeaning',
            'm0:listening:teach',
            'm0:listening:hearMeaning',
            'm1:listening:teach',
            'm1:listening:hearMeaning',
            'm2:listening:teach',
            'm2:listening:hearMeaning',
            'h0:production:teach',
            'h0:production:rearrange',
            'h1:production:teach',
            'h1:production:rearrange',
            'h2:production:teach',
            'h2:production:rearrange',
            // The exercise.
            'e0:speaking:own',
            'match(m0,m1,m2)',
            'h0:speaking:own',
            'e1:speaking:own',
            'h1:speaking:own',
            'e2:speaking:own',
            'h2:speaking:own',
          ]);

          final cell = cardLesson('g', 'voy', modes: DrillMode.vocabulary);
          expect(plan(<Card>[cell]), <String>[
            'g:grammar:teach',
            'g:grammar:own',
          ]);
        },
      );

      test(
        'without a voice, a medium card is checked by choosing the word',
        () {
          final items = plan(medium, voice: false, speech: false);
          expect(items, <String>[
            'm0:production:teach',
            'm0:production:chooseWord',
            'm1:production:teach',
            'm1:production:chooseWord',
            'm2:production:teach',
            'm2:production:chooseWord',
            'match(m0,m1,m2)',
          ]);
        },
      );
    });
  });

  group('a lesson on screen', () {
    testWidgets(
      'a word is taught on one card: the IPA opens the pronunciation, the '
      'meaning the dictionary, and a swipe goes on to its question',
      (tester) async {
        usePhone(tester);
        final state = AppState.test(
          decks: MemoryDeckSource(<String, String>{
            'decks/es/es-en-teach.yaml': '''
schema: 1
id: es-en-teach
name: "Teach"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-en-teach-0001
    target: "hola"
    native: "hello"
    ipa: "ˈola"
    notes: "Said when you meet."
    examples:
      - target: "Hola, Ana."
        native: "Hello, Ana."
  - id: es-en-teach-0002
    target: "adiós"
    native: "goodbye"
''',
          }),
        );
        await pumpScreen(
          tester,
          DrillPage(
            request: DrillRequest.lesson(language: 'es', deckId: 'es-en-teach'),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        final first = sessionOf(tester).item.card;
        expect(first.id, 'es-en-teach-0001');
        expect(find.byType(TeachCard), findsOneWidget);
        expect(find.text('hola'), findsOneWidget);
        expect(find.text('Said when you meet.'), findsOneWidget);
        expect(find.text(l10n.commonContinue), findsNothing);

        // The IPA is a button: it opens the pronunciation, which asks for the
        // IPA course where it is not on the phone.
        await tester.tap(find.text(l10n.wordSheetIpa('ˈola')));
        await tester.pumpAndSettle();
        expect(find.text(l10n.teachPronunciationBody), findsOneWidget);
        expect(find.text(l10n.ipaSymbolsNone), findsOneWidget);
        await tester.tap(find.text(l10n.commonClose));
        await tester.pumpAndSettle();
        expect(find.text(l10n.teachPronunciationBody), findsNothing);

        // The examples are on the card; the meaning is the dictionary button,
        // which has them too.
        expect(find.text('Hola, Ana.'), findsOneWidget);
        await tester.tap(find.text('hello'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.teachDictionaryBody), findsOneWidget);
        expect(find.text('Hola, Ana.'), findsNWidgets(2));
        await tester.tap(find.text(l10n.commonClose));
        await tester.pumpAndSettle();

        // Nothing behind the first card: a swipe toward the end edge is held
        // back, and the card is where it was.
        await tester.fling(find.byType(TeachCard), const Offset(300, 0), 1000);
        await tester.pumpAndSettle();
        expect(sessionOf(tester).ask, Ask.teach);
        expect(find.byType(TeachCard), findsOneWidget);

        // A swipe toward the start edge goes on, and records nothing.
        await tester.fling(find.byType(TeachCard), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.byType(TeachCard), findsNothing);
        expect(find.byType(TeachDrill), findsNothing);
        expect(find.byType(DrillPage), findsOneWidget);
        expect(state.progress.log, isEmpty);
      },
    );

    testWidgets('Today\'s one button starts the day: with nothing to review it '
        'teaches the new words, each taught, then asked', (tester) async {
      usePhone(tester);
      final state = spanishLearner();
      await pumpScreen(tester, const TodayPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.byType(DailyCard), findsOneWidget);
      expect(find.text(l10n.todayDailyStart), findsOneWidget);
      // The split: nothing to review yet, and the new words are what the
      // session's own plan teaches in the time (#886), not a lesson's nine.
      final spanish = state.languages.firstWhere((l) => l.code == 'es');
      final words = state.dailyPlanFor(spanish).split.newWords;
      expect(words, greaterThan(0));
      // Under the ring the split reads in minutes, never in cards (#1009).
      final minutes = state.dailyPlanFor(spanish).newMinutes;
      expect(minutes, greaterThan(0));
      expect(find.text(l10n.todayDailyReviewMinutes(0)), findsOneWidget);
      expect(find.text(l10n.todayDailyNewMinutes(minutes)), findsOneWidget);
      expect(find.text(l10n.todayDailyProgress(0, 15)), findsOneWidget);
      // Those words, plus the members of a set one of them belongs to,
      // which come whole.
      final lesson = state.lessonFor(
        DrillRequest.lesson(language: 'es'),
        words: words,
        beyondRoom: true,
      );
      final taught = lessonCardCount(lesson);
      expect(taught, greaterThanOrEqualTo(words));

      final planned = <SessionItem>[
        for (final item in lesson)
          if (item.ask != Ask.teach && item.ask != Ask.showSet)
            ...item.group.isEmpty ? <SessionItem>[item] : item.group,
      ].length;
      await tester.tap(find.text(l10n.todayDailyStart));
      await tester.pumpAndSettle();
      // A set card comes first, whole or in parts, and records nothing; then
      // the first word is taught before it is asked.
      while (sessionOf(tester).ask == Ask.showSet) {
        expect(find.byType(SetDrill), findsOneWidget);
        sessionOf(tester).learnt();
        await tester.pumpAndSettle();
      }
      expect(find.byType(TeachDrill), findsOneWidget);
      expect(find.byType(TeachCard), findsOneWidget);
      final first = sessionOf(tester).item.card;
      expect(find.text(first.native), findsOneWidget);
      // No Continue: the chevron goes on, as a swipe does.
      expect(find.text(l10n.commonContinue), findsNothing);
      // The round teaches every new word first, and asks them after, with
      // older reviews between (#886): so the chevron goes on to the next
      // word taught, until the words are all taught.
      final taughtIds = <String>{};
      while (sessionOf(tester).ask.onlyShows) {
        if (sessionOf(tester).ask == Ask.teach) {
          taughtIds.add(sessionOf(tester).item.card.id);
        }
        await tester.tap(find.byTooltip(l10n.drillNextCard));
        await tester.pumpAndSettle();
      }
      expect(taughtIds, contains(first.id));
      // Then the first question is about a word just taught, and nothing is
      // recorded until it is answered.
      expect(find.byType(TeachDrill), findsNothing);
      expect(taughtIds, contains(sessionOf(tester).item.card.id));
      expect(state.progress.log, isEmpty);

      await finishLesson(tester);
      expect(find.byType(SummaryPage), findsOneWidget);
      // Every word taught, each recorded in two skills but a grammar cell, which has
      // one, all right.
      final log = state.progress.log;
      expect(log.map((e) => e.cardId).toSet(), hasLength(taught));
      expect(log, hasLength(planned));
      // A right choice in Hear or Write records 3, a right choice or match
      // of a meaning seen 4 (ADR-0034): every answer is right.
      expect(log.every((e) => e.grade >= 3), isTrue);
      expect(
        log
            .where((e) => e.mode == DrillMode.recognition)
            .every((e) => e.grade >= 4),
        isTrue,
      );
      expect(state.lessonDoneToday('es'), isTrue);

      // The summary offers another; back on Today, the day goes on.
      // The summary's list is lazy, and what the lesson unlocked sits above
      // the buttons: scroll to them.
      await tester.scrollUntilVisible(
        find.text(l10n.summaryAnotherLesson),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.summaryAnotherLesson), findsOneWidget);
      Navigator.of(tester.element(find.byType(SummaryPage)))
          .popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.byType(DailyCard), findsOneWidget);
      expect(find.text(l10n.todayNewWords(taught)), findsOneWidget);
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
  });

  group('how a card is asked', () {
    group('reviewAsks', () {
      test('recognition is asked by match pairs, then choice; a sentence or a '
          'phrase is rearranged', () {
        expect(asked(recognising(10)), <String>[
          'match(r0,r1,r2,r3)',
          'r4:chooseMeaning',
          'r5:chooseMeaning',
          'r6:chooseMeaning',
          'r7:chooseMeaning',
          'r8:chooseMeaning',
          'r9:chooseMeaning',
        ]);

        final items = <SessionItem>[
          item(cardAsk('s', target: 'yo soy Ana'), DrillMode.production),
          item(
            cardAsk('p', target: 'muy bien', pos: 'phrase'),
            DrillMode.production,
          ),
          item(cardAsk('w', target: 'buenos días'), DrillMode.production),
          item(cardAsk('l', target: 'yo soy Ana'), DrillMode.listening),
        ];
        expect(asked(items), <String>[
          's:rearrange',
          'p:rearrange',
          'w:own',
          // Hearing a sentence is never rearranged: it asks the meaning.
          'l:hearMeaning',
        ]);
      });
    });

    group('Hear (ADR-0034)', () {
      final now = DateTime(2026, 10, 8, 9);
      SessionItem heard(String id, {FsrsState? state}) => SessionItem(
        card: cardAsk(id),
        mode: DrillMode.listening,
        state: state,
      );
      final remembered = Fsrs.next(null, 4, now: now);
      final missed = Fsrs.next(
        remembered,
        1,
        now: now.add(const Duration(days: 3)),
      );

      test('chooses the meaning while new or last missed, types it once '
          'remembered', () {
        expect(
          asked(<SessionItem>[
            heard('a'),
            heard('b', state: missed),
            heard('c', state: remembered),
          ]),
          <String>['a:hearMeaning', 'b:hearMeaning', 'c:own'],
        );
      });
    });
  });

  group('sets', () {
    group('the deck format', () {
      test(
        'a set card is read into the deck\'s sets, its layer giving its name '
        'and explanation',
        () {
          final deck = mergeLayer(
            DeckParser.parseCore(coreWith(refSet + ruleSets), source: 'c.yaml'),
            DeckParser.parseLayer(layerWith(texts), source: 'l.yaml'),
            source: 'l.yaml',
          );
          expect(deck.cards.map((c) => c.id), isNot(contains('zz-9201')));
          expect(deck.sets.map((s) => s.id), ['zz-9201', 'zz-9202', 'zz-9203']);
          final words = deck.sets.first;
          expect(words.name, 'Three first words');
          expect(words.explanation, 'Three words you meet first.');
          expect(words.members, ['zz-9001', 'zz-9004', 'zz-9006']);
          expect(words.rule, isNull);
          final noun = deck.sets[1].rule!;
          expect(
            (noun.rule, noun.axis, noun.value, noun.fixesRow),
            ('zz-grammar-case-endings', 'noun', 'అమ్మ', true),
          );
          expect(deck.sets[2].rule!.fixesRow, isFalse);
          expect(deck.sets[2].shown, ['zz-9004', 'zz-9001']);
          expect(deck.sets[1].shown, isEmpty);
          // A deck's set survives its cards being replaced, as refs resolve.
          expect(deck.withCards(const <Card>[]).sets, hasLength(3));

          final core = DeckParser.parseCore(coreWith(refSet), source: 'c.yaml');
          expect(
            () => mergeLayer(
              core,
              DeckParser.parseLayer(
                homeLayer.replaceFirst(
                  'cards:\n',
                  'cards:\n  "zz-9201":\n    native: "Words"\n',
                ),
                source: 'l.yaml',
              ),
              source: 'l.yaml',
            ),
            fails('explanation is required'),
          );
          expect(
            () => mergeLayer(
              DeckParser.parseCore(homeCore, source: 'c.yaml'),
              DeckParser.parseLayer(
                homeLayer.replaceFirst(
                  '    native: "mother"\n',
                  '    native: "mother"\n    explanation: "x"\n',
                ),
                source: 'l.yaml',
              ),
              source: 'l.yaml',
            ),
            fails('explanation is only for a set card'),
          );
        },
      );
    });

    group('a lesson with sets', () {
      // Telugu: one verb across nine forms, the request last, then one
      // person across six verbs: both sets, then drills.
      const slots = [
        'nenu',
        'memu',
        'manam',
        'nuvvu',
        'miru',
        'atanu',
        'ame-adi',
        'vallu',
        'please',
      ];
      const verbs = ['ceyu', 'vellu', 'ra', 'tinu', 'tagu', 'cudu'];
      final table = <Card>[
        for (final verb in verbs)
          for (final slot in slots) cellSetCards(verb, slot, '$verb-$slot'),
      ];
      Card form(String verb, String slot) =>
          table.firstWhere((c) => c.target == '$verb-$slot');
      final fresh = <Card>{
        form('tagu', 'atanu'),
        form('tagu', 'ame-adi'),
        form('tagu', 'please'),
        form('cudu', 'atanu'),
      };
      // Listed person first: the order comes from the lesson, not the deck.
      final person = ResolvedSet(
        set: ruleSet('person', 'person', 'atanu'),
        members: setMembers(
          ruleSet('person', 'person', 'atanu'),
          table,
          ruleOf: rulesOf,
        ),
      );
      final verb = ResolvedSet(
        set: ruleSet('verb', 'verb', 'tagu'),
        members: setMembers(
          ruleSet('verb', 'verb', 'tagu'),
          table,
          ruleOf: rulesOf,
        ),
      );

      LessonSets telugu(List<Card> picked) => lessonSets(
        picked,
        sets: [person, verb],
        isNew: fresh.contains,
        isKnown: (c) => !fresh.contains(c),
      );

      // Hindi: आप (āp), तुम (tum) known, तू (tū).
      final ap = wordSetCards('hi-1', 'आप', reading: 'āp');
      final tum = wordSetCards('hi-2', 'तुम', reading: 'tum');
      final tu = wordSetCards('hi-3', 'तू', reading: 'tū');
      final other = wordSetCards('hi-4', 'घर', reading: 'ghar');
      final you = ResolvedSet(
        set: const CardSet(
          id: 'hi-9001',
          deckId: 'hi-en-a',
          name: 'You',
          explanation: 'Three words for you.',
        ),
        members: [ap, tum, tu],
      );

      test(
        'the set comes first, its known member marked, and every new form is '
        'taught once',
        () {
          final lesson = lessonSets(
            [ap, other],
            sets: [you],
            isNew: (c) => c != tum,
            isKnown: (c) => c == tum,
          );
          expect(lesson.parts, hasLength(1));
          final part = lesson.parts.single;
          expect(part.members, [ap, tum, tu]);
          expect(part.isKnown(tum), isTrue);
          expect(part.isKnown(ap), isFalse);
          expect(part.isSplit, isFalse);
          // तू (tū) comes with आप (āp), though the lesson did not pick it.
          expect(lesson.cards, [ap, tu, other]);
          expect(lesson.members, {'hi-1', 'hi-3'});

          {
            final lesson = telugu([form('tagu', 'atanu')]);
            expect(lesson.cards, [
              form('tagu', 'atanu'),
              form('tagu', 'ame-adi'),
              form('tagu', 'please'),
              form('cudu', 'atanu'),
            ]);
            expect(lesson.members, hasLength(4));
          }
        },
      );
    });

    group('aksharas', () {
      test('a line breaks only between aksharas, never inside one', () {
        expect(aksharasOf('తాగుతుంది'), ['తా', 'గు', 'తుం', 'ది']);
        expect(aksharasOf('చూస్తాడు'), ['చూ', 'స్తా', 'డు']);
        expect(aksharasOf('क्षत्रिय'), ['क्ष', 'त्रि', 'य']);
        expect(aksharasOf('আপনি'), ['আ', 'প', 'নি']);
        expect(aksharasOf('తాగుతుంది').join(), 'తాగుతుంది');
        expect(breakableWord('తాగుతుంది'), 'తా​గు​తుం​ది');
        // Short words, and text with spaces, are left as they are.
        expect(breakableWord('తాగు'), 'తాగు');
        expect(breakableWord('ఇంటి నుంచి'), 'ఇంటి నుంచి');
      });
    });
  });

  group('sets on screen', () {
    testWidgets('the set comes first; a split set shows its parts', (
      tester,
    ) async {
      usePhone(tester);
      final state = learner();
      await openLesson(tester, state);
      final l10n = l10nOf(tester);
      expect(find.byType(SetDrill), findsOneWidget);
      expect(find.text(l10n.setTitle), findsOneWidget);
      expect(find.text('Words you meet first, together.'), findsOneWidget);
      expect(find.byType(SetMemberRow), findsNWidgets(3));
      expect(find.text(l10n.setNew), findsNWidgets(3));
      expect(find.text(l10n.setKnown), findsNothing);
      // It fits on one card: no Full list.
      expect(find.text(l10n.setFullList), findsNothing);
      expect(
        find.text(
          l10n.setNextWords(3, 'ఇల్లు (illu), అమ్మ (amma) and నేను (nēnu)'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.drillPositionShort(1, sessionOfSetDrill(tester).total)),
        findsOneWidget,
      );

      await nextCard(tester);
      expect(find.byType(TeachDrill), findsOneWidget);
      expect(state.progress.log, isEmpty);

      {
        usePhone(tester);
        final state = learner(split: true);
        await openLesson(tester, state);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.setPartTitle(1, 2)), findsOneWidget);
        expect(find.byType(SetMemberRow), findsNWidgets(3));
        // Only the last part says what comes next.
        expect(find.textContaining('Next:'), findsNothing);
        expect(find.text(l10n.setFullList), findsOneWidget);

        await tester.tap(find.text(l10n.setFullList));
        await tester.pumpAndSettle();
        expect(find.text('First words'), findsOneWidget);
        expect(find.text(l10n.setSheetWords(5, 5)), findsOneWidget);
        expect(find.byType(SetMemberRow), findsNWidgets(3 + 5));
        await tester.tap(find.byTooltip(l10n.commonClose).last);
        await tester.pumpAndSettle();
        expect(find.byType(SetMemberRow), findsNWidgets(3));

        await nextCard(tester);
        expect(find.text(l10n.setPartTitle(2, 2)), findsOneWidget);
        expect(find.textContaining('Next:'), findsOneWidget);
      }
    });
  });

  group('number practice', () {
    final hi = bundled('hi');

    test('heard, a number is answered in digits, shown, in words; only the '
        'skills asked for', () {
      final typed = numberPractice(
        hi,
        deckId: 'hi-en-numbers-big',
        modes: const <DrillMode>{DrillMode.production, DrillMode.grammar},
        random: Random(1),
      );
      expect(typed.map((i) => i.mode).toSet(), {DrillMode.production});
      expect(
        numberPractice(
          hi,
          deckId: 'hi-en-numbers-big',
          modes: const <DrillMode>{DrillMode.grammar},
          random: Random(1),
        ),
        isEmpty,
      );

      final card = numberCard(
        number: 2020,
        spellings: spellNumber(hi, 2020),
        rulesId: hi.id,
        deckId: 'hi-en-numbers-big',
      );
      expect(card.acceptedAnswers(DrillMode.listening), <String>['2020']);
      expect(card.acceptedAnswers(DrillMode.production), <String>[
        'दो हज़ार बीस',
        'दो हजार बीस',
      ]);
      expect(card.acceptedAnswers(DrillMode.recognition), <String>['2020']);
      expect(card.promptFor(DrillMode.production), '2020');
      expect(card.promptFor(DrillMode.recognition), 'दो हज़ार बीस');
    });
  });

  group('spelling numbers', () {
    group('Hindi: every number to 99 is a word of its own', () {
      final hi = bundled('hi');

      test('the spelling follows each rules file: 2020 joined, and a hundred '
          'changes its form when more follows', () {
        expect(spellNumber(hi, 2020).first, 'दो हज़ार बीस');
        expect(spellNumber(hi, 2020), contains('दो हजार बीस'));
        expect(spellNumber(hi, 1950).first, 'एक हज़ार नौ सौ पचास');
        expect(spellNumber(hi, 4007).first, 'चार हज़ार सात');
        expect(spellNumber(hi, 1000).first, 'एक हज़ार');

        {
          final te = bundled('te');

          expect(spellNumber(te, 2000).first, 'రెండు వేలు');
          expect(spellNumber(te, 1200).first, 'వెయ్యి రెండు వందలు');
          expect(spellNumber(te, 1150).first, 'వెయ్యి నూట యాభై');
          expect(spellNumber(te, 250).first, 'రెండు వందల యాభై');
        }
      });
    });

    group('a file that is not number rules is refused', () {
      final good = File('decks/hi/hi-numbers.yaml').readAsStringSync();

      test(
        'a malformed rules file is refused: the wrong kind, a hundred missing',
        () {
          expect(
            () => parseNumberRules(
              good.replaceFirst('kind: numbers', 'kind: vocab'),
              source: 'x',
            ),
            refusedWith('"kind: numbers"'),
          );

          expect(
            () => parseNumberRules(
              good.replaceFirst(RegExp(r'\n  9: .*सौ.*'), ''),
              source: 'x',
            ),
            refusedWith('hundreds needs an entry for 9'),
          );
        },
      );
    });
  });

  group('a tag\'s practice', () {
    test('a tag\'s practice is a capped set of taught words carrying the tag, '
        'and records every answer', () async {
      final state = await knowing(8);
      final tag = state.deckById('hi-en-phrasebook')!.cards.first.tags.first;
      final request = DrillRequest.tag(tag, count: 3, language: 'hi');
      expect(request.recordsRevision, isTrue);
      final items = state.sessionItems(request);
      final words = <String>{for (final item in items) item.card.id};
      expect(words, isNotEmpty);
      expect(words.length, lessThanOrEqualTo(3));
      for (final item in items) {
        expect(item.card.tags, contains(tag));
        expect(state.isTaught(item.card), isTrue);
      }
    });
  });
  group('a deck\'s known cards come up a few at a time', () {
    final cards = <Card>[
      for (var i = 0; i < 12; i++)
        Card(
          id: 'k$i',
          deckId: 'known',
          target: 't$i',
          native: 'n$i',
          modes: const {DrillMode.recognition},
        ),
    ];

    /// A known card due a day before [at], last reviewed [daysAgo] days
    /// before it.
    FsrsState known(DateTime at, {int daysAgo = 30}) => FsrsState(
      stability: 20,
      difficulty: 5,
      repetitions: 3,
      intervalDays: 20,
      dueAt: at.subtract(const Duration(days: 1)),
      lastReviewAt: at.subtract(Duration(days: daysAgo)),
      recallAtReview: 0.92,
    );

    /// A known card reviewed right at [at], so not due for weeks.
    FsrsState passed(DateTime at) => FsrsState(
      stability: 25,
      difficulty: 5,
      repetitions: 4,
      intervalDays: 25,
      dueAt: at.add(const Duration(days: 25)),
      lastReviewAt: at,
      recallAtReview: 0.93,
    );

    FsrsState missed(DateTime at) => FsrsState(
      stability: 1,
      difficulty: 6,
      repetitions: 0,
      intervalDays: 1,
      dueAt: at.add(const Duration(days: 1)),
      lastReviewAt: at,
      lapses: 1,
    );

    List<String> due(
      Map<String, FsrsState> states, {
      DateTime? at,
      int take = 12,
    }) => SessionQueue.build(
      cards: cards.take(take),
      stateOf: (c, m) => states[c.id],
      hasVoice: (_) => false,
      now: at ?? now,
      newCardLimit: 0,
      sampleKnown: true,
    ).due.map((i) => i.card.id).toList();

    // k0 was reviewed longest ago, then k1, and so on.
    Map<String, FsrsState> pending() => {
      for (var i = 0; i < 12; i++) 'k$i': known(now, daysAgo: 60 - i),
    };

    test('a pending deck shows two, the ones reviewed longest ago', () {
      expect(due(pending()), <String>['k0', 'k1']);
    });

    test('a passed sample holds the rest for the day, and the cards not '
        'sampled have their turn before any is sampled again', () {
      final states = pending();
      for (final id in <String>['k0', 'k1']) {
        states[id] = passed(now);
      }
      expect(due(states), isEmpty);
      // The next day the deck is sampled again, the cards not yet reviewed
      // first, though the others are due too.
      final later = now.add(const Duration(days: 1));
      expect(due(states, at: later), <String>['k2', 'k3']);
    });

    test('a failed sample asks more, and a second failure brings every due '
        'known card of the deck', () {
      final states = pending();
      states['k0'] = missed(now);
      states['k1'] = passed(now);
      final more = due(states);
      expect(more.length, inInclusiveRange(3, 5));
      expect(more.first, 'k2');
      states['k2'] = missed(now);
      expect(due(states), <String>[for (var i = 3; i < 12; i++) 'k$i']);
    });

    test('a skill\'s own review sees the deck\'s misses in the other skills, '
        'so its tile and its session agree', () {
      final two = <Card>[
        for (var i = 0; i < 12; i++)
          Card(id: 'm$i', deckId: 'known', target: 't$i', native: 'n$i'),
      ];
      // Two known Recognition cards were right today, ten wait, and one
      // Write was missed today: the deck is stressed.
      FsrsState? stateOf(Card c, DrillMode m) {
        final i = int.parse(c.id.substring(1));
        if (m == DrillMode.recognition) {
          return i < 2 ? passed(now) : known(now, daysAgo: 60 - i);
        }
        if (m == DrillMode.production && i == 5) return missed(now);
        return null;
      }

      List<String> session(Set<DrillMode> modes, {Set<DrillMode>? sample}) =>
          SessionQueue.build(
            cards: two,
            stateOf: stateOf,
            hasVoice: (_) => false,
            now: now,
            newCardLimit: 0,
            sampleKnown: true,
            sampleModes: sample,
            modes: modes,
          ).due.map((i) => '${i.card.id}/${i.mode.name}').toList();

      const both = <DrillMode>{DrillMode.recognition, DrillMode.production};
      const read = <DrillMode>{DrillMode.recognition};
      expect(session(both), isNotEmpty, reason: 'Today asks more');
      expect(
        session(read),
        isEmpty,
        reason: 'the bug: Recognition alone does not see the miss',
      );
      expect(
        session(read, sample: both),
        isNotEmpty,
        reason: 'Recognition sampled by every skill\'s pairs agrees',
      );
    });

    test('a card is known when it was likely recalled at its last review, '
        'not by how long its interval is', () {
      final states = pending();
      // k0 and k1 were remembered at 60%, reviewed late: not known, so they
      // come up whatever the sample is.
      for (final id in <String>['k0', 'k1']) {
        final s = states[id]!;
        states[id] = FsrsState(
          stability: s.stability,
          difficulty: s.difficulty,
          repetitions: s.repetitions,
          intervalDays: 60,
          dueAt: s.dueAt,
          lastReviewAt: s.lastReviewAt,
          recallAtReview: 0.6,
        );
      }
      expect(
        due(states),
        containsAll(<String>['k0', 'k1']),
        reason: 'not known, so never held back',
      );
      expect(due(states), hasLength(4), reason: 'and two known samples');
    });

    /// A known card reviewed on time: last reviewed [interval] days before
    /// it came due, a minute apart per [i], so the order is fixed.
    FsrsState onTime(DateTime at, int i, {int interval = 20}) {
      final dueAt = at.subtract(Duration(minutes: 11 - i));
      return FsrsState(
        stability: interval + 0.4,
        difficulty: 5,
        repetitions: 3,
        intervalDays: interval,
        dueAt: dueAt,
        lastReviewAt: dueAt.subtract(Duration(days: interval)),
        recallAtReview: 0.9,
      );
    }

    /// Plays days of sessions on a deck of 12 known cards, all due on day 0,
    /// each shown card reviewed right when it is shown. Returns the day each
    /// card was reviewed on, and checks the day's rules on the way.
    Map<String, int> playDays(int interval, int days) {
      final states = <String, FsrsState>{
        for (var i = 0; i < 12; i++) 'k$i': onTime(now, i, interval: interval),
      };
      final reviewedOn = <String, int>{};
      for (var day = 0; day < days; day++) {
        final at = now.add(Duration(days: day));
        final shown = due(states, at: at);
        expect(
          shown.length,
          lessThanOrEqualTo(kSampleSize),
          reason: 'day $day: only a small sample of the known cards',
        );
        for (final id in shown) {
          expect(
            reviewedOn,
            isNot(contains(id)),
            reason: '$id asked again before every card had a turn',
          );
          states[id] = Fsrs.next(states[id], 4, now: at);
          expect(
            isKnownState(states[id]!),
            isTrue,
            reason: '$id is still known after a right review on time',
          );
          reviewedOn[id] = day;
        }
        expect(
          due(states, at: at),
          isEmpty,
          reason: 'day $day: a passed sample holds the rest until tomorrow',
        );
      }
      return reviewedOn;
    }

    test('sampling rotates through the whole deck, so every card is '
        'eventually reviewed, the ones reviewed longest ago first', () {
      final reviewedOn = playDays(20, 12);
      expect(reviewedOn, hasLength(12));
      // Two a day, in the order they were last reviewed.
      expect(reviewedOn.keys.toList(), <String>[
        for (var i = 0; i < 12; i++) 'k$i',
      ]);
    });

    test('a known card due waits a few days, not its whole interval, for '
        'its turn', () {
      // At 30-day intervals, holding the deck for the samples' interval
      // would leave the last of 12 cards waiting months.
      final reviewedOn = playDays(30, 12);
      expect(reviewedOn, hasLength(12));
      expect(
        reviewedOn.values.reduce(max),
        lessThanOrEqualTo(12 ~/ kSampleSize - 1),
        reason: 'every card is reviewed within six days of being due',
      );
    });

    test('a card missed and then answered right the same day is not '
        'known, and its miss still counts as a failed sample', () {
      var s = FsrsState(
        stability: 20.4,
        difficulty: 5,
        repetitions: 3,
        intervalDays: 20,
        dueAt: now.add(const Duration(days: 15)),
        lastReviewAt: now.subtract(const Duration(days: 5)),
        recallAtReview: 0.9,
      );
      s = Fsrs.review(s, Rating.again, now: now);
      expect(s.recallAtReview, greaterThan(0.9), reason: 'it was well known');
      s = Fsrs.review(s, Rating.good, now: now.add(const Duration(hours: 1)));
      expect(s.repetitions, 1);
      expect(isKnownState(s), isFalse);

      final states = pending();
      states['k0'] = s;
      expect(
        due(states, at: now.add(const Duration(hours: 1))).length,
        inInclusiveRange(kStressMin, kStressTotal),
        reason: 'the failed sample asks more, not the usual two',
      );
    });

    test('cards still being learned are not sampled', () {
      final states = <String, FsrsState>{
        for (var i = 0; i < 5; i++) 'k$i': dueDaysAgo(1),
      };
      expect(due(states, take: 5), hasLength(5));
    });
  });
}
