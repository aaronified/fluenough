import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/data/deck_parser.dart';

/// Gender classes (#512): a language's path lists them, and the app reads
/// them into [LanguagePath.genders].
String pathFile(String genders) =>
    '''
schema: 1
kind: "path"
id: "te-path"
language: "te"
$genders
units:
  - ["te-home"]
''';

Matcher refusing(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

void main() {
  test('reads the classes in order', () {
    final path = parseLanguagePath(pathFile('genders: ["mahat", "amahat"]'));
    expect(path.genders, ['mahat', 'amahat']);
  });

  test('an empty list is a language without gender', () {
    expect(parseLanguagePath(pathFile('genders: []')).genders, isEmpty);
  });

  test('a path that lists none has null', () {
    expect(parseLanguagePath(pathFile('')).genders, isNull);
  });

  test('refuses a value that is not a list', () {
    expect(
      () => parseLanguagePath(pathFile('genders: "m"')),
      refusing('genders must be a list'),
    );
  });

  test('refuses a class that is not text, or blank', () {
    expect(
      () => parseLanguagePath(pathFile('genders: ["m", 1]')),
      refusing('genders[1] must be a class name'),
    );
    expect(
      () => parseLanguagePath(pathFile('genders: [" f"]')),
      refusing('genders[0] must be a class name'),
    );
  });

  test('refuses a class listed twice', () {
    expect(
      () => parseLanguagePath(pathFile('genders: ["m", "f", "m"]')),
      refusing('genders[2]: "m" is listed twice'),
    );
  });
}
