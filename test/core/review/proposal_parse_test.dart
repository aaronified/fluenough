// Proposals in the decks (ADR-0038): the parser reads a card's `proposed`
// changes into [Deck.proposals], in a single-file deck, a core and a layer,
// and merges a core's and its layer's. Learners never see them, so one that
// cannot be read is left out rather than failing the deck.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/models/proposal.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';

// Written by tools/proposals.py, whose ids are the facts' hash.
const _target =
    '- { id: "84bab583fa", field: "target", now: "అమ్మ", text: "అమ్మా", '
    'by: "FL-7K3M-Q9TD-6", date: "2026-10-09" }';
const _native =
    '- { id: "aa4d82e8b2", field: "native", now: "mother", text: "mum", '
    'by: "FL-0000-0000-0", date: "2026-10-09", why: "Less formal.", '
    'accepted: ["FL-7K3M-Q9TD-6"] }';
const _single =
    '- { id: "5be6983aba", field: "native", now: "pen", text: "a pen", '
    'by: "FL-7K3M-Q9TD-6", date: "2026-10-09" }';

String single(String extra) =>
    '''
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
    native: "pen"
$extra  - id: "zz-0002"
    target: "కాలం"
    reading: "kālam"
    native: "time"
''';

void main() {
  test('a single-file card carries its proposals', () {
    final deck = DeckParser.parse(
      single('    proposed:\n      $_single\n'),
      source: 'zz-en-probe.yaml',
    );
    expect(deck.cards, hasLength(2));
    final found = deck.proposals['zz-0001']!.single;
    expect(found.id, '5be6983aba');
    expect(found.card, 'zz-0001');
    expect(found.field, ProposalField.native);
    expect(found.now, 'pen');
    expect(found.text, 'a pen');
    expect(found.by, 'FL-7K3M-Q9TD-6');
    expect(found.date, '2026-10-09');
    expect(found.why, '');
    expect(found.accepted, isEmpty);
    expect(deck.proposals.containsKey('zz-0002'), isFalse);
    // A learner's card is the same with or without them.
    expect(deck.cards.first.native, 'pen');
  });

  test('a deck without proposals has none', () {
    final deck = DeckParser.parse(single(''), source: 'zz-en-probe.yaml');
    expect(deck.proposals, isEmpty);
  });

  test('one that cannot be read is left out, not the deck', () {
    final deck = DeckParser.parse(
      single(
        '    proposed:\n'
        '      - { id: "0123456789", field: "pos", now: "", text: "noun", '
        'by: "x", date: "2026-10-09" }\n'
        '      - { id: "0123456789", field: "native" }\n'
        '      $_single\n',
      ),
      source: 'zz-en-probe.yaml',
    );
    expect(deck.proposals['zz-0001']!.map((p) => p.id), <String>['5be6983aba']);
  });

  test('a core and its layer: merged, each card has both', () {
    final core = File('$appendix/zz-home.yaml').readAsStringSync().replaceFirst(
      '      - { id: "address", kind: "usage" }\n',
      '      - { id: "address", kind: "usage" }\n'
          '    proposed:\n      $_target\n',
    );
    final layer = File('$appendix/en/zz-en-home.yaml')
        .readAsStringSync()
        .replaceFirst(
          '    native: "mother"\n',
          '    native: "mother"\n    proposed:\n      $_native\n',
        );
    final deck = mergeLayer(
      DeckParser.parseCore(core, source: 'zz-home.yaml'),
      DeckParser.parseLayer(layer, source: 'zz-en-home.yaml'),
      source: 'zz-en-home.yaml',
    );
    final both = deck.proposals['zz-9004']!;
    expect(both.map((p) => p.field), <ProposalField>[
      ProposalField.target,
      ProposalField.native,
    ]);
    expect(both.last.why, 'Less formal.');
    expect(both.last.accepted, <String>['FL-7K3M-Q9TD-6']);
    // Resolving refs or expanding keeps them.
    expect(deck.withCards(deck.cards).proposals, same(deck.proposals));
  });

  test('the index says how many a file holds', () {
    final index = DeckIndex.parse('''
{"version": 1, "schema": 1, "bundled": [], "languages": [
  {"code": "zz", "name": "Testlang", "natives": [], "files": [
    {"path": "decks/zz/zz-en-probe.yaml", "size": 1, "sha256": "${'0' * 64}", "schema": 1, "kind": "vocab", "proposed": 2},
    {"path": "decks/zz/zz-en-other.yaml", "size": 1, "sha256": "${'0' * 64}", "schema": 1, "kind": "vocab"}
  ]}
]}''');
    final files = index.languages.single.files;
    expect(files.first.proposed, 2);
    expect(files.first.toJson()['proposed'], 2);
    expect(files.last.proposed, 0);
    expect(files.last.toJson().containsKey('proposed'), isFalse);
  });
}
