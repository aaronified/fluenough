import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/situations_parser.dart';

const String _file = '''
schema: 1
id: te-situations
name: "Telugu situations"
kind: situations
language: { code: te, iso639_3: tel, name: Telugu, script: telugu, tts: te-IN }
license: "CC-BY-SA-4.0"
situations:
  - id: taxi
    icon: taxi
    title: { en: "Taxi", bn: "ট্যাক্সি" }
    phrases: ["te-0275"]
    words: ["te-0273", "te-0274"]
''';

void main() {
  test('a situations file lists card ids, phrases then words, and titles '
      'in the learner\'s language', () {
    final file = parseSituations(_file, source: 'te-situations.yaml');
    final taxi = file.byId('taxi')!;
    expect(taxi.cardIds, <String>['te-0275', 'te-0273', 'te-0274']);
    expect(taxi.titleFor(<String>['hi', 'bn']), 'ট্যাক্সি');
    expect(taxi.titleFor(<String>['hi']), 'Taxi');
    expect(file.withIcon('taxi'), same(taxi));
  });

  test('a sheet that lists no card is refused, as a broken file', () {
    final broken = _file
        .replaceAll('    phrases: ["te-0275"]\n', '')
        .replaceAll('    words: ["te-0273", "te-0274"]\n', '');
    expect(
      () => parseSituations(broken, source: 'te-situations.yaml'),
      throwsA(isA<DeckParseException>()),
    );
    expect(
      DeckCatalog.checkFile('decks/te/te-situations.yaml', broken),
      isNotNull,
    );
    expect(DeckCatalog.checkFile('decks/te/te-situations.yaml', _file), isNull);
  });
}
