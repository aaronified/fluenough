// Who checked a card (#449): the parser reads each card entry's
// `checked_by` into [Deck.checkedBy], in a single-file deck, a core and a
// layer, and a merged deck takes its layer's, the core's only for a card
// the layer gives nothing for. Read leniently, as proposals are.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';
const alice = 'FL-7K3M-Q9TD-6';
const bob = 'FL-0000-0000-0';

String single(String first, {String second = ''}) =>
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
$first  - { id: "zz-0002", target: "కాలం", reading: "kālam", native: "time"$second }
''';

void main() {
  test('a block card and a flow card carry their codes', () {
    final deck = DeckParser.parse(
      single(
        '    checked_by: ["$alice", "$bob"]\n',
        second: ', checked_by: ["$bob"]',
      ),
      source: 'zz-en-probe.yaml',
    );
    expect(deck.checkedBy['zz-0001'], <String>[alice, bob]);
    expect(deck.checkedBy['zz-0002'], <String>[bob]);
    // A learner's card is the same with or without them.
    expect(deck.cards.first.native, 'pen');
    expect(deck.withCards(deck.cards).checkedBy, same(deck.checkedBy));
  });

  test('a deck no one has checked has none', () {
    final deck = DeckParser.parse(single(''), source: 'zz-en-probe.yaml');
    expect(deck.checkedBy, isEmpty);
  });

  test('what is not text is left out, not the deck', () {
    final deck = DeckParser.parse(
      single('    checked_by: [7, "$alice"]\n', second: ', checked_by: []'),
      source: 'zz-en-probe.yaml',
    );
    expect(deck.checkedBy['zz-0001'], <String>[alice]);
    expect(deck.checkedBy.containsKey('zz-0002'), isFalse);
  });

  test('merged, a card takes its layer\'s codes, the core\'s only where the '
      'layer gives it nothing', () {
    final core = File('$appendix/zz-home.yaml')
        .readAsStringSync()
        .replaceFirst(
          '      - { id: "address", kind: "usage" }\n',
          '      - { id: "address", kind: "usage" }\n'
              '    checked_by: ["$alice", "$bob"]\n',
        )
        .replaceFirst(
          'phrasebook: true }',
          'phrasebook: true, checked_by: ["$bob"] }',
        )
        .replaceFirst(
          '      - { word: "వెళ్తాను", ref: "zz-9003" }\n',
          '      - { word: "వెళ్తాను", ref: "zz-9003" }\n'
              '    checked_by: ["$bob"]\n',
        );
    final layer = File('$appendix/en/zz-en-home.yaml')
        .readAsStringSync()
        .replaceFirst(
          '    native: "mother"\n',
          '    native: "mother"\n    checked_by: ["$alice"]\n',
        )
        .replaceFirst('  "zz-9002":\n    native: "I will go home."\n', '');
    final deck = mergeLayer(
      DeckParser.parseCore(core, source: 'zz-home.yaml'),
      DeckParser.parseLayer(layer, source: 'zz-en-home.yaml'),
      source: 'zz-en-home.yaml',
    );
    // Bob checked the word through another layer, not this meaning.
    expect(deck.checkedBy['zz-9004'], <String>[alice]);
    // The layer gives zz-9101 a meaning but no codes: not checked here.
    expect(deck.checkedBy.containsKey('zz-9101'), isFalse);
    // The layer has no entry for zz-9002: the core's codes stand.
    expect(deck.checkedBy['zz-9002'], <String>[bob]);
  });
}
