// Split out of lesson_and_review_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: Hear, the IPA line, speaking, try again and Hear yourself, grammar questions, the grammar drill, minimal pairs, reading.

import 'dart:io';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/rule_expander.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/grammar_pattern.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:fluenough/core/sound/sound_check.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/grammar_cells.dart';
import 'package:fluenough/features/drill/grammar_drill.dart';
import 'package:fluenough/features/drill/pair_drill.dart';
import 'package:fluenough/features/drill/pair_fixture.dart';
import 'package:fluenough/features/drill/reading_drill.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/features/drill/speaking_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/ui/widgets/feedback_banner.dart';
import 'package:fluenough/ui/widgets/incoming.dart';
import 'package:fluenough/ui/widgets/ipa_line.dart';
import 'package:fluenough/ui/widgets/play_button.dart';
import 'package:fluenough/ui/widgets/speaker.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'support/fit_learner.dart';
import 'support/harness.dart';
import 'support/lesson_and_review_shared.dart';

// From hear_test.dart.
/// Hear (ADR-0034): the word is played, and its meaning chosen while the
/// pair is new or was last missed, typed once it was last remembered. In
/// script practice what was heard is typed instead.

const String spanishHear = 'es-fixture-hear';

/// A small Spanish deck, in memory, with a meaning in parts.
MemoryDeckSource fixtureDecks() => MemoryDeckSource(const <String, String>{
  'decks/es/$spanishHear.yaml': '''
schema: 1
id: es-fixture-hear
name: "Spanish (Hear fixture)"
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-fixture-hear-0001
    target: "ir"
    native: "to go, to leave"
  - id: es-fixture-hear-0002
    target: "la casa"
    native: "the house"
    alt_native: ["the home"]
  - id: es-fixture-hear-0003
    target: "el perro"
    native: "the dog"
  - id: es-fixture-hear-0004
    target: "el gato"
    native: "the cat"
  - id: es-fixture-hear-0005
    target: "la mesa"
    native: "the table"
''',
});

AppState spanishState({MemoryProgress? progress, DateTime? now}) =>
    AppState.test(
      decks: fixtureDecks(),
      tts: FixedTtsEngine(const <String>{'es'}),
      progress: progress,
      now: now,
    );

/// [target] of the fixture deck heard, typed, as a remembered word is.
Future<AppState> pumpTyped(WidgetTester tester, String target) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(spanishHear, skill: Skill.listening),
    preset: DrillPreset(target: target),
  ),
  state: spanishState(),
);

Future<void> typeAndCheckHear(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.pump();
  await tapText(tester, l10nOf(tester).drillCheck);
}

/// `la ventana`, as the deck says it.
const String ventana = '/la benˈtana/';

AppState ipaApp({bool showIpa = true, double cardTextScale = 1.0}) =>
    AppState.test(
      tts: FixedTtsEngine(<String>{'es', 'hi', 'bn'}),
      settings: SettingsNotifier(cardTextScale: cardTextScale)
        ..showIpa = showIpa,
    );

Future<AppState> pumpDrillIpaLine(
  WidgetTester tester,
  DrillRequest request, {
  DrillPreset? preset,
  AppState? state,
}) => pumpScreen(
  tester,
  DrillPage(request: request, preset: preset),
  state: state ?? ipaApp(),
);

Finder ipaLine(String shown) =>
    find.descendant(of: find.byType(IpaLine), matching: find.text(shown));

// From speaking_drill_test.dart.
/// The speaking drill, the switch that turns speaking on, and the Voices
/// page's speech section (#89, ADR-0014).

AppState speakingState(FixedSpeechEngine speech, {bool on = true}) =>
    AppState.test(
      speech: speech,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: <Skill>{
          ...Skill.values.where((s) => s.onByDefault),
          if (on) Skill.speaking,
        },
      ),
    );

Future<AppState> pumpSpeaking(
  WidgetTester tester,
  FixedSpeechEngine speech,
) async {
  final state = speakingState(speech);
  await state.load();
  await state.startSpeech();
  await pumpScreen(
    tester,
    DrillPage(request: DrillRequest.untaught(spanish, skill: Skill.speaking)),
    state: state,
  );
  return state;
}

Future<void> speak(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  final mic = find.bySemanticsLabel(l10n.drillSpeak);
  await tester.ensureVisible(mic);
  await tester.pumpAndSettle();
  await tester.tap(mic);
  await tester.pumpAndSettle();
}

// From speaking_retry_test.dart.
/// Trying a pronunciation again, and hearing yourself then the voice
/// (#231, ADR-0014): the first answer is the one
/// recorded; a try again is graded and shown, never recorded.

