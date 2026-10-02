import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import 'sound_check.dart';

/// The phone's microphone, through `record`, and its speaker, through
/// `audioplayers` (#89). The recording stays in memory: it streams as PCM,
/// is wrapped as WAV, played back, and dropped. Nothing is saved.
class SystemSoundCheck implements SoundCheckEngine {
  SystemSoundCheck();

  static const int _sampleRate = 16000;

  /// Below this peak a recording counts as silence: a muted or covered
  /// microphone still picks up a little noise.
  static const double silence = 0.01;

  @override
  Future<Recording> record(Duration duration) async {
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        return const Recording.failed(RecordFailure.refused);
      }
      // The recorder may change the rate or channels to suit the
      // microphone; the WAV header must say what it really used.
      var sampleRate = _sampleRate;
      var channels = 1;
      await recorder.setOnConfigChanged((config) {
        sampleRate = config.sampleRate;
        channels = config.numChannels;
      });
      final bytes = BytesBuilder(copy: false);
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      final listening = stream.listen(bytes.add);
      await Future<void>.delayed(duration);
      await recorder.stop();
      await listening.cancel();
      final pcm = bytes.takeBytes();
      if (pcm.isEmpty) return const Recording.failed(RecordFailure.failed);
      if (peakOfPcm16(pcm) < silence) {
        return const Recording.failed(RecordFailure.silent);
      }
      return Recording(
        wavFromPcm16(pcm, sampleRate: sampleRate, channels: channels),
      );
    } catch (_) {
      return const Recording.failed(RecordFailure.failed);
    } finally {
      unawaited(recorder.dispose());
    }
  }

  @override
  Future<bool> play(Recording recording) async {
    final wav = recording.wav;
    if (wav == null) return false;
    final player = AudioPlayer();
    final done = Completer<void>();
    final completes = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await player.play(BytesSource(wav, mimeType: 'audio/wav'));
      // The recording's own length, from its header's bytes per second,
      // and a little more for the player to start; a player that never
      // reports is given up on.
      final byteRate = ByteData.sublistView(wav).getUint32(28, Endian.little);
      final millis = (wav.length - 44) * 1000 ~/ byteRate;
      await done.future.timeout(Duration(milliseconds: millis + 3000));
      return true;
    } catch (_) {
      return false;
    } finally {
      await completes.cancel();
      unawaited(player.dispose());
    }
  }
}
