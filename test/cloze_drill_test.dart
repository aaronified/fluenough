// The cloze drill (#321): the meaning above, the sentence with a known word
// left out, and the words to choose it from, graded by the exact word and
// recorded in Write; in Latin letters when the learner writes in them.
import 'dart:math';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/cloze_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const String _spanish = '''
schema: 1
id: es-fixture-cloze
name: "Spanish (cloze fixture)"
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-fixture-9001
    target: "yo"
    native: "I"
    pos: pronoun
  - id: es-fixture-9002
    target: "tengo"
    native: "I have"
    pos: verb
  - id: es-fixture-9003
    target: "un"
    native: "a"
    pos: adj
  - id: es-fixture-9004
    target: "perro"
    native: "dog"
    pos: noun
  - id: es-fixture-9005
    target: "gato"
    native: "cat"
    pos: noun
  - id: es-fixture-9006
    target: "casa"
    native: "house"
    pos: noun
  - id: es-fixture-9007
    target: "libro"
    native: "book"
    pos: noun
  - id: es-fixture-9010
    target: "yo tengo un perro"
    native: "I have a dog"
    pos: phrase
    bases:
      - { word: "tengo", ref: "es-fixture-9002" }
      - { word: "perro", ref: "es-fixture-9004" }
''';

const String _marathi = '''
schema: 1
id: mr-fixture-cloze
name: "Marathi (cloze fixture)"
kind: vocab
language: { code: mr, iso639_3: mar, name: Marathi, script: devanagari, tts: mr-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: mr-fixture-9001
    target: "माझ्याकडे"
    reading: "mājhyākaḍē"
    native: "I have"
    pos: pronoun
  - id: mr-fixture-9002
    target: "एक"
    reading: "ēk"
    native: "a"
    pos: adj
  - id: mr-fixture-9003
    target: "कुत्रा"
    reading: "kutrā"
    native: "dog"
    pos: noun
  - id: mr-fixture-9004
    target: "आहे"
    reading: "āhē"
    native: "is"
    pos: verb
  - id: mr-fixture-9005
    target: "मांजर"
    reading: "māñjar"
    native: "cat"
    pos: noun
  - id: mr-fixture-9006
    target: "घर"
    reading: "ghar"
    native: "house"
    pos: noun
  - id: mr-fixture-9007
    target: "पुस्तक"
    reading: "pustak"
    native: "book"
    pos: noun
  - id: mr-fixture-9010
    target: "माझ्याकडे एक कुत्रा आहे"
    reading: "mājhyākaḍē ēk kutrā āhē"
    native: "I have a dog"
    pos: phrase
''';

