import 'dart:io';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/private_import.dart';
import 'package:fluenough/app/private_store.dart';
import 'package:fluenough/core/models/level.dart';
import 'package:flutter_test/flutter_test.dart';

// A private package uses the same deck kinds as a public course (D14, T27 of
// Plan-Deck-Kinds-And-Topics): genre, level and hidden are read by the
// catalog's own parser, and the level gate applies to its decks.

const String _fixture = 'test/fixtures/private/qaa-tiny';

const String _secret = '''
schema: 1
id: "fnpd-qaa-secret"
name: "Secret"
kind: "vocab"
language: { code: "qaa", iso639_3: "qaa", name: "Tiny", script: "latin" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
hidden: true
cards:
  - id: "fnpd-qaa-0101"
    target: "tamo"
    native: "key"
''';

void main() {
  test('a package deck keeps its genre and level; the gate applies', () async {
    final files = await readPackageFolder(Directory(_fixture));
    expect(files, isNotNull);
    final edited = <String, String>{...files!};
    edited['qaa/fnpd-qaa-food.yaml'] = edited['qaa/fnpd-qaa-food.yaml']!
        .replaceFirst(
          'kind: "vocab"\n',
          'kind: "vocab"\ngenre: "proverbs"\nlevel: "B1"\n',
        );
    edited['qaa/fnpd-qaa-secret.yaml'] = _secret;

    final store = MemoryPrivateStore();
    final result = await importPrivatePackage(
      edited,
      store: store,
      appVersion: '0.10.0',
    );
    expect(result.problems, isEmpty);
    expect(result.installed, isTrue);

    final catalog = await DeckCatalog(
      MemoryDeckSource(const <String, String>{}),
      privateStore: store,
    ).load();
    expect(catalog.broken, isEmpty);

    final food = catalog.byId('fnpd-qaa-en-food')!;
    expect(food.private, isTrue);
    expect(food.deck.genre, 'proverbs');
    expect(food.deck.level, Level.b1);

    // Hidden: off every list, but on the phone and still a private deck.
    expect(catalog.decks.map((e) => e.id), isNot(contains('fnpd-qaa-secret')));
    expect(catalog.hidden.map((e) => e.id), contains('fnpd-qaa-secret'));
    expect(catalog.hidden.single.private, isTrue);

    // The level gate keeps the private mark and drops what is above.
    final atA1 = catalog.forLevels((_) => Level.a1);
    expect(atA1.byId('fnpd-qaa-en-food'), isNull);
    expect(atA1.byId('fnpd-qaa-en-home'), isNotNull);
    expect(atA1.byId('fnpd-qaa-en-home')!.private, isTrue);
    final atB1 = catalog.forLevels((_) => Level.b1);
    expect(atB1.byId('fnpd-qaa-en-food')!.private, isTrue);
  });
}
