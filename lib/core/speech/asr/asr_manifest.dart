/// `asr-manifest.json`: which files make up each language's on-device
/// listener pack, how big they are and how to check them (#1004, task 10).
///
/// The shape is written by `tools/asr/publish_manifest.py`:
/// `{packVersion, languages: [{code, files: [{name, kind, bytes, sha256,
/// url}]}]}`. Pure Dart, so the parser is tested without a disk or a
/// network.
library;

import 'dart:convert';

/// One file of a pack.
class AsrFileSpec {
  const AsrFileSpec({
    required this.name,
    required this.kind,
    required this.bytes,
    required this.sha256,
    required this.url,
  });

  /// The name it is stored under, such as `encoder.int8.onnx`.
  final String name;

  /// `encoder` or `head`.
  final String kind;

  final int bytes;

  /// Lower-case hex.
  final String sha256;

  final String url;
}

/// One language's pack.
class AsrLanguagePack {
  const AsrLanguagePack({required this.code, required this.files});

  final String code;
  final List<AsrFileSpec> files;

  /// What the download comes to.
  int get totalBytes => files.fold<int>(0, (sum, f) => sum + f.bytes);
}

/// The manifest: every language that has a pack.
class AsrManifest {
  const AsrManifest({required this.packVersion, required this.languages});

  final int packVersion;
  final List<AsrLanguagePack> languages;

  /// The pack of [code], or null when the manifest has none.
  AsrLanguagePack? pack(String code) {
    for (final l in languages) {
      if (l.code == code) return l;
    }
    return null;
  }

  /// Parses [text]. Throws [FormatException] naming what is wrong: a
  /// manifest that is not understood must never be half-used.
  factory AsrManifest.parse(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('asr manifest is not JSON: ${e.message}');
    }
    if (root is! Map<String, dynamic>) {
      throw const FormatException('asr manifest is not an object');
    }
    final version = root['packVersion'];
    final langs = root['languages'];
    if (version is! int || langs is! List) {
      throw const FormatException(
        'asr manifest lacks packVersion or languages',
      );
    }
    final languages = <AsrLanguagePack>[];
    for (final l in langs) {
      if (l is! Map<String, dynamic> ||
          l['code'] is! String ||
          l['files'] is! List) {
        throw const FormatException('asr manifest has a bad language entry');
      }
      final files = <AsrFileSpec>[];
      for (final f in l['files'] as List<dynamic>) {
        if (f is! Map<String, dynamic> ||
            f['name'] is! String ||
            f['kind'] is! String ||
            f['bytes'] is! int ||
            f['sha256'] is! String ||
            f['url'] is! String) {
          throw FormatException(
            'asr manifest has a bad file entry for ${l['code']}',
          );
        }
        final name = f['name'] as String;
        // The name becomes a path: never let it climb out of the folder.
        if (name.isEmpty ||
            name.contains('/') ||
            name.contains('\\') ||
            name == '.' ||
            name == '..') {
          throw FormatException('asr manifest file name "$name" is not plain');
        }
        if ((f['bytes'] as int) <= 0) {
          throw FormatException('asr manifest file $name has no size');
        }
        files.add(
          AsrFileSpec(
            name: name,
            kind: f['kind'] as String,
            bytes: f['bytes'] as int,
            sha256: (f['sha256'] as String).toLowerCase(),
            url: f['url'] as String,
          ),
        );
      }
      languages.add(AsrLanguagePack(code: l['code'] as String, files: files));
    }
    return AsrManifest(packVersion: version, languages: languages);
  }
}
