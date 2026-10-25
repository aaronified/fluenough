import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/speech/system_speech_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// A recogniser that lets the test play out Android's callbacks.
class _Android extends SpeechToText {
  _Android() : super.withMethodChannel();

  void Function(String)? status;
  void Function(SpeechRecognitionResult)? result;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    onError,
    onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    status = onStatus;
    return true;
  }

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
    result = onResult;
  }

  @override
  Future<void> cancel() async {}
}

SpeechRecognitionResult _said(String words, {required bool isFinal}) =>
    SpeechRecognitionResult(<SpeechRecognitionWords>[
      SpeechRecognitionWords(words, null, 0.9),
    ], isFinal ? ResultType.finalResult.value : ResultType.partial.value);

void main() {
  /// Starts a listen, plays Android's callbacks, and gives what was heard.
  Future<SpeechHeard> heard(
    WidgetTester tester,
    _Android android,
    Future<void> Function() play,
  ) async {
    final listening = SystemSpeechEngine(android)
        .listen(bcp47: 'hi-IN', onDevice: true);
    await tester.pump();
    await play();
    // Past the listen's own deadline (listenFor 8 s + 4 s grace).
    await tester.pump(const Duration(seconds: 15));
    return listening;
  }

  testWidgets('a final result that comes after the done status is heard', (
    tester,
  ) async {
    final android = _Android();
    final h = await heard(tester, android, () async {
      android.status!('done');
      await tester.pump(const Duration(milliseconds: 800));
      android.result!(_said('नमस्ते', isFinal: true));
    });
    expect(h.failed, isFalse);
    expect(h.alternatives.single.text, 'नमस्ते');
  });

  testWidgets('the last partial result is heard when no final one comes', (
    tester,
  ) async {
    final android = _Android();
    final h = await heard(tester, android, () async {
      android.result!(_said('नमस्ते', isFinal: false));
      android.status!('done');
    });
    expect(h.failed, isFalse);
    expect(h.alternatives.single.text, 'नमस्ते');
  });

  testWidgets('the last partial result is heard when the deadline passes', (
    tester,
  ) async {
    final android = _Android();
    final h = await heard(tester, android, () async {
      android.result!(_said('नमस्ते', isFinal: false));
    });
    expect(h.failed, isFalse);
    expect(h.alternatives.single.text, 'नमस्ते');
  });

  testWidgets('done with nothing heard is no match coded done-before-result, '
      'and an empty final result is coded empty-result', (tester) async {
    final done = await heard(tester, _Android(), () async {});
    expect(done.failure, SpeechFailure.noMatch);
    // No callback at all ends in the listen's own deadline instead.
    expect(done.code, 'timeout');

    final android = _Android();
    final silent = await heard(
      tester,
      android,
      () async => android.status!('done'),
    );
    expect(silent.failure, SpeechFailure.noMatch);
    expect(silent.code, 'done-before-result');

    final other = _Android();
    final empty = await heard(
      tester,
      other,
      () async => other.result!(_said('  ', isFinal: true)),
    );
    expect(empty.failure, SpeechFailure.noMatch);
    expect(empty.code, 'empty-result');
  });
}
