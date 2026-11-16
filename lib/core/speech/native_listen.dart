import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';

import 'speech_engine.dart';

// A listen that owns the microphone and feeds the recogniser from it, so that
// the learner's voice is kept at the very moment it is recognised
// (ADR-0054, option 2). Android 13 (API 33) lets an app hand the recogniser
// audio it captures itself (RecognizerIntent.EXTRA_AUDIO_SOURCE), so one
// stream serves both. The platform side is in MainActivity, which
// tools/brand_android.py writes; below Android 13, or where the recogniser
// ignores the extra, the engine falls back as it always did. Off by default
// (#1107): `SystemSpeechEngine.recordWhileRecognising` must be on to use it.

/// What one native listen gave: readings, or an error code, and the audio it
/// captured while it listened.
class NativeListenResult {
  const NativeListenResult({
    this.alternatives = const <SpeechAlternative>[],
    this.error,
    this.pcm16,
    this.sampleRate = 16000,
  });

  /// The readings, best first; empty when [error] is set.
  final List<SpeechAlternative> alternatives;

  /// The recogniser's error code (`error_no_match`, `error_network`...) or a
  /// code of this side: `unsupported` (Android below 13, or no recogniser
  /// service), `exception`, `error_audio`, `error_client`, `error_busy`.
  final String? error;

  /// The audio the listen captured: 16-bit little-endian mono PCM.
  final Uint8List? pcm16;
  final int sampleRate;

  /// The audio as the engine keeps it, or null.
  OwnAudio? get audio {
    final pcm = pcm16;
    if (pcm == null || pcm.isEmpty) return null;
    return OwnAudio(pcm, sampleRate: sampleRate);
  }

  /// Whether the native listen could not do its job, so that the engine
  /// should listen the plain way instead of reporting a failure: an error of
  /// this side, not the recogniser's verdict on the learner's speech.
  bool get fallsBack => switch (error) {
    'unsupported' ||
    'exception' ||
    'error_audio' ||
    'error_client' ||
    'error_busy' => true,
    _ => false,
  };
}

/// The phone's own listen that keeps the learner's audio; narrow enough that
/// tests fake it.
abstract interface class NativeListener {
  /// Whether this phone can listen this way (Android 13 and later with a
  /// recogniser service). Never throws.
  Future<bool> get available;

  /// Listens once for at most [listenFor] in [bcp47]. Never throws: a
  /// failure is in the result.
  Future<NativeListenResult> listen({
    required String bcp47,
    required bool onDevice,
    required Duration listenFor,
  });

  /// Ends the listen under way; what was heard is still delivered.
  Future<void> cancel();
}

/// [NativeListener] through the app's own platform channel,
/// `app.fluenough/system` (MainActivity, written by tools/brand_android.py).
/// Only on Android: anywhere else it is not available.
class ChannelNativeListener implements NativeListener {
  const ChannelNativeListener({this.channel = defaultChannel});

  static const MethodChannel defaultChannel = MethodChannel(
    'app.fluenough/system',
  );

  final MethodChannel channel;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> get available async {
    if (!_android) return false;
    try {
      return await channel.invokeMethod<bool>('canListenWithAudio') ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<NativeListenResult> listen({
    required String bcp47,
    required bool onDevice,
    required Duration listenFor,
  }) async {
    try {
      final raw = await channel.invokeMethod<Object?>(
        'listenWithAudio',
        <String, Object?>{
          'language': bcp47,
          'onDevice': onDevice,
          'seconds': listenFor.inSeconds < 1 ? 1 : listenFor.inSeconds,
        },
      );
      return parse(raw);
    } on Object {
      return const NativeListenResult(error: 'exception');
    }
  }

  @override
  Future<void> cancel() async {
    if (!_android) return;
    try {
      await channel.invokeMethod<void>('cancelListen');
    } on Object {
      // Nothing was listening.
    }
  }

  /// A channel's answer as a result: a map with `error`, or with `texts` and
  /// `confidences`, and `pcm` with `sampleRate`.
  static NativeListenResult parse(Object? raw) {
    if (raw is! Map) return const NativeListenResult(error: 'exception');
    final texts = <String>[
      for (final t in (raw['texts'] as List<Object?>? ?? const <Object?>[]))
        if (t is String) t,
    ];
    final confidences = <double>[
      for (final c
          in (raw['confidences'] as List<Object?>? ?? const <Object?>[]))
        if (c is num) c.toDouble(),
    ];
    final pcm = raw['pcm'];
    return NativeListenResult(
      alternatives: <SpeechAlternative>[
        for (var i = 0; i < texts.length; i++)
          if (texts[i].trim().isNotEmpty)
            SpeechAlternative(
              texts[i],
              // Android scores readings after the best 0: a score, but -1 is
              // none.
              confidence: i < confidences.length && confidences[i] >= 0
                  ? confidences[i]
                  : null,
            ),
      ],
      error: raw['error'] as String?,
      pcm16: pcm is Uint8List ? pcm : null,
      sampleRate: (raw['sampleRate'] as num?)?.toInt() ?? 16000,
    );
  }
}

/// A scripted native listener, for tests.
class FixedNativeListener implements NativeListener {
  FixedNativeListener({
    this.isAvailable = true,
    List<NativeListenResult>? results,
  }) : results = results ?? <NativeListenResult>[];

  final bool isAvailable;

  /// What the next listens give, in order; the last one repeats.
  final List<NativeListenResult> results;

  /// How many listens were asked, and cancels.
  int listens = 0;
  int cancels = 0;
  String? lastLanguage;
  bool? lastOnDevice;

  /// A listen that never answers, to test the deadline.
  bool never = false;

  @override
  Future<bool> get available async => isAvailable;

  @override
  Future<NativeListenResult> listen({
    required String bcp47,
    required bool onDevice,
    required Duration listenFor,
  }) {
    listens++;
    lastLanguage = bcp47;
    lastOnDevice = onDevice;
    if (never) return Completer<NativeListenResult>().future;
    final at = listens - 1 < results.length ? listens - 1 : results.length - 1;
    return Future<NativeListenResult>.value(
      results.isEmpty
          ? const NativeListenResult(error: 'unsupported')
          : results[at],
    );
  }

  @override
  Future<void> cancel() async => cancels++;
}
