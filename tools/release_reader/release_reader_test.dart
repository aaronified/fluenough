// The released app reads the decks (#524).
//
// Phones download decks from main, so a deck change reaches every installed
// app at once, but an app reads only the format of its own release: 0.4.3
// refused main's decks once they were split (owner, 2026-10-14). CI copies
// this test into a checkout of the latest release, with the change's decks in
// place of the release's, and runs it there with `flutter test`
// (.github/workflows/ci.yml, "Released app reads the decks"). It checks every
// file as the released downloader does before keeping it, except the files
// the index gates above the release's version (`min_app`, ADR-0052): the
// released app never downloads those, so what they hold cannot break it.
//
// It compiles against the release's code, not this branch's: use only what
// the latest release has.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/decks/deck_index.dart';

/// A recording or an image, as `decks/index.json` lists them.
final _media = RegExp(r'\.(opus|webp)$');

/// The released app's version, as its `pubspec.yaml` has it, without the
/// build number.
String releaseVersion() {
  final match = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync());
  return match!.group(1)!;
}

/// What the released app, [appVersion], cannot read in [indexText]'s files,
/// one line each. A file or language whose `min_app` is newer than
/// [appVersion] is skipped, as the released downloader skips it: it never
/// asks for it. [readFile] gives a file's bytes; [checked][0] counts the
/// files read.
List<String> problemsOf(
  String indexText,
  String appVersion,
  List<int> Function(String path) readFile,
  List<int> checked,
) {
  final index = DeckIndex.parse(indexText, appVersion: appVersion);
  final problems = <String>[];
  for (final file in index.filesByPath.values) {
    // A recording or an image is checked by its hash alone, as the
    // downloader does. By its extension, not `IndexFile.isMedia`, so the
    // test still compiles against a release from before media.
    if (_media.hasMatch(file.path)) continue;
    if (file.appTooOld) continue;
    final String text;
    try {
      text = utf8.decode(readFile(file.path));
    } on Object catch (e) {
      problems.add('${file.path}: $e');
      continue;
    }
    final problem = DeckCatalog.checkFile(file.path, text);
    if (problem != null) problems.add(problem);
    checked[0]++;
  }
  return problems;
}

/// A valid hash: the current parser refuses anything but 64 hex digits.
final String _hash = '0' * 64;

/// A one-language index listing one romanisation file, gated at [minApp]
/// when given.
String _fakeIndex(String path, {String? minApp}) => jsonEncode({
  'version': 1,
  'schema': 1,
  'bundled': <Object?>[],
  'shared': <Object?>[],
  'languages': [
    {
      'code': 'xx',
      'name': 'Xx',
      'own_name': 'Xx',
      'icon': 'Xx',
      'script': 'latin',
      'script_decks': false,
      'natives': <Object?>[],
      'size': 1,
      'path': <Object?>[],
      'units': <Object?>[],
      'fonts': <Object?>[],
      'files': [
        {
          'path': path,
          'kind': 'romanisation',
          'schema': 1,
          'size': 1,
          'sha256': _hash,
          'content_sha256': _hash,
          'min_app': ?minApp,
        },
      ],
    },
  ],
});

const _unknownStandard = '''
schema: 1
kind: romanisation
id: xx-romanisation
language: xx
scheme: "Letters."
standard: "No Such Standard"
typed:
  - ["a", "a"]
''';

void main() {
  test('a file gated above the release is skipped; an ungated one is not', () {
    const path = 'decks/xx/xx-romanisation.yaml';
    List<int> read(String _) => utf8.encode(_unknownStandard);
    final gated = <int>[0];
    expect(
      problemsOf(_fakeIndex(path, minApp: '99.0.0'), '0.10.6', read, gated),
      isEmpty,
    );
    expect(gated[0], 0, reason: 'a gated file is not read at all');
    final open = <int>[0];
    expect(
      problemsOf(_fakeIndex(path), '0.10.6', read, open),
      isNotEmpty,
      reason: 'an ungated file with an unknown standard still fails',
    );
    expect(open[0], 1);
  });

  test('the released app reads decks/index.json and every deck in it', () {
    final checked = <int>[0];
    final problems = problemsOf(
      File('decks/index.json').readAsStringSync(),
      releaseVersion(),
      (path) => File(path).readAsBytesSync(),
      checked,
    );
    expect(
      checked[0],
      greaterThan(0),
      reason: 'decks/index.json lists no decks',
    );
    expect(
      problems,
      isEmpty,
      reason:
          'The latest release cannot read these deck files. Phones download '
          'decks from main, so this change would break the released app '
          '(#524). Keep the change to what the release reads, gate the file '
          'with decks/min_app.json (ADR-0052), or hold it until a release '
          'that reads it.',
    );
  });
}
