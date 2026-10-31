import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/meaning_rules.dart';
import 'package:fluenough/core/grading/synonym_sets.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';

// `not_synonyms` (ADR-0050, #924): a card's refusal of listed words. Every
// English word below is made up, so that no test depends on real English.

const String _sets = '''
version: 1
sets:
  - ["florp", "quandle"]
''';

String _deck(String extra) => '''
schema: 1
id: "zz-en-probe"
name: "Probe"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC0-1.0"
cards:
  - id: "zz-0001"
    target: "కలం"
    reading: "kalam"
    native: "florp"
$extra''';

Deck _parse(String text) => DeckParser.parse(text, source: 'zz-en-probe.yaml');

const String _core = '''
schema: 1
id: "zz-probe"
part: "core"
kind: "vocab"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu" }
license: "CC0-1.0"
cards:
  - { id: "zz-0001", target: "కలం", reading: "kalam" }
''';

String _layer(String entry) => '''
schema: 1
id: "zz-en-probe"
kind: "layer"
core: "zz-probe"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Probe"
license: "CC0-1.0"
cards:
  "zz-0001":
    native: "florp"
$entry''';

void main() {
  /// What the drill does: the card's entries in comparison form go to the
  /// grader with the sets.
  GradedAnswer grade(Card card, String typed) =>
      AnswerGrader(meaning: true, synonyms: SynonymSets.parse(_sets)).grade(
        typed,
        card.native,
        alternates: card.altNative,
        notSynonyms: <String>{for (final t in card.notSynonyms) meaningKey(t)},
      );

  group('a single-file card', () {
    test('without the field, its synonym is accepted', () {
      final card = _parse(_deck('')).cards.single;
      expect(card.notSynonyms, isEmpty);
      final graded = grade(card, 'quandle');
      expect(graded.outcome, AnswerOutcome.exact);
      expect(graded.viaSynonym, isTrue);
    });

    test('a listed word is not accepted, though it is in the set', () {
      final card = _parse(_deck('    not_synonyms: ["quandle"]\n'))
          .cards
          .single;
      expect(card.notSynonyms, <String>['quandle']);
      expect(grade(card, 'quandle').outcome, AnswerOutcome.wrong);
      // Typed in another form, it is the same word.
      expect(grade(card, 'Quandle!').outcome, AnswerOutcome.wrong);
    });

    test('the card\'s own answers still win', () {
      final card = _parse(
        _deck(
          '    alt_native: ["glim"]\n    not_synonyms: ["quandle", "glim"]\n',
        ),
      ).cards.single;
      expect(grade(card, 'florp').outcome, AnswerOutcome.exact);
      final alt = grade(card, 'glim');
      expect(alt.outcome, AnswerOutcome.exact);
      expect(alt.viaSynonym, isFalse);
    });

    test('must be a list of text', () {
      expect(
        () => _parse(_deck('    not_synonyms: "quandle"\n')),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  group('a layer', () {
    test('an entry may carry it and the merged card has it', () {
      final deck = mergeLayer(
        DeckParser.parseCore(_core, source: 'zz-probe.yaml'),
        DeckParser.parseLayer(
          _layer('    not_synonyms: ["quandle"]\n'),
          source: 'zz-en-probe.yaml',
        ),
        source: 'zz-en-probe.yaml',
      );
      expect(deck.cards.single.notSynonyms, <String>['quandle']);
      expect(grade(deck.cards.single, 'quandle').outcome, AnswerOutcome.wrong);
    });

    test('the core never carries it: it belongs to a native language', () {
      expect(
        () => DeckParser.parseCore(
          _core.replaceFirst(
            'reading: "kalam" }',
            'reading: "kalam", not_synonyms: ["quandle"] }',
          ),
          source: 'zz-probe.yaml',
        ),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            contains('not_synonyms'),
          ),
        ),
      );
    });
  });
}
