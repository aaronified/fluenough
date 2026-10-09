import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
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

  /// The voice chosen last, by name, or null for the language's default.
  String? _currentVoice;

  /// The engine's last error while speaking, from its error handler.
  String? _error;
  bool _handling = false;

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
      // Android gives "1" or "0", or a bool, as the plugin's version does.
      final network = entry['network_required']?.toString();
      voices.add(
        TtsVoice(
          name: name,
          locale: locale,
          networkRequired: network == '1' || network == 'true',
        ),
      );
    }
    return voices;
  }

  @override
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) async {
    if (text.trim().isEmpty) return;
    if (!await isLanguageAvailable(bcp47)) return;
    if (!_handling) {
      // The plugin reports an error while speaking here, not by throwing.
      // Its message names the engine's error, never the text.
      _tts.setErrorHandler((message) => _error = '$message');
      _handling = true;
    }

    try {
      // A voice the engine no longer lists, removed since it was chosen,
      // is the default (#123).
      final chosen = voice == null
          ? null
          : (await voicesFor(bcp47)).where((v) => v.name == voice).firstOrNull;
      if (_currentLanguage != bcp47 ||
          (_currentVoice != null && chosen == null)) {
        // Setting the language goes back to its default voice.
        await _tts.setLanguage(bcp47);
        _currentLanguage = bcp47;
        _currentVoice = null;
      }
      if (chosen != null && _currentVoice != chosen.name) {
        await _tts.setVoice(<String, String>{
          'name': chosen.name,
          'locale': chosen.locale,
        });
        _currentVoice = chosen.name;
      }
      if (_currentRate != rate) {
        await _tts.setSpeechRate(rate);
        _currentRate = rate;
      }

      _error = null;
      // awaitSpeakCompletion makes speak() resolve when playback ends rather
      // than when it starts, so a drill can await the audio before accepting
      // an answer.
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } on PlatformException catch (e) {
      throw TtsFailure(e.code);
    }
    if (_error case final error?) {
      _error = null;
      throw TtsFailure(error);
    }
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() async {
    await _tts.stop();
  }
}
