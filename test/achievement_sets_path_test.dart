// A path's chosen sets for the achievements (#322, decision 7 of the
// achievements mockup): `achievement_sets` is optional, so an older path
// stays valid, and a course sees only the decks it has.

import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String _path(String sets) => '''
schema: 1
kind: path
id: hi-path
language: hi
units:
  - [hi-pronouns, hi-pronouns-sentences, hi-reading-who-is-who]
  - [hi-family]
  - [hi-grammar-past]
$sets''';

const String _pronouns =
    '  - {id: pronouns, kind: word, decks: [hi-pronouns, '
    'hi-pronouns-sentences, hi-reading-who-is-who]}\n';

void _refuses(String body, String why) {
  expect(
    () => parseLanguagePath(_path('achievement_sets:\n$body')),
    throwsA(
      isA<DeckParseException>().having(
        (e) => e.message,
        'message',
        contains(why),
      ),
    ),
    reason: body,
  );
}

void main() {
  group('achievement_sets in a path file', () {
    test('a path without the key has no sets and stays valid', () {
      final language = parseLanguagePath(_path(''));
      expect(language.achievementSets, isEmpty);
      final course = language.forNative('en', exists: (_) => true);
      expect(course.achievementSets, isEmpty);
    });

    test('reads each set with its kind and decks, in the file order', () {
      final language = parseLanguagePath(
        _path(
          'achievement_sets:\n$_pronouns'
          '  - id: past-tense\n'
          '    kind: grammar\n'
          '    decks: [hi-grammar-past]\n',
        ),
      );
      final sets = language.achievementSets;
      expect(sets.map((s) => s.id), <String>['pronouns', 'past-tense']);
      expect(sets.map((s) => s.grammar), <bool>[false, true]);
      expect(sets.first.decks, <String>[
        'hi-pronouns',
        'hi-pronouns-sentences',
        'hi-reading-who-is-who',
      ]);
    });

    test('a course gets the sets by its own deck ids, only the decks it has, '
        'and no set with none of them', () {
      final language = parseLanguagePath(
        _path(
          'achievement_sets:\n$_pronouns'
          '  - {id: family, kind: word, decks: [hi-family]}\n',
        ),
      );
      const missing = <String>{'hi-en-pronouns-sentences', 'hi-en-family'};
      final course = language.forNative(
        'en',
        exists: (id) => !missing.contains(id),
      );
      expect(course.achievementSets.map((s) => s.id), <String>['pronouns']);
      expect(course.achievementSets.single.decks, <String>[
        'hi-en-pronouns',
        'hi-en-reading-who-is-who',
      ]);
    });

    test('the private marking and the placed path keep the sets', () {
      final language = parseLanguagePath(
        _path(
          'achievement_sets:\n'
          '  - {id: family, kind: word, decks: [hi-family]}\n',
        ),
      );
      expect(language.asPrivatelyModified().achievementSets, hasLength(1));
      final course = language.forNative('en', exists: (_) => true);
      final placed = course.placing(const [], (_) => null);
      expect(placed.achievementSets, hasLength(1));
    });

    test('a bad set is refused, naming what is wrong', () {
      expect(
        () => parseLanguagePath(_path('achievement_sets: family\n')),
        throwsA(isA<DeckParseException>()),
      );
      _refuses(
        '  - {id: Family, kind: word, decks: [hi-family]}\n',
        'id must match [a-z0-9-]+',
      );
      _refuses(
        '  - {id: a, kind: word, decks: [hi-family]}\n'
        '  - {id: a, kind: word, decks: [hi-family]}\n',
        '"a" is listed twice',
      );
      _refuses(
        '  - {id: a, kind: verbs, decks: [hi-family]}\n',
        'kind must be "word" or "grammar"',
      );
      _refuses(
        '  - {id: a, kind: word, decks: [hi-health]}\n',
        'lists "hi-health", which the path does not',
      );
      _refuses(
        '  - {id: a, kind: word, decks: []}\n',
        'decks must be a non-empty list',
      );
      _refuses(
        '  - {id: a, kind: word, decks: [hi-family], x: 1}\n',
        'unknown field "x"',
      );
    });
  });
}