/// A learner of the fixtures, who has [known] the word cards of [deck] by
/// number: each answered right three times, a minute apart.
Future<AppState> _learner({required int knownCards}) async {
  final progress = MemoryProgress();
  final start = DateTime(2026, 1, 1, 9);
  for (final (deck, prefix) in <(String, String)>[
    ('es-fixture-cloze', 'es-fixture-90'),
    ('mr-fixture-cloze', 'mr-fixture-90'),
  ]) {
    for (var n = 1; n <= knownCards; n++) {
      for (var i = 0; i < 3; i++) {
        progress.record(
          deckId: deck,
          cardId: '$prefix${n.toString().padLeft(2, '0')}',
          mode: DrillMode.recognition,
          grade: 4,
          now: start.add(Duration(minutes: i)),
        );
      }
    }
  }
  final state = AppState.test(
    decks: MemoryDeckSource(const <String, String>{
      'decks/es/es-fixture-cloze.yaml': _spanish,
      'decks/mr/mr-fixture-cloze.yaml': _marathi,
    }),
    progress: progress,
    tts: FixedTtsEngine(<String>{'es', 'mr'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: Skill.values.toSet(),
    ),
  );
  await state.load();
  return state;
}

Card _sentence(AppState state, String deck, String id) =>
    state.deckById(deck)!.cards.firstWhere((card) => card.id == id);

DrillSession _session(
  AppState state,
  Card sentence, {
  InputMode? inputMode,
  int seed = 1,
}) {
  final session = DrillSession(
    state: state,
    items: <SessionItem>[
      SessionItem(
        card: sentence,
        mode: DrillMode.production,
        state: null,
        ask: Ask.cloze,
      ),
    ],
    inputMode: inputMode,
    random: Random(seed),
  );
  addTearDown(session.dispose);
  return session;
}

void main() {
  group('the session', () {
    late AppState state;
    late Card sentence;

    setUp(() async {
      state = await _learner(knownCards: 7);
      sentence = _sentence(state, 'es-fixture-cloze', 'es-fixture-9010');
    });

    tearDown(() => state.dispose());

    test('asks the sentence as a cloze on a known word, with the words to '
        'choose from', () {
      final session = _session(state, sentence);
      expect(session.ask, Ask.cloze);
      // perro is the only word with other known nouns to stand beside.
      expect(session.cloze!.gap.word.id, 'es-fixture-9004');
      final view = session.clozeView!;
      expect(view.answer, 'perro');
      expect(view.before, 'yo tengo un ');
      expect(view.after, '');
      expect(view.options.toSet(), <String>{'perro', 'gato', 'casa', 'libro'});
    });

    test('a right word is recorded in Write as a choice, a hard recall', () {
      final session = _session(state, sentence);
      session.pickCloze('perro');
      expect(session.answer!.graded!.outcome.isCorrect, isTrue);
      expect(session.answer!.grade, DrillSession.scheduledChoiceGrade);
      final event = state.progress.log.last;
      expect(event.cardId, 'es-fixture-9010');
      expect(event.mode, DrillMode.production);
      expect(event.grade, DrillSession.scheduledChoiceGrade);
      expect(event.asked, Ask.cloze);
      expect(event.answerGiven, 'perro');
    });

    test('any other word is wrong, recorded as a miss', () {
      final session = _session(state, sentence);
      session.pickCloze('gato');
      expect(session.answer!.graded!.outcome, AnswerOutcome.wrong);
      final event = state.progress.log.last;
      expect(event.grade, 1);
      expect(event.asked, Ask.cloze);
    });

    test('is answered once, and only with a word it offers', () {
      final session = _session(state, sentence);
      session.pickCloze('mesa');
      expect(session.answer, isNull);
      session.pickCloze('perro');
      final recorded = state.progress.log.length;
      session.pickCloze('gato');
      expect(state.progress.log.length, recorded);
      expect(session.clozePicked, 'perro');
    });

    test('falls back to rearrange when no word is known', () async {
      final fresh = await _learner(knownCards: 0);
      addTearDown(fresh.dispose);
      final session = _session(
        fresh,
        _sentence(fresh, 'es-fixture-cloze', 'es-fixture-9010'),
      );
      expect(session.cloze, isNull);
      expect(session.ask, Ask.rearrange);
    });
  });

  group('the Script and Latin letters switch', () {
    late AppState state;
    late Card sentence;

    setUp(() async {
      state = await _learner(knownCards: 7);
      sentence = _sentence(state, 'mr-fixture-cloze', 'mr-fixture-9010');
    });

    tearDown(() => state.dispose());

    test('in the script, the sentence and the words are in it', () {
      final session = _session(state, sentence, inputMode: InputMode.script);
      expect(session.transliterating, isFalse);
      final view = session.clozeView!;
      expect(view.reading, isFalse);
      expect(view.answer, 'कुत्रा');
      expect(view.before, 'माझ्याकडे एक ');
      expect(view.options, contains('मांजर'));
    });

    test('in Latin letters, the reading is shown and the word chosen in it, '
        'graded as the same word', () {
      final session = _session(state, sentence, inputMode: InputMode.translit);
      expect(session.transliterating, isTrue);
      final view = session.clozeView!;
      expect(view.reading, isTrue);
      expect(view.answer, 'kutrā');
      expect(view.before, 'mājhyākaḍē ēk ');
      expect(view.after, ' āhē');
      expect(view.options.toSet(), <String>{
        'kutrā',
        'māñjar',
        'ghar',
        'pustak',
      });
      session.pickCloze('kutrā');
      expect(session.answer!.graded!.outcome.isCorrect, isTrue);
      expect(state.progress.log.last.asked, Ask.cloze);
    });

    test('and back again', () {
      final session = _session(state, sentence, inputMode: InputMode.translit);
      expect(session.clozeView!.reading, isTrue);
      session.inputMode = InputMode.script;
      expect(session.clozeView!.reading, isFalse);
      expect(session.clozeView!.answer, 'कुत्रा');
    });
  });

  group('the screen', () {
    Future<AppState> pump(WidgetTester tester) async {
      usePhone(tester);
      final state = (await tester.runAsync(() => _learner(knownCards: 7)))!;
      addTearDown(state.dispose);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'es-fixture-cloze',
            skill: Skill.production,
          ),
          preset: const DrillPreset(
            target: 'yo tengo un perro',
            ask: Ask.cloze,
          ),
        ),
        state: state,
        settle: false,
      );
      // Wait, capped, for the screen; never for the frames to settle.
      for (var i = 0; i < 40; i++) {
        if (find.byType(ClozeDrill).evaluate().isNotEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      return state;
    }

    Future<void> tap(WidgetTester tester, String word) async {
      await tester.tap(find.text(word));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows the meaning, the sentence with a gap and the words', (
      tester,
    ) async {
      await pump(tester);
      final l10n = l10nOf(tester);
      expect(find.byType(ClozeDrill), findsOneWidget);
      expect(find.text(l10n.drillClozePrompt), findsOneWidget);
      expect(find.text('I have a dog'), findsOneWidget);
      expect(find.text('yo tengo un ${ClozeDrill.blank}'), findsOneWidget);
      for (final word in <String>['perro', 'gato', 'casa', 'libro']) {
        expect(find.text(word), findsOneWidget, reason: word);
      }
    });

    testWidgets('a right word fills the gap and is marked right', (
      tester,
    ) async {
      final state = await pump(tester);
      await tap(tester, 'perro');
      expect(find.text(l10nOf(tester).feedbackCorrect), findsOneWidget);
      expect(find.text('yo tengo un perro'), findsOneWidget);
      expect(find.text(ClozeDrill.blank), findsNothing);
      expect(state.progress.log.last.grade, DrillSession.scheduledChoiceGrade);
    });

    testWidgets('a wrong word is marked wrong, with the right one shown', (
      tester,
    ) async {
      final state = await pump(tester);
      await tap(tester, 'gato');
      final l10n = l10nOf(tester);
      expect(find.text(l10n.feedbackWrong), findsOneWidget);
      expect(find.text(l10n.feedbackAnswer('perro')), findsOneWidget);
      expect(find.text('gato'), findsOneWidget);
      expect(find.text('casa'), findsNothing);
      expect(state.progress.log.last.grade, 1);
    });
  });
}
