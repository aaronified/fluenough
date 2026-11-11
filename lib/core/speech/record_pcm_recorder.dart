import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'asr/pcm_recorder.dart';

/// The microphone through `record`, as 16-bit mono PCM from `startStream`,
/// the same call [RecordMicCapture] uses (#1004). Nothing is written to disk.
///
/// Every error is reported to [log] and never thrown out of the stream: a
/// failed start ends the stream empty, and a failed stop is only logged.
class RecordPcmRecorder implements PcmRecorder {
  RecordPcmRecorder({this.log});

  final void Function(String)? log;
  AudioRecorder? _recorder;

  AudioRecorder _ensureRecorder() => _recorder ??= AudioRecorder();

  @override
  Future<bool> hasPermission() async {
    try {
      return await _ensureRecorder().hasPermission();
    } catch (e, st) {
      log?.call('RecordPcmRecorder: permission check failed: $e\n$st');
      return false;
    }
  }

  @override
  Stream<Uint8List> start(int sampleRate) {
    try {
      final recorder = _ensureRecorder();
      final started = recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );
      return Stream<Stream<Uint8List>>.fromFuture(started)
          .asyncExpand<Uint8List>((Stream<Uint8List> pcm) => pcm)
          .handleError((Object e, StackTrace st) {
            log?.call('RecordPcmRecorder: stream failed: $e\n$st');
          });
    } catch (e, st) {
      log?.call('RecordPcmRecorder: start failed: $e\n$st');
      return const Stream<Uint8List>.empty();
    }
  }

  @override
  Future<void> stop() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    try {
      await recorder.stop();
    } catch (e, st) {
      log?.call('RecordPcmRecorder: stop failed: $e\n$st');
    }
    try {
      await recorder.dispose();
    } catch (e, st) {
      log?.call('RecordPcmRecorder: dispose failed: $e\n$st');
    }
  }
}
