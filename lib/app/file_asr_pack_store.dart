import 'dart:io';

import 'file_asr_pack_locator.dart';

/// Where the on-device listener's files live: `<root>/<code>/` holding
/// `encoder.int8.onnx`, `head_<code>.f32` and `head_<code>.json`, the layout
/// [FileAsrPackLocator] reads (#1004, task 10). A file is written as
/// `<name>.part` and renamed into place only once it is whole and checked, so
/// the locator never sees a half file. Errors are logged through [log] and
/// rethrown for the downloader to turn into a failure.
class FileAsrPackStore {
  FileAsrPackStore(this.root, {required this.log});

  /// The `asr` folder.
  final Directory root;
  final void Function(String) log;

  /// The folder of [code]'s pack.
  Directory dirOf(String code) => Directory('${root.path}/$code');

  /// The finished file [name] of [code]'s pack.
  File fileOf(String code, String name) => File('${root.path}/$code/$name');

  /// The download in progress of [name].
  File partOf(String code, String name) =>
      File('${root.path}/$code/$name.part');

  /// The three file names a language needs, as the locator reads them.
  static List<String> requiredNames(String code) => <String>[
    FileAsrPackLocator.encoderName,
    'head_$code.f32',
    'head_$code.json',
  ];

  /// Makes [code]'s folder.
  Future<void> prepare(String code) async {
    try {
      await dirOf(code).create(recursive: true);
    } catch (e, st) {
      log('FileAsrPackStore: preparing $code failed: $e\n$st');
      rethrow;
    }
  }

  /// Whether all three files of [code] are in place (checked when they were
  /// renamed in, not again here).
  Future<bool> isInstalled(String code) async {
    try {
      for (final name in requiredNames(code)) {
        if (!await fileOf(code, name).exists()) return false;
      }
      return true;
    } catch (e, st) {
      log('FileAsrPackStore: looking for $code failed: $e\n$st');
      return false;
    }
  }

  /// Renames the finished [name] download into place, replacing a file.
  Future<void> commit(String code, String name) async {
    try {
      await partOf(code, name).rename(fileOf(code, name).path);
    } catch (e, st) {
      log('FileAsrPackStore: committing $code/$name failed: $e\n$st');
      rethrow;
    }
  }

  /// Deletes [code]'s whole folder, parts included. Returns whether it is
  /// gone.
  Future<bool> remove(String code) async {
    try {
      final dir = dirOf(code);
      if (await dir.exists()) await dir.delete(recursive: true);
      return true;
    } catch (e, st) {
      log('FileAsrPackStore: removing $code failed: $e\n$st');
      return false;
    }
  }
}
