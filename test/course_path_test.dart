import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/data/deck_parser.dart';

String pathFile(String units) => '''
schema: 1
kind: path
id: hi-en-path
language: hi
native: en
units:
$units''';

void main() {
  test('reads the units in order, each a list of deck ids', () {
    final path = parseCoursePath(
      pathFile(
        '  - [hi-en-first-words, hi-en-grammar-sentences]\n'
        '  - [hi-en-questions]\n',
      ),
    );
    expect(path.id, 'hi-en-path');
    expect(path.course, 'hi/en');
    expect(path.units, [
      ['hi-en-first-words', 'hi-en-grammar-sentences'],
      ['hi-en-questions'],
    ]);
    expect(path.deckIds, [
      'hi-en-first-words',
      'hi-en-grammar-sentences',
      'hi-en-questions',
    ]);
    expect(path.unitOf('hi-en-grammar-sentences'), 0);
    expect(path.unitOf('hi-en-questions'), 1);
    expect(path.unitOf('hi-en-market'), isNull);
  });

  test('refuses what is not a well-formed path file', () {
    for (final (text, why) in <(String, String)>[
      ('schema: 1\nkind: themes\nunits:\n  - [hi-en-market]\n', 'kind: path'),
      (
        pathFile('  - [hi-en-market]\n')
            .replaceFirst('language: hi', 'language: Hindi'),
        'language code',
      ),
      (
        pathFile('  - [hi-en-market]\n')
            .replaceFirst('native: en', 'native: English'),
        'language code',
      ),
      (
        pathFile('  - [hi-en-market]\n')
            .replaceFirst('id: hi-en-path', 'id: hi-path'),
        'has id "hi-en-path"',
      ),
      (pathFile('  []\n'), 'non-empty list'),
      (pathFile('  - hi-en-market\n'), 'non-empty list of deck ids'),
      (pathFile('  - []\n'), 'non-empty list of deck ids'),
      (pathFile('  - [Hi Market]\n'), 'lists deck ids'),
      (
        pathFile('  - [hi-en-market]\n  - [hi-en-help, hi-en-market]\n'),
        'listed twice',
      ),
    ]) {
      expect(
        () => parseCoursePath(text),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            contains(why),
          ),
        ),
        reason: why,
      );
    }
  });

  test('names the decks that need the alphabet, each on the path', () {
    const units = '  - [hi-en-script-vowels]\n  - [hi-en-market]\n';
    final path = parseCoursePath(
      pathFile(units)
          .replaceFirst('units:', 'alphabet: [hi-en-script-vowels]\nunits:'),
    );
    expect(path.alphabet, <String>{'hi-en-script-vowels'});
    expect(parseCoursePath(pathFile(units)).alphabet, isEmpty);
    // Kept when added decks are placed.
    expect(path.placing(const [], (_) => null).alphabet, path.alphabet);
    expect(
      () => parseCoursePath(
        pathFile(units)
            .replaceFirst('units:', 'alphabet: [hi-en-spelling]\nunits:'),
      ),
      throwsA(
        isA<DeckParseException>().having(
          (e) => e.message,
          'message',
          contains('which the path does not'),
        ),
      ),
    );
  });

  test('a unit may end in "*", and a unit of "*" alone is the last', () {
    final path = parseCoursePath(
      pathFile(
        '  - [hi-en-script-vowels]\n'
        '  - [hi-en-market, hi-en-grammar-nouns, "*"]\n'
        '  - [hi-en-home, "*"]\n'
        '  - ["*"]\n',
      ),
    );
    expect(path.units, [
      ['hi-en-script-vowels'],
      ['hi-en-market', 'hi-en-grammar-nouns'],
      ['hi-en-home'],
      <String>[],
    ]);
    expect(path.open, {1, 2, 3});
    expect(path.deckIds, contains('hi-en-home'));
    expect(path.deckIds, isNot(contains('*')));

    for (final (units, why) in <(String, String)>[
      ('  - ["*", hi-en-market]\n', 'can only end a unit'),
      ('  - [hi-en-market, "*", "*"]\n', 'can only end a unit'),
      ('  - ["*"]\n  - [hi-en-market]\n', 'alone can only be the last'),
    ]) {
      expect(
        () => parseCoursePath(pathFile(units)),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            contains(why),
          ),
        ),
        reason: units,
      );
    }
  });

  group('placing decks the path does not list', () {
    final path = parseCoursePath(
      pathFile(
        '  - [hi-en-script-vowels]\n'
        '  - [hi-en-market, hi-en-grammar-nouns, "*"]\n'
        '  - [hi-en-home, "*"]\n'
        '  - ["*"]\n',
      ),
    );
    const themes = <String, String>{
      'hi-en-market': 'market',
      'hi-en-home': 'home',
    };
    String? themeOf(String id) => themes[id];

    test('one of a theme goes at the bottom of its unit, any other at '
        'the end', () {
      final placed = path.placing(<({String id, String? theme})>[
        (id: 'hi-en-my-home', theme: 'home'),
        (id: 'hi-en-my-words', theme: null),
        (id: 'hi-en-my-market', theme: 'market'),
        (id: 'hi-en-my-weather', theme: 'weather'),
        (id: 'hi-en-my-market-2', theme: 'market'),
      ], themeOf);
      expect(placed.units, [
        ['hi-en-script-vowels'],
        [
          'hi-en-market',
          'hi-en-grammar-nouns',
          'hi-en-my-market',
          'hi-en-my-market-2',
        ],
        ['hi-en-home', 'hi-en-my-home'],
        ['hi-en-my-words', 'hi-en-my-weather'],
      ]);
      expect(placed.open, isEmpty);
    });

    test('with nothing to place, the empty last unit goes', () {
      expect(path.placing(const [], themeOf).units, [
        ['hi-en-script-vowels'],
        ['hi-en-market', 'hi-en-grammar-nouns'],
        ['hi-en-home'],
      ]);
    });

    test('a path without wildcards leaves a deck out, as before', () {
      final closed = parseCoursePath(pathFile('  - [hi-en-market]\n'));
      expect(
        closed.placing(<({String id, String? theme})>[
          (id: 'hi-en-my-market', theme: 'market'),
        ], themeOf).units,
        [
          ['hi-en-market'],
        ],
      );
    });
  });
}
