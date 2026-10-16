/// Plays a card's own recording (#518): a file shipped with its deck,
/// downloaded to the phone, said by a person rather than the phone's voice.
///
/// Narrow enough that tests fake it, as the TTS engine is. Only `main.dart`
/// names the one that reaches the platform ([SystemClipPlayer]).
abstract interface class ClipPlayer {
  /// Plays the file at [path] on the phone, at [rate] times its speed, and
  /// completes when it ends or is stopped. Throws when it cannot play it.
  Future<void> play(String path, {double rate = 1});

  /// Stops what is playing, if anything.
  Future<void> stop();
}

/// No player: a recording cannot be played, so the card is spoken by the
/// phone's voice instead. The default, for tests and the gallery.
class NullClipPlayer implements ClipPlayer {
  const NullClipPlayer();

  @override
  Future<void> play(String path, {double rate = 1}) async =>
      throw UnsupportedError('no clip player');

  @override
  Future<void> stop() async {}
}

/// Records what it was asked to play, for tests.
class FakeClipPlayer implements ClipPlayer {
  final List<(String, double)> played = <(String, double)>[];

  /// While set, [play] throws it.
  Object? failure;

  @override
  Future<void> play(String path, {double rate = 1}) async {
    if (failure case final failure?) throw failure;
    played.add((path, rate));
  }

  @override
  Future<void> stop() async {}
}
