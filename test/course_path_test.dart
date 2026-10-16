import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/data/deck_parser.dart';

String pathFile(String units) => '''
schema: 1
kind: path
id: hi-path
language: hi
units:
$units''';

/// [text]'s path as learners from English are taught it, where every deck
/// it names exists in English.
CoursePath fromEnglish(String text) =>
    parseLanguagePath(text).forNative('en', exists: (_) => true);

Matcher refusing(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

void main() {
  test('reads the units in order, each a list of core ids', () {
    final language = parseLanguagePath(
      pathFile(
        '  - [hi-first-words, hi-grammar-sentences]\n'
        '  - [hi-questions]\n',
      ),
    );
    expect(language.id, 'hi-path');
    expect(language.language, 'hi');
    expect(language.plan.map((u) => u.decks), [
      ['hi-first-words', 'hi-grammar-sentences'],
      ['hi-questions'],
    ]);
  });

  test("a course reads it through its own decks' ids", () {
    final path = fromEnglish(
      pathFile(
        '  - [hi-first-words, hi-grammar-sentences]\n'
        '  - [hi-questions]\n',
      ),
    );
    expect(path.id, 'hi-path');
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
      ('schema: 1\nkind: themes\nunits:\n  - [hi-market]\n', 'kind: path'),
      (
        pathFile('  - [hi-market]\n')
            .replaceFirst('language: hi', 'language: Hindi'),
        'language code',
      ),
      (
        pathFile('  - [hi-market]\n').replaceFirst('id: hi-path', 'id: hi-en'),
        'has id "hi-path"',
      ),
      (
        pathFile('  - [hi-market]\n')
            .replaceFirst('units:', 'theme: home\nunits:'),
        'unknown field "theme"',
      ),
      (pathFile('  []\n'), 'non-empty list'),
      (pathFile('  - hi-market\n'), 'a list of core ids, or a mapping'),
      (pathFile('  - []\n'), 'non-empty list of core ids'),
      (pathFile('  - [Hi Market]\n'), 'is not a core id of hi'),
      (pathFile('  - [bn-market]\n'), '"bn-market" is not a core id of hi'),
      (pathFile('  - [hi-market]\n  - [hi-help, hi-market]\n'), 'listed twice'),
    ]) {
      expect(() => parseLanguagePath(text), refusing(why), reason: why);
    }
  });

  test('a path for one course is refused, saying what to do', () {
    const perCourse = '''
schema: 1
kind: path
id: hi-en-path
language: hi
native: en
units:
  - [hi-en-market]
''';
    expect(
      () => parseLanguagePath(perCourse),
      refusing(
        'native: a path is one per language learnt, decks/hi/hi-path.yaml, '
        'shared by every native language (ADR-0036); list core ids',
      ),
    );
  });

  test('names the decks that need the alphabet, each on the path', () {
    const units = '  - [hi-script-vowels]\n  - [hi-market]\n';
    final language = parseLanguagePath(
      pathFile(units)
          .replaceFirst('units:', 'alphabet: [hi-script-vowels]\nunits:'),
    );
    expect(language.alphabet, <String>{'hi-script-vowels'});
    final path = language.forNative('en', exists: (_) => true);
    expect(path.alphabet, <String>{'hi-en-script-vowels'});
    expect(fromEnglish(pathFile(units)).alphabet, isEmpty);
    // Kept when added decks are placed.
    expect(path.placing(const [], (_) => null).alphabet, path.alphabet);
    expect(
      () => parseLanguagePath(
        pathFile(units)
            .replaceFirst('units:', 'alphabet: [hi-spelling]\nunits:'),
      ),
      refusing('which the path does not'),
    );
  });

  test('a unit may end in "*", and a unit of "*" alone is the last', () {
    final path = fromEnglish(
      pathFile(
        '  - [hi-script-vowels]\n'
        '  - [hi-market, hi-grammar-nouns, "*"]\n'
        '  - [hi-home, "*"]\n'
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
      ('  - ["*", hi-market]\n', 'can only end a unit'),
      ('  - [hi-market, "*", "*"]\n', 'can only end a unit'),
      ('  - ["*"]\n  - [hi-market]\n', 'alone can only be the last'),
    ]) {
      expect(
        () => parseLanguagePath(pathFile(units)),
        refusing(why),
        reason: units,
      );
    }
  });

  group('one path, every native language', () {
    final language = parseLanguagePath(
      pathFile(
        '  - [hi-first-words, hi-grammar-sentences, "*"]\n'
        '  - [hi-sound-differences]\n'
        '  - [hi-market, "*"]\n'
        '  - ["*"]\n',
      ),
    );
    // English teaches every unit; Bengali has two decks so far.
    const bengali = <String>{'hi-bn-first-words', 'hi-bn-market'};
    final fromBengali = language.forNative('bn', exists: bengali.contains);

    test('a core id becomes the course\'s deck where it has one', () {
      expect(fromBengali.course, 'hi/bn');
      expect(fromBengali.units, [
        ['hi-bn-first-words'],
        ['hi-bn-market'],
        <String>[],
      ]);
    });

    test('a written unit with no deck in the native language is coming, '
        'and out of units and open', () {
      expect(fromBengali.open, {0, 1, 2});
      expect(fromBengali.plan.map((u) => u.isComing), [
        false,
        true,
        false,
        false,
      ]);
      expect(fromBengali.plan[1].decks, isEmpty);
      // Placing an added deck does not take the coming unit for "*" alone.
      final placed = fromBengali.placing(<({String id, String? theme})>[
        (id: 'hi-bn-my-words', theme: null),
      ], (_) => null);
      expect(placed.units.last, ['hi-bn-my-words']);
    });

    test('coverage counts the written units each course has decks in', () {
      final fromEnglish = language.forNative('en', exists: (_) => true);
      expect(fromEnglish.coveredUnits, 3);
      expect(fromEnglish.writtenUnits, 3);
      expect(fromBengali.coveredUnits, 2);
      expect(fromBengali.writtenUnits, 3);
    });
  });

  group('placing decks the path does not list', () {
    final path = fromEnglish(
      pathFile(
        '  - [hi-script-vowels]\n'
        '  - [hi-market, hi-grammar-nouns, "*"]\n'
        '  - [hi-home, "*"]\n'
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
      final closed = fromEnglish(pathFile('  - [hi-market]\n'));
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
