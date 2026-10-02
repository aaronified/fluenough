import 'dart:async';
import 'dart:io';

/// Why an update did not reach Android's installer (ADR-0017).
enum InstallFailure {
  /// The learner has not allowed Fluenough to install apps.
  notAllowed,

  /// The APK could not be downloaded: no network, GitHub had no file, or
  /// the download stalled.
  download,

  /// The download did not match the checksum GitHub gave for it.
  checksum,

  /// Android did not start installing it, or another install was running.
  install,

  /// Anything else went wrong on the phone.
  internal,

  /// The download was cancelled before it finished. One the learner cancels
  /// is not a failure: the row offers it again.
  cancelled,
}

/// One step of an update: how much has downloaded, Android's installer
/// opening, or why it stopped.
class InstallEvent {
  const InstallEvent.downloading(int this.percent)
    : installing = false,
      failure = null;

  const InstallEvent.installing()
    : percent = null,
      installing = true,
      failure = null;

  const InstallEvent.failed(InstallFailure this.failure)
    : percent = null,
      installing = false;

  /// How much has downloaded, from 0 to 100, while downloading.
  final int? percent;

  /// Android's installer has been opened on the download. What the learner
  /// does there is not reported back: the next launch finds out.
  final bool installing;

  final InstallFailure? failure;
}

/// Downloads an APK into the app's own storage and opens Android's
/// installer on it (ADR-0017). Narrow enough that tests fake it; only
/// `main.dart` names the one that does it.
abstract interface class ApkInstaller {
  /// Downloads [url] as [fileName], replacing any file of that name, checks
  /// it against [sha256] if given, and opens the installer. The stream ends
  /// after [InstallEvent.installing] or a failure. Never throws.
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  });

  /// Stops the download under way, if there is one: its stream ends with
  /// [InstallFailure.cancelled].
  Future<void> cancel();
}

/// No installer: every install fails. The default, so that no test or
/// gallery state downloads anything.
class NullApkInstaller implements ApkInstaller {
  const NullApkInstaller();

  @override
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  }) => Stream<InstallEvent>.value(
    const InstallEvent.failed(InstallFailure.internal),
  );

  @override
  Future<void> cancel() async {}
}

/// An installer that reports [events] and records what it was asked to
/// install, into [files] if given. For tests and the gallery.
class FixedApkInstaller implements ApkInstaller {
  FixedApkInstaller(this.events, {this.files, this.gate});

  /// What every install reports, in order. Can change between installs.
  List<InstallEvent> events;

  /// Where a download lands: given a file named as asked once the events
  /// say it downloaded, as the real one does.
  final MemoryDownloadStore? files;

  /// While set and not completed, an install waits on it after reporting
  /// its first event, so that a step can be seen. One never completed is a
  /// download that stalls, until [cancel].
  Completer<void>? gate;

  /// Every install asked for: its url, file name and checksum.
  final List<({String url, String fileName, String? sha256})> asked =
      <({String url, String fileName, String? sha256})>[];

  /// How many times [cancel] was called.
  int cancels = 0;

  Completer<void>? _cancelled;

  @override
  Stream<InstallEvent> install(
    String url, {
    required String fileName,
    String? sha256,
  }) async* {
    asked.add((url: url, fileName: fileName, sha256: sha256));
    final cancelled = _cancelled = Completer<void>();
    final wait = gate;
    for (final (i, event) in events.indexed) {
      if (event.installing) files?.names.add(fileName);
      yield event;
      if (i == 0 && wait != null) {
        await Future.any(<Future<void>>[wait.future, cancelled.future]);
      }
      if (cancelled.isCompleted) {
        yield const InstallEvent.failed(InstallFailure.cancelled);
        return;
      }
    }
  }

  @override
  Future<void> cancel() async {
    cancels++;
    final cancelled = _cancelled;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
  }
}

/// The files the updater leaves in the app's own storage, by name, so that
/// a finished update's APK can be deleted (ADR-0017).
abstract interface class DownloadStore {
  Future<bool> exists(String fileName);

  /// Deletes [fileName], if it is there.
  Future<void> delete(String fileName);
}

/// Nothing downloaded and nothing to delete. The default.
class NullDownloadStore implements DownloadStore {
  const NullDownloadStore();

  @override
  Future<bool> exists(String fileName) async => false;

  @override
  Future<void> delete(String fileName) async {}
}

/// Files in memory, by name. For tests and the gallery.
class MemoryDownloadStore implements DownloadStore {
  MemoryDownloadStore([Iterable<String> names = const <String>[]])
    : names = <String>{...names};

  final Set<String> names;

  /// Every name deleted, in order.
  final List<String> deleted = <String>[];

  @override
  Future<bool> exists(String fileName) async => names.contains(fileName);

  @override
  Future<void> delete(String fileName) async {
    deleted.add(fileName);
    names.remove(fileName);
  }
}

/// Files in [directory]: the one ota_update downloads into.
class FileDownloadStore implements DownloadStore {
  const FileDownloadStore(this.directory);

  final Directory directory;

  File _file(String fileName) => File('${directory.path}/$fileName');

  @override
  Future<bool> exists(String fileName) => _file(fileName).exists();

  @override
  Future<void> delete(String fileName) async {
    final file = _file(fileName);
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Left for the next download, which replaces it.
    }
  }
}
