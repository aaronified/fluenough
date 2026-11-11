// Say keeps the learner's voice at the moment it is recognised (ADR-0054):
// on Android 13 and later the app owns the microphone and feeds the
// recogniser from it; in a browser a recorder runs beside the recogniser.
// Where neither can be done the engine listens as it always did, a cancelled
// or failed listen keeps nothing, and silence is never offered as a take.
import 'dart:typed_data';

import 'package:fluenough/core/speech/mic_capture.dart';
import 'package:fluenough/core/speech/native_listen.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/speech/system_speech_engine.dart';
import 'package:fluenough/core/speech/web_speech_browser.dart';
import 'package:fluenough/core/speech/web_speech_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 16-bit mono PCM of [count] samples at [level] (0 to 1).
Uint8List _pcm(int count, double level) {
  final bytes = ByteData(count * 2);
  for (var i = 0; i < count; i++) {
    bytes.setInt16(i * 2, (level * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

final OwnAudio _voice = OwnAudio(_pcm(16000, 0.4), sampleRate: 16000);

/// The plugin's recogniser, scripted: what a plain (second-route) listen does.
class _Plugin extends SpeechToText {
  _Plugin() : super.withMethodChannel();

  int listens = 0;
  void Function(SpeechRecognitionResult)? onResult;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    onError,
    onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async => true;

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
  }) async {
    listens++;
    this.onResult = onResult;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> stop() async {}
}

class _Capture implements MicCapture {
  int starts = 0;

  @override
  Future<void> start() async => starts++;

  @override
  Future<OwnAudio?> finish() async => null;
}

NativeListenResult _heardNative({OwnAudio? audio, String text = 'నమస్తే'}) =>
    NativeListenResult(
      alternatives: <SpeechAlternative>[
        SpeechAlternative(text, confidence: 0.9),
      ],
      pcm16: audio?.pcm16,
      sampleRate: audio?.sampleRate ?? 16000,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('recording at the same time is off by default (#1107)', () {
    test('the plain listen runs and neither the piped listen nor the capture '
        'starts', () async {
      final native = FixedNativeListener(
        results: <NativeListenResult>[_heardNative(audio: _voice)],
      );
      final plugin = _Plugin();
      final capture = _Capture();
      final engine = SystemSpeechEngine(plugin, capture, native);
      expect(engine.recordWhileRecognising, isFalse);
      final attempt = engine.listen(bcp47: 'te-IN', onDevice: false);
      await Future<void>.delayed(Duration.zero);
      expect(plugin.listens, 1);
      expect(native.listens, 0, reason: 'no EXTRA_AUDIO_SOURCE route');
      expect(capture.starts, 0, reason: 'no second recorder');
      plugin.onResult!(
        SpeechRecognitionResult(<SpeechRecognitionWords>[
          const SpeechRecognitionWords('నమస్తే', null, 0.9),
        ], ResultType.finalResult.value),
      );
      final h = await attempt;
      expect(h.alternatives.single.text, 'నమస్తే');
      expect(h.ownAudio, isNull, reason: 'Hear yourself records a take');
    });

    test('the browser is not asked to record beside the recogniser', () async {
      final browser = FixedSpeechBrowser(
        heard: const BrowserHeard(<SpeechAlternative>[
          SpeechAlternative('namaste'),
        ]),
        audio: _voice,
      );
      final h = await WebSpeechEngine(browser)
          .listen(bcp47: 'hi-IN', onDevice: false);
      expect(browser.recordings, <bool>[false]);
      expect(h.ownAudio, isNull);
    });

    test('with the switch on the browser records beside it', () async {
      final browser = FixedSpeechBrowser(
        heard: const BrowserHeard(<SpeechAlternative>[
          SpeechAlternative('namaste'),
        ]),
        audio: _voice,
      );
      final h = await WebSpeechEngine(
        browser,
        true,
      ).listen(bcp47: 'hi-IN', onDevice: false);
      expect(browser.recordings, <bool>[true]);
      expect(h.ownAudio, isNotNull);
    });
  });

  group('Android 13 and later: one stream for the recogniser and the take', () {
    test(
      'a listen gives the readings and the audio that was recognised',
      () async {
        final native = FixedNativeListener(
          results: <NativeListenResult>[_heardNative(audio: _voice)],
        );
        final plugin = _Plugin();
        final engine = SystemSpeechEngine(plugin, null, native, true);
        final h = await engine.listen(bcp47: 'te-IN', onDevice: true);
        expect(h.failed, isFalse);
        expect(h.alternatives.single.text, 'నమస్తే');
        expect(h.ownAudio, isNotNull);
        expect(h.ownAudio!.pcm16, _voice.pcm16);
        expect(h.ownAudio!.sampleRate, 16000);
        expect(native.listens, 1);
        expect(native.lastLanguage, 'te-IN');
        expect(native.lastOnDevice, isTrue);
        // The plugin never listened: one reader of the microphone.
        expect(plugin.listens, 0);
      },
    );

    test('silence is not offered as the learner\'s voice', () async {
      final native = FixedNativeListener(
        results: <NativeListenResult>[
          _heardNative(audio: OwnAudio(_pcm(16000, 0), sampleRate: 16000)),
        ],
      );
      final h = await SystemSpeechEngine(
        _Plugin(),
        null,
        native,
        true,
      ).listen(bcp47: 'te-IN', onDevice: true);
      expect(h.failed, isFalse);
      expect(
        h.ownAudio,
        isNull,
        reason: 'the drill then records a second take',
      );
    });

    test('a failure of the piped listen is not final: the same attempt '
        'listens again the plain way and that verdict is reported', () async {
      for (final error in <String>[
        'error_network',
        'error_language_unavailable',
        'error_permission',
      ]) {
        final native = FixedNativeListener(
          results: <NativeListenResult>[
            NativeListenResult(error: error, pcm16: _voice.pcm16),
          ],
        );
        final plugin = _Plugin();
        final engine = SystemSpeechEngine(plugin, null, native, true);
        final attempt = engine.listen(bcp47: 'te-IN', onDevice: true);
        await Future<void>.delayed(Duration.zero);
        expect(native.listens, 1, reason: error);
        expect(plugin.listens, 1, reason: '$error: plain attempt ran');
        plugin.onResult!(
          SpeechRecognitionResult(<SpeechRecognitionWords>[
            const SpeechRecognitionWords('నమస్తే', null, 0.9),
          ], ResultType.finalResult.value),
        );
        final h = await attempt;
        expect(h.failed, isFalse, reason: error);
        expect(h.alternatives.single.text, 'నమస్తే');
      }
    });

    test('a phone that cannot listen this way listens as before', () async {
      final native = FixedNativeListener(isAvailable: false);
      final plugin = _Plugin();
      final capture = _Capture();
      final engine = SystemSpeechEngine(plugin, capture, native, true);
      final listening = engine.listen(bcp47: 'te-IN', onDevice: true);
      await Future<void>.delayed(Duration.zero);
      expect(plugin.listens, 1, reason: 'the plain route listened');
      expect(native.listens, 0);
      plugin.onResult!(
        SpeechRecognitionResult(<SpeechRecognitionWords>[
          const SpeechRecognitionWords('నమస్తే', null, 0.9),
        ], ResultType.finalResult.value),
      );
      expect((await listening).alternatives.single.text, 'నమస్తే');
      expect(capture.starts, 1, reason: 'the best-effort capture still runs');
    });

    test('a failure of the native side falls back to the plain route, and '
        'two in a row stop it being tried', () async {
      final native = FixedNativeListener(
        results: <NativeListenResult>[
          const NativeListenResult(error: 'unsupported'),
        ],
      );
      final plugin = _Plugin();
      final engine = SystemSpeechEngine(plugin, null, native, true);
      for (var i = 0; i < 3; i++) {
        final listening = engine.listen(bcp47: 'te-IN', onDevice: true);
        await Future<void>.delayed(Duration.zero);
        plugin.onResult!(
          SpeechRecognitionResult(<SpeechRecognitionWords>[
            const SpeechRecognitionWords('x', null, 0.9),
          ], ResultType.finalResult.value),
        );
        await listening;
      }
      expect(plugin.listens, 3, reason: 'every listen was heard the plain way');
      expect(native.listens, 2, reason: 'not asked a third time');
    });

    test('nothing recognised from a silent stream is listened to again the '
        'plain way in the same attempt', () async {
      final silent = OwnAudio(_pcm(16000, 0), sampleRate: 16000);
      for (final first in <NativeListenResult>[
        NativeListenResult(error: 'error_no_match', pcm16: silent.pcm16),
        NativeListenResult(error: 'error_speech_timeout', pcm16: silent.pcm16),
        const NativeListenResult(error: 'error_no_match'),
        NativeListenResult(pcm16: silent.pcm16),
      ]) {
        final native = FixedNativeListener(
          results: <NativeListenResult>[first],
        );
        final plugin = _Plugin();
        final engine = SystemSpeechEngine(plugin, null, native, true);
        final attempt = engine.listen(bcp47: 'te-IN', onDevice: true);
        await Future<void>.delayed(Duration.zero);
        // The same attempt reached the plain route: no no-match was shown.
        expect(native.listens, 1, reason: '${first.error}');
        expect(plugin.listens, 1, reason: '${first.error}');
        plugin.onResult!(
          SpeechRecognitionResult(<SpeechRecognitionWords>[
            const SpeechRecognitionWords('నమస్తే', null, 0.9),
          ], ResultType.finalResult.value),
        );
        final h = await attempt;
        expect(h.failed, isFalse);
        expect(h.alternatives.single.text, 'నమస్తే');
        // Tried once more (one failure does not drop it), and again the
        // plain way in the same attempt.
        final again = engine.listen(bcp47: 'te-IN', onDevice: true);
        await Future<void>.delayed(Duration.zero);
        expect(native.listens, 2);
        expect(plugin.listens, 2);
        plugin.onResult!(
          SpeechRecognitionResult(<SpeechRecognitionWords>[
            const SpeechRecognitionWords('x', null, 0.9),
          ], ResultType.finalResult.value),
        );
        await again;
      }
    });

    test(
      'no match from the piped listen, even with a voice in the stream, '
      'is not final: the plain attempt runs in the same attempt (#1107)',
      () async {
        final native = FixedNativeListener(
          results: <NativeListenResult>[
            NativeListenResult(error: 'error_no_match', pcm16: _voice.pcm16),
          ],
        );
        final plugin = _Plugin();
        final engine = SystemSpeechEngine(plugin, null, native, true);
        final attempt = engine.listen(bcp47: 'te-IN', onDevice: true);
        await Future<void>.delayed(Duration.zero);
        expect(native.listens, 1);
        expect(
          plugin.listens,
          1,
          reason: 'no no-match shown before the fallback',
        );
        plugin.onResult!(
          SpeechRecognitionResult(<SpeechRecognitionWords>[
            const SpeechRecognitionWords('నమస్తే', null, 0.9),
          ], ResultType.finalResult.value),
        );
        final h = await attempt;
        expect(h.failed, isFalse);
        expect(h.alternatives.single.text, 'నమస్తే');
      },
    );

    test('the plain attempt\'s own no match is what the learner sees, and two '
        'piped failures in a row drop the piped route', () async {
      final native = FixedNativeListener(
        results: <NativeListenResult>[
          NativeListenResult(error: 'error_no_match', pcm16: _voice.pcm16),
        ],
      );
      final plugin = _Plugin();
      final engine = SystemSpeechEngine(plugin, null, native, true);
      for (var i = 0; i < 3; i++) {
        final attempt = engine.listen(bcp47: 'te-IN', onDevice: true);
        await Future<void>.delayed(Duration.zero);
        expect(plugin.listens, i + 1);
        plugin.onResult!(
          SpeechRecognitionResult(
            <SpeechRecognitionWords>[],
            ResultType.finalResult.value,
          ),
        );
        final h = await attempt;
        expect(h.failure, SpeechFailure.noMatch);
      }
      expect(native.listens, 2, reason: 'not asked a third time');
    });

    test('an aborted listen (the app was paused) is a failure, never a '
        'listen again in the background', () async {
      final native = FixedNativeListener(
        results: <NativeListenResult>[
          const NativeListenResult(error: 'aborted'),
        ],
      );
      final plugin = _Plugin();
      final h = await SystemSpeechEngine(
        plugin,
        null,
        native,
        true,
      ).listen(bcp47: 'te-IN', onDevice: true);
      expect(h.failed, isTrue);
      expect(h.failure, SpeechFailure.other);
      expect(plugin.listens, 0);
    });

    test('stop cancels the native listen', () async {
      final native = FixedNativeListener();
      await SystemSpeechEngine(_Plugin(), null, native, true).stop();
      expect(native.cancels, 1);
    });
  });

  group('which browsers record beside the recogniser', () {
    test('not Safari and not any browser on iOS, where it would abort the '
        'recogniser', () {
      const safari =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/17.4 Safari/605.1.15';
      const iphoneSafari =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
      const iphoneChrome =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 '
          '(KHTML, like Gecko) CriOS/124.0 Mobile/15E148 Safari/604.1';
      const chrome =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';
      const edge = '$chrome Edg/124.0';
      const androidChrome =
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';
      const firefox =
          'Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0';
      expect(recorderBesideRecognition(safari), isFalse);
      expect(recorderBesideRecognition(iphoneSafari), isFalse);
      expect(recorderBesideRecognition(iphoneChrome), isFalse);
      expect(recorderBesideRecognition(chrome), isTrue);
      expect(recorderBesideRecognition(edge), isTrue);
      expect(recorderBesideRecognition(androidChrome), isTrue);
      expect(recorderBesideRecognition(firefox), isTrue);
    });
  });

  group('what the channel answers', () {
    test('is read as readings, scores and the audio', () {
      final r = ChannelNativeListener.parse(<String, Object?>{
        'texts': <Object?>['నమస్తే', '  ', 'నమస్కారం'],
        'confidences': <Object?>[0.8, 0.0, -1.0],
        'error': null,
        'pcm': _voice.pcm16,
        'sampleRate': 16000,
      });
      expect(r.error, isNull);
      expect(r.alternatives.map((a) => a.text), <String>['నమస్తే', 'నమస్కారం']);
      expect(r.alternatives.first.confidence, 0.8);
      expect(r.alternatives.last.confidence, isNull, reason: '-1 is no score');
      expect(r.audio!.pcm16, _voice.pcm16);
    });

    test('an error, or something else, is an error of this side', () {
      expect(
        ChannelNativeListener.parse(<String, Object?>{'error': 'unsupported'})
            .fallsBack,
        isTrue,
      );
      expect(ChannelNativeListener.parse('nonsense').fallsBack, isTrue);
      expect(
        ChannelNativeListener.parse(<String, Object?>{
          'error': 'error_no_match',
        }).fallsBack,
        isFalse,
      );
    });

    test(
      'the channel is asked with the language, on-device and seconds',
      () async {
        final calls = <MethodCall>[];
        const channel = MethodChannel('test/native-listen');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return <String, Object?>{
                'texts': <Object?>['hi'],
                'confidences': <Object?>[0.5],
                'pcm': _voice.pcm16,
                'sampleRate': 16000,
              };
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final r = await const ChannelNativeListener(channel: channel).listen(
          bcp47: 'te-IN',
          onDevice: true,
          listenFor: const Duration(seconds: 6),
        );
        expect(r.alternatives.single.text, 'hi');
        expect(calls.single.method, 'listenWithAudio');
        expect(calls.single.arguments, <String, Object?>{
          'language': 'te-IN',
          'onDevice': true,
          'seconds': 6,
        });
        // Not Android in the test VM: never available.
        expect(
          await const ChannelNativeListener(channel: channel).available,
          isFalse,
        );
      },
    );
  });

  group('the browser: a recorder beside the recogniser', () {
    test('a listen gives the readings and the take', () async {
      final browser = FixedSpeechBrowser(
        heard: const BrowserHeard(<SpeechAlternative>[
          SpeechAlternative('namaste'),
        ]),
        audio: _voice,
      );
      final engine = WebSpeechEngine(browser, true);
      expect(await engine.start(), isTrue);
      final h = await engine.listen(bcp47: 'hi-IN', onDevice: false);
      expect(h.failed, isFalse);
      expect(h.ownAudio, isNotNull);
      expect(h.ownAudio!.pcm16, _voice.pcm16);
    });

    test('a failed listen keeps nothing', () async {
      final browser = FixedSpeechBrowser(
        heard: const BrowserHeard.error('no-speech'),
        audio: _voice,
      );
      final engine = WebSpeechEngine(browser, true);
      await engine.start();
      final h = await engine.listen(bcp47: 'hi-IN', onDevice: false);
      expect(h.failure, SpeechFailure.noMatch);
      expect(h.ownAudio, isNull);
    });

    test('a browser that cannot record gives readings and no take', () async {
      final engine = WebSpeechEngine(
        FixedSpeechBrowser(
          heard: const BrowserHeard(<SpeechAlternative>[
            SpeechAlternative('namaste'),
          ]),
        ),
        true,
      );
      await engine.start();
      final h = await engine.listen(bcp47: 'hi-IN', onDevice: false);
      expect(h.failed, isFalse);
      expect(h.ownAudio, isNull);
    });

    test('a reading with an error has no audio to keep', () {
      expect(
        const BrowserHeard.error('aborted').withAudio(_voice).ownAudio,
        isNull,
      );
      expect(
        const BrowserHeard(<SpeechAlternative>[]).withAudio(_voice).ownAudio,
        _voice,
      );
    });
  });
}
