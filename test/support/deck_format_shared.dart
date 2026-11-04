// Helpers and fixtures that more than one of the files split out of
// deck_format_test.dart use, moved here unchanged.

import 'dart:io';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';

// From deck_parser_test.dart.
Deck parse(String yaml) => DeckParser.parse(yaml, source: 'test.yaml');

const header = '''
schema: 1
id: test-deck
name: Test deck
language: {code: es, iso639_3: spa, name: Spanish, script: latin}
native: {code: en, iso639_3: eng, name: English}
license: CC0-1.0
''';

const oneCard = '''
  - id: test-0001
    target: la casa
    native: the house
''';

/// A valid vocab deck around [cards], with [extra] header lines.
String vocab({String cards = oneCard, String extra = ''}) =>
    '$header${extra}cards:\n$cards';

// From b1_format_test.dart.
const appendix = 'test/fixtures/b1/appendix-a/zz';
const features = 'test/fixtures/b1/features/zz';

String read(String path) => File(path).readAsStringSync();

/// A single-file Testlang deck taught from English, with [cards].
String single(String cards) => '''
schema: 1
id: "zz-en-probe"
name: "Probe"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC0-1.0"
cards:
$cards''';

/// One single-file card with [extra] fields, for the card checks.
String probeCard(String extra) => single('''
  - id: "zz-0001"
    target: "కలం"
    reading: "kalam"
    native: "pen"
$extra''');

Deck parseProbe(String yaml) =>
    DeckParser.parse(yaml, source: 'zz-en-probe.yaml');

final homeCore = read('$appendix/zz-home.yaml');
final homeLayer = read('$appendix/en/zz-en-home.yaml');
final words = read('$features/zz-en-words.yaml');

String coreWith(String data) =>
    homeCore.replaceFirst('    pos: "noun"\n', data);

String layerWith(String texts) => homeLayer.replaceFirst(
  '    wiktionary: true\n',
  '    wiktionary: true\n$texts',
);

Card merged(String data, String texts) => mergeLayer(
  DeckParser.parseCore(coreWith(data), source: 'zz.yaml'),
  DeckParser.parseLayer(layerWith(texts), source: 'en.yaml'),
  source: 'layer.yaml',
).cards.firstWhere((c) => c.id == 'zz-9001');

const readingHeader = '''
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
${readingHeader}passages:
  - id: p1
    title: "Lunch"
$extra    sentences:
$sentences    questions:
$questions''';
