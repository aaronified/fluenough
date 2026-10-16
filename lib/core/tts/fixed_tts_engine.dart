import 'tts_engine.dart';

/// One call to [FixedTtsEngine.speak].
typedef SpokenText = ({String text, String bcp47, double rate, String? voice});

/// A [TtsEngine] with a fixed set of voices, that says nothing aloud and
/// remembers what it was asked to say. For tests and the debug gallery, like
/// [NullTtsEngine], but able to report a voice.
///
/// A language is available when its tag, or its primary subtag, is in
/// [voices]: `{'es'}` covers `es-ES` and `es-MX`. It has one voice,
/// `fixed-<tag>`, or the [named] ones given for its primary subtag.
class FixedTtsEngine implements TtsEngine {
  FixedTtsEngine(
    Set<String> voices, {
    this.named = const <String, List<TtsVoice>>{},
  }) : voices = Set<String>.unmodifiable(voices.map((v) => v.toLowerCase()));

  final Set<String> voices;

  /// The voices each language offers, by primary subtag, where it offers
  /// more than the one.
  final Map<String, List<TtsVoice>> named;

  /// An error the next [speak] calls throw, as an engine reports one.
  TtsFailure? failing;

  /// Every [speak] call so far, oldest first.
  final List<SpokenText> spoken = <SpokenText>[];

  int stops = 0;

  @override
  Future<bool> isLanguageAvailable(String bcp47) async {
    final tag = bcp47.toLowerCase();
    return voices.contains(tag) || voices.contains(tag.split('-').first);
  }

  @override
  Future<List<TtsVoice>> voicesFor(String bcp47) async {
    if (!await isLanguageAvailable(bcp47)) return const <TtsVoice>[];
    return named[bcp47.split('-').first.toLowerCase()] ??
        <TtsVoice>[TtsVoice(name: 'fixed-$bcp47', locale: bcp47)];
  }

  @override
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) async {
    if (text.trim().isEmpty || !await isLanguageAvailable(bcp47)) return;
    if (failing case final failure?) throw failure;
    // A voice the engine does not have is the default, as on a phone.
    final known = (await voicesFor(bcp47)).any((v) => v.name == voice);
    spoken.add((
      text: text,
      bcp47: bcp47,
      rate: rate,
      voice: known ? voice : null,
    ));
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}
}