/// What was played, in order: the learner's recording, then the voice.
final List<String> _played = <String>[];

/// A sound check that also notes, in [_played], when it plays.
class _OrderedSoundCheck extends FixedSoundCheck {
  _OrderedSoundCheck();

  @override
  Future<bool> play(Recording recording) async {
    _played.add('self');
    return super.play(recording);
  }
}

/// A voice that also notes, in [_played], what it says.
class _OrderedTts extends FixedTtsEngine {
  _OrderedTts() : super(<String>{'es'});

  @override
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) async {
    _played.add('voice $text');
    return super.speak(text, bcp47: bcp47, rate: rate, voice: voice);
  }
}

AppState _state(
  FixedSpeechEngine speech, {
  SoundCheckEngine? soundCheck,
  TtsEngine? tts,
}) => AppState.test(
  speech: speech,
  soundCheck: soundCheck ?? _OrderedSoundCheck(),
  tts: tts ?? _OrderedTts(),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
    enabledSkills: <Skill>{
      ...Skill.values.where((s) => s.onByDefault),
      Skill.speaking,
    },
  ),
);

String _unaccented(String text) => text
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');
const rulesDeck = 'zz-en-grammar-case-endings';
final rulesCore = read('$appendix/zz-grammar-case-endings.yaml');
final rulesLayer = read('$appendix/en/zz-en-grammar-case-endings.yaml');

Deck merge(String core, String layer) => mergeLayer(
  DeckParser.parseCore(core, source: 'core.yaml'),
  DeckParser.parseLayer(layer, source: 'layer.yaml'),
  source: 'layer.yaml',
);

/// The rules deck's cells, from [core] and [layer] as edited.
List<Card> cellsOf({String? core, String? layer}) {
  final home = merge(homeCore, homeLayer);
  return expandRules(
    merge(core ?? rulesCore, layer ?? rulesLayer),
    wordOf: (id) => home.cards.where((c) => c.id == id).firstOrNull,
  );
}

