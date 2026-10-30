import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/synonym_sets.dart';

// Every word below is made up, so that no test depends on real English
// (AGENTS.md, "Tests check behaviour"). The function words (a, the, to, my,
// up, never, very) are the real ones the frame rules look at. The members of
// a set are far apart on purpose: the card's own typo pass must not be what
// accepts an answer.
const String _file = '''
# test sets
version: 1
sets:
  - ["florp", "quandle"]
  - ["glim", "snarkle"]
  - ["brontle", "zib"]
  - ["gribbet", "zab"]
  - ["mib", "trundle"]
  - ["thrim glo", "wexa pold"]
  - ["fennick", "vorn"]
  - ["pellum", "vorb"]
  - ["frobise", "frobize"]
  - ["om", "ux"]
''';

void main() {
  final sets = SynonymSets.parse(_file);
  final grader = AnswerGrader(meaning: true, synonyms: sets);

  GradedAnswer grade(
    String card,
    String typed, {
    List<String> alternates = const <String>[],
    Set<String> notSynonyms = const <String>{},
    AnswerGrader? using,
  }) => (using ?? grader).grade(
    typed,
    card,
    alternates: alternates,
    notSynonyms: notSynonyms,
  );

  void right(String card, String typed) {
    final graded = grade(card, typed);
    expect(graded.outcome, AnswerOutcome.exact, reason: '$typed for $card');
    expect(graded.viaSynonym, isTrue, reason: '$typed for $card');
    expect(graded.matched, card);
  }

  void wrong(String card, String typed) => expect(
    grade(card, typed).outcome,
    AnswerOutcome.wrong,
    reason: '$typed for $card',
  );

  group('a word of the same set', () {
    test('is right, flagged, and the card keeps its own answer', () {
      final graded = grade('Florp!', 'QUANDLE.');
      expect(graded.outcome, AnswerOutcome.exact);
      expect(graded.viaSynonym, isTrue);
      expect(graded.matched, 'Florp!');
      expect(graded.synonym, 'quandle');
    });

    test('is not needed when the card lists the word itself', () {
      final listed = grade('florp; quandle', 'quandle');
      expect(listed.outcome, AnswerOutcome.exact);
      expect(listed.viaSynonym, isFalse);
      final alternate = grade('florp', 'quandle', alternates: ['quandle']);
      expect(alternate.viaSynonym, isFalse);
    });

    test('is refused when the card says so, but a listed one still wins', () {
      expect(
        grade('glim', 'snarkle', notSynonyms: {'snarkle'}).outcome,
        AnswerOutcome.wrong,
      );
      final listed = grade(
        'glim',
        'snarkle',
        alternates: ['snarkle'],
        notSynonyms: {'snarkle'},
      );
      expect(listed.outcome, AnswerOutcome.exact);
      expect(listed.viaSynonym, isFalse);
    });

    test('drops a bracketed qualifier on the card', () {
      right('thrim glo (said to someone leaving)', 'wexa pold');
    });
  });

  group('the frame: a lead word, the core, nothing after', () {
    test('an article is free on either side, but a and the differ', () {
      right('glim', 'a snarkle');
      right('glim', 'an snarkle');
      right('the glim', 'snarkle');
      right('a glim', 'an snarkle');
      wrong('a glim', 'the snarkle');
    });

    test('"to" is free on a verb card only', () {
      right('to zib', 'to brontle');
      right('to zib', 'brontle');
      wrong('glim', 'to snarkle');
      wrong('to zib', 'a brontle');
    });

    test('a possessive must be on both sides, the same', () {
      right('my glim', 'my snarkle');
      wrong('my glim', 'your snarkle');
      wrong('my glim', 'snarkle');
    });

    test('nothing else is skipped: no trailing word, particle or "never"', () {
      wrong('to mib', 'to trundle up');
      wrong('to zib', 'never brontle');
      wrong('florp', 'very quandle');
      wrong('thrim glo', 'wexa pold about');
      wrong('it is a glim', 'it is a snarkle');
    });
  });

  group('endings', () {
    test('are found by rule and must be equal', () {
      right('glims', 'snarkles');
      wrong('glims', 'a snarkle');
      right('zibbed', 'brontled');
      right('frobised', 'frobized');
      wrong('frobising', 'frobizes');
    });

    test('are not guessed for an irregular form that no set lists', () {
      right('zab', 'gribbet');
      wrong('zab', 'brontled');
    });

    test('differ by -ll- and -l- only as one word, for listed lemmas', () {
      right('travelling', 'traveling');
      right('traveled', 'travelled');
      right('cancelled', 'canceled');
      right('labelling', 'labeling');
      right('counsellor', 'counselor');
    });

    test('a slip is not a regional spelling: it is a close typo', () {
      for (final (card, typed) in [
        ('telling', 'teling'),
        ('spelling', 'speling'),
        ('selling', 'seling'),
        ('yelling', 'yeling'),
        ('swelling', 'sweling'),
        ('dwelling', 'dweling'),
      ]) {
        final graded = grade(card, typed);
        expect(graded.outcome, AnswerOutcome.closeTypo, reason: typed);
        expect(graded.viaSynonym, isFalse, reason: typed);
      }
    });
  });

  group('a slip in a synonym', () {
    test('is a near miss with the member spelled right', () {
      final graded = grade('florp', 'quandl');
      expect(graded.outcome, AnswerOutcome.closeTypo);
      expect(graded.viaSynonym, isTrue);
      expect(graded.synonym, 'quandle');
      expect(graded.matched, 'florp');
    });

    test('is nothing under three letters', () {
      wrong('om', 'uxx');
    });

    test('is not made of a real word that is in another set', () {
      final both = grade('fennick', 'vorb');
      expect(both.outcome, AnswerOutcome.wrong);
      final alone = SynonymSets.parse('sets:\n  - ["fennick", "vorn"]\n');
      final slip = grade(
        'fennick',
        'vorb',
        using: AnswerGrader(meaning: true, synonyms: alone),
      );
      expect(slip.outcome, AnswerOutcome.closeTypo);
      expect(slip.viaSynonym, isTrue);
    });
  });

  group('the file', () {
    test('a malformed or empty one is no sets, and grading is as before', () {
      for (final text in <String>[
        'not a synonym file',
        'sets:\n  - ["a"]\n',
        'sets:\n  - [florp, quandle]\n',
        'sets:\n  - ["florp", "quandle"]\n  - ["quandle", "glim"]\n',
        'version: 2\nsets:\n  - ["florp", "quandle"]\n',
      ]) {
        final broken = AnswerGrader(
          meaning: true,
          synonyms: SynonymSets.tryParse(text),
        );
        expect(
          grade('florp', 'quandle', using: broken).outcome,
          AnswerOutcome.wrong,
          reason: text,
        );
      }
      expect(SynonymSets.tryParse(null).isEmpty, isTrue);
      expect(SynonymSets.tryParse('version: 1\nsets: []\n').isEmpty, isTrue);
    });

    test('each member accepts the others', () {
      final three = SynonymSets.parse('sets:\n  - ["a b", "c", "d"]\n');
      expect(three.equivalents('c'), {'a b', 'd'});
      expect(three.equivalents('e'), isEmpty);
    });

    test('the bundled one is readable', () {
      final text = File('assets/synonyms/en.yaml').readAsStringSync();
      expect(SynonymSets.parse(text), isA<SynonymSets>());
    });
  });
}
