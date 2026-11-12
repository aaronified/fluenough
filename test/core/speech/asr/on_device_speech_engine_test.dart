import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/speech/asr/asr_pack.dart';
import 'package:fluenough/core/speech/asr/asr_runtime.dart';
import 'package:fluenough/core/speech/asr/on_device_speech_engine.dart';
import 'package:fluenough/core/speech/asr/pcm_recorder.dart';
import 'package:fluenough/core/speech/speech_engine.dart';

const int _rate = 16000;

Uint8List _pcm(int milliseconds, {double amplitude = 0}) {
  final samples = milliseconds * _rate ~/ 1000;
  final out = Uint8List(samples * 2);
  final data = ByteData.sublistView(out);
  for (var n = 0; n < samples; n++) {
    final value = amplitude == 0
        ? 0
        : (amplitude * 32767 * math.sin(2 * math.pi * 440 * n / _rate)).round();
    data.setInt16(2 * n, value, Endian.little);
  }
  return out;
}

/// A take of speech then enough quiet to end it, in 100 ms chunks.
void _speak(FakePcmRecorder recorder) {
  for (var i = 0; i < 5; i++) {
    recorder.add(_pcm(100, amplitude: 0.3));
  }
  for (var i = 0; i < 11; i++) {
    recorder.add(_pcm(100));
  }
}

/// A tiny head: dim 2, pieces `▁a` and `▁b`, the blank last. Class 0 follows
/// feature row 0, class 1 follows row 1, the blank has bias 1.
AsrPack _pack({String code = 'te', String? json, Uint8List? bytes}) {
  final weights = <double>[1, 0, 0, 1, 0, 0];
  final bias = <double>[0, 0, 1];
  final data = ByteData((weights.length + bias.length) * 4);
  var at = 0;
  for (final v in <double>[...weights, ...bias]) {
    data.setFloat32(at, v, Endian.little);
    at += 4;
  }
  final meta =
      json ??
      jsonEncode(<String, Object?>{
        'pieces': <String>['▁a', '▁b'],
        'blank': 2,
        'dim': 2,
        'vocab': 3,
        'language': code,
      });
  return AsrPack(
    code: code,
    encoderPath: '/files/asr/$code/encoder.int8.onnx',
    readHeadBytes: () async => bytes ?? data.buffer.asUint8List(),
    readHeadJson: () async => meta,
  );
}

/// The encoder says: frame 0 is `▁a`, frame 1 is `▁b`, frame 2 is blank.
AsrOutput _heardAB() =>
    AsrOutput(Float32List.fromList(<double>[10, 0, -10, 0, 10, -10]), 2, 3);

/// The encoder says blank everywhere.
AsrOutput _silent() => AsrOutput(Float32List(6), 2, 3);

