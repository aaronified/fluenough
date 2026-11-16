import 'dart:io';
import 'dart:typed_data';

import '../core/speech/asr/asr_pack.dart';

/// Looks for packs in the app's files folder: `asr/<code>/` holding
/// `encoder.int8.onnx`, `head_<code>.f32` and `head_<code>.json`, as
/// `tools/asr/export_pack.py` writes them (#1004). A language counts as
/// installed only when all three files exist; it does not check checksums
/// (the downloader of task 10 does, before it renames a file into place).
/// Errors are logged through [log] and the language is then not installed.
class FileAsrPackLocator implements AsrPackLocator {
  FileAsrPackLocator(this.root, {required this.log});

  /// The `asr` folder.
  final Directory root;
  final void Function(String) log;

  static const String encoderName = 'encoder.int8.onnx';

  @override
  Future<AsrPack?> find(String code) async {
    try {
      final dir = '${root.path}/$code';
      final encoder = File('$dir/$encoderName');
      final head = File('$dir/head_$code.f32');
      final json = File('$dir/head_$code.json');
      if (!await encoder.exists() || !await head.exists()) return null;
      if (!await json.exists()) return null;
      return AsrPack(
        code: code,
        encoderPath: encoder.path,
        readHeadBytes: () async => Uint8List.fromList(await head.readAsBytes()),
        readHeadJson: json.readAsString,
      );
    } catch (e, st) {
      log('FileAsrPackLocator: find $code failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<Set<String>> installed() async {
    try {
      if (!await root.exists()) return const <String>{};
      final found = <String>{};
      await for (final entry in root.list()) {
        if (entry is! Directory) continue;
        final code = entry.uri.pathSegments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
        if (code.isNotEmpty && await find(code) != null) found.add(code);
      }
      return found;
    } catch (e, st) {
      log('FileAsrPackLocator: listing ${root.path} failed: $e\n$st');
      return const <String>{};
    }
  }
}
