import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/grammar_pattern.dart';

/// Mirrors `decks/es/es-grammar-present-ar.yaml`.
const presentAr = GrammarPattern(
  name: 'Present tense, regular -ar verbs',
  slotName: 'person',
  slots: ['yo', 'tú', 'él/ella', 'nosotros', 'vosotros', 'ellos'],
  prompt: '{lemma} ({gloss}) — {slot}',
  notes:
      'Drop -ar from the infinitive and add -o, -as, -a, -amos, -áis, -an. '
      'The vosotros form is used in Spain; Latin American Spanish uses '
      'ustedes with the ellos form.',
  entries: [
    PatternEntry(
      lemma: 'hablar',
      gloss: 'to speak',
      forms: {
        'yo': 'hablo',
        'tú': 'hablas',
        'él/ella': 'habla',
        'nosotros': 'hablamos',
        'vosotros': 'habláis',
        'ellos': 'hablan',
      },
    ),
    PatternEntry(
      lemma: 'trabajar',
      gloss: 'to work',
      forms: {
        'yo': 'trabajo',
        'tú': 'trabajas',
        'él/ella': 'trabaja',
        'nosotros': 'trabajamos',
        'vosotros': 'trabajáis',
        'ellos': 'trabajan',
      },
    ),
    PatternEntry(
      lemma: 'estudiar',
      gloss: 'to study',
      forms: {
        'yo': 'estudio',
        'tú': 'estudias',
        'él/ella': 'estudia',
        'nosotros': 'estudiamos',
        'vosotros': 'estudiáis',
        'ellos': 'estudian',
      },
    ),
    PatternEntry(
      lemma: 'comprar',
      gloss: 'to buy',
      forms: {
        'yo': 'compro',
        'tú': 'compras',
        'él/ella': 'compra',
        'nosotros': 'compramos',
        'vosotros': 'compráis',
        'ellos': 'compran',
      },
    ),
    PatternEntry(
      lemma: 'caminar',
      gloss: 'to walk',
      forms: {
        'yo': 'camino',
        'tú': 'caminas',
        'él/ella': 'camina',
        'nosotros': 'caminamos',
        'vosotros': 'camináis',
        'ellos': 'caminan',
      },
    ),
  ],
);

const spanish = LanguageInfo(code: 'es', name: 'Spanish', tts: 'es-ES');
const english = LanguageInfo(code: 'en', name: 'English');

void main() {
  group('GrammarPattern', () {
    test('holds the es-grammar-present-ar table', () {
      expect(presentAr.entries, hasLength(5));
      expect(presentAr.slots, hasLength(6));
      expect(presentAr.entries.map((e) => e.lemma), [
        'hablar',
        'trabajar',
        'estudiar',
        'comprar',
        'caminar',
      ]);
      for (final entry in presentAr.entries) {
        expect(entry.forms.keys, unorderedEquals(presentAr.slots));
      }
    });

    test('slots are positional, so an index names one slot', () {
      expect(presentAr.slots.indexOf('yo'), 0);
      expect(presentAr.slots.indexOf('nosotros'), 3);
      expect(presentAr.slots.indexOf('ellos'), 5);
    });

    test('permits a null cell for a defective form', () {
      const llover = PatternEntry(
        lemma: 'llover',
        gloss: 'to rain',
        forms: {
          'yo': null,
          'tú': null,
          'él/ella': 'llueve',
          'nosotros': null,
          'vosotros': null,
          'ellos': null,
        },
      );
      expect(llover.forms, containsPair('yo', isNull));
      expect(llover.forms['él/ella'], 'llueve');
      expect(llover.forms.keys, unorderedEquals(presentAr.slots));
    });

    test('notes is optional', () {
      const bare = GrammarPattern(
        name: 'n',
        slotName: 's',
        slots: ['a'],
        prompt: '{slot}',
        entries: [],
      );
      expect(bare.notes, isNull);
    });
  });

  group('Deck.pattern', () {
    test('is null on a vocab deck', () {
      const deck = Deck(
        id: 'es-core-100',
        name: 'Spanish Core 100',
        kind: DeckKind.vocab,
        language: spanish,
        native: english,
        license: 'CC0-1.0',
        cards: [],
      );
      expect(deck.pattern, isNull);
    });

    test('holds the table on an unexpanded grammar deck', () {
      const deck = Deck(
        id: 'es-grammar-present-ar',
        name: 'Spanish present tense, regular -ar verbs',
        kind: DeckKind.grammar,
        language: spanish,
        native: english,
        license: 'CC0-1.0',
        cards: [],
        pattern: presentAr,
      );
      expect(deck.pattern, same(presentAr));
      expect(deck.cards, isEmpty);
    });
  });
}
