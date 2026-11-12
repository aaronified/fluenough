// Recommended works (wiki/Plan-Deck-Kinds-And-Topics.md, D13, T24): a
// language's recommendations file is read with its briefing, legal route and
// comprehension questions; the books-and-scripts rule and the level gate say
// which a learner is offered; questions are asked only on a completed work; and
// the creators and recommendations files are shared, per-language, deck-owned
// downloads checked before use.

import 'dart:convert';

import 'package:fluenough/core/data/deck_parser.dart' show DeckParseException;
import 'package:fluenough/core/data/recommendations.dart';
import 'package:fluenough/core/decks/recommendations.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/decks/shared_data.dart';
import 'package:fluenough/core/models/level.dart';
import 'package:fluenough/core/models/recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kinds_fixture.dart';

RecommendationsFile _fixture() => parseRecommendations(
  kindsFixtureFiles()['decks/recommendations/zz.yaml']!,
  source: 'zz.yaml',
);

void main() {
  final file = _fixture();
  final book = file.byId('zz-rec-cartas-de-prueba')!;
  final film = file.byId('zz-rec-una-pelicula')!;

  group('the recommendations file', () {
    test('keeps the book and the film with their briefing and questions', () {
      expect(file.problems, isEmpty);
      expect(book.medium, RecommendationMedium.book);
      expect(book.isBook, isTrue);
      expect(book.script, 'latin');
      expect(book.level, Level.a2);
      expect(book.creators, <String>['zz-ejemplo-autora']);
      expect(book.quotedIn, 'zz-culture-ejemplo');
      expect(
        book.briefingFor(<String>['bn', 'en']),
        startsWith('A short book'),
      );
      expect(book.legal.single.kind, 'library');
      expect(book.legal.single.noteFor(<String>['en']), 'Free: public domain');
      expect(film.isBook, isFalse);
      expect(film.legal, isEmpty);
    });

    test(
      'reads each question as a reading question, the answer counted from 0',
      () {
        expect(book.questions, hasLength(3));
        final first = book.questions.first;
        expect(first.id, 'q1');
        expect(first.prompt['en'], 'Who writes the letters?');
        expect(first.options.map((o) => o['en']), <String>[
          'Friends',
          'Strangers',
        ]);
        // The file says 1, the first option.
        expect(first.answer, 0);
        expect(first.isRight(0), isTrue);
        expect(book.questionKey(first), 'zz-rec-cartas-de-prueba#q1');
      },
    );

    test('reads a true or false question, and drops what cannot be read', () {
      final read = parseRecommendations('''
schema: 1
kind: "recommendations"
language: "zz"
recommendations:
  - id: "zz-rec-uno"
    medium: "song"
    title: { text: "Uno" }
    creator: "zz-ejemplo-poeta"
    questions:
      - { id: "t", prompt: { en: "Is it sad?" }, answer: false }
      - { id: "bad", prompt: { en: "?" }, options: { en: ["a", "b"] }, answer: 3 }
      - { id: "t", prompt: { en: "Dup" }, answer: true }
    legal:
      - { kind: "stream", url: "http://insecure.example/x" }
      - { kind: "stream", url: "https://example.org/x", note: { en: "Paid" } }
  - id: "zz-rec-sin-medio"
    medium: "hologram"
    title: { text: "Nada" }
    creator: ["zz-ejemplo-poeta"]
  - id: "zz-rec-sin-autor"
    medium: "film"
    title: { text: "Nadie" }
''', source: 'zz.yaml');
      expect(read.recommendations.map((r) => r.id), <String>['zz-rec-uno']);
      final uno = read.byId('zz-rec-uno')!;
      expect(uno.questions.single.isTrueFalse, isTrue);
      expect(uno.questions.single.answer, 1);
      expect(uno.legal.single.url, 'https://example.org/x');
      expect(read.problems.length, greaterThanOrEqualTo(5));
    });

    test('refuses a file that is not a recommendations file, or is newer', () {
      expect(
        () => parseRecommendations('kind: "creators"\n', source: 'x.yaml'),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => parseRecommendations(
          'schema: 2\nkind: "recommendations"\nlanguage: "zz"\n'
          'recommendations: []\n',
          source: 'x.yaml',
        ),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  group('who is offered a work', () {
    const learnsScript = RecommendationCourse(pathHasAlphabet: true);
    const latin = RecommendationCourse(latinOnly: true);
    const noScript = RecommendationCourse();

    test('a book only where the course includes script learning', () {
      expect(recommendationOffered(book, learnsScript, Level.a2), isTrue);
      expect(recommendationOffered(book, latin, Level.a2), isTrue);
      expect(recommendationOffered(book, noScript, Level.a2), isFalse);
      // Other media are not gated by script.
      expect(recommendationOffered(film, noScript, Level.b1), isTrue);
    });

    test('a script-only learner sees only books in a script they learn', () {
      const latinLearner = RecommendationCourse(
        scriptOnly: true,
        scriptsLearned: <String>{'latin'},
      );
      const teluguLearner = RecommendationCourse(
        scriptOnly: true,
        scriptsLearned: <String>{'telugu'},
      );
      expect(recommendationOffered(book, latinLearner, Level.a2), isTrue);
      expect(recommendationOffered(book, teluguLearner, Level.a2), isFalse);
      expect(recommendationOffered(film, teluguLearner, Level.b1), isTrue);
    });

    test('never above the learner\'s level', () {
      expect(recommendationOffered(film, learnsScript, Level.a2), isFalse);
      expect(recommendationOffered(film, learnsScript, null), isFalse);
      expect(
        offeredRecommendations(file.recommendations, learnsScript, Level.a2),
        <Recommendation>[book],
      );
      expect(
        offeredRecommendations(file.recommendations, learnsScript, Level.b1),
        hasLength(2),
      );
    });

    test('questions are asked only on a completed work', () {
      expect(openQuestions(book, const <String>{}), isEmpty);
      expect(openQuestions(book, <String>{book.id}), hasLength(3));
      expect(openQuestions(book, <String>{film.id}), isEmpty);
    });
  });

  group('the shared files of a language', () {
    test('are told by their path, apart from the fixed shared files', () {
      expect(sharedKindOf('decks/creators/te.yaml'), 'creators');
      expect(sharedKindOf('decks/recommendations/te.yaml'), 'recommendations');
      expect(sharedKindOf('decks/themes.yaml'), 'themes');
      expect(sharedKindOf('decks/creators/images/te-x.jpg'), isNull);
      expect(sharedKindOf('decks/creators/te/x.yaml'), isNull);
      expect(sharedKindOf('decks/other.yaml'), isNull);
    });

    test(
      'are checked as the app reads them, and must be for their language',
      () {
        final files = kindsFixtureFiles();
        expect(
          checkSharedText(
            'decks/creators/zz.yaml',
            files['decks/creators/zz.yaml']!,
          ),
          isNull,
        );
        expect(
          checkSharedText(
            'decks/recommendations/zz.yaml',
            files['decks/recommendations/zz.yaml']!,
          ),
          isNull,
        );
        expect(
          checkSharedText(
            'decks/creators/yy.yaml',
            files['decks/creators/zz.yaml']!,
          ),
          contains('zz'),
        );
        expect(
          checkSharedText('decks/creators/zz.yaml', 'kind: "topics"\n'),
          isNotNull,
        );
      },
    );

    test('are listed by the index, kept under names that do not meet', () {
      final text = kindsFixtureFiles()['decks/creators/zz.yaml']!;
      final bytes = utf8.encode(text);
      final found = parseSharedFiles(<Object?>[
        <String, Object?>{
          'path': 'decks/creators/zz.yaml',
          'size': bytes.length,
          'sha256': sha256Hex(bytes),
          'kind': 'creators',
        },
        <String, Object?>{
          'path': 'decks/recommendations/zz.yaml',
          'size': 10,
          'sha256': sha256Hex(utf8.encode('x')),
        },
        <String, Object?>{
          'path': 'decks/later.yaml',
          'size': 10,
          'sha256': sha256Hex(utf8.encode('x')),
        },
      ]);
      expect(found.files.map((f) => f.kind), <String>[
        'creators',
        'recommendations',
      ]);
      expect(found.files.first.unusableReason, isNull);
      expect(found.problems, isEmpty);
      expect(
        sharedNoteName('decks/creators/zz.yaml'),
        'shared-creators-zz.yaml',
      );
      expect(
        sharedNoteName('decks/recommendations/zz.yaml'),
        'shared-recommendations-zz.yaml',
      );
      expect(sharedNoteName('decks/themes.yaml'), 'shared-themes.yaml');
    });
  });
}
