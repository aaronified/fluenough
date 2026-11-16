/// What the on-device listener needs of an installed language pack (#1004).
///
/// A pack is what `tools/asr/export_pack.py` writes for one language: the
/// encoder (`encoder.int8.onnx`) and the CTC head (`head_<code>.f32` and
/// `head_<code>.json`). Where the files live and how they are read is the
/// locator's business, so that this file stays pure Dart and tests need no
/// disk. The downloader and the settings row come later (tasks 10 to 12).
library;

import 'dart:typed_data';

/// One installed language: the encoder's path for the runtime, and readers
/// for the two head files (small, read into memory).
class AsrPack {
  const AsrPack({
    required this.code,
    required this.encoderPath,
    required this.readHeadBytes,
    required this.readHeadJson,
  });

  /// The primary language subtag, such as `te`.
  final String code;

  /// Path of `encoder.int8.onnx`, which the runtime loads from the file.
  final String encoderPath;

  /// The bytes of `head_<code>.f32`.
  final Future<Uint8List> Function() readHeadBytes;

  /// The text of `head_<code>.json`.
  final Future<String> Function() readHeadJson;
}

/// Finds the installed packs. Implementations may throw; the engines catch
/// and log it, and treat the language as not installed.
abstract interface class AsrPackLocator {
  /// The pack of the language with this primary subtag, or null when it is
  /// not (completely) installed.
  Future<AsrPack?> find(String code);

  /// The primary subtags of every installed pack.
  Future<Set<String>> installed();
}

/// A locator with no packs: before the listener is installed.
class NoAsrPacks implements AsrPackLocator {
  const NoAsrPacks();

  @override
  Future<AsrPack?> find(String code) async => null;

  @override
  Future<Set<String>> installed() async => const <String>{};
}

/// A locator over a fixed map, for tests.
class FakeAsrPackLocator implements AsrPackLocator {
  FakeAsrPackLocator(this.packs, {this.error});

  final Map<String, AsrPack> packs;

  /// Thrown by [find] and [installed] when set.
  Object? error;

  @override
  Future<AsrPack?> find(String code) async {
    final e = error;
    if (e != null) throw e;
    return packs[code];
  }

  @override
  Future<Set<String>> installed() async {
    final e = error;
    if (e != null) throw e;
    return packs.keys.toSet();
  }
}
