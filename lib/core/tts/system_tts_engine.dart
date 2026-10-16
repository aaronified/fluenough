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

  /// Every voice the engine listed when last asked, so that speaking in a
  /// chosen voice need not ask again for each word. [voicesFor] asks again;
  /// a failure to speak forgets it.
  List<TtsVoice>? _voices;

  /// Completed with the engine's error while a word is spoken. The plugin
  /// reports one only through its error handler, and never completes the
  /// pending speak() call, so [speak] waits on this as well.
  Completer<String>? _failed;
  bool _handling = false;

  @override
  Future<bool> isLanguageAvailable(String bcp47) async {
    final cached = _availability[bcp47];
    if (cached != null) return cached;

    final bool available;
    try {
      available = await _tts.isLanguageAvailable(bcp47) == true;
    } on Exception catch (e) {
      // A device with no engine installed throws rather than returning
      // false. Not remembered: the app log has it, and it is asked again.
      throw TtsFailure(_codeOf(e));
    }
    _availability[bcp47] = available;
    return available;
  }

  @override
  Future<List<TtsVoice>> voicesFor(String bcp47) async =>
      _forLanguage(_voices = await _listVoices(), bcp47);

  /// Every voice the engine lists, in every language.
  Future<List<TtsVoice>> _listVoices() async {
    final List<dynamic> raw;
    try {
      raw = await _tts.getVoices as List<dynamic>? ?? const <dynamic>[];
    } on Exception catch (e) {
      throw TtsFailure(_codeOf(e));
    }
    final voices = <TtsVoice>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString();
      final locale = entry['locale']?.toString();
      if (name == null || locale == null) continue;
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

  static List<TtsVoice> _forLanguage(List<TtsVoice> voices, String bcp47) {
    final prefix = bcp47.split('-').first.toLowerCase();
    return <TtsVoice>[
      for (final voice in voices)
        if (voice.locale.toLowerCase().startsWith(prefix)) voice,
    ];
  }

  /// The engine's error code: a platform error's own, or else its type.
  static String _codeOf(Object error) =>
      error is PlatformException ? error.code : '${error.runtimeType}';

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
      _tts.setErrorHandler((message) {
        final failed = _failed;
        if (failed != null && !failed.isCompleted) failed.complete('$message');
      });
      _handling = true;
    }

    final String? error;
    try {
      // A voice the engine no longer lists, removed since it was chosen,
      // is the default (#123). The list is the one asked for last.
      final chosen = voice == null
          ? null
          : _forLanguage(
              _voices ??= await _listVoices(),
              bcp47,
            ).where((v) => v.name == voice).firstOrNull;
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

      // awaitSpeakCompletion makes speak() resolve when playback ends rather
      // than when it starts, so a drill can await the audio before accepting
      // an answer. An error never resolves it: the error handler ends the
      // wait instead.
      await _tts.awaitSpeakCompletion(true);
      final failed = _failed = Completer<String>();
      try {
        error = await Future.any<String?>(<Future<String?>>[
          _tts.speak(text).then((_) => null),
          failed.future,
        ]);
      } finally {
        if (identical(_failed, failed)) _failed = null;
      }
    } on PlatformException catch (e) {
      _forget();
      throw TtsFailure(e.code);
    }
    if (error != null) {
      _forget();
      throw TtsFailure(error);
    }
  }

  /// After a failure, asks the engine again for its voices and sets the
  /// language and voice again before the next word: the voice may be gone.
  void _forget() {
    _voices = null;
    _currentLanguage = null;
    _currentVoice = null;
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() async {
    await _tts.stop();
  }
}
