/// One reading of what the learner said, and how sure the recogniser was.
class SpeechAlternative {
  const SpeechAlternative(this.text, {this.confidence});

  final String text;

  /// 0 to 1, or null when the recogniser gives none, as Android often does.
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

  /// The microphone permission was refused.
  permissionDenied,

  /// The phone has no speech recogniser at all.
  noRecogniser,

  /// Online recognition was tried and the network failed.
  network,

  /// Anything else the recogniser reported.
  other,
}

/// What one listen produced: the recogniser's readings, best first, or why
/// there are none.
class SpeechHeard {
  const SpeechHeard(this.alternatives) : failure = null;

  const SpeechHeard.failed(SpeechFailure this.failure)
    : alternatives = const <SpeechAlternative>[];

  final List<SpeechAlternative> alternatives;
  final SpeechFailure? failure;

  bool get failed => failure != null || alternatives.isEmpty;

  @override
  String toString() => failure == null
      ? 'SpeechHeard($alternatives)'
      : 'SpeechHeard.failed($failure)';
}

/// The phone's speech recogniser, narrow enough that tests can fake it and a
/// second implementation is additive (ADR-0014). Nothing outside
/// `lib/core/speech` refers to a concrete engine.
///
/// Audio stays on the phone unless a caller asks for online recognition,
/// which the app does only for a language the learner has allowed.
abstract interface class SpeechEngine {
  /// Whether the microphone permission is granted. Never asks.
  Future<bool> hasPermission();

  /// Readies the recogniser, asking for the microphone permission if it
  /// has not been granted. Call only when the learner turns speaking on,
  /// never at launch. False when the permission is refused or the phone has
  /// no recogniser.
  Future<bool> start();

  /// The languages the recogniser lists, by BCP-47 primary subtag (`hi`),
  /// after [start]. On Android 13 and later these are the on-device
  /// recogniser's; earlier, the default recogniser's. Empty when it cannot
  /// say.
  Future<Set<String>> languages();

  /// Listens once, for a word or a short phrase in [bcp47], for at most
  /// [listenFor]. With [onDevice], audio never leaves the phone, and a
  /// language the device cannot recognise fails with
  /// [SpeechFailure.notOnDevice].
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

/// A recogniser that recognises [languages] on the device, or [online] ones
/// only online, and hears whatever [next] says. For tests and the gallery.
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
      granted ? <String>{...onDevice, ...online} : const <String>{};

  @override
  Future<SpeechHeard> listen({
    required String bcp47,
    required bool onDevice,
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    listens.add((bcp47: bcp47, onDevice: onDevice));
    if (!granted) {
      return const SpeechHeard.failed(SpeechFailure.permissionDenied);
    }
    final code = bcp47.split(RegExp('[-_]')).first.toLowerCase();
    if (onDevice && !this.onDevice.contains(code)) {
      return const SpeechHeard.failed(SpeechFailure.notOnDevice);
    }
    if (!this.onDevice.contains(code) && !online.contains(code)) {
      return const SpeechHeard.failed(SpeechFailure.noRecogniser);
    }
    if (next.isEmpty) return const SpeechHeard.failed(SpeechFailure.noMatch);
    return SpeechHeard(next);
  }

  @override
  Future<void> stop() async {}
}
