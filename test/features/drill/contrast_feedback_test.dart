import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/sound_contrasts.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/drill/answer_feedback.dart';
import 'package:fluenough/features/drill/drill_session.dart';

import '../../support/harness.dart';

/// The speaking drill names the sound a wrong word differs by, when the
/// word heard is the answer with one sound changed (#89, ADR-0015).

const String probe = '''
schema: 1
id: bn-en-probe
name: "Probe"
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: bn-en-probe-0001, target: "কাল", native: "time", reading: "kal" }
  - { id: bn-en-probe-0002, target: "খাল", native: "canal", reading: "khal" }
''';

const String sounds = '''
schema: 1
kind: sounds
id: bn-sounds
language: bn
contrasts:
  - id: aspiration
    name: "a breath after the consonant"
    pairs: [["ক", "খ"]]
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppState, DrillSession)> sessionOn(
    String cardId, {
    bool withSounds = true,
  }) async {
    final state = AppState.test(
      decks: MemoryDeckSource(<String, String>{
        'decks/bn/bn-en-probe.yaml': probe,
        if (withSounds) 'decks/bn/bn-sounds.yaml': sounds,
      }),
      speech: FixedSpeechEngine(onDevice: <String>{'bn'}),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: Skill.values.toSet(),
      ),
    );
    addTearDown(state.dispose);
    await state.load();
    await state.startSpeech();
    final item = state
        .buildSession(
          DrillRequest.untaught('bn-en-probe', skill: Skill.speaking),
        )
        .items
        .firstWhere((i) => i.card.id == cardId);
    final session = DrillSession(state: state, items: [item]);
    addTearDown(session.dispose);
    return (state, session);
  }

  test('a word heard with one sound changed names the sound, and what the '
      'word heard means', () async {
    final (_, s) = await sessionOn('bn-en-probe-0001');
    s.checkSpoken(const <SpeechAlternative>[SpeechAlternative('খাল')]);
    final answer = s.answer!;
    expect(answer.graded!.outcome, AnswerOutcome.wrong);
    expect(answer.contrast!.id, 'aspiration');
    expect(answer.heardCard!.native, 'canal');
  });

  test('nothing to name for a right answer, another word, or a language '
      'with no sounds file', () async {
    final (_, right) = await sessionOn('bn-en-probe-0001');
    right.checkSpoken(const <SpeechAlternative>[SpeechAlternative('কাল')]);
    expect(right.answer!.contrast, isNull);

    final (_, other) = await sessionOn('bn-en-probe-0001');
    other.checkSpoken(const <SpeechAlternative>[SpeechAlternative('মাছ')]);
    expect(other.answer!.graded!.outcome, AnswerOutcome.wrong);
    expect(other.answer!.contrast, isNull);

    final (_, none) = await sessionOn('bn-en-probe-0001', withSounds: false);
    none.checkSpoken(const <SpeechAlternative>[SpeechAlternative('খাল')]);
    expect(none.answer!.contrast, isNull);
  });

  group('the feedback', () {
    const kal = Card(id: 'k', deckId: 'd', target: 'কাল', native: 'time');
    const khal = Card(id: 'h', deckId: 'd', target: 'খাল', native: 'canal');
    const breath = SoundContrast(
      id: 'aspiration',
      name: 'a breath after the consonant',
      pairs: <(String, String)>[('ক', 'খ')],
    );

    Future<void> pump(WidgetTester tester, TypedAnswer answer) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: AnswerFeedback(
            answer: answer,
            card: kal,
            expected: kal.target,
            transliterating: false,
            spoken: true,
          ),
        ),
      );
    }

    const wrong = GradedAnswer(AnswerOutcome.wrong, matched: null);

    testWidgets('names the sound, and what the word heard means', (
      tester,
    ) async {
      await pump(
        tester,
        const TypedAnswer(
          typed: 'খাল',
          graded: wrong,
          grade: 1,
          contrast: breath,
          heardCard: khal,
        ),
      );
      final l10n = l10nOf(tester);
      expect(
        find.text(
          l10n.feedbackSaidContrastMeaning(
            'খাল',
            'canal',
            'a breath after the consonant',
            'কাল',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('names the sound alone when no deck has the word heard', (
      tester,
    ) async {
      await pump(
        tester,
        const TypedAnswer(
          typed: 'খাল',
          graded: wrong,
          grade: 1,
          contrast: breath,
        ),
      );
      final l10n = l10nOf(tester);
      expect(
        find.text(
          l10n.feedbackSaidContrast(
            'খাল',
            'a breath after the consonant',
            'কাল',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('without a contrast, says only what was heard', (tester) async {
      await pump(
        tester,
        const TypedAnswer(typed: 'মাছ', graded: wrong, grade: 1),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.feedbackSaidAnswer('মাছ', 'কাল')), findsOneWidget);
    });
  });
}
