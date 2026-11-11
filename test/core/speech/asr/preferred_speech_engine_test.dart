import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/speech/asr/asr_pack.dart';
import 'package:fluenough/core/speech/asr/on_device_speech_engine.dart';
import 'package:fluenough/core/speech/asr/preferred_speech_engine.dart';
import 'package:fluenough/core/speech/speech_engine.dart';

/// An engine that answers [heard] and remembers what it was asked.
class _Stub implements SpeechEngine {
  _Stub(this.heard, {this.languagesAre = const <String>{}});

  SpeechHeard heard;
  final Set<String> languagesAre;
  Object? throws;
  Completer<SpeechHeard>? hold;
  int listens = 0;
  int stops = 0;
  int starts = 0;
  int permissions = 0;
  final List<bool> onDeviceFlags = <bool>[];

  @override
  Future<bool> hasPermission() async {
    permissions++;
    return true;
  }

  @override
  Future<bool> start() async {
    starts++;
    return true;
  }

  @override
  Future<Set<String>> languages() async => languagesAre;

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    listens++;
    onDeviceFlags.add(onDevice);
    final e = throws;
    if (e != null) throw e;
    final h = hold;
    if (h != null) return h.future;
    return heard;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

SpeechHeard _text(String t) =>
    SpeechHeard(<SpeechAlternative>[SpeechAlternative(t, confidence: 0.9)]);

AsrPack _pack(String code) => AsrPack(
  code: code,
  encoderPath: '/asr/$code/encoder.int8.onnx',
  readHeadBytes: () async => Uint8List(0),
  readHeadJson: () async => '{}',
);

void main() {
  group('PreferOnDeviceSpeechEngine (#1004)', () {
    late List<String> logs;
    late _Stub onDevice;
    late _Stub system;

    PreferOnDeviceSpeechEngine make({
      Set<String> installed = const <String>{'te'},
      Object? packError,
    }) => PreferOnDeviceSpeechEngine(
      aiListener: onDevice,
      system: system,
      packs: FakeAsrPackLocator(<String, AsrPack>{
        for (final c in installed) c: _pack(c),
      }, error: packError),
      log: logs.add,
    );

    setUp(() {
      logs = <String>[];
      onDevice = _Stub(_text('on device'));
      system = _Stub(_text('system'));
    });

    test('an installed pack: the on-device engine only', () async {
      final heard = await make().listen(bcp47: 'te-IN', onDevice: false);

      expect(heard.alternatives.single.text, 'on device');
      expect(onDevice.listens, 1);
      expect(system.listens, 0);
      expect(onDevice.onDeviceFlags, <bool>[true]);
    });

    test('an empty transcript is a no-match, not retried', () async {
      onDevice.heard = const SpeechHeard.failed(
        SpeechFailure.noMatch,
        code: AsrSpeechCode.empty,
      );
      final heard = await make().listen(bcp47: 'te', onDevice: false);

      expect(heard.failure, SpeechFailure.noMatch);
      expect(system.listens, 0);
    });

    test('permission and other failures are not retried either', () async {
      onDevice.heard = const SpeechHeard.failed(
        SpeechFailure.permissionDenied,
        code: AsrSpeechCode.permission,
      );
      final heard = await make().listen(bcp47: 'te', onDevice: false);

      expect(heard.failure, SpeechFailure.permissionDenied);
      expect(system.listens, 0);
    });

    test(
      'a runtime error falls back once to the system engine, logged',
      () async {
        onDevice.heard = const SpeechHeard.failed(
          SpeechFailure.other,
          code: AsrSpeechCode.runtimeError,
        );
        final heard = await make().listen(
          bcp47: 'te',
          onDevice: true,
          listenFor: const Duration(seconds: 3),
        );

        expect(heard.alternatives.single.text, 'system');
        expect(onDevice.listens, 1);
        expect(system.listens, 1);
        expect(logs.single, contains('asr_runtime_error'));
        expect(logs.single, contains('system recogniser'));
      },
    );

    test('an engine that throws counts as a runtime error', () async {
      onDevice.throws = StateError('native crash');
      final heard = await make().listen(bcp47: 'te', onDevice: false);

      expect(heard.alternatives.single.text, 'system');
      expect(logs.any((l) => l.contains('native crash')), isTrue);
    });

    test(
      'the system engine failing after a fallback is returned as is',
      () async {
        onDevice.heard = const SpeechHeard.failed(
          SpeechFailure.other,
          code: AsrSpeechCode.runtimeError,
        );
        system.heard = const SpeechHeard.failed(
          SpeechFailure.network,
          code: 'error_network',
        );
        final heard = await make().listen(bcp47: 'te', onDevice: false);

        expect(heard.failure, SpeechFailure.network);
        expect(onDevice.listens, 1);
        expect(system.listens, 1);
      },
    );

    test('no pack: the system engine, with the caller\'s flag', () async {
      final heard = await make(installed: <String>{'bn'})
          .listen(bcp47: 'te', onDevice: true);

      expect(heard.alternatives.single.text, 'system');
      expect(onDevice.listens, 0);
      expect(system.onDeviceFlags, <bool>[true]);
    });

    test(
      'a failing pack store is logged and means the system engine',
      () async {
        final heard = await make(packError: StateError('disk'))
            .listen(bcp47: 'te', onDevice: false);

        expect(heard.alternatives.single.text, 'system');
        expect(onDevice.listens, 0);
        expect(logs.any((l) => l.contains('disk')), isTrue);
      },
    );

    test('start and hasPermission go to the system engine', () async {
      final e = make();
      expect(await e.start(), isTrue);
      expect(await e.hasPermission(), isTrue);

      expect(system.starts, 1);
      expect(system.permissions, 1);
      expect(onDevice.starts, 0);
      expect(onDevice.permissions, 0);
    });

    test('languages are the system\'s plus the installed packs\'', () async {
      system = _Stub(_text('system'), languagesAre: <String>{'hi', 'bn'});
      final e = make(installed: <String>{'te', 'bn'});

      expect(await e.languages(), <String>{'hi', 'bn', 'te'});
    });

    test('stop reaches the engine that is listening', () async {
      onDevice.hold = Completer<SpeechHeard>();
      final e = make();
      final listening = e.listen(bcp47: 'te', onDevice: false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await e.stop();
      onDevice.hold!.complete(_text('on device'));
      await listening;

      expect(onDevice.stops, 1);
      expect(system.stops, 0);

      await e.stop();
      expect(system.stops, 1, reason: 'idle: the system engine, as before');
    });
  });
}
