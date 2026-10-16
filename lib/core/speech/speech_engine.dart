/// One reading of what the learner said, and how sure the recogniser was.
class SpeechAlternative {
  const SpeechAlternative(this.text, {this.confidence});

  final String text;

  /// 0 to 1, or null when the recogniser gives none. Android scores every
  /// reading after the best one 0, which is a score, not a missing one.
  final double? confidence;

  @override
  String toString() => 'SpeechAlternative($text, $confidence)';
}

/// Why a listen produced nothing to grade.
enum SpeechFailure {
  /// Nothing was said, or nothing the recogniser could match.
  noMatch,

  /// The language cannot be recognised on the device: no pack for it is
  /// installed, or the on-device recogniser does not support it.
  notOnDevice,

  /// Online recognition was tried and does not support the language either.
  unsupported,

  /// The microphone permission was refused.
  permissionDenied,

  /// The phone has no speech recogniser at all.
  noRecogniser,

  /// Online recognition was tried and the network failed.
  network,

  /// Anything else the recogniser reported.
  other,
}

/// Why the recogniser could not be readied, asked or stopped: its own
/// error code, such as a platform error's, or `timeout` for a question it
/// never answered. What the app log needs to say what failed (#162).
class SpeechError implements Exception {
  const SpeechError(this.code);

  final String code;

  @override
  String toString() => 'SpeechError($code)';
}

/// What one listen produced: the recogniser's readings, best first, or why
/// there are none.
class SpeechHeard {
  const SpeechHeard(this.alternatives) : failure = null, code = null;

  const SpeechHeard.failed(SpeechFailure this.failure, {this.code})
    : alternatives = const <SpeechAlternative>[];

  final List<SpeechAlternative> alternatives;
  final SpeechFailure? failure;

  /// The recogniser's own error code, such as `error_no_match`, when it gave
  /// one: what a report needs to say exactly what failed. `timeout` for a
  /// listen that never answered. Null when it failed without one, or when
  /// the app knew beforehand that it could not listen.
  final String? code;

  bool get failed => failure != null || alternatives.isEmpty;

  @override
  String toString() => failure == null
      ? 'SpeechHeard($alternatives)'
      : 'SpeechHeard.failed($failure${code == null ? '' : ', $code'})';
}

/// The phone's speech recogniser, narrow enough that tests can fake it and a
/// second implementation is additive (ADR-0014). Nothing outside
/// `lib/core/speech` refers to a concrete engine.
///
/// Every listen asks to stay on the phone unless a caller asks for online
/// recognition, which the app does only for a language the learner has
/// allowed.
abstract interface class SpeechEngine {
  /// Whether the microphone permission is granted. Never asks.
  ///
  /// This, [start], [languages] and [stop] throw a [SpeechError] when the
  /// recogniser fails, so that the caller can log why.
  Future<bool> hasPermission();

  /// Readies the recogniser, asking for the microphone permission if it
  /// has not been granted. Call only when the learner turns speaking on,
  /// never at launch. False when the permission is refused or the phone has
  /// no recogniser.
  Future<bool> start();

  /// The languages the recogniser lists, by BCP-47 primary subtag (`hi`),
  /// after [start]. On Android 13 and later these are the on-device
  /// recogniser's; earlier, the default recogniser's. Empty when it lists
  /// none.
  Future<Set<String>> languages();

  /// Listens once, for a word or a short phrase in [bcp47], for at most
  /// [listenFor]. With [onDevice], the on-device recogniser listens where
  /// the phone has one (Android 12 and later); before that the default
  /// recogniser is asked to stay offline. A language it cannot recognise
  /// fails with [SpeechFailure.notOnDevice]. Without [onDevice], a language
  /// the recogniser does not support fails with [SpeechFailure.unsupported].
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  });

  /// Stops listening and keeps what was heard.
  Future<void> stop();
}

/// No recogniser: tests, and phones without one.
class NullSpeechEngine implements SpeechEngine {
  const NullSpeechEngine();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> start() async => false;

  @override
  Future<Set<String>> languages() async => const <String>{};

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async => const SpeechHeard.failed(SpeechFailure.noRecogniser);

  @override
  Future<void> stop() async {}
}

/// A recogniser that recognises [onDevice] languages on the device, or
/// [online] ones only online, and hears whatever [next] says. It lists only
/// the on-device ones, as Android 13 and later do. For tests and the
/// gallery.
class FixedSpeechEngine implements SpeechEngine {
  FixedSpeechEngine({
    this.onDevice = const <String>{},
    this.online = const <String>{},
    this.grants = true,
    this.granted = false,
  });

  /// Primary subtags recognised on the device.
  final Set<String> onDevice;

  /// Primary subtags recognised only online.
  final Set<String> online;

  /// Whether [start] is granted the microphone.
  final bool grants;

  /// Whether the permission was granted before the app asked.
  bool granted;

  /// How many times [start] asked.
  int starts = 0;

  /// What the next listen hears, in order, best first. Empty: no match.
  List<SpeechAlternative> next = const <SpeechAlternative>[];

  /// A failure the next listens give, in place of hearing [next], with the
  /// code Android gives for it: a network failure, say.
  SpeechHeard? failing;

  /// Every listen asked for, in order.
  final List<({String bcp47, bool onDevice})> listens =
      <({String bcp47, bool onDevice})>[];

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> start() async {
    starts++;
    if (grants) granted = true;
    return granted && (onDevice.isNotEmpty || online.isNotEmpty);
  }

  @override
  Future<Set<String>> languages() async =>
      granted ? onDevice : const <String>{};

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    listens.add((bcp47: bcp47, onDevice: onDevice));
    if (!granted) {
      return const SpeechHeard.failed(
        SpeechFailure.permissionDenied,
        code: 'error_permission',
      );
    }
    final code = bcp47.split(RegExp('[-_]')).first.toLowerCase();
    if (onDevice && !this.onDevice.contains(code)) {
      return const SpeechHeard.failed(
        SpeechFailure.notOnDevice,
        code: 'error_language_unavailable',
      );
    }
    if (!this.onDevice.contains(code) && !online.contains(code)) {
      return const SpeechHeard.failed(
        SpeechFailure.unsupported,
        code: 'error_language_not_supported',
      );
    }
    if (failing case final failure?) return failure;
    if (next.isEmpty) {
      return const SpeechHeard.failed(
        SpeechFailure.noMatch,
        code: 'error_no_match',
      );
    }
    return SpeechHeard(next);
  }

  @override
  Future<void> stop() async {}
}
