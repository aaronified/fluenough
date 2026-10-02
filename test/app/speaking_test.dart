import 'package:flutter_test/flutter_test.dart';

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

    test('a language the recogniser does not list is missing', () async {
      final speech = FixedSpeechEngine(onDevice: <String>{'ja'});
      final state = speaking(speech);
      addTearDown(state.dispose);
      await state.load();
      await state.setSpeaking(true);
      final info = state.deckById(spanish)!.language;
      expect(state.speechStatus(info), SpeechStatus.missing);
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

      final japanese = speaking(FixedSpeechEngine(onDevice: <String>{'ja'}));
      addTearDown(japanese.dispose);
      await japanese.load();
      await japanese.setSpeaking(true);
      expect(
        japanese
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

    test('another reading counts if the recogniser was fairly sure of it, '
        'and not otherwise', () async {
      final s = await session();
      addTearDown(s.dispose);
      final target = s.item.card.target;
      s.checkSpoken(<SpeechAlternative>[
        const SpeechAlternative('xyz', confidence: 0.9),
        SpeechAlternative(target, confidence: 0.6),
      ]);
      expect(s.answer!.graded!.outcome.isCorrect, isTrue);
      expect(s.answer!.typed, target);

      s.next();
      final second = s.item.card.target;
      s.checkSpoken(<SpeechAlternative>[
        const SpeechAlternative('xyz', confidence: 0.9),
        SpeechAlternative(second, confidence: 0.2),
      ]);
      expect(s.answer!.graded!.outcome.isCorrect, isFalse);
      expect(s.answer!.typed, 'xyz');
      expect(s.answer!.grade, 1);
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
    expect(
      SystemSpeechEngine.failureOf('error_language_unavailable'),
      SpeechFailure.notOnDevice,
    );
    expect(
      SystemSpeechEngine.failureOf('error_language_not_supported'),
      SpeechFailure.notOnDevice,
    );
    expect(
      SystemSpeechEngine.failureOf('error_speech_timeout'),
      SpeechFailure.noMatch,
    );
    expect(
      SystemSpeechEngine.failureOf('error_permission'),
      SpeechFailure.permissionDenied,
    );
    expect(
      SystemSpeechEngine.failureOf('error_network_timeout'),
      SpeechFailure.network,
    );
    expect(SystemSpeechEngine.failureOf('error_busy'), SpeechFailure.other);
  });
}
