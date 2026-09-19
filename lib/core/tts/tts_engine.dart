/// A voice offered by a TTS engine.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  final String name;

  /// BCP-47 tag, e.g. `es-ES`.
  final String locale;

  @override
  String toString() => '$name ($locale)';
}

/// Text to speech, narrow enough that a second implementation is additive.
///
/// Nothing outside `lib/core/tts` may refer to a concrete engine. The v1
/// implementation wraps the operating system's synthesiser; a neural backend
/// can be added later without touching drill code. See
/// `docs/adr/0002-system-tts.md`.
abstract interface class TtsEngine {
  /// Whether a voice for [bcp47] is installed and usable.
  ///
  /// Listening drills are *hidden* rather than broken when this is false. A
  /// language-agnostic app has to degrade gracefully on a device that has no
  /// voice for the deck's language — which is the common case for anything
  /// outside the major languages.
  Future<bool> isLanguageAvailable(String bcp47);

  Future<List<TtsVoice>> voicesFor(String bcp47);

  /// Speaks [text]. Completes when playback finishes, so drills can await it.
  ///
  /// [rate] is 0.0–1.0 in engine-defined units. Learners routinely want slower
  /// than natural speech, which is why it is a per-call argument.
  Future<void> speak(String text, {required String bcp47, double rate});

  Future<void> stop();

  Future<void> dispose();
}

/// A no-op engine for tests and for devices with no synthesiser at all.
class NullTtsEngine implements TtsEngine {
  const NullTtsEngine();

  @override
  Future<bool> isLanguageAvailable(String bcp47) async => false;

  @override
  Future<List<TtsVoice>> voicesFor(String bcp47) async => const <TtsVoice>[];

  @override
  Future<void> speak(String text,
      {required String bcp47, double rate = 0.5}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
