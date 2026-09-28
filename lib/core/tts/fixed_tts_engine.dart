import 'tts_engine.dart';

/// One call to [FixedTtsEngine.speak].
typedef SpokenText = ({String text, String bcp47, double rate});

/// A [TtsEngine] with a fixed set of voices, that says nothing aloud and
/// remembers what it was asked to say. For tests and the debug gallery, like
/// [NullTtsEngine], but able to report a voice.
///
/// A language is available when its tag, or its primary subtag, is in
/// [voices]: `{'es'}` covers `es-ES` and `es-MX`.
class FixedTtsEngine implements TtsEngine {
  FixedTtsEngine(Set<String> voices)
    : voices = Set<String>.unmodifiable(voices.map((v) => v.toLowerCase()));

  final Set<String> voices;

  /// Every [speak] call so far, oldest first.
  final List<SpokenText> spoken = <SpokenText>[];

  int stops = 0;

  @override
  Future<bool> isLanguageAvailable(String bcp47) async {
    final tag = bcp47.toLowerCase();
    return voices.contains(tag) || voices.contains(tag.split('-').first);
  }

  @override
  Future<List<TtsVoice>> voicesFor(String bcp47) async =>
      await isLanguageAvailable(bcp47)
      ? <TtsVoice>[TtsVoice(name: 'fixed-$bcp47', locale: bcp47)]
      : const <TtsVoice>[];

  @override
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
  }) async {
    if (text.trim().isEmpty || !await isLanguageAvailable(bcp47)) return;
    spoken.add((text: text, bcp47: bcp47, rate: rate));
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}
}
