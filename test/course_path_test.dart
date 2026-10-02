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
}
