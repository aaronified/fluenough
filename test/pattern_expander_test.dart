import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/pattern_expander.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/drill/grammar_cells.dart';

void main() {
  final bundled = DeckParser.parse(
    File('decks/es/es-grammar-present-ar.yaml').readAsStringSync(),
    source: 'es-grammar-present-ar.yaml',
  );

  test('the bundled -ar deck expands to 30 cards, 5 lemmas by 6 slots', () {
    final cards = expandPattern(bundled);
    expect(cards, hasLength(30));
    expect(cards.first.id, 'es-grammar-present-ar-hablar-0');
    expect(cards.first.target, 'hablo');
    expect(cards.first.native, 'hablar (to speak) — yo');
    expect(cards[4].id, 'es-grammar-present-ar-hablar-4');
    expect(cards[4].target, 'habláis');
  });

  test('ids follow the documented scheme and are stable across runs', () {
    final first = [for (final c in expandPattern(bundled)) c.id];
    final again = [for (final c in expandPattern(bundled)) c.id];
    expect(again, first);
    expect(first.toSet(), hasLength(first.length), reason: 'unique');
    for (final id in first) {
      expect(id, matches(RegExp(r'^es-grammar-present-ar-[a-z]+-[0-5]$')));
    }
  });

  test('grammar only, and the notes shown after answering', () {
    for (final card in expandPattern(bundled)) {
      expect(card.modes, {DrillMode.grammar});
      expect(card.modesIn(ttsAvailable: true), {DrillMode.grammar});
      expect(card.notes, bundled.pattern!.notes);
      expect(card.deckId, bundled.id);
    }
  });

  test('a null form is skipped, and its slot keeps its index', () {
    final deck = DeckParser.parse('''
schema: 1
id: es-en-grammar-probe
name: Probe
kind: grammar
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: P
  slot_name: person
  slots: [yo, tú, él]
  prompt: "{slot} of {lemma}, {gloss}"
  entries:
    - lemma: soler
      gloss: to tend to
      forms: { yo: suelo, tú: null, él: suele }
''', source: 'probe');
    final cards = expandPattern(deck);
    expect(cards.map((c) => c.id), [
      'es-en-grammar-probe-soler-0',
      'es-en-grammar-probe-soler-2',
    ]);
    expect(cards.last.native, 'él of soler, to tend to');
  });

  test('a deck without a pattern has no cards to expand', () {
    final vocab = DeckParser.parse(
      File('decks/es/es-core-100.yaml').readAsStringSync(),
      source: 'es-core-100.yaml',
    );
    expect(expandPattern(vocab), isEmpty);
  });

  test('a key stands in for a lemma that cannot go into an id', () {
    final deck = DeckParser.parse('''
schema: 1
id: hi-en-grammar-probe
name: Probe
kind: grammar
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
pattern:
  name: P
  slot_name: person
  slots: ["मैं (m)", "मैं (f)"]
  prompt: "{lemma} ({gloss}) — {slot}"
  entries:
    - lemma: "जाना"
      key: jaanaa
      gloss: to go
      forms: { "मैं (m)": "गया", "मैं (f)": "गई" }
''', source: 'probe.yaml');
    final cards = expandPattern(deck);
    expect(cards.map((c) => c.id), [
      'hi-en-grammar-probe-jaanaa-0',
      'hi-en-grammar-probe-jaanaa-1',
    ]);
    expect(cards.first.native, 'जाना (to go) — मैं (m)');
    expect(cards.last.target, 'गई');

    // The drill finds each card's cell by the same id.
    final cell = grammarCellOf(cards.last, deck.withCards(cards))!;
    expect(cell.entry.lemma, 'जाना');
    expect(cell.slot, 'मैं (f)');
  });
}