/// Every file of the example set, keyed as the catalog keys bundled decks.
Map<String, String> appendixFiles() => <String, String>{
  for (final file in Directory(appendix).parent.listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/${file.path.substring(Directory(appendix).parent.path.length + 1)}':
          file.readAsStringSync(),
};

// From grammar_drill_test.dart.
/// The real bundled pattern, as the drill reads it.
Future<GrammarPattern> realPattern() async {
  final state = AppState.test();
  await state.load();
  return state.deckById(grammarFixtureDeckId)!.deck.pattern!;
}

AppState grammarOn() => AppState.test(features: FeatureRegistry.all());

FeedbackBanner banner(WidgetTester tester) =>
    tester.widget<FeedbackBanner>(find.byType(FeedbackBanner));

AppState pairOn([FixedTtsEngine? tts]) => AppState.test(
  features: FeatureRegistry.all(),
  tts: tts ?? FixedTtsEngine(const <String>{'hi'}),
);

final DrillRequest readReadingDrill = DrillRequest.untaught(
  readingFixtureDeckId,
  skill: Skill.reading,
);

const List<String> shop = <String>[
  'নমস্কার। কত দাম?',
  'পঞ্চাশ টাকা।',
  'একটু কম করুন।',
  'আচ্ছা। ধন্যবাদ।',
];

AppState readingApp({
  FixedTtsEngine? tts,
  SettingsNotifier? settings,
  MemoryProgress? progress,
}) => AppState.test(
  decks: readingFixtureDecks(),
  tts: tts ?? FixedTtsEngine(<String>{'bn'}),
  settings: settings,
  progress: progress,
  now: noon,
);

/// Whether the reading drill on screen is on its passage page, the one that
/// goes on to the questions by swipe or the chevron.
bool onPassagePage(WidgetTester tester) =>
    tester.widget<ReadingDrill>(find.byType(ReadingDrill)).session.showsPassage;

Future<void> tapTextReadingDrill(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Whether [finder] is drawn inside the phone's screen, not scrolled off it.
void expectOnScreen(WidgetTester tester, Finder finder) {
  expect(finder, findsWidgets);
  final rect = tester.getRect(finder.first);
  expect(
    rect.top >= 0 && rect.bottom <= 844 && rect.left >= 0 && rect.right <= 390,
    isTrue,
    reason: '$finder is at $rect, off the screen',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hear', () {
    group('a Hear choice', () {
      testWidgets(
        'a new word heard has its meaning chosen; typed, a part of the meaning '
        'is accepted',
        (tester) async {
          usePhone(tester);
          final tts = FixedTtsEngine(const <String>{'es'});
          final state = await pumpScreen(
            tester,
            DrillPage(
              request: DrillRequest.untaught(
                spanishHear,
                skill: Skill.listening,
              ),
            ),
            state: AppState.test(decks: fixtureDecks(), tts: tts),
          );
          final l10n = l10nOf(tester);
          expect(find.byType(ChoiceDrill), findsOneWidget);
          final session = tester
              .widget<ChoiceDrill>(find.byType(ChoiceDrill))
              .session;
          final card = session.item.card;
          expect(session.ask, Ask.hearMeaning);
          expect(session.item.mode, DrillMode.listening);
          expect(find.text(l10n.drillChooseHeardMeaning), findsOneWidget);
          // The options are meanings; the word is not given away.
          expect(session.options, hasLength(DrillSession.optionCount));
          for (final option in session.options) {
            expect(find.text(option.native), findsOneWidget);
            expect(find.text(option.target), findsNothing);
          }
          await tester.tap(find.byType(PlayButton));
          await tester.pumpAndSettle();
          expect(tts.spoken.last.text, card.target);

          await tapText(tester, card.native);
          final event = state.progress.log.single;
          expect(event.cardId, card.id);
          expect(event.mode, DrillMode.listening);
          expect(event.grade, DrillSession.scheduledChoiceGrade);
          expect(event.grade, 3);
          expect(event.answerGiven, card.native);
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);
          // Now the word is shown with its meaning.
          expect(find.text(card.target), findsOneWidget);

          {
            usePhone(tester);
            final state = await pumpTyped(tester, 'ir');
            final l10n = l10nOf(tester);
            final session = tester
                .widget<TypedDrill>(find.byType(TypedDrill))
                .session;
            expect(session.hearsMeaning, isTrue);
            expect(find.text(l10n.drillTypeMeaning), findsOneWidget);
            // Each part of "to go, to leave" is the meaning.
            expect(
              session.acceptedAnswers,
              containsAll(<String>['to go', 'to leave']),
            );

            await typeAndCheckHear(tester, 'to leave');
            expect(find.text(l10n.feedbackCorrect), findsOneWidget);
            final event = state.progress.log.single;
            expect(event.mode, DrillMode.listening);
            expect(event.grade, greaterThanOrEqualTo(4));
          }
        },
      );
    });

    group('script practice', () {
      testWidgets('a card is typed as heard, in the script', (tester) async {
        usePhone(tester);
        final decks = MemoryDeckSource(const <String, String>{
          'decks/hi/hi-en-script-reading.yaml': '''
schema: 1
id: hi-en-script-reading
name: "Script reading"
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-9001, target: "क", native: "ka", reading: "ka", pos: "letter" }
  - { id: hi-9002, target: "ख", native: "kha", reading: "kha", pos: "letter" }
''',
        });
        final card = (await () async {
          final s = AppState.test(decks: decks);
          await s.load();
          return s.deckById(script)!.cards.firstWhere((c) => c.reading != null);
        }());
        final state = await pumpScreen(
          tester,
          DrillPage(
            request: DrillRequest.untaught(script, skill: Skill.listening),
            preset: DrillPreset(target: card.target),
          ),
          state: AppState.test(
            decks: decks,
            tts: FixedTtsEngine(const <String>{'hi'}),
          ),
        );
        final l10n = l10nOf(tester);
        final session = tester
            .widget<TypedDrill>(find.byType(TypedDrill))
            .session;
        expect(session.hearsMeaning, isFalse);
        expect(session.acceptedAnswers.first, card.target);
        expect(find.text(l10n.drillTypeHeard), findsOneWidget);
        expect(find.text(l10n.drillTypeMeaning), findsNothing);

        await typeAndCheckHear(tester, card.target);
        expect(find.text(l10n.feedbackCorrect), findsOneWidget);
        expect(state.progress.log.single.mode, DrillMode.listening);
        expect(state.progress.log.single.grade, 5);
      });
    });
  });

  group('the IPA line', () {
    testWidgets(
      'the IPA shows on recognition from the start, and never before the '
      'answer when listening',
      (tester) async {
        usePhone(tester);
        await pumpDrillIpaLine(
          tester,
          DrillRequest.untaught(spanish, skill: Skill.recognition),
          preset: const DrillPreset(target: 'la ventana'),
        );
        expect(ipaLine(ventana), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(IpaLine)).label,
          l10nOf(tester).ipaSemantics('la benˈtana'),
        );

        usePhone(tester);
        await pumpDrillIpaLine(
          tester,
          DrillRequest.untaught(spanish, skill: Skill.listening),
          preset: const DrillPreset(target: 'la ventana'),
        );
        expect(find.byType(IpaLine), findsNothing);
      },
    );
  });

  group('speaking', () {
    testWidgets(
      'a word heard right says so; a wrong one says what was heard and the '
      'answer',
      (tester) async {
        usePhone(tester);
        final handle = tester.ensureSemantics();
        final speech = FixedSpeechEngine(onDevice: <String>{'es'});
        final state = await pumpSpeaking(tester, speech);
        final l10n = l10nOf(tester);
        expect(find.byType(SpeakingDrill), findsOneWidget);
        final card = state
            .buildSession(DrillRequest.untaught(spanish, skill: Skill.speaking))
            .items
            .first
            .card;
        expect(find.text(l10n.drillSayIn('Spanish')), findsOneWidget);
        expect(find.text(card.native), findsOneWidget);

        speech.next = <SpeechAlternative>[SpeechAlternative(card.target)];
        await speak(tester);
        expect(find.text(l10n.feedbackCorrect), findsOneWidget);
        expect(state.progress.log.single.mode, DrillMode.speaking);
        expect(speech.listens.single.onDevice, isTrue);
        handle.dispose();

        {
          usePhone(tester);
          final handle = tester.ensureSemantics();
          final speech = FixedSpeechEngine(onDevice: <String>{'es'});
          final state = await pumpSpeaking(tester, speech);
          final l10n = l10nOf(tester);
          // Not a word of any course: a real word would be found as a card,
          // and its IPA added to the line.
          speech.next = const <SpeechAlternative>[SpeechAlternative('zxq wvk')];
          await speak(tester);
          expect(find.text(l10n.feedbackWrong), findsOneWidget);
          // What the phone heard is in its own box, as heard.
          expect(find.text('zxq wvk'), findsOneWidget);
          expect(state.progress.log.single.grade, 1);
          handle.dispose();
        }
      },
    );

    testWidgets('nothing heard asks again and records nothing', (tester) async {
      usePhone(tester);
      final handle = tester.ensureSemantics();
      final speech = FixedSpeechEngine(onDevice: <String>{'es'});
      final state = await pumpSpeaking(tester, speech);
      final l10n = l10nOf(tester);
      await speak(tester);
      expect(find.text(l10n.drillUnheardNoMatch), findsOneWidget);
      expect(state.progress.log, isEmpty);
      handle.dispose();
    });
  });

  group('try again and Hear yourself', () {
    setUp(_played.clear);

    group('the session', () {
      late AppState state;
      late FixedSpeechEngine speech;

      Future<DrillSession> session({
        SoundCheckEngine? soundCheck,
        TtsEngine? tts,
        FixedSpeechEngine? recogniser,
        bool Function(SessionItem item)? where,
      }) async {
        speech = recogniser ?? FixedSpeechEngine(onDevice: <String>{'es'});
        state = _state(speech, soundCheck: soundCheck, tts: tts);
        await state.load();
        await state.startSpeech();
        final items = state
            .buildSession(DrillRequest.untaught(spanish, skill: Skill.speaking))
            .items
            .where(where ?? (_) => true)
            .toList();
        final s = DrillSession(state: state, items: items);
        addTearDown(s.dispose);
        addTearDown(state.dispose);
        return s;
      }

      test('a wrong answer offers a try again, and only a failed first answer '
          'brings the word back', () async {
        final s = await session();
        final target = s.item.card.target;
        speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
        await s.listen();
        expect(s.answer!.grade, 1);
        expect(s.canRetry, isTrue);
        expect(s.retried, isNull);

        speech.next = <SpeechAlternative>[SpeechAlternative(target)];
        await s.retry();
        expect(s.retried!.graded!.outcome, AnswerOutcome.exact);
        expect(s.retries, 1);
        // The first answer counts: one review, failed, so the word comes
        // back sooner.
        expect(state.progress.log.single.grade, 1);
        expect(state.progress.log.single.answerGiven, 'el perro');
        expect(s.answer!.typed, 'el perro');
        // As often as the learner likes.
        expect(s.canRetry, isTrue);
        speech.next = const <SpeechAlternative>[SpeechAlternative('el gato')];
        await s.retry();
        expect(s.retried!.graded!.outcome, AnswerOutcome.wrong);
        expect(s.retries, 2);
        expect(state.progress.log, hasLength(1));
        expect(speech.listens, hasLength(3));

        {
          var s = await session();
          speech.next = const <SpeechAlternative>[
            SpeechAlternative('el perro'),
          ];
          await s.listen();
          expect(s.firstTryFailed, isTrue);

          s = await session();
          s.dontKnow();
          expect(s.firstTryFailed, isTrue);

          s = await session(
            where: (item) => _unaccented(item.card.target) != item.card.target,
          );
          speech.next = <SpeechAlternative>[
            SpeechAlternative(_unaccented(s.item.card.target)),
          ];
          await s.listen();
          expect(s.answer!.grade, 4);
          // Recorded as a pass: a try again changes nothing, sooner or later.
          expect(s.firstTryFailed, isFalse);
          speech.next = <SpeechAlternative>[
            SpeechAlternative(s.item.card.target),
          ];
          await s.retry();
          expect(s.retried!.graded!.outcome, AnswerOutcome.exact);
          expect(s.firstTryFailed, isFalse);
          expect(state.progress.log.single.grade, 4);
        }
      });

      test('Hear yourself records, plays the recording, then the voice, and '
          'records nothing in the log', () async {
        final sound = _OrderedSoundCheck();
        final s = await session(soundCheck: sound);
        final target = s.item.card.target;
        expect(s.canHearSelf, isFalse);
        speech.next = <SpeechAlternative>[SpeechAlternative(target)];
        await s.listen();
        expect(s.canHearSelf, isTrue);
        _played.clear();
        await s.hearSelf();
        expect(sound.recordings, 1);
        expect(sound.playbacks, 1);
        expect(_played, <String>['self', 'voice $target']);
        expect(s.hearingSelf, SelfTake.idle);
        expect(s.selfFailure, isNull);
        expect(state.progress.log, hasLength(1));
      });
    });
  });

  group('grammar questions', () {
    final now = DateTime(2026, 10, 9, 18);
    final cells = cellsOf();
    // అమ్మతో (ammatō), "with mother", among అమ్మలో, అమ్మకి, అమ్మ నుంచి.
    final withMother = cell(cells, '9004-2');

    group('the meaning question, Ask.chooseFormMeaning (4.8, 1)', () {
      test('the meaning question shows the form and asks its meaning; the form '
          'question shows the meaning and offers the row\'s forms', () {
        expect(
          withMother.promptFor(DrillMode.grammarUnderstood),
          'అమ్మతో (ammatō)',
        );
        expect(withMother.acceptedAnswers(DrillMode.grammarUnderstood), [
          'with mother',
        ]);
        expect(Ask.chooseFormMeaning.chooses, isTrue);
        expect(Ask.chooseFormMeaning.choosesMeaning, isTrue);
        expect(Ask.chooseFormMeaning.optionOf(withMother), 'with mother');

        expect(
          withMother.promptFor(DrillMode.grammar),
          'అమ్మ (amma): with mother',
        );
        expect(Ask.chooseForm.chooses, isTrue);
        expect(Ask.chooseForm.choosesMeaning, isFalse);
        final options = formChoices(withMother, Ask.chooseForm, cells);
        expect(options.map((c) => c.target), [
          'అమ్మలో',
          'అమ్మకి',
          'అమ్మ నుంచి',
        ]);
        expect(options.map((c) => c.reading), [
          'ammalō',
          'ammaki',
          'amma nuñci',
        ]);
      });
    });

    group('lessons (4.8, 5)', () {
      test('a cell is understood, then produced, and the Grammar switch covers '
          'both', () async {
        expect(lessonQuestions(withMother), [
          (mode: DrillMode.grammarUnderstood, ask: Ask.chooseFormMeaning),
          (mode: DrillMode.grammar, ask: Ask.chooseForm),
        ]);
        final plan = lessonPlan(
          [withMother],
          modesOf: (c) => c.modesIn(ttsAvailable: false),
          canChoose: (card, ask) =>
              formChoices(card, ask, cells).isNotEmpty ||
              !ask.choosesAmongForms,
        );
        expect(plan.map((i) => (i.mode, i.ask)), [
          (DrillMode.grammarUnderstood, Ask.teach),
          (DrillMode.grammarUnderstood, Ask.chooseFormMeaning),
          (DrillMode.grammar, Ask.chooseForm),
        ]);

        {
          Future<AppState> loaded({SettingsNotifier? settings}) async {
            final state = AppState.test(
              decks: MemoryDeckSource(appendixFiles()),
              progress: MemoryProgress(),
              settings: settings,
              now: now,
            );
            await state.load();
            return state;
          }

          final settings = SettingsNotifier();
          final state = await loaded(settings: settings);
          expect(
            state.sessionModes,
            containsAll(<DrillMode>[
              DrillMode.grammarUnderstood,
              DrillMode.grammar,
            ]),
          );
          settings.setSkillEnabled(Skill.grammar, false);
          expect(
            state.sessionModes,
            isNot(contains(DrillMode.grammarUnderstood)),
          );
          expect(state.sessionModes, isNot(contains(DrillMode.grammar)));
          expect(
            state.sessionItems(
              const DrillRequest(deckIds: {rulesDeck}, untaught: true),
            ),
            isEmpty,
          );
        }
      });
    });

    group('the log replays as it is', () {
      test('an old grammar answer stays grammar', () {
        final id = 'te-grammar-case-endings-0042-1';
        final old = [
          review(id, DrillMode.grammar, now, 4),
          review(id, DrillMode.grammar, now.add(const Duration(days: 3)), 3),
        ];
        final text = LogJsonl.encode([
          for (final r in old)
            (
              deckId: 'te-en-grammar',
              at: r.at,
              grade: r.grade,
              elapsed: r.elapsed,
              answerGiven: r.answerGiven,
              script: null,
              asked: null,
              key: r.key,
            ),
        ], const []);
        expect(text, contains('"grammar"'));
        expect(text, isNot(contains('grammarUnderstood')));
        final decoded = LogJsonl.decode(text).reviews;
        expect(decoded.map((r) => r.key.mode), everyElement(DrillMode.grammar));
        final replayed = replayReviews(decoded, skills: const SkillMap());
        expect(replayed.states.keys, [(cardId: id, mode: DrillMode.grammar)]);
        expect(
          replayed.events.map((e) => e.mode),
          everyElement(DrillMode.grammar),
        );
      });
    });
  });

  group('the grammar drill', () {
    group('grammar drill', () {
      testWidgets(
        'asks a cell; a wrong answer shows the table with the cell marked',
        (tester) async {
          usePhone(tester);
          await pumpScreen(tester, const GrammarDrill(), state: grammarOn());
          final l10n = l10nOf(tester);
          expect(find.text('hablar (to speak) — vosotros'), findsOneWidget);
          expect(find.text(l10n.drillTypeSlot('vosotros')), findsOneWidget);
          expect(find.text(l10n.drillPositionShort(1, 3)), findsOneWidget);
          expect(find.text('hablo'), findsNothing, reason: 'no table yet');
          expect(find.byType(IncomingFeature), findsNothing);

          {
            usePhone(tester);
            final semantics = tester.ensureSemantics();
            final pattern = await realPattern();
            await pumpScreen(tester, const GrammarDrill(), state: grammarOn());
            await typeAndCheck(tester, 'hablamos');
            final l10n = l10nOf(tester);

            expect(banner(tester).kind, FeedbackKind.wrong);
            expect(banner(tester).title, l10n.feedbackWrong);
            expect(banner(tester).detail, l10n.feedbackAnswer('habláis'));

            final row = findGrammarCell(
              pattern,
              lemma: 'hablar',
              slot: 'yo',
            )!.table;
            for (final cell in row) {
              // The asked slot is in the chip too.
              expect(find.text(cell.slot), findsWidgets);
              expect(find.text(cell.form!), findsOneWidget);
              final node = tester.getSemantics(find.text(cell.form!));
              if (cell.slot == 'vosotros') {
                expect(node, isSemantics(isSelected: true));
              } else {
                expect(node, isNot(isSemantics(isSelected: true)));
              }
            }
            expect(find.text(pattern.notes!), findsOneWidget);
            semantics.dispose();
          }
        },
      );
    });

    testWidgets('live: a session card is graded, recorded, and shows its table '
        'and notes', (tester) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            grammarFixtureDeckId,
            skill: Skill.grammar,
          ),
        ),
        state: AppState.test(),
      );
      final l10n = l10nOf(tester);
      final pattern = state.deckById(grammarFixtureDeckId)!.deck.pattern!;
      expect(find.byType(GrammarDrill), findsOneWidget);
      // The first new cell in deck order: hablar, yo.
      expect(find.text('hablar (to speak) — yo'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hablo');
      await tester.pump();
      await tester.tap(find.text(l10n.drillCheck));
      await tester.pumpAndSettle();

      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(find.text('hablas'), findsOneWidget, reason: 'the whole table');
      expect(find.text(pattern.notes!), findsOneWidget);
      final review = state.progress.log.single;
      expect(review.mode, DrillMode.grammar);
      expect(review.cardId, 'es-grammar-present-ar-hablar-0');
      expect(review.answerGiven, 'hablo');
      expect(review.grade, greaterThanOrEqualTo(4));
    });
  });

  group('minimal pairs', () {
    testWidgets(
      'Play speaks the sound asked; choosing it says so, with the contrast',
      (tester) async {
        usePhone(tester);
        final tts = FixedTtsEngine(const <String>{'hi'});
        final state = await pumpScreen(
          tester,
          const PairDrill(),
          state: pairOn(tts),
        );
        expect(pairFixtureRounds.first.heard, first.b);

        await tester.tap(find.byType(PlayButton));
        await tester.pumpAndSettle();
        expect(tts.spoken, hasLength(1));
        expect(tts.spoken.single.text, first.b.target);
        expect(tts.spoken.single.bcp47, pairFixtureLanguage.ttsTag);
        expect(tts.spoken.single.rate, state.settings.ttsRate());

        usePhone(tester);
        final semantics = tester.ensureSemantics();
        await pumpScreen(tester, const PairDrill(), state: pairOn());
        final l10n = l10nOf(tester);
        expect(find.text(l10n.drillPairQuestion), findsOneWidget);
        for (final sound in <PairSound>[first.a, first.b]) {
          expect(find.text(sound.reading), findsOneWidget);
          expect(
            find.bySemanticsLabel(
              l10n.drillPairOption(sound.target, sound.reading),
            ),
            findsOneWidget,
          );
        }
        expect(find.text(first.contrast), findsNothing);

        await choose(tester, first.b);
        expect(banner(tester).kind, FeedbackKind.correct);
        expect(banner(tester).title, l10n.feedbackPairCorrect(first.b.reading));
        expect(banner(tester).detail, l10n.feedbackPairHeard(first.b.target));
        expect(find.text(first.contrast), findsOneWidget);
        final options = tester.widgetList<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(options, hasLength(2));
        expect(options.every((b) => b.onPressed == null), isTrue);

        await nextCard(tester);
        expect(find.text(l10n.drillPositionShort(2, 2)), findsOneWidget);
        expect(find.text(pairFixtureRounds[1].pair.a.target), findsOneWidget);
        expect(find.byType(FeedbackBanner), findsNothing);
        semantics.dispose();
      },
    );
  });

  group('reading', () {
    group('read', () {
      testWidgets(
        'a passage shows on its own, then its questions; a choice is recorded '
        'at once',
        (tester) async {
          usePhone(tester);
          final tts = FixedTtsEngine(<String>{'bn'});
          final state = readingApp(tts: tts);
          await pumpScreen(
            tester,
            DrillPage(request: readReadingDrill),
            state: state,
          );
          final l10n = l10nOf(tester);
          expect(find.byType(ReadingDrill), findsOneWidget);
          expect(find.text('At the shop'), findsOneWidget);
          expect(find.text(l10n.readingIntro(3)), findsOneWidget);
          for (final sentence in shop) {
            expect(find.text(sentence), findsOneWidget);
          }
          expect(find.text('nomoshkar. koto dam?'), findsOneWidget);
          expectOnScreen(
            tester,
            find.text(l10n.readingSource(readingFixtureSource)),
          );
          expect(find.byType(SpeakerIcon), findsNWidgets(4));
          // No question yet.
          expect(find.text('What does the buyer ask first?'), findsNothing);

          await tester.tap(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is SpeakerIcon && w.label == l10n.readingPlaySentence,
                )
                .at(1),
          );
          await tester.pumpAndSettle();
          expect(tts.spoken.single.text, shop[1]);
          expect(tts.spoken.single.bcp47, 'bn-IN');

          state.settings.showRomanisation = false;
          await tester.pumpAndSettle();
          expect(find.text('nomoshkar. koto dam?'), findsNothing);

          await nextCard(tester);
          expect(find.text('What does the buyer ask first?'), findsOneWidget);
          for (final choice in ['The price', 'The way', 'The time']) {
            expect(find.text(choice), findsOneWidget);
          }
          // The passage is under the choices, to look back at.
          expect(find.text(l10n.readingPassage), findsOneWidget);
          expect(find.text(shop.first), findsOneWidget);
          expect(state.progress.log, isEmpty);

          {
            usePhone(tester);
            final state = readingApp();
            await pumpScreen(
              tester,
              DrillPage(request: readReadingDrill),
              state: state,
            );
            final l10n = l10nOf(tester);
            await nextCard(tester);

            await tapTextReadingDrill(tester, 'The price');
            final right = state.progress.log.single;
            expect(right.deckId, readingFixtureDeckId);
            expect(right.cardId, 'bn-en-fixture-reading-shop-q1');
            expect(right.mode, DrillMode.reading);
            expect(right.grade, ReadingQuestion.rightGrade);
            expect(right.answerGiven, '1');
            expect(find.text(l10n.feedbackCorrect), findsOneWidget);
            expect(find.text(l10n.feedbackAnswer('The price')), findsOneWidget);
            // Choosing again changes nothing.
            // (Answered right, only the right choice is left to tap.)
            expect(find.text('The way'), findsNothing);
            await tester.tap(find.text('The price'));
            await tester.pumpAndSettle();
            expect(state.progress.log, hasLength(1));

            // The next question about the same passage follows at once.
            await nextCard(tester);
            expect(onPassagePage(tester), isFalse);
            expect(find.text(l10n.readingTrueOrFalse), findsOneWidget);
            expect(
              find.text('The buyer asks for a lower price.'),
              findsOneWidget,
            );
            await tapTextReadingDrill(tester, l10n.readingFalse);
            final wrong = state.progress.log.last;
            expect(wrong.cardId, 'bn-en-fixture-reading-shop-q2');
            expect(wrong.grade, ReadingQuestion.wrongGrade);
            expect(wrong.answerGiven, 'false');
            expect(find.text(l10n.feedbackWrong), findsOneWidget);
            expect(
              find.text(l10n.feedbackAnswer(l10n.readingTrue)),
              findsOneWidget,
            );

            await nextCard(tester);
            await tapTextReadingDrill(tester, 'Fifty taka');
            await nextCard(tester);
            // The next passage shows on its own first.
            expect(find.text('Going home'), findsOneWidget);
            expect(onPassagePage(tester), isTrue);
            expect(find.text(home), findsOneWidget);
          }
        },
      );

      testWidgets('Words opens the glossary: the word as written, today\'s '
          'form, its reading with romanisation on, and its meaning', (
        tester,
      ) async {
        usePhone(tester);
        final state = readingApp();
        await pumpScreen(
          tester,
          DrillPage(
            request: readReadingDrill,
            preset: const DrillPreset(target: home),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text(home), findsOneWidget);
        await tapTextReadingDrill(tester, l10n.readingWords);
        expect(find.text(l10n.readingWordsTitle), findsOneWidget);
        final glossary = find.byType(Glossary);
        for (final text in <String>['ক’রে', 'করে']) {
          final shown = find.descendant(
            of: glossary,
            matching: find.text(text),
          );
          expect(shown, findsOneWidget);
          expect(
            find.ancestor(of: shown, matching: find.byType(TargetText)),
            findsOneWidget,
          );
        }
        expect(find.text('kore'), findsOneWidget);
        expect(find.text('having done'), findsOneWidget);
        // A word written the same today shows once, with no arrow to itself.
        expect(
          find.descendant(of: glossary, matching: find.text('বাড়িতে')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: glossary,
            matching: find.byIcon(Icons.arrow_forward),
          ),
          findsOneWidget,
        );
        expect(
          find.text('older spelling; the apostrophe marks a dropped ই'),
          findsOneWidget,
        );
        state.settings.showRomanisation = false;
        await tester.pumpAndSettle();
        expect(find.text('kore'), findsNothing);
        // Behind the sheet, Words stays by the passage, to open it again.
        expect(
          find.descendant(
            of: find.byType(ReadingDrill),
            matching: find.text(l10n.readingWords),
          ),
          findsOneWidget,
        );
      });
    });

    group('heard', () {
      testWidgets('the passage is read aloud, its text hidden until the '
          'question is answered', (tester) async {
        usePhone(tester);
        final tts = FixedTtsEngine(<String>{'bn'});
        final state = readingApp(tts: tts);
        await pumpScreen(tester, DrillPage(request: heard), state: state);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.readingListenIntro(3)), findsOneWidget);
        expect(find.text(l10n.readingTextHidden), findsOneWidget);
        for (final sentence in shop) {
          expect(find.text(sentence), findsNothing);
        }
        expect(find.text('nomoshkar. koto dam?'), findsNothing);
        expect(find.text(l10n.drillCantListen), findsOneWidget);

        await tester.tap(find.byType(PlayButton));
        await tester.pumpAndSettle();
        expect(tts.spoken.map((s) => s.text), shop);

        await nextCard(tester);
        expect(find.byType(PlayButton), findsOneWidget);
        for (final sentence in shop) {
          expect(find.text(sentence), findsNothing);
        }
        await tapTextReadingDrill(tester, 'The price');
        expect(state.progress.log.single.mode, DrillMode.listening);
        for (final sentence in shop) {
          expect(find.text(sentence), findsOneWidget);
        }
        expect(find.text(l10n.readingTextHidden), findsNothing);

        // Hidden again for the next question.
        await nextCard(tester);
        for (final sentence in shop) {
          expect(find.text(sentence), findsNothing);
        }
      });
    });
  });
}
