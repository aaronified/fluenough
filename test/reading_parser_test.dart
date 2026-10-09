import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';

/// Reading decks (#98, ADR-0019): `kind: reading`, passages and their
/// questions, read by `DeckParser`.

Deck parse(String yaml) => DeckParser.parse(yaml, source: 'test.yaml');

/// A [DeckParseException] whose message contains every one of [mentions].
Matcher rejects(List<String> mentions) {
  var matcher = isA<DeckParseException>();
  for (final text in mentions) {
    matcher = matcher.having((e) => e.message, 'message', contains(text));
  }
  return throwsA(matcher);
}

const header = '''
schema: 1
id: bn-en-test-reading
name: "Test reading"
kind: reading
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali, tts: bn-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
''';

/// A deck of one passage with [sentences] and [questions], and [extra]
/// passage fields.
String deck({
  String sentences = '''
      - text: "আমি ভাত খাই।"
        reading: "ami bhat khai."
''',
  String questions = '''
      - id: q1
        prompt: { en: "Rice is eaten." }
        answer: true
      - id: q2
        prompt: { en: "What is eaten?" }
        options:
          - { en: "Rice" }
          - { en: "Fish" }
        answer: 1
''',
  String extra = '',
}) =>
    '''
${header}passages:
  - id: p1
    title: "Lunch"
$extra    sentences:
$sentences    questions:
$questions''';

