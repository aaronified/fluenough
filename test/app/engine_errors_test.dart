import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/speech/system_speech_engine.dart';
import 'package:fluenough/core/tts/system_tts_engine.dart';

/// What the phone's own speech and voice engines fail with reaches the app
/// log by its code (#162), rather than being swallowed into "no" or "none"
/// inside the engine.

/// The recogniser plugin, failing as asked: [broken] for every call, or a
/// languages question that never answers.
class _Recogniser extends SpeechToText {
  _Recogniser({this.broken, this.answersLanguages = true})
    : super.withMethodChannel();

  final PlatformException? broken;
  final bool answersLanguages;
  int stops = 0;

  @override
  Future<bool> get hasPermission async {
    if (broken case final e?) throw e;
    return true;
  }

  @override
  Future<bool> initialize({
    onError,
    onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    if (broken case final e?) throw e;
    return true;
  }

  @override
  Future<List<LocaleName>> locales() {
    if (broken case final e?) throw e;
    if (!answersLanguages) return Completer<List<LocaleName>>().future;
    return Future.value(<LocaleName>[LocaleName('hi_IN', 'Hindi')]);
  }

  /// Never answers: the recogniser neither hears nor gives up.
  @override
  Future<void> listen({
    onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {}

  @override
  Future<void> stop() async {
    stops++;
    if (broken case final e?) throw e;
  }

  @override
  Future<void> cancel() async {}
}

/// The voice plugin, throwing [broken] for whatever it is asked.
class _BrokenVoices extends FlutterTts {
  _BrokenVoices(this.broken);

  final PlatformException broken;

  @override
  Future<dynamic> isLanguageAvailable(String language) async => throw broken;

  @override
  Future<dynamic> get getVoices async => throw broken;
}

AppState _speaking(SpeechEngine speech) => AppState.test(
  speech: speech,
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
    enabledSkills: <Skill>{...Skill.values.where((s) => s.onByDefault)},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the recogniser', () {
    test('a failure to ready it is logged with its code', () async {
      final state = _speaking(
        SystemSpeechEngine(
          _Recogniser(
            broken: PlatformException(code: 'recognizerNotAvailable'),
          ),
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      expect(await state.startSpeech(), SpeechSetup.noRecogniser);
      expect(
        state.log.text,
        contains('Speech error: start recognizerNotAvailable'),
      );
    });

    test('a failure to say whether the microphone is granted is logged, '
        'at launch too', () async {
      final state = _speaking(
        SystemSpeechEngine(
          _Recogniser(broken: PlatformException(code: 'no_activity')),
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      await pumpEventQueue();
      expect(state.log.text, contains('Speech error: permission no_activity'));
    });

    testWidgets('languages that never come are logged as a timeout, and '
        'every language is then tried on the phone', (tester) async {
      final state = _speaking(
        SystemSpeechEngine(_Recogniser(answersLanguages: false)),
      );
      addTearDown(state.dispose);
      await tester.runAsync(state.load);
      final setup = state.startSpeech();
      await tester.pump(const Duration(seconds: 6));
      expect(await setup, SpeechSetup.ready);
      expect(state.log.text, contains('Speech error: languages timeout'));
      expect(state.speechStatus(state.languages.first), SpeechStatus.onDevice);
    });

    testWidgets('a listen that never answers fails with the code timeout', (
      tester,
    ) async {
      final listening = SystemSpeechEngine(_Recogniser())
          .listen(bcp47: 'hi-IN', onDevice: true);
      await tester.pump(const Duration(seconds: 13));
      final heard = await listening;
      expect(heard.failure, SpeechFailure.noMatch);
      expect(heard.code, 'timeout');
    });

    test('a listen whose recogniser cannot be readied says why', () async {
      final heard = await SystemSpeechEngine(
        _Recogniser(broken: PlatformException(code: 'recognizerNotAvailable')),
      ).listen(bcp47: 'hi-IN', onDevice: true);
      expect(heard.failure, SpeechFailure.noRecogniser);
      expect(heard.code, 'recognizerNotAvailable');
    });

    test('a failure to stop is logged', () async {
      final state = _speaking(
        SystemSpeechEngine(
          _Recogniser(broken: PlatformException(code: 'stop_failed')),
        ),
      );
      addTearDown(state.dispose);
      await state.stopListening();
      expect(state.log.text, contains('Speech error: stop stop_failed'));
    });
  });

  group('the voice engine', () {
    test('a failure to say whether it has a language, or which voices, is '
        'logged with its code', () async {
      final state = AppState.test(
        tts: SystemTtsEngine(
          tts: _BrokenVoices(PlatformException(code: 'no_engine')),
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      final spanish = state.languages.firstWhere((l) => l.code == 'es');
      expect(state.hasVoice(spanish), isFalse);
      expect(
        state.log.text,
        contains('Voice error: ${spanish.ttsTag} availability no_engine'),
      );
      expect(await state.voicesFor(spanish), isEmpty);
      expect(
        state.log.text,
        contains('Voice error: ${spanish.ttsTag} voices no_engine'),
      );
    });
  });
}
