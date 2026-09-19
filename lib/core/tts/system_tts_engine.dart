import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// [TtsEngine] backed by the operating system: `android.speech.tts` on
/// Android, `AVSpeechSynthesizer` on iOS.
///
/// Adds nothing to the download size, needs no network, and covers far more
/// languages than any bundled model could. Voice quality and language coverage
/// are the device's business, not ours — on Android, users install voices
/// through system settings.
class SystemTtsEngine implements TtsEngine {
  SystemTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// Availability is stable for the lifetime of the process and each query
  /// crosses the platform channel, so it is worth caching.
  final Map<String, bool> _availability = <String, bool>{};

  String? _currentLanguage;
  double? _currentRate;

  @override
  Future<bool> isLanguageAvailable(String bcp47) async {
    final cached = _availability[bcp47];
    if (cached != null) return cached;

    bool available;
    try {
      available = await _tts.isLanguageAvailable(bcp47) == true;
    } on Exception {
      // A device with no engine installed throws rather than returning false.
      available = false;
    }
    _availability[bcp47] = available;
    return available;
  }

  @override
  Future<List<TtsVoice>> voicesFor(String bcp47) async {
    final List<dynamic> raw;
    try {
      raw = await _tts.getVoices as List<dynamic>? ?? const <dynamic>[];
    } on Exception {
      return const <TtsVoice>[];
    }

    final prefix = bcp47.split('-').first.toLowerCase();
    final voices = <TtsVoice>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString();
      final locale = entry['locale']?.toString();
      if (name == null || locale == null) continue;
      if (!locale.toLowerCase().startsWith(prefix)) continue;
      voices.add(TtsVoice(name: name, locale: locale));
    }
    return voices;
  }

  @override
  Future<void> speak(String text,
      {required String bcp47, double rate = 0.5}) async {
    if (text.trim().isEmpty) return;
    if (!await isLanguageAvailable(bcp47)) return;

    if (_currentLanguage != bcp47) {
      await _tts.setLanguage(bcp47);
      _currentLanguage = bcp47;
    }
    if (_currentRate != rate) {
      await _tts.setSpeechRate(rate);
      _currentRate = rate;
    }

    // awaitSpeakCompletion makes speak() resolve when playback ends rather
    // than when it starts, so a drill can await the audio before accepting an
    // answer.
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() async {
    await _tts.stop();
  }
}
