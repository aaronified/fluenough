// ChannelAsrRuntime (#1004): what it sends to the Kotlin side of
// app.fluenough/asr, how it reads the answer, and that every failure is
// logged and thrown as an AsrError carrying the platform's code.

import 'dart:typed_data';

import 'package:fluenough/app/channel_asr_runtime.dart';
import 'package:fluenough/core/speech/asr/asr_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.fluenough/asr');
  final calls = <MethodCall>[];
  final logs = <String>[];
  late ChannelAsrRuntime runtime;
  Future<Object?> Function(MethodCall call) handler = (call) async => null;

  setUp(() {
    calls.clear();
    logs.clear();
    handler = (call) async => null;
    runtime = ChannelAsrRuntime(log: logs.add);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Uint8List bytesOf(List<double> values) =>
      Float32List.fromList(values).buffer.asUint8List();

  Matcher asrError(String code) =>
      isA<AsrError>().having((e) => e.code, 'code', code);

  test('uses the app.fluenough/asr channel by default', () {
    expect(ChannelAsrRuntime.defaultChannel.name, 'app.fluenough/asr');
  });

  group('load', () {
    test('sends the path and the threads', () async {
      await runtime.load('/files/asr/te/encoder.int8.onnx', threads: 4);
      expect(calls.single.method, 'load');
      expect(calls.single.arguments, <String, Object?>{
        'path': '/files/asr/te/encoder.int8.onnx',
        'threads': 4,
      });
      expect(logs, isEmpty);
    });

    test('lets the runtime choose the threads by default', () async {
      await runtime.load('/m.onnx');
      expect((calls.single.arguments as Map<Object?, Object?>)['threads'], 0);
    });

    for (final code in <String>['load_failed', 'out_of_memory']) {
      test('maps the platform code $code and logs it', () async {
        handler = (call) async =>
            throw PlatformException(code: code, message: 'it said no');
        await expectLater(runtime.load('/m.onnx'), throwsA(asrError(code)));
        expect(logs.single, contains('load'));
        expect(logs.single, contains(code));
        expect(logs.single, contains('it said no'));
      });
    }

    test('a missing channel is load_failed, logged', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(
        runtime.load('/m.onnx'),
        throwsA(asrError('load_failed')),
      );
      expect(logs.single, contains('load_failed'));
    });
  });

  group('run', () {
    test('sends the feature bytes and frames, and reads the answer', () async {
      handler = (call) async => <String, Object?>{
        'data': bytesOf(<double>[0.5, -1, 2, 3, 4, 5]),
        'dims': <int>[1, 2, 3],
      };
      final features = Float32List.fromList(<double>[1, 2, 3, 4, 5, 6]);
      final out = await runtime.run(features, 3);

      expect(calls.single.method, 'run');
      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args['frames'], 3);
      expect(args['features'], bytesOf(<double>[1, 2, 3, 4, 5, 6]));

      expect(out.dim, 2);
      expect(out.frames, 3);
      expect(out.data, <double>[0.5, -1, 2, 3, 4, 5]);
      expect(logs, isEmpty);
    });

    test('sends only the bytes of a view, not the buffer behind it', () async {
      handler = (call) async => <String, Object?>{
        'data': bytesOf(<double>[1]),
        'dims': <int>[1, 1, 1],
      };
      final backing = Float32List.fromList(<double>[9, 1, 2, 9]);
      await runtime.run(Float32List.sublistView(backing, 1, 3), 2);
      final sent =
          (calls.single.arguments as Map<Object?, Object?>)['features']!
              as Uint8List;
      expect(sent, bytesOf(<double>[1, 2]));
    });

    for (final code in <String>['no_model', 'run_failed', 'out_of_memory']) {
      test('maps the platform code $code and logs it', () async {
        handler = (call) async =>
            throw PlatformException(code: code, message: 'because');
        await expectLater(
          runtime.run(Float32List(4), 2),
          throwsA(asrError(code)),
        );
        expect(logs.single, contains(code));
        expect(logs.single, contains('because'));
      });
    }

    test('keeps a code it does not know', () async {
      handler = (call) async => throw PlatformException(code: 'odd');
      await expectLater(
        runtime.run(Float32List(4), 2),
        throwsA(asrError('odd')),
      );
      expect(logs.single, contains('odd'));
    });

    test('refuses features that are not whole rows, without asking', () async {
      await expectLater(
        runtime.run(Float32List(5), 2),
        throwsA(asrError('run_failed')),
      );
      await expectLater(
        runtime.run(Float32List(4), 0),
        throwsA(asrError('run_failed')),
      );
      await expectLater(
        runtime.run(Float32List(0), 2),
        throwsA(asrError('run_failed')),
      );
      expect(calls, isEmpty);
      expect(logs, hasLength(3));
    });

    test('a malformed answer is run_failed, logged', () async {
      final answers = <Object?>[
        null,
        <String, Object?>{
          'dims': <int>[1, 2, 3],
        },
        <String, Object?>{
          'data': bytesOf(<double>[1]),
          'dims': <int>[2, 1],
        },
        <String, Object?>{
          'data': bytesOf(<double>[1]),
          'dims': <int>[1, 2, 3],
        },
        <String, Object?>{
          'data': bytesOf(<double>[1]),
          'dims': <int>[1, 0, 1],
        },
      ];
      for (final answer in answers) {
        logs.clear();
        handler = (call) async => answer;
        await expectLater(
          runtime.run(Float32List(4), 2),
          throwsA(asrError('run_failed')),
        );
        expect(logs, hasLength(1), reason: '$answer');
      }
    });

    test('a missing channel is run_failed, logged', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(
        runtime.run(Float32List(4), 2),
        throwsA(asrError('run_failed')),
      );
      expect(logs.single, contains('run_failed'));
    });
  });

  group('close', () {
    test('asks the platform to release the model', () async {
      await runtime.close();
      expect(calls.single.method, 'close');
      expect(logs, isEmpty);
    });

    test('a failure is thrown as an AsrError and logged', () async {
      handler = (call) async =>
          throw PlatformException(code: 'run_failed', message: 'stuck');
      await expectLater(runtime.close(), throwsA(asrError('run_failed')));
      expect(logs.single, contains('close'));
      expect(logs.single, contains('stuck'));
    });
  });

  test('a logger that throws does not hide the failure', () async {
    final loud = ChannelAsrRuntime(log: (line) => throw StateError('log full'));
    handler = (call) async => throw PlatformException(code: 'load_failed');
    await expectLater(loud.load('/m.onnx'), throwsA(asrError('load_failed')));
  });
}
