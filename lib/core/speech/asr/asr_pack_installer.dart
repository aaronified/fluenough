/// What the Voices page and [AppState] need of the on-device listener's
/// download (#1004, task 10 and 12): which languages have a pack, their size,
/// install, cancel and remove, and a stream of how each is getting on. The
/// real one is `lib/app/asr_pack_downloader.dart`; this file stays pure Dart
/// so that tests use a fake.
library;

import 'dart:async';

/// Where a language's pack stands.
enum AsrInstallPhase { notInstalled, downloading, installed, failed }

/// Why an install failed, for the line the learner reads.
enum AsrInstallFailure {
  /// No manifest, or no network.
  network,

  /// The phone has no room.
  space,

  /// A file arrived whole but did not match the manifest.
  checksum,

  /// Anything else; the app log has the detail.
  other,
}

/// A language's pack state.
class AsrInstallState {
  const AsrInstallState(
    this.phase, {
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.failure,
  });

  static const AsrInstallState notInstalled = AsrInstallState(
    AsrInstallPhase.notInstalled,
  );
  static const AsrInstallState installed = AsrInstallState(
    AsrInstallPhase.installed,
  );

  final AsrInstallPhase phase;
  final int receivedBytes;
  final int totalBytes;
  final AsrInstallFailure? failure;

  /// 0 to 100 while downloading.
  int get percent =>
      totalBytes <= 0 ? 0 : (receivedBytes * 100 ~/ totalBytes).clamp(0, 100);

  @override
  bool operator ==(Object other) =>
      other is AsrInstallState &&
      other.phase == phase &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(phase, receivedBytes, totalBytes, failure);
}

/// A state change of one language.
typedef AsrInstallChange = ({String code, AsrInstallState state});

/// Installs and removes language packs. Methods never throw: a failure is
/// the language's [AsrInstallState] and a line in the app log.
abstract interface class AsrPackInstaller {
  /// The primary subtags that have a pack to install. Others are not offered.
  Set<String> get languages;

  /// Where [code]'s pack stands now.
  AsrInstallState stateOf(String code);

  /// Every change, of every language.
  Stream<AsrInstallChange> get changes;

  /// Looks at the disk for what is installed, and tells [changes].
  Future<void> refresh();

  /// What [code]'s download comes to, from the manifest, or null when it
  /// cannot be fetched.
  Future<int?> sizeOf(String code);

  /// Downloads and checks [code]'s pack. Completes when it is installed,
  /// failed or cancelled.
  Future<void> install(String code);

  /// Stops [code]'s download; what was downloaded is kept to resume.
  void cancel(String code);

  /// Deletes [code]'s pack and anything half downloaded.
  Future<void> remove(String code);
}

/// No packs: a build or a test with no listener to install.
class NullAsrPackInstaller implements AsrPackInstaller {
  const NullAsrPackInstaller();

  @override
  Set<String> get languages => const <String>{};

  @override
  AsrInstallState stateOf(String code) => AsrInstallState.notInstalled;

  @override
  Stream<AsrInstallChange> get changes =>
      const Stream<AsrInstallChange>.empty();

  @override
  Future<void> refresh() async {}

  @override
  Future<int?> sizeOf(String code) async => null;

  @override
  Future<void> install(String code) async {}

  @override
  void cancel(String code) {}

  @override
  Future<void> remove(String code) async {}
}

/// An installer driven by the test: set [states], [sizes], and read the calls.
class FakeAsrPackInstaller implements AsrPackInstaller {
  FakeAsrPackInstaller({
    this.languages = const <String>{'te'},
    Map<String, int?>? sizes,
    Map<String, AsrInstallState>? states,
  }) : sizes = sizes ?? <String, int?>{'te': 137000000},
       states = states ?? <String, AsrInstallState>{};

  @override
  final Set<String> languages;
  final Map<String, int?> sizes;
  final Map<String, AsrInstallState> states;
  final List<String> calls = <String>[];
  final StreamController<AsrInstallChange> _changes =
      StreamController<AsrInstallChange>.broadcast();

  /// Sets [code]'s state as the real installer would, and announces it.
  void set(String code, AsrInstallState state) {
    states[code] = state;
    _changes.add((code: code, state: state));
  }

  @override
  AsrInstallState stateOf(String code) =>
      states[code] ?? AsrInstallState.notInstalled;

  @override
  Stream<AsrInstallChange> get changes => _changes.stream;

  @override
  Future<void> refresh() async => calls.add('refresh');

  @override
  Future<int?> sizeOf(String code) async {
    calls.add('size $code');
    return sizes[code];
  }

  @override
  Future<void> install(String code) async {
    calls.add('install $code');
    set(code, AsrInstallState.installed);
  }

  @override
  void cancel(String code) {
    calls.add('cancel $code');
    set(code, AsrInstallState.notInstalled);
  }

  @override
  Future<void> remove(String code) async {
    calls.add('remove $code');
    set(code, AsrInstallState.notInstalled);
  }
}
