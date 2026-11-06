// The sample deck (owner, 2026-11-06): the small, frozen deck set both CIs
// hold to. The decks live on the decks-live branch; main keeps this sample,
// and the app is checked against it. The decks-live branch's CI validates the
// same sample and checks its real decks speak its format
// (tools/check_sample_contract.py).
import 'dart:convert';
import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:flutter_test/flutter_test.dart';

const _root = 'test/fixtures/sample-decks';

void main() {
  late DeckIndex index;

  setUpAll(() {
    index = DeckIndex.parse(File('$_root/decks/index.json').readAsStringSync());
  });

  test('the index is one this app reads, with every language readable', () {
    final json =
        jsonDecode(File('$_root/decks/index.json').readAsStringSync())
            as Map<String, Object?>;
    expect(json['version'], supportedIndexVersion);
    expect(index.languages, isNotEmpty);
    for (final language in index.languages) {
      expect(
        language.files.where((f) => !f.readable),
        isEmpty,
        reason: '${language.code} has a file this app cannot read',
      );
    }
  });

  test('every file the index lists is there, with the size it states', () {
    for (final entry in index.filesByPath.entries) {
      final file = File('$_root/${entry.key}');
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(
        file.lengthSync(),
        entry.value.size,
        reason: '${entry.key} is not the size the index says',
      );
    }
  });

  test('the catalog reads the sample deck whole, with nothing broken', () async {
    final catalog = await DeckCatalog(RepositoryDeckSource(_root)).load();
    expect(catalog.broken, isEmpty);
    expect(catalog.decks, isNotEmpty);
  });
}
