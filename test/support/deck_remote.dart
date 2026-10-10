import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/sha256.dart';

/// GitHub's `main`, faked: serves deck files and `decks/index.json` from
/// memory, so that no test reaches the network (#210). Each file's
/// failure can be set, and what was asked is recorded.
class FakeDeckRemote implements DeckFetcher {
  /// Serves [files], by path, with an index made from them ([indexFor]).
  FakeDeckRemote(Map<String, String> files)
    : files = Map<String, String>.of(files);

  /// Serves the repository's own `decks/`, and its committed
  /// `decks/index.json` as it is: what the app on a phone would get.
  FakeDeckRemote.repo() : files = <String, String>{}, _repo = true;

  /// Every file, by path, as GitHub would serve it.
  final Map<String, String> files;
  bool _repo = false;

  /// Served in place of the index made from [files], when set.
  String? index;

  /// Files that fail, by path, each the way given.
  final Map<String, FetchFailure> failures = <String, FetchFailure>{};

  /// While set, every file fails this way: no network, say.
  FetchFailure? failAll;

  /// Files served with other bytes than the index's: changed on GitHub
  /// between the index and the file, or cut short on the way.
  final Map<String, String> served = <String, String>{};

  /// Fails every file after this many have been served.
  int? failAfter;
  FetchFailure failAfterWith = FetchFailure.offline;

  /// Every path asked for, in order.
  final List<String> asked = <String>[];

  /// While set and not completed, every fetch waits on it.
  Completer<void>? gate;

  @override
  Future<Fetched> fetch(String path) async {
    asked.add(path);
    await gate?.future;
    if (failAll case final failure?) return Fetched.failed(failure);
    if (failures[path] case final failure?) return Fetched.failed(failure);
    final after = failAfter;
    if (after != null &&
        asked.where((p) => p != 'decks/index.json').length > after) {
      return Fetched.failed(failAfterWith);
    }
    final text = served[path] ?? _text(path);
    if (text == null) return const Fetched.failed(FetchFailure.notFound);
    return Fetched(Uint8List.fromList(utf8.encode(text)));
  }

  String? _text(String path) {
    if (_repo) {
      final file = File(path);
      return file.existsSync() ? file.readAsStringSync() : null;
    }
    if (path == 'decks/index.json') return index ?? indexFor(files);
    return files[path];
  }
}

/// An index of [files], as `tools/deck_index.py` writes one, with [version]:
/// each language's files with their hashes, its path's order from its
/// `<lang>-path.yaml`, and each deck's core id and native language from its
/// path and its header.
String indexFor(Map<String, String> files, {int version = 1}) {
  final languages = <String, List<Map<String, Object?>>>{};
  final paths = <String, List<String>>{};
  final names = <String, String>{};
  final natives = <String, Set<String>>{};
  for (final path in files.keys.toList()..sort()) {
    final parts = path.split('/');
    if (parts.length < 3 || parts[0] != 'decks') continue;
    final code = parts[1];
    final text = files[path]!;
    final bytes = utf8.encode(text);
    final yaml = loadYaml(text);
    final header = yaml is YamlMap ? yaml : YamlMap();
    final kind = header['kind'] as String? ?? 'vocab';
    final id = header['id'] as String? ?? '';
    final core = header['part'] == 'core';
    if (header['language'] case final YamlMap language) {
      names[code] = language['name'] as String? ?? code;
    }
    String? native;
    String? deck;
    if (kind == 'layer') {
      native = parts[2];
      deck = header['core'] as String?;
    } else if (core) {
      deck = id;
    } else if (!const <String>{
      'path',
      'facts',
      'numbers',
      'romanisation',
      'sounds',
      'script',
    }.contains(kind)) {
      final segments = id.split('-');
      native = segments.length > 2 ? segments[1] : null;
      deck = segments.length > 2
          ? '${segments[0]}-${segments.sublist(2).join('-')}'
          : id;
    }
    if (native != null) (natives[code] ??= <String>{}).add(native);
    if (kind == 'path') {
      paths[code] = <String>[
        for (final unit in header['units'] as YamlList)
          for (final deck in unit is YamlList ? unit : const <Object?>[])
            if (deck is String && deck != '*') deck,
      ];
    }
    (languages[code] ??= <Map<String, Object?>>[]).add(<String, Object?>{
      'path': path,
      'size': bytes.length,
      'sha256': sha256Hex(bytes),
      'content_sha256': sha256Hex(utf8.encode(contentOf(text))),
      'schema': header['schema'] is int ? header['schema'] : 1,
      'kind': kind,
      'native': ?native,
      'deck': ?deck,
      if (core) 'part': 'core',
    });
  }
  return jsonEncode(<String, Object?>{
    'version': version,
    'schema': 1,
    'bundled': <String>['decks/themes.yaml'],
    'languages': <Object?>[
      for (final code in languages.keys)
        <String, Object?>{
          'code': code,
          'name': names[code] ?? code,
          'natives': <Object?>[
            for (final n in (natives[code] ?? <String>{}).toList()..sort())
              <String, String>{'code': n, 'name': n},
          ],
          'path': paths[code] ?? const <String>[],
          'files': languages[code],
        },
    ],
  });
}

/// [text], a deck file, with its proposals taken out, as
/// `tools/deck_index.py` hashes it for `content_sha256` (#444): each
/// `proposed:` line and the items indented under it, and blank lines
/// between two items.
String contentOf(String text) {
  final lines = text.split('\n');
  final out = <String>[];
  final key = RegExp(r'^( *)proposed:[ \t]*\r?$');
  int indentOf(String line) => line.length - line.trimLeft().length;
  var i = 0;
  while (i < lines.length) {
    final m = key.firstMatch(lines[i]);
    if (m == null) {
      out.add(lines[i]);
      i++;
      continue;
    }
    final indent = m.group(1)!.length;
    i++;
    while (i < lines.length) {
      var j = i;
      while (j < lines.length && lines[j].trim().isEmpty) {
        j++;
      }
      if (j == lines.length || indentOf(lines[j]) <= indent) break;
      i = j + 1;
    }
  }
  return out.join('\n');
}

/// [text] with a reviewer's proposal on the field line [field], as the
/// review bot writes one (ADR-0038).
String withProposal(String text, String field, {String to = 'changed'}) {
  final at = text.indexOf('$field\n');
  if (at < 0) throw ArgumentError.value(field, 'field', 'not in the file');
  final indent = field.length - field.trimLeft().length;
  final pad = ' ' * indent;
  final end = at + field.length + 1;
  return '${text.substring(0, end)}${pad}proposed:\n'
      '$pad  - { id: "3f9c0a1b2d", field: "native", now: "x", text: "$to", '
      'by: "FL-7K3M-Q9TD-6", date: "2026-10-09" }\n'
      '${text.substring(end)}';
}

/// The repository's own files of [languages], by path, as GitHub serves
/// them. Read synchronously, so it works inside a widget test.
Map<String, String> repoFiles(List<String> languages) => <String, String>{
  for (final code in languages)
    for (final entity in Directory('decks/$code').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.yaml'))
        entity.path.replaceAll(r'\', '/'): entity.readAsStringSync(),
};
