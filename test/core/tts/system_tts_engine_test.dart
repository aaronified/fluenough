import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:fluenough/core/tts/system_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';

/// The plugin as Android's flutter_tts 4.2.5 behaves: with
/// awaitSpeakCompletion, speak() completes when the utterance is done, and
/// an utterance that fails calls the error handler and never completes it.
class _Plugin extends FlutterTts {
  _Plugin();

  /// The voices getVoices lists, as the plugin gives them.
  List<Map<String, String>> voices = <Map<String, String>>[
    <String, String>{'name': 'es-es-x-eea', 'locale': 'es-ES'},
    <String, String>{'name': 'es-us-x-esd', 'locale': 'es-US'},
  ];

  /// What getVoices or isLanguageAvailable throws, for a broken engine.
  PlatformException? broken;

  /// The pending utterance, completed by [finish] or never.
  Completer<dynamic>? utterance;

  int voiceLists = 0;
  final List<String> calls = <String>[];

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    if (broken case final e?) throw e;
    return true;
  }

  @override
  Future<dynamic> get getVoices async {
    voiceLists++;
    if (broken case final e?) throw e;
    return voices;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    calls.add('language $language');
    return 1;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    calls.add('voice ${voice['name']}');
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) {
    calls.add('speak $text');
    return (utterance = Completer<dynamic>()).future;
  }

  @override
  Future<dynamic> stop() async => 1;

  /// The utterance ends as it should.
  void finish() => utterance!.complete(1);

  /// The engine reports an error, as onError does: through the handler,
  /// leaving speak() pending.
  void fail(String message) => errorHandler!(message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Plugin plugin;
  late SystemTtsEngine engine;
  setUp(() {
    plugin = _Plugin();
    engine = SystemTtsEngine(tts: plugin);
  });

  test('a word that plays completes when it is done', () async {
    var done = false;
    final speaking = engine
        .speak('hola', bcp47: 'es-ES')
        .then((_) => done = true);
    await pumpEventQueue();
    expect(plugin.calls, contains('speak hola'));
    expect(done, isFalse);
    plugin.finish();
    await speaking;
    expect(done, isTrue);
  });

  test('an error the engine reports only to its handler fails the word with '
      'its code, though the plugin never completes speak()', () async {
    final speaking = engine.speak('hola', bcp47: 'es-ES');
    await pumpEventQueue();
    plugin.fail('Error from TextToSpeech (speak) - -8');
    await expectLater(
      speaking.timeout(const Duration(seconds: 1)),
      throwsA(
        isA<TtsFailure>().having(
          (f) => f.code,
          'code',
          'Error from TextToSpeech (speak) - -8',
        ),
      ),
    );
  });

  test('an error for one word does not fail the next', () async {
    final first = engine.speak('hola', bcp47: 'es-ES');
    await pumpEventQueue();
    plugin.fail('Error from TextToSpeech (speak) - -8');
    await expectLater(first, throwsA(isA<TtsFailure>()));
    final second = engine.speak('adiós', bcp47: 'es-ES');
    await pumpEventQueue();
    plugin.finish();
    await second;
  });

  test('a chosen voice is looked up once, not for every word', () async {
    for (final word in <String>['uno', 'dos', 'tres']) {
      final speaking = engine.speak(word, bcp47: 'es-ES', voice: 'es-us-x-esd');
      await pumpEventQueue();
      plugin.finish();
      await speaking;
    }
    expect(plugin.voiceLists, 1);
    expect(plugin.calls, <String>[
      'language es-ES',
      'voice es-us-x-esd',
      'speak uno',
      'speak dos',
      'speak tres',
    ]);
  });

  test('a voice gone from the list asked for last is the language\'s '
      'default', () async {
    plugin.voices = <Map<String, String>>[
      <String, String>{'name': 'es-es-x-eea', 'locale': 'es-ES'},
    ];
    expect(await engine.voicesFor('es-ES'), hasLength(1));
    final speaking = engine.speak('uno', bcp47: 'es-ES', voice: 'es-us-x-esd');
    await pumpEventQueue();
    plugin.finish();
    await speaking;
    expect(plugin.calls, <String>['language es-ES', 'speak uno']);
    expect(plugin.voiceLists, 1);
  });

  test('after a failure the voices are asked for again, and the language '
      'and voice set again', () async {
    final first = engine.speak('uno', bcp47: 'es-ES', voice: 'es-us-x-esd');
    await pumpEventQueue();
    plugin.fail('Error from TextToSpeech (speak) - -9');
    await expectLater(first, throwsA(isA<TtsFailure>()));
    // The voice was removed meanwhile.
    plugin.voices = <Map<String, String>>[
      <String, String>{'name': 'es-es-x-eea', 'locale': 'es-ES'},
    ];
    plugin.calls.clear();
    final second = engine.speak('dos', bcp47: 'es-ES', voice: 'es-us-x-esd');
    await pumpEventQueue();
    plugin.finish();
    await second;
    expect(plugin.voiceLists, 2);
    expect(plugin.calls, <String>['language es-ES', 'speak dos']);
  });

  test('an engine that cannot list its voices or say whether it has a '
      'language says why, rather than answering none', () async {
    plugin.broken = PlatformException(code: 'no_engine');
    await expectLater(
      engine.voicesFor('es-ES'),
      throwsA(isA<TtsFailure>().having((f) => f.code, 'code', 'no_engine')),
    );
    await expectLater(
      engine.isLanguageAvailable('es-ES'),
      throwsA(isA<TtsFailure>().having((f) => f.code, 'code', 'no_engine')),
    );
    // Not remembered as missing: asked again once the engine answers.
    plugin.broken = null;
    expect(await engine.isLanguageAvailable('es-ES'), isTrue);
  });
}