Future<void> _until(bool Function() test) async {
  for (var i = 0; i < 200 && !test(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _ThrowingRecorder implements PcmRecorder {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Stream<Uint8List> start(int sampleRate) => throw StateError('no mic');

  @override
  Future<void> stop() async {}
}

void main() {
  group('OnDeviceSpeechEngine (#1004)', () {
    late List<String> logs;
    late FakePcmRecorder recorder;
    late FakeAsrRuntime runtime;

    OnDeviceSpeechEngine engine({
      Map<String, AsrPack>? packs,
      PcmRecorder? withRecorder,
      Object? packError,
    }) => OnDeviceSpeechEngine(
      packs: FakeAsrPackLocator(
        packs ?? <String, AsrPack>{'te': _pack()},
        error: packError,
      ),
      recorder: withRecorder ?? recorder,
      runtime: runtime,
      log: logs.add,
      timeoutGrace: Duration.zero,
    );

    setUp(() {
      logs = <String>[];
      recorder = FakePcmRecorder();
      runtime = FakeAsrRuntime(output: _heardAB());
    });

    test('hears the take: text, confidence and the same audio back', () async {
      _speak(recorder);
      final heard = await engine().listen(bcp47: 'te-IN', onDevice: true);

      expect(heard.failed, isFalse);
      expect(heard.alternatives.single.text, 'a b');
      expect(heard.alternatives.single.confidence, greaterThan(0.9));
      final audio = heard.ownAudio;
      expect(audio, isNotNull);
      expect(audio!.sampleRate, _rate);
      expect(audio.pcm16.length.isEven, isTrue);
      expect(audio.pcm16.length, greaterThanOrEqualTo(1500 * 32));
      expect(audio.pcm16.length, lessThanOrEqualTo(1600 * 32));
      expect(recorder.startedRate, _rate);
      expect(recorder.startCount, 1);
      expect(recorder.stopCount, 1);
      expect(runtime.loadedPath, '/files/asr/te/encoder.int8.onnx');
      expect(runtime.runCalls, 1);
      // [1, 80, frames], row by row.
      final (features, frames) = runtime.runs.single;
      expect(features.length, 80 * frames);
      expect(logs.last, contains('heard te'));
      expect(logs.last, contains('real-time factor'));
    });

    test('empty transcript is a no-match and keeps no audio', () async {
      runtime.output = _silent();
      _speak(recorder);
      final heard = await engine().listen(bcp47: 'te', onDevice: true);

      expect(heard.failure, SpeechFailure.noMatch);
      expect(heard.code, AsrSpeechCode.empty);
      expect(heard.alternatives, isEmpty);
      expect(logs.last, contains('empty transcript'));
    });

    test('no pack: notOnDevice, nothing recorded or loaded', () async {
      final heard = await engine(packs: <String, AsrPack>{})
          .listen(bcp47: 'te', onDevice: true);

      expect(heard.failure, SpeechFailure.notOnDevice);
      expect(heard.code, AsrSpeechCode.noPack);
      expect(recorder.startCount, 0);
      expect(runtime.loadCalls, 0);
      expect(logs.last, contains('no pack installed'));
    });

    test('a failing pack store is logged and means no pack', () async {
      final heard = await engine(packError: StateError('disk'))
          .listen(bcp47: 'te', onDevice: true);

      expect(heard.code, AsrSpeechCode.noPack);
      expect(logs.any((l) => l.contains('disk')), isTrue);
    });

    test('permission refused', () async {
      recorder = FakePcmRecorder(permitted: false);
      final heard = await engine().listen(bcp47: 'te', onDevice: true);

      expect(heard.failure, SpeechFailure.permissionDenied);
      expect(heard.code, AsrSpeechCode.permission);
      expect(recorder.startCount, 0);
    });

    test(
      'a runtime error is asr_runtime_error with the AsrError code',
      () async {
        runtime.runError = const AsrError(AsrErrorCode.runFailed, 'boom');
        _speak(recorder);
        final heard = await engine().listen(bcp47: 'te', onDevice: true);

        expect(heard.failure, SpeechFailure.other);
        expect(heard.code, AsrSpeechCode.runtimeError);
        expect(logs.last, contains('run_failed'));
        expect(logs.last, contains('boom'));
      },
    );

    test('a load error is asr_runtime_error too', () async {
      runtime.loadError = const AsrError(AsrErrorCode.loadFailed, 'no file');
      _speak(recorder);
      final heard = await engine().listen(bcp47: 'te', onDevice: true);

      expect(heard.code, AsrSpeechCode.runtimeError);
      expect(logs.any((l) => l.contains('load_failed')), isTrue);
    });

    test('a malformed head is asr_runtime_error', () async {
      _speak(recorder);
      final heard = await engine(
        packs: <String, AsrPack>{'te': _pack(json: 'not json')},
      ).listen(bcp47: 'te', onDevice: true);

      expect(heard.code, AsrSpeechCode.runtimeError);
      expect(logs.any((l) => l.contains('head')), isTrue);
    });

    test('an encoder answer of the wrong size is asr_runtime_error', () async {
      runtime.output = AsrOutput(Float32List(5), 2, 3);
      _speak(recorder);
      final heard = await engine().listen(bcp47: 'te', onDevice: true);

      expect(heard.code, AsrSpeechCode.runtimeError);
    });

    test('nobody speaks: no-match, the model is not run', () async {
      final e = OnDeviceSpeechEngine(
        packs: FakeAsrPackLocator(<String, AsrPack>{'te': _pack()}),
        recorder: recorder,
        runtime: runtime,
        log: logs.add,
        neverSpeechSeconds: 1,
        timeoutGrace: Duration.zero,
      );
      for (var i = 0; i < 12; i++) {
        recorder.add(_pcm(100));
      }
      final heard = await e.listen(bcp47: 'te', onDevice: true);

      expect(heard.failure, SpeechFailure.noMatch);
      expect(heard.code, AsrSpeechCode.noSpeech);
      expect(runtime.runCalls, 0);
    });

    test('a click is not speech', () async {
      final e = OnDeviceSpeechEngine(
        packs: FakeAsrPackLocator(<String, AsrPack>{'te': _pack()}),
        recorder: recorder,
        runtime: runtime,
        log: logs.add,
        neverSpeechSeconds: 1,
        timeoutGrace: Duration.zero,
      );
      recorder.add(_pcm(20, amplitude: 0.5));
      for (var i = 0; i < 12; i++) {
        recorder.add(_pcm(100));
      }
      final heard = await e.listen(bcp47: 'te', onDevice: true);

      expect(heard.code, AsrSpeechCode.noSpeech);
    });

    test('no audio before the deadline: timeout', () async {
      final heard = await engine().listen(
        bcp47: 'te',
        onDevice: true,
        listenFor: const Duration(milliseconds: 100),
      );

      expect(heard.failure, SpeechFailure.other);
      expect(heard.code, AsrSpeechCode.timeout);
      expect(recorder.stopCount, 1);
    });

    test('stop with nothing heard: no-match', () async {
      final e = engine();
      final listening = e.listen(bcp47: 'te', onDevice: true);
      await _until(() => recorder.startCount > 0);
      await e.stop();
      final heard = await listening;

      expect(heard.failure, SpeechFailure.noMatch);
      expect(heard.code, AsrSpeechCode.stopped);
      expect(recorder.stopCount, 1);
    });

    test('stop after speech keeps what was heard', () async {
      final e = engine();
      final listening = e.listen(bcp47: 'te', onDevice: true);
      await _until(() => recorder.startCount > 0);
      for (var i = 0; i < 5; i++) {
        recorder.add(_pcm(100, amplitude: 0.3));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await e.stop();
      final heard = await listening;

      expect(heard.alternatives.single.text, 'a b');
      expect(heard.ownAudio, isNotNull);
    });

    test('a recorder that throws never throws out of listen', () async {
      final heard = await engine(withRecorder: _ThrowingRecorder())
          .listen(bcp47: 'te', onDevice: true);

      expect(heard.failure, SpeechFailure.other);
      expect(heard.code, AsrSpeechCode.recordError);
      expect(logs.any((l) => l.contains('no mic')), isTrue);
    });

    test('a second listen while one runs is refused', () async {
      final e = engine();
      final first = e.listen(bcp47: 'te', onDevice: true);
      await _until(() => recorder.startCount > 0);
      final second = await e.listen(bcp47: 'te', onDevice: true);
      expect(second.code, AsrSpeechCode.busy);
      await e.stop();
      await first;
    });

    test(
      'languages lists the packs, start needs permission and a pack',
      () async {
        final e = engine();
        expect(await e.languages(), <String>{'te'});
        expect(await e.start(), isTrue);
        recorder = FakePcmRecorder(permitted: false);
        expect(await engine().start(), isFalse);
        expect(await engine(packs: <String, AsrPack>{}).start(), isFalse);
      },
    );
  });
}
