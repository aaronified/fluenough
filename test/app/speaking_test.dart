import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/speech/system_speech_engine.dart';
import 'package:fluenough/features/drill/drill_session.dart';

/// Speaking (#89, ADR-0014): when the microphone is asked for, which
/// languages can be heard, and how what was heard is graded.

const String spanish = 'es-en-core-100';

AppState speaking(FixedSpeechEngine speech, {bool on = false}) => AppState.test(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the microphone', () {
    test('is not asked for at launch, and speaking starts off', () async {
      final speech = FixedSpeechEngine(onDevice: <String>{'es'});
      final state = AppState.test(speech: speech);
      addTearDown(state.dispose);
      await state.load();
      expect(speech.starts, 0);
      expect(state.settings.isEnabled(Skill.speaking), isFalse);
      final spanishInfo = state.deckById(spanish)!.language;
      expect(state.speechStatus(spanishInfo), SpeechStatus.off);
      expect(state.canHear(spanishInfo), isFalse);
    });

    test('granted before, it is checked quietly at launch', () async {
      final speech = FixedSpeechEngine(onDevice: <String>{'es'}, granted: true);
      final state = AppState.test(speech: speech);
      addTearDown(state.dispose);
      await state.load();
      // Not awaited by load: the check can take seconds.
      await pumpEventQueue();
      expect(speech.starts, 1);
      final info = state.deckById(spanish)!.language;
      expect(state.speechStatus(info), SpeechStatus.onDevice);
    });

    test('switching speaking on asks, and it stays off when refused or '
        'there is no recogniser', () async {
      final yes = FixedSpeechEngine(onDevice: <String>{'es'});
      final state = speaking(yes);
      addTearDown(state.dispose);
      await state.load();
      expect(await state.setSpeaking(true), SpeechSetup.ready);
      expect(yes.starts, 1);
      expect(state.settings.isEnabled(Skill.speaking), isTrue);
      expect(await state.setSpeaking(false), SpeechSetup.ready);
      expect(state.settings.isEnabled(Skill.speaking), isFalse);

      final no = FixedSpeechEngine(onDevice: <String>{'es'}, grants: false);
      final refused = speaking(no);
      addTearDown(refused.dispose);
      await refused.load();
      expect(await refused.setSpeaking(true), SpeechSetup.refused);
      expect(refused.settings.isEnabled(Skill.speaking), isFalse);
      // Asking again asks again.
      expect(await refused.setSpeaking(true), SpeechSetup.refused);
      expect(no.starts, 2);

      final none = speaking(FixedSpeechEngine());
      addTearDown(none.dispose);
      await none.load();
      expect(await none.setSpeaking(true), SpeechSetup.noRecogniser);
      expect(none.settings.isEnabled(Skill.speaking), isFalse);
    });
  });

  group('where it can be heard', () {
    test('on the device first; a language the device cannot hear asks '
        'before going online', () async {
      final speech = FixedSpeechEngine(online: <String>{'es'});
      final state = speaking(speech);
      addTearDown(state.dispose);
      await state.load();
      await state.setSpeaking(true);
      final info = state.deckById(spanish)!.language;
      expect(
        state.speechStatus(info),
        SpeechStatus.onDevice,
        reason:
            'not '
            'known to be otherwise until a listen',
      );

      speech.next = const <SpeechAlternative>[SpeechAlternative('la casa')];
      final first = await state.listenFor(info);
      expect(first.failure, SpeechFailure.notOnDevice);
      expect(speech.listens.single.onDevice, isTrue);
      expect(state.speechStatus(info), SpeechStatus.onlineOnly);
      expect(state.canHear(info), isFalse);

      // Not allowed: nothing is sent.
      expect((await state.listenFor(info)).failure, SpeechFailure.notOnDevice);
      expect(speech.listens, hasLength(1));

      state.settings.allowOnlineSpeech('es', true);
      expect(state.speechStatus(info), SpeechStatus.online);
      expect(state.canHear(info), isTrue);
      final heard = await state.listenFor(info);
      expect(heard.alternatives.single.text, 'la casa');
      expect(speech.listens.last.onDevice, isFalse);
    });

    test('a language the device does not list may still be heard online, '
        'with leave', () async {
      // Android 13 and later list only the on-device languages.
      final speech = FixedSpeechEngine(
        onDevice: <String>{'hi'},
        online: <String>{'es'},
      );
      final state = speaking(speech);
      addTearDown(state.dispose);
      await state.load();
      await state.setSpeaking(true);
      final info = state.deckById(spanish)!.language;
      expect(state.speechStatus(info), SpeechStatus.onlineOnly);
      expect((await state.listenFor(info)).failure, SpeechFailure.notOnDevice);
      expect(speech.listens, isEmpty);

      state.settings.allowOnlineSpeech('es', true);
      speech.next = const <SpeechAlternative>[SpeechAlternative('la casa')];
      final heard = await state.listenFor(info);
      expect(heard.alternatives.single.text, 'la casa');
      expect(speech.listens.single.onDevice, isFalse);
    });

    test('a language online does not know either is missing, and is not '
        'listened for again', () async {
      final speech = FixedSpeechEngine(onDevice: <String>{'hi'});
      final state = speaking(speech);
      addTearDown(state.dispose);
      await state.load();
      await state.setSpeaking(true);
      final info = state.deckById(spanish)!.language;
      state.settings.allowOnlineSpeech('es', true);
      expect(state.speechStatus(info), SpeechStatus.online);

      expect((await state.listenFor(info)).failure, SpeechFailure.unsupported);
      expect(state.speechStatus(info), SpeechStatus.missing);
      expect(state.canHear(info), isFalse);
      expect((await state.listenFor(info)).failure, SpeechFailure.unsupported);
      expect(speech.listens, hasLength(1));
    });

    test('what listens found survives a restart, and Check again forgets '
        'it', () async {
      final speech = FixedSpeechEngine(online: <String>{'es'});
      final state = speaking(speech);
      addTearDown(state.dispose);
      await state.load();
      await state.setSpeaking(true);
      final info = state.deckById(spanish)!.language;
      await state.listenFor(info);
      state.settings.allowOnlineSpeech('es', true);
      expect(state.speechStatus(info), SpeechStatus.online);
      state.settings.foundSpeech('hi', unsupported: true);

      final stored = state.settings.toStored();
      final restarted = AppState.test(
        speech: FixedSpeechEngine(online: <String>{'es'}, granted: true),
        settings: SettingsNotifier()..restore(stored),
      );
      addTearDown(restarted.dispose);
      await restarted.load();
      await pumpEventQueue();
      expect(restarted.speechStatus(info), SpeechStatus.online);
      expect(restarted.settings.speechUnsupported, <String>{'hi'});
      expect(restarted.settings.speechNotOnDevice, <String>{'es', 'hi'});

      await restarted.recheckSpeech();
      expect(restarted.settings.speechNotOnDevice, isEmpty);
      expect(restarted.speechStatus(info), SpeechStatus.onDevice);
    });

    test('Check again never asks for the microphone', () async {
      final speech = FixedSpeechEngine(onDevice: <String>{'es'});
      final state = speaking(speech);
      addTearDown(state.dispose);
      await state.load();
      await state.recheckSpeech();
      expect(speech.starts, 0);
    });

    test('sessions drill speaking only while it is on and the language can '
        'be heard', () async {
      final speech = FixedSpeechEngine(onDevice: <String>{'es'});
      final state = speaking(speech);
      addTearDown(state.dispose);
      await state.load();
      Set<DrillMode> modes() => <DrillMode>{
        for (final item
            in state.buildSession(DrillRequest.learnAnyway(spanish)).items)
          item.mode,
      };
      expect(modes(), isNot(contains(DrillMode.speaking)));

      await state.setSpeaking(true);
      final spoken = state.buildSession(
        DrillRequest.deck(spanish, skill: Skill.speaking),
      );
      expect(spoken.items, isNotEmpty);
      expect(spoken.items.map((i) => i.mode), everyElement(DrillMode.speaking));

      final hindiOnly = speaking(FixedSpeechEngine(onDevice: <String>{'hi'}));
      addTearDown(hindiOnly.dispose);
      await hindiOnly.load();
      await hindiOnly.setSpeaking(true);
      expect(
        hindiOnly
            .buildSession(DrillRequest.deck(spanish, skill: Skill.speaking))
            .items,
        isEmpty,
      );
    });
  });

  group('cards', () {
    const word = Card(id: 'w', deckId: 'd', target: 't', native: 'n');
    const phrase = Card(
      id: 'p',
      deckId: 'd',
      target: 't',
      native: 'n',
      pos: 'phrase',
    );
    const grammar = Card(
      id: 'g',
      deckId: 'd',
      target: 't',
      native: 'n',
      modes: <DrillMode>{DrillMode.grammar},
    );

    test('words and phrases can be spoken where speech is heard; grammar '
        'cards cannot', () {
      expect(
        word.modesIn(ttsAvailable: true, speechAvailable: true),
        contains(DrillMode.speaking),
      );
      expect(
        phrase.modesIn(ttsAvailable: false, speechAvailable: true),
        <DrillMode>{DrillMode.recognition, DrillMode.speaking},
      );
      expect(
        word.modesIn(ttsAvailable: true),
        isNot(contains(DrillMode.speaking)),
      );
      expect(
        grammar.modesIn(ttsAvailable: true, speechAvailable: true),
        <DrillMode>{DrillMode.grammar},
      );
      expect(word.acceptedAnswers(DrillMode.speaking).first, 't');
      expect(word.promptFor(DrillMode.speaking), 'n');
    });
  });

  group('grading what was heard', () {
    late AppState state;
    late FixedSpeechEngine speech;

    Future<DrillSession> session() async {
      speech = FixedSpeechEngine(onDevice: <String>{'es'});
      state = speaking(speech, on: true);
      await state.load();
      await state.startSpeech();
      final queue = state.buildSession(
        DrillRequest.deck(spanish, skill: Skill.speaking),
      );
      return DrillSession(state: state, items: queue.items);
    }

    tearDown(() => state.dispose());

    test('the best reading, right, is correct and recorded with what was '
        'heard', () async {
      final s = await session();
      addTearDown(s.dispose);
      final target = s.item.card.target;
      speech.next = <SpeechAlternative>[SpeechAlternative(target)];
      await s.listen();
      expect(s.answer!.graded!.outcome.isCorrect, isTrue);
      expect(s.answer!.grade, 5);
      expect(state.progress.log.single.answerGiven, target);
      expect(state.progress.log.single.mode, DrillMode.speaking);
    });

    test('another reading counts if the recogniser said it was fairly sure '
        'of it, and not otherwise', () async {
      final s = await session();
      addTearDown(s.dispose);
      final target = s.item.card.target;
      s.checkSpoken(<SpeechAlternative>[
        const SpeechAlternative('xyz', confidence: 0.9),
        SpeechAlternative(target, confidence: 0.6),
      ]);
      expect(s.answer!.graded!.outcome.isCorrect, isTrue);
      expect(s.answer!.typed, target);

      // Low, 0 as Android gives every reading after the best, or none
      // given: not taken as what was said.
      for (final confidence in <double?>[0.2, 0.0, null]) {
        s.next();
        final other = s.item.card.target;
        s.checkSpoken(<SpeechAlternative>[
          const SpeechAlternative('xyz', confidence: 0.9),
          SpeechAlternative(other, confidence: confidence),
        ]);
        expect(
          s.answer!.graded!.outcome.isCorrect,
          isFalse,
          reason: '$confidence',
        );
        expect(s.answer!.typed, 'xyz');
        expect(s.answer!.grade, 1);
      }
    });

    test('a near miss is wrong: in speech it is another word', () async {
      final s = await session();
      addTearDown(s.dispose);
      final target = s.item.card.target;
      final miss = '${target.substring(0, target.length - 1)}x';
      s.checkSpoken(<SpeechAlternative>[SpeechAlternative(miss)]);
      expect(s.answer!.graded!.outcome.isCorrect, isFalse);
      expect(s.answer!.awaitsJudgement, isFalse);
    });

    test('nothing heard records nothing, and the card can be said again or '
        'skipped', () async {
      final s = await session();
      addTearDown(s.dispose);
      final first = s.item.card.id;
      await s.listen();
      expect(s.unheard, SpeechFailure.noMatch);
      expect(s.answer, isNull);
      expect(state.progress.log, isEmpty);
      s.skipUnheard();
      expect(s.item.card.id, isNot(first));
      expect(state.progress.log, isEmpty);
    });
  });

  test('the plugin\'s error codes map to the reasons the app tells apart', () {
    SpeechFailure of(String code, {bool onDevice = true}) =>
        SystemSpeechEngine.failureOf(code, onDevice: onDevice);
    expect(of('error_language_unavailable'), SpeechFailure.notOnDevice);
    expect(of('error_language_not_supported'), SpeechFailure.notOnDevice);
    expect(
      of('error_language_unavailable', onDevice: false),
      SpeechFailure.unsupported,
    );
    expect(
      of('error_language_not_supported', onDevice: false),
      SpeechFailure.unsupported,
    );
    expect(of('error_no_match'), SpeechFailure.noMatch);
    expect(of('error_speech_timeout'), SpeechFailure.noMatch);
    expect(of('error_permission'), SpeechFailure.permissionDenied);
    expect(of('error_network'), SpeechFailure.network);
    expect(of('error_network_timeout'), SpeechFailure.network);
    expect(of('error_server'), SpeechFailure.network);
    expect(of('error_server_disconnected'), SpeechFailure.network);
    expect(of('error_busy'), SpeechFailure.other);
  });

  test('the plugin\'s readings keep a score of 0, and only -1 means none '
      'given', () {
    final readings = SystemSpeechEngine.alternativesOf(
      SpeechRecognitionResult(const <SpeechRecognitionWords>[
        SpeechRecognitionWords('la casa', null, 0.92),
        SpeechRecognitionWords('la masa', null, 0),
        SpeechRecognitionWords('  ', null, 0.5),
        SpeechRecognitionWords(
          'las casas',
          null,
          SpeechRecognitionWords.missingConfidence,
        ),
      ], ResultType.finalResult.value),
    );
    expect(readings.map((r) => r.text), <String>[
      'la casa',
      'la masa',
      'las casas',
    ]);
    expect(readings.map((r) => r.confidence), <double?>[0.92, 0.0, null]);
  });
}
