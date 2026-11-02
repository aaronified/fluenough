// The shared question shell (#509, phase 0): what the learner sees happen
// when a card is gone back to, when the phone's recogniser keeps the audio
// of an answer, and when the phone heard text that is no card.

import 'dart:typed_data';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/heard_reading.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/sound/sound_check.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:flutter_test/flutter_test.dart';

const String _spanish = 'es-en-core-100';

void main() {
  group('what the phone heard, read in Latin letters', () {
    test('Telugu, Bengali and Hindustani are written as their courses are', () {
      // Telugu: the anusvara as the nasal said, ṁ at the end of a word.
      expect(
        heardReading('ఆమె తెలుగు నేర్చుకుంటోంది', 'te'),
        'āme telugu nērcukuṇṭōndi',
      );
      expect(heardReading('కాలం', 'te'), 'kālaṁ');
      // Bengali: no final a, ô for the inherent vowel, o before i or u.
      expect(heardReading('আমি জল চাই', 'bn'), 'āmi jôl cāi');
      // Hindustani: the inherent a left out where it is not said.
      expect(heardReading('कितना', 'hi'), 'kitnā');
      expect(heardReading('नहीं', 'hi'), 'nahīm̐');
    });

    test(
      'a language with no rules shows no reading rather than a wrong one',
      () {
        expect(heardReading('hola', 'es'), isNull);
        expect(heardReading('नमस्ते', 'ur'), isNull);
      },
    );

    test('the word that differs is the one underlined', () {
      expect(differingWords('मुझे पानी चाहिये', 'मुझे पानी चाहिए'), <int>{2});
      expect(differingWords('a b c', 'a b c.'), isEmpty);
    });
  });

  group('going back', () {
    late AppState state;
    late DrillSession session;

    setUp(() async {
      state = AppState.test();
      await state.load();
      final items = state
          .buildSession(
            DrillRequest.untaught(_spanish, skill: Skill.recognition),
          )
          .items
          .where((i) => i.mode == DrillMode.recognition && i.ask == Ask.own)
          .take(3)
          .toList();
      session = DrillSession(state: state, items: items);
    });

    tearDown(() {
      session.dispose();
      state.dispose();
    });

    test('a card gone back to is read-only, and going on records nothing', () {
      expect(session.canGoBack, isFalse, reason: 'nothing behind the first');
      session.reveal();
      session.rate(SelfGrade.good);
      expect(session.position, 2);
      expect(session.canGoBack, isFalse, reason: 'not answered yet');
      session.reveal();
      expect(session.canGoBack, isTrue);

      session.back();
      expect(session.readOnly, isTrue);
      expect(session.position, 1);
      expect(session.phase, DrillPhase.revealed);

      // On a card gone back to, a swipe goes on: it does not rate again.
      session.rate(SelfGrade.again);
      expect(session.readOnly, isFalse);
      expect(session.position, 2);
      expect(session.phase, DrillPhase.revealed);
      expect(state.progress.log, hasLength(1));
      expect(session.answers, hasLength(1));
    });
  });

  group('your recording', () {
    late FixedSpeechEngine speech;
    late FixedSoundCheck sound;
    late AppState state;
    late DrillSession session;

    setUp(() async {
      speech = FixedSpeechEngine(onDevice: <String>{'es'});
      sound = FixedSoundCheck();
      state = AppState.test(
        speech: speech,
        soundCheck: sound,
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
          enabledSkills: <Skill>{
            ...Skill.values.where((s) => s.onByDefault),
            Skill.speaking,
          },
        ),
      );
      await state.load();
      await state.startSpeech();
      session = DrillSession(
        state: state,
        items: state
            .buildSession(
              DrillRequest.untaught(_spanish, skill: Skill.speaking),
            )
            .items,
      );
    });

    tearDown(() {
      session.dispose();
      state.dispose();
    });

    test(
      'plays the audio the recogniser kept, without recording again',
      () async {
        speech.next = <SpeechAlternative>[
          SpeechAlternative(session.item.card.target),
        ];
        speech.audio = OwnAudio(Uint8List(32000), sampleRate: 16000);
        await session.listen();
        expect(session.hasOwnTake, isTrue);
        expect(session.ownTakeLength, const Duration(seconds: 1));

        await session.replayOwn();
        expect(sound.playbacks, 1);
        expect(sound.recordings, 0);
        expect(session.replaying, isFalse);
      },
    );

    test('with no audio kept, it records the word again, as Hear yourself '
        'does, and keeps that take', () async {
      speech.next = <SpeechAlternative>[
        SpeechAlternative(session.item.card.target),
      ];
      await session.listen();
      expect(session.hasOwnTake, isFalse);

      await session.replayOwn();
      expect(sound.recordings, 1);
      expect(session.hasOwnTake, isTrue);

      // The next press replays that take.
      await session.replayOwn();
      expect(sound.recordings, 1);
      expect(sound.playbacks, 2);
    });
  });
}
