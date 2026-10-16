import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'clip_player.dart';

/// [ClipPlayer] through `audioplayers`, which the sound check already uses
/// (#89): a card's recording, an Opus file on the phone (#518).
class SystemClipPlayer implements ClipPlayer {
  AudioPlayer? _player;

  /// The longest a recording of a word or a phrase may play before it is
  /// taken as stuck.
  static const Duration _longest = Duration(seconds: 30);

  @override
  Future<void> play(String path, {double rate = 1}) async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.setSource(DeviceFileSource(path));
    await player.setPlaybackRate(rate);
    final done = player.onPlayerStateChanged.firstWhere(
      (state) =>
          state == PlayerState.completed ||
          state == PlayerState.stopped ||
          state == PlayerState.disposed,
    );
    await player.resume();
    await done.timeout(_longest, onTimeout: () => PlayerState.stopped);
  }

  @override
  Future<void> stop() async => _player?.stop();
}
