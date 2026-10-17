// The released app reads the decks (#524).
//
// Phones download decks from main, so a deck change reaches every installed
// app at once, but an app reads only the format of its own release: 0.4.3
// refused main's decks once they were split (owner, 2026-10-14). CI copies
// this test into a checkout of the latest release, with the change's decks in
// place of the release's, and runs it there with `flutter test`
// (.github/workflows/ci.yml, "Released app reads the decks"). It checks every
// file as the released downloader does before keeping it.
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

void main() {
  test('the released app reads decks/index.json and every deck in it', () {
    final index = DeckIndex.parse(File('decks/index.json').readAsStringSync());
    final problems = <String>[];
    var checked = 0;
    for (final file in index.filesByPath.values) {
      // A recording or an image is checked by its hash alone, as the
      // downloader does. By its extension, not `IndexFile.isMedia`, so the
      // test still compiles against a release from before media.
      if (_media.hasMatch(file.path)) continue;
      final String text;
      try {
        text = utf8.decode(File(file.path).readAsBytesSync());
      } on Object catch (e) {
        problems.add('${file.path}: $e');
        continue;
      }
      final problem = DeckCatalog.checkFile(file.path, text);
      if (problem != null) problems.add(problem);
      checked++;
    }
    expect(checked, greaterThan(0), reason: 'decks/index.json lists no decks');
    expect(
      problems,
      isEmpty,
      reason:
          'The latest release cannot read these deck files. Phones download '
          'decks from main, so this change would break the released app '
          '(#524). Keep the change to what the release reads, or hold it '
          'until a release that reads it.',
    );
  });
}
