// FakeAsrRuntime, the stand-in every on-device listener test uses (#1004):
// it behaves like the interface says, so the tests built on it mean
// something.

import 'dart:typed_data';

import 'package:fluenough/core/speech/asr/asr_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAsrRuntime', () {
    test('loads, answers what it was told and closes', () async {
      final answer = AsrOutput(
        Float32List.fromList(<double>[1, 2, 3, 4]),
        2,
        2,
      );
      final runtime = FakeAsrRuntime(output: answer);
      await runtime.load('/models/te/encoder.int8.onnx', threads: 3);
      expect(runtime.isLoaded, isTrue);
      expect(runtime.loadedPath, '/models/te/encoder.int8.onnx');
      expect(runtime.loadedThreads, 3);

      final features = Float32List.fromList(<double>[0, 1, 2, 3, 4, 5]);
      final out = await runtime.run(features, 3);
      expect(out, same(answer));
      expect(runtime.runs.single.$1, features);
      expect(runtime.runs.single.$2, 3);

      await runtime.close();
      expect(runtime.isLoaded, isFalse);
      expect(runtime.closeCalls, 1);
    });

    test('computes its answer from the features when told to', () async {
      final runtime = FakeAsrRuntime(
        onRun: (features, frames) =>
            AsrOutput(features, features.length ~/ frames, frames),
      );
      await runtime.load('m');
      final out = await runtime.run(Float32List(8), 4);
      expect(out.dim, 2);
      expect(out.frames, 4);
      expect(out.data.length, 8);
      expect(runtime.loadedThreads, 0);
    });

    test(
      'running with no model is no_model, and so is running after close',
      () async {
        final runtime = FakeAsrRuntime();
        await expectLater(
          runtime.run(Float32List(2), 1),
          throwsA(isA<AsrError>().having((e) => e.code, 'code', 'no_model')),
        );
        await runtime.load('m');
        await runtime.close();
        await expectLater(
          runtime.run(Float32List(2), 1),
          throwsA(isA<AsrError>().having((e) => e.code, 'code', 'no_model')),
        );
        expect(runtime.runCalls, 2);
        expect(runtime.runs, isEmpty);
      },
    );

    test('fails each call with the error it was given', () async {
      final runtime = FakeAsrRuntime(
        loadError: const AsrError('load_failed', 'bad file'),
        runError: const AsrError('out_of_memory', 'too big'),
        closeError: const AsrError('run_failed', 'stuck'),
      );
      await expectLater(
        runtime.load('m'),
        throwsA(
          isA<AsrError>().having((e) => e.message, 'message', 'bad file'),
        ),
      );
      expect(runtime.isLoaded, isFalse);
      expect(runtime.loadCalls, 1);

      runtime.loadError = null;
      await runtime.load('m');
      await expectLater(
        runtime.run(Float32List(2), 1),
        throwsA(isA<AsrError>().having((e) => e.code, 'code', 'out_of_memory')),
      );
      await expectLater(
        runtime.close(),
        throwsA(isA<AsrError>().having((e) => e.code, 'code', 'run_failed')),
      );
      expect(runtime.closeCalls, 1);
    });

    test('a second load replaces the first model', () async {
      final runtime = FakeAsrRuntime();
      await runtime.load('a');
      await runtime.load('b', threads: 2);
      expect(runtime.loadedPath, 'b');
      expect(runtime.loadedThreads, 2);
      expect(runtime.loadCalls, 2);
    });
  });

  group('AsrError', () {
    test('says its code and message', () {
      const error = AsrError('load_failed', 'no model file at /x');
      expect(error.toString(), 'AsrError(load_failed): no model file at /x');
      expect(error, isA<Exception>());
    });

    test('the codes are the ones the Kotlin side answers', () {
      expect(AsrErrorCode.noModel, 'no_model');
      expect(AsrErrorCode.loadFailed, 'load_failed');
      expect(AsrErrorCode.runFailed, 'run_failed');
      expect(AsrErrorCode.outOfMemory, 'out_of_memory');
    });
  });
}
