/// A voice offered by a TTS engine.
class TtsVoice {
  const TtsVoice({
    required this.name,
    required this.locale,
    this.networkRequired = false,
  });

  /// The engine's name for it, which [TtsEngine.speak] takes to choose it.
  final String name;

  /// BCP-47 tag, e.g. `es-ES`.
  final String locale;

  /// Whether it speaks only with a connection: a voice the app, which works
  /// offline, marks as such.
  final bool networkRequired;

  @override
  String toString() => '$name ($locale)';
}

/// Why the engine could not speak: its own error code, never the text it
/// was given, so that the app log can say exactly what failed (#162).
class TtsFailure implements Exception {
  const TtsFailure(this.code);

  final String code;

  @override
  String toString() => 'TtsFailure($code)';
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
  ///
  /// Throws a [TtsFailure] when the engine cannot say, so that the caller
  /// can log why before treating it as no voice.
  Future<bool> isLanguageAvailable(String bcp47);

  /// The voices the engine lists for [bcp47], asked afresh each time.
  ///
  /// Throws a [TtsFailure] when the engine cannot say.
  Future<List<TtsVoice>> voicesFor(String bcp47);

  /// Speaks [text]. Completes when playback finishes, so drills can await it.
  ///
  /// [rate] is 0.0–1.0 in engine-defined units. Learners routinely want slower
  /// than natural speech, which is why it is a per-call argument.
  ///
  /// [voice] is a [TtsVoice.name] from [voicesFor], the learner's choice
  /// (#123), or null for the engine's default for [bcp47]. A voice the
  /// engine no longer listed when last asked falls back to the default.
  ///
  /// Throws a [TtsFailure] when the engine reports an error, whether by
  /// throwing or through its error handler while speaking.
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate,
    String? voice,
  });

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
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