void main() {
  group('a reading deck', () {
    test('is its passages, and its questions are its cards', () {
      final d = parse(readingFixtureYaml);
      expect(d.kind, DeckKind.reading);
      expect(d.passages.map((p) => p.id), [
        'bn-en-fixture-reading-shop',
        'bn-en-fixture-reading-home',
      ]);
      expect(d.cards.map((c) => c.id), [
        'bn-en-fixture-reading-shop-q1',
        'bn-en-fixture-reading-shop-q2',
        'bn-en-fixture-reading-shop-q3',
        'bn-en-fixture-reading-home-q1',
        'bn-en-fixture-reading-home-q2',
      ]);
      final first = d.cards.first as QuestionCard;
      expect(first.deckId, 'bn-en-fixture-reading');
      expect(first.passage.title, 'At the shop');
      expect(first.target, 'নমস্কার। কত দাম?');
      expect(first.native, 'What does the buyer ask first?');
      expect(first.modes, {DrillMode.reading, DrillMode.listening});
      expect(first.source, readingFixtureSource);
      expect(first.passage.theme, 'market');
      // The second passage names no source, so its deck's is used.
      expect((d.cards.last as QuestionCard).source, readingFixtureDeckSource);
      expect(d.source, readingFixtureDeckSource);
    });

    test('numbers an answer from 1, and keys text by language', () {
      final d = parse(readingFixtureYaml);
      final q1 = d.passages.first.questions[0];
      expect(q1.isTrueFalse, isFalse);
      expect(q1.choiceCount, 3);
      expect(q1.answer, 0);
      expect(q1.prompt['hi'], 'ग्राहक पहले क्या पूछता है?');
      expect(q1.options[1], {'en': 'The way', 'hi': 'रास्ता'});
      expect(q1.languages, {'en', 'hi'});
      expect(q1.languageFor(const ['bn', 'hi', 'en']), 'hi');
      expect(q1.languageFor(const ['bn']), 'en');
      final q3 = d.passages.first.questions[2];
      expect(q3.answer, 1);
      expect(q3.isRight(1), isTrue);
      expect(q3.isRight(0), isFalse);
      expect(q3.logged(1), '2');
    });

    test('takes true or false without options', () {
      final q = parse(deck()).passages.single.questions.first;
      expect(q.isTrueFalse, isTrue);
      expect(q.choiceCount, 2);
      expect(q.answer, 0);
      expect(q.logged(0), 'true');
      expect(q.logged(1), 'false');
      final no = parse(
        deck(
          questions: '''
      - id: q1
        prompt: { en: "Fish is eaten." }
        answer: false
''',
        ),
      ).passages.single.questions.single;
      expect(no.answer, 1);
      expect(no.gradeFor(1), ReadingQuestion.rightGrade);
      expect(no.gradeFor(0), ReadingQuestion.wrongGrade);
    });

    test('keeps a passage\'s text byte for byte, as a quotation must be', () {
      // Curly quotes and apostrophes, a precomposed য় (U+09DF) beside a
      // decomposed one (য + ়), a two-part vowel sign ো written as one
      // (U+09CB) and as two (ে + া), a space inside, and spaces outside:
      // nothing is folded, trimmed or normalised.
      const text = '  ‘ক’রে’ য় য় ো ো  “কী?”  ';
      final yaml = deck(
        sentences:
            '''
      - text: "$text"
        reading: "kore"
''',
      );
      final sentence = parse(yaml).passages.single.sentences.single;
      expect(utf8.encode(sentence.text), utf8.encode(text));
      expect(sentence.text.length, text.length);
    });

    test(
      'keeps a glossary as written, and its word must be in the passage',
      () {
        final passage = parse(readingFixtureYaml).passages.last;
        expect(passage.glossary, hasLength(2));
        final gloss = passage.glossary.first;
        expect(passage.glossary.last.modern, passage.glossary.last.word);
        expect(utf8.encode(gloss.word), utf8.encode('ক’রে'));
        expect(gloss.modern, 'করে');
        expect(gloss.reading, 'kore');
        expect(gloss.meaning, {'en': 'having done'});
        expect(gloss.note['en'], contains('dropped ই'));
        expect(parse(deck()).passages.single.glossary, isEmpty);

        expect(
          () => parse(
            deck(
              extra: '''
    glossary:
      - word: "লয়"
        modern: "নেয়"
        reading: "ney"
        meaning: { en: "takes" }
''',
            ),
          ),
          rejects(['glossary[0].word', 'does not occur in the passage']),
        );
        // A straight apostrophe is not the curly one the passage has.
        final curly = deck(
          sentences: '''
      - text: "সে কাজ ক’রে যায়।"
''',
        );
        expect(
          () => parse(
            curly.replaceFirst('    sentences:', '''
    glossary:
      - word: "ক'রে"
        modern: "করে"
        meaning: { en: "having done" }
    sentences:'''),
          ),
          rejects(['does not occur']),
        );
        expect(
          () => parse(
            curly.replaceFirst('    sentences:', '''
    glossary:
      - word: "ক’রে"
        modern: "করে"
        meaning: { bn: "করে" }
    sentences:'''),
          ),
          rejects(['glossary[0].meaning', 'missing "en"']),
        );
      },
    );
  });

  group('a reading deck is refused', () {
    test('with a question id used twice, or a passage\'s id', () {
      expect(
        () => parse(
          deck(
            questions: '''
      - id: q1
        prompt: { en: "A." }
        answer: true
      - id: q1
        prompt: { en: "B." }
        answer: false
''',
          ),
        ),
        rejects(['questions[1].id', 'duplicate id "q1"']),
      );
      expect(
        () => parse(
          deck(
            questions: '''
      - id: p1
        prompt: { en: "A." }
        answer: true
''',
          ),
        ),
        rejects(['duplicate id "p1"']),
      );
    });

    test('with an answer that is no option, or not true or false', () {
      expect(
        () => parse(
          deck(
            questions: '''
      - id: q1
        prompt: { en: "Which?" }
        options: [{ en: "A" }, { en: "B" }]
        answer: 3
''',
          ),
        ),
        rejects(['answer', 'from 1 to 2', '3']),
      );
      expect(
        () => parse(
          deck(
            questions: '''
      - id: q1
        prompt: { en: "Which?" }
        options: [{ en: "A" }, { en: "B" }]
        answer: true
''',
          ),
        ),
        rejects(['answer', 'from 1 to 2']),
      );
      expect(
        () => parse(
          deck(
            questions: '''
      - id: q1
        prompt: { en: "True?" }
        answer: 1
''',
          ),
        ),
        rejects(['true or false']),
      );
    });

    test('with one option, or five', () {
      for (final options in <String>[
        '[{ en: "A" }]',
        '[{ en: "A" }, { en: "B" }, { en: "C" }, { en: "D" }, { en: "E" }]',
      ]) {
        expect(
          () => parse(
            deck(
              questions:
                  '''
      - id: q1
        prompt: { en: "Which?" }
        options: $options
        answer: 1
''',
            ),
          ),
          rejects(['2 to 4 options']),
        );
      }
    });

    test('with text in no English, or keyed by a bare false', () {
      expect(
        () => parse(
          deck(
            questions: '''
      - id: q1
        prompt: { bn: "ভাত?" }
        answer: true
''',
          ),
        ),
        rejects(['prompt', 'missing "en"']),
      );
      expect(
        () => parse(
          deck(
            questions: '''
      - id: q1
        prompt: { en: "Rice?", false: "Ris?" }
        answer: true
''',
          ),
        ),
        rejects(['read as the boolean false']),
      );
    });

    test('with no sentences, or a sentence of nothing', () {
      expect(
        () => parse(deck(sentences: '      []\n')),
        rejects(['sentences must not be empty']),
      );
      expect(
        () => parse(deck(sentences: '      - text: "  "\n')),
        rejects(['text must not be empty']),
      );
    });

    test('with cards, or passages on another kind of deck', () {
      expect(
        () => parse(
          deck().replaceFirst(
            'passages:',
            'cards:\n  - { id: c1, target: "x", native: "y" }\npassages:',
          ),
        ),
        rejects(['a reading deck has passages, not cards']),
      );
      expect(
        () => parse(deck().replaceFirst('kind: reading\n', '')),
        rejects(['passages are only for a reading deck']),
      );
    });

    test('and a card cannot be drilled by reading', () {
      expect(
        () => parse('''
schema: 1
id: bn-en-test
name: "Test"
language: { code: bn, iso639_3: ben, name: Bengali, script: bengali }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: c1
    target: "ভাত"
    native: "rice"
    modes: [recognition, reading]
'''),
        rejects(['unknown mode "reading"']),
      );
    });
  });
}
