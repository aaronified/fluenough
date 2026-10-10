import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/sound/sound_check.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_session.dart';

import '../../support/harness.dart';

/// Trying a pronunciation again, and hearing yourself then the voice
/// (#231, docs/plans/pronunciation-retry.md): the first answer is the one
/// recorded; a try again is graded and shown, never recorded.

const String spanish = 'es-en-core-100';

/// What was played, in order: the learner's recording, then the voice.
final List<String> _played = <String>[];

/// A sound check that also notes, in [_played], when it plays.
class _OrderedSoundCheck extends FixedSoundCheck {
  _OrderedSoundCheck({super.grants, super.records, super.plays});

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

void main() {
  setUp(_played.clear);

  group('the session', () {
    late AppState state;
    late FixedSpeechEngine speech;

    Future<DrillSession> session({
      SoundCheckEngine? soundCheck,
      TtsEngine? tts,
      bool Function(SessionItem item)? where,
    }) async {
      speech = FixedSpeechEngine(onDevice: <String>{'es'});
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

    test('a wrong answer offers a try again; a right one passes, says so, '
        'and the first answer stays the one recorded', () async {
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
    });

    test(
      'a wrong try again is graded as the first answer was, unrecorded',
      () async {
        final s = await session();
        speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
        await s.listen();
        speech.next = const <SpeechAlternative>[SpeechAlternative('xyzzy')];
        await s.retry();
        expect(s.retried!.typed, 'xyzzy');
        expect(s.retried!.graded!.outcome, AnswerOutcome.wrong);
        expect(s.retried!.grade, 1);
        expect(state.progress.log, hasLength(1));
      },
    );

    test('a right answer offers no try again', () async {
      final s = await session();
      speech.next = <SpeechAlternative>[SpeechAlternative(s.item.card.target)];
      await s.listen();
      expect(s.canRetry, isFalse);
      await s.retry();
      expect(speech.listens, hasLength(1));
      expect(s.retried, isNull);
    });

    test('an almost-right answer offers a try again', () async {
      final s = await session(
        where: (item) => _unaccented(item.card.target) != item.card.target,
      );
      final said = _unaccented(s.item.card.target);
      speech.next = <SpeechAlternative>[SpeechAlternative(said)];
      await s.listen();
      expect(s.answer!.graded!.outcome, AnswerOutcome.closeDiacritics);
      expect(s.canRetry, isTrue);
    });

    test('"Don\'t know" offers a try again, which records nothing', () async {
      final s = await session();
      s.dontKnow();
      expect(s.canRetry, isTrue);
      speech.next = <SpeechAlternative>[SpeechAlternative(s.item.card.target)];
      await s.retry();
      expect(s.retried!.graded!.outcome.isCorrect, isTrue);
      expect(state.progress.log.single.grade, 1);
    });

    test(
      'a try again that hears nothing says why and records nothing',
      () async {
        final s = await session();
        speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
        await s.listen();
        speech.next = const <SpeechAlternative>[];
        await s.retry();
        expect(s.unheard, SpeechFailure.noMatch);
        expect(s.retried, isNull);
        expect(s.hearing, isFalse);
        expect(state.progress.log, hasLength(1));
      },
    );

    test('Continue forgets the try again for the next card', () async {
      final s = await session();
      speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
      await s.listen();
      speech.next = <SpeechAlternative>[SpeechAlternative(s.item.card.target)];
      await s.retry();
      s.next();
      expect(s.position, 2);
      expect(s.retried, isNull);
      expect(s.retries, 0);
      expect(s.canRetry, isFalse);
      expect(state.progress.log, hasLength(1));
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

    test(
      'Hear yourself says why it could not record, and plays nothing',
      () async {
        for (final (failure, sound) in <(RecordFailure, FixedSoundCheck)>[
          (RecordFailure.refused, _OrderedSoundCheck(grants: false)),
          (
            RecordFailure.silent,
            _OrderedSoundCheck(records: RecordFailure.silent),
          ),
          (RecordFailure.failed, _OrderedSoundCheck(plays: false)),
        ]) {
          final s = await session(soundCheck: sound);
          s.dontKnow();
          _played.clear();
          await s.hearSelf();
          expect(s.selfFailure, failure);
          expect(s.hearingSelf, SelfTake.idle);
          expect(_played.where((p) => p.startsWith('voice')), isEmpty);
        }
      },
    );

    test('without a voice, Hear yourself plays the recording alone', () async {
      final sound = _OrderedSoundCheck();
      final s = await session(soundCheck: sound, tts: const NullTtsEngine());
      expect(s.canPlay, isFalse);
      s.dontKnow();
      _played.clear();
      await s.hearSelf();
      expect(_played, <String>['self']);
      expect(s.selfFailure, isNull);
    });
  });

  group('the drill', () {
    Future<(AppState, FixedSpeechEngine)> pump(
      WidgetTester tester, {
      SoundCheckEngine? soundCheck,
    }) async {
      final speech = FixedSpeechEngine(onDevice: <String>{'es'});
      final state = _state(speech, soundCheck: soundCheck);
      await state.load();
      await state.startSpeech();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(spanish, skill: Skill.speaking),
        ),
        state: state,
      );
      return (state, speech);
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).first);
      await tester.pumpAndSettle();
    }

    Future<void> speak(WidgetTester tester) async {
      final mic = find.bySemanticsLabel(l10nOf(tester).drillSpeak);
      await tester.ensureVisible(mic);
      await tester.pumpAndSettle();
      await tester.tap(mic);
      await tester.pumpAndSettle();
    }

    String target(AppState state) => state
        .buildSession(DrillRequest.untaught(spanish, skill: Skill.speaking))
        .items
        .first
        .card
        .target;

    testWidgets('Try again after a wrong word: a right try says so, and the '
        'first answer is the one recorded', (tester) async {
      usePhone(tester);
      final handle = tester.ensureSemantics();
      final (state, speech) = await pump(tester);
      final l10n = l10nOf(tester);
      final word = target(state);
      speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
      await speak(tester);
      expect(find.text(l10n.feedbackWrong), findsOneWidget);
      expect(find.text(l10n.drillTryAgain), findsOneWidget);
      expect(find.text(l10n.commonContinue), findsOneWidget);

      speech.next = <SpeechAlternative>[SpeechAlternative(word)];
      await tapText(tester, l10n.drillTryAgain);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(find.text(l10n.drillRetryPassed), findsOneWidget);
      expect(state.progress.log.single.grade, 1);

      speech.next = const <SpeechAlternative>[SpeechAlternative('el gato')];
      await tapText(tester, l10n.drillTryAgain);
      expect(find.text(l10n.feedbackWrong), findsOneWidget);
      expect(
        find.text(l10n.feedbackSaidAnswer('el gato', word)),
        findsOneWidget,
      );
      expect(find.text(l10n.drillRetryPractice), findsOneWidget);

      speech.next = const <SpeechAlternative>[];
      await tapText(tester, l10n.drillTryAgain);
      expect(find.text(l10n.drillUnheardNoMatch), findsOneWidget);
      expect(state.progress.log, hasLength(1));

      await tapText(tester, l10n.commonContinue);
      expect(find.text(l10n.drillTryAgain), findsNothing);
      expect(state.progress.log, hasLength(1));
      handle.dispose();
    });

    testWidgets('a right word offers Hear yourself but not Try again', (
      tester,
    ) async {
      usePhone(tester);
      final sound = _OrderedSoundCheck();
      final (state, speech) = await pump(tester, soundCheck: sound);
      final l10n = l10nOf(tester);
      final word = target(state);
      speech.next = <SpeechAlternative>[SpeechAlternative(word)];
      await speak(tester);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(find.text(l10n.drillTryAgain), findsNothing);
      _played.clear();
      await tapText(tester, l10n.drillHearYourself);
      expect(sound.recordings, 1);
      expect(_played, <String>['self', 'voice $word']);
      expect(find.text(l10n.drillHearYourself), findsOneWidget);
    });

    testWidgets('Hear yourself with sound off says so and records nothing', (
      tester,
    ) async {
      usePhone(tester);
      final sound = _OrderedSoundCheck();
      final (state, speech) = await pump(tester, soundCheck: sound);
      final l10n = l10nOf(tester);
      speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
      await speak(tester);
      state.settings.soundOn = false;
      await tester.pumpAndSettle();
      await tapText(tester, l10n.drillHearYourself);
      expect(find.text(l10n.speakerSoundOff), findsOneWidget);
      expect(sound.recordings, 0);
    });

    testWidgets('Hear yourself refused says how to allow the microphone', (
      tester,
    ) async {
      usePhone(tester);
      final (_, speech) = await pump(
        tester,
        soundCheck: _OrderedSoundCheck(grants: false),
      );
      final l10n = l10nOf(tester);
      speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
      await speak(tester);
      await tapText(tester, l10n.drillHearYourself);
      expect(find.text(l10n.drillHearYourselfRefused), findsOneWidget);
    });

    testWidgets('after a try again, every state fits at twice the text size '
        'and meets the tap-target, label and contrast guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final scale in <double>[1.0, 2.0]) {
        usePhone(tester, textScale: scale);
        await tester.pumpWidget(const SizedBox.shrink());
        final (state, speech) = await pump(tester);
        final l10n = l10nOf(tester);
        speech.next = const <SpeechAlternative>[SpeechAlternative('el perro')];
        await speak(tester);
        speech.next = <SpeechAlternative>[SpeechAlternative(target(state))];
        await tapText(tester, l10n.drillTryAgain);
        expect(tester.takeException(), isNull, reason: 'scale $scale');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });
  });
}
