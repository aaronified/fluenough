// A card's and an example's `words` (DECK-FORMAT.md, Base words; #661):
// Chinese and Japanese are written without spaces, so the deck gives the
// words of each target, and the app splits by them where it would split at
// spaces: the tiles put in order, whether a card is one word, how many
// words it has.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';

const _header = '''
schema: 1
id: test-deck
name: Test deck
language: { code: zh, iso639_3: cmn, name: Mandarin Chinese, script: han_simplified, scripts: [han_simplified, han_traditional] }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
''';

const _phrase = '''
  - id: zh-0011
    target: "我听不懂"
    target_scripts: { han_traditional: "我聽不懂" }
    words: ["我", "听不懂"]
    reading: "wǒ tīng bu dǒng"
    native: "I don't understand"
    pos: "phrase"
    examples:
      - target: "对不起，我听不懂。"
        words: ["对不起", "我", "听不懂"]
        native: "Sorry, I don't understand."
''';

Card _card(String yaml) =>
    DeckParser.parse('$_header$yaml', source: 'test.yaml').cards.single;

Matcher _fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

void main() {
  group('words (#661)', () {
    test('a card and its example keep their words', () {
      final card = _card(_phrase);
      expect(card.words, <String>['我', '听不懂']);
      expect(card.examples.single.words, <String>['对不起', '我', '听不懂']);
      expect(card.wordCount, 2);
    });

    test('a card without them has none, and is split at its spaces', () {
      final card = _card('''
  - id: zh-0001
    target: "你好"
    native: "hello"
''');
      expect(card.words, isNull);
      expect(card.wordCount, 1);
      expect(card.tilesOfSpelling('你好'), <String>['你好']);
    });

    test('a core card and its example carry them into the merged card', () {
      final core = DeckParser.parseCore('''
schema: 1
id: "zh-test"
part: "core"
kind: "vocab"
language: { code: "zh", iso639_3: "cmn", name: "Mandarin Chinese", script: "han_simplified" }
license: "CC-BY-SA-4.0"
cards:
  - id: "zh-0011"
    target: "我听不懂"
    words: ["我", "听不懂"]
    reading: "wǒ tīng bu dǒng"
    pos: "phrase"
    examples:
      - { target: "我听不懂。", words: ["我", "听不懂"] }
''', source: 'zh-test.yaml');
      final layer = DeckParser.parseLayer('''
schema: 1
id: "zh-en-test"
kind: "layer"
core: "zh-test"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Test"
license: "CC-BY-SA-4.0"
cards:
  "zh-0011":
    native: "I don't understand"
    examples: { "我听不懂。": "I don't understand." }
''', source: 'zh-en-test.yaml');
      final card = mergeLayer(core, layer, source: 'l.yaml').cards.single;
      expect(card.words, <String>['我', '听不懂']);
      expect(card.examples.single.words, <String>['我', '听不懂']);
    });

    test('an empty list or a list of other than text is refused', () {
      expect(
        () => _card(_phrase.replaceAll('["我", "听不懂"]', '[]')),
        _fails('words must not be empty'),
      );
      expect(
        () => _card(_phrase.replaceAll('["我", "听不懂"]', '"我听不懂"')),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('a phrase of two given words is put in order', () {
      final card = _card(_phrase);
      expect(card.rearranges, isTrue);
      expect(card.tilesOfSpelling('我听不懂'), <String>['我', '听不懂']);
      // Without its words it is one word, and typed instead.
      expect(
        _card(_phrase.replaceAll('    words: ["我", "听不懂"]\n', '')).rearranges,
        isFalse,
      );
    });

    test('the traditional spelling takes the words letter for letter', () {
      final card = _card(_phrase);
      expect(card.wordsOfSpelling('我聽不懂'), <String>['我', '聽不懂']);
      expect(card.tilesOfSpelling('我聽不懂'), <String>['我', '聽不懂']);
      // Another answer has no words of its own.
      expect(card.wordsOfSpelling('我不懂'), isNull);
    });

    test('a spelling of another length takes none', () {
      expect(carryWords(<String>['我', '听不懂'], from: '我听不懂', to: '我聽不'), isNull);
      expect(
        carryWords(<String>['ありがとう', 'ございます'], from: 'ありがとうございます', to: 'x'),
        isNull,
      );
    });

    test('a card of several given words is not one word', () {
      final card = _card(
        _phrase.replaceAll('    pos: "phrase"\n', '    pos: "other"\n'),
      );
      expect(countsAsWord(card, DeckKind.vocab), isFalse);
      final one = _card('''
  - id: zh-0101
    target: "我"
    words: ["我"]
    native: "I"
    pos: "pronoun"
''');
      expect(countsAsWord(one, DeckKind.vocab), isTrue);
    });
  });

  group('tilesOfWords (#661)', () {
    test('gives each word and each mark between them a tile', () {
      expect(tilesOfWords('多少钱？', <String>['多少', '钱']), <String>[
        '多少',
        '钱',
        '？',
      ]);
      expect(tilesOfWords('ありがとうございます', <String>['ありがとう', 'ございます']), <String>[
        'ありがとう',
        'ございます',
      ]);
      expect(tilesOfWords('对不起，我听不懂。', <String>['对不起', '我', '听不懂']), <String>[
        '对不起',
        '，',
        '我',
        '听不懂',
        '。',
      ]);
    });

    test('a word in a spaced text is lowercased, as tilesOf does', () {
      expect(tilesOfWords('¿Cómo estás?', <String>['Cómo', 'estás']), <String>[
        '¿',
        'cómo',
        'estás',
        '?',
      ]);
    });

    test('words that are not the text, in order, fall back to tilesOf', () {
      expect(tilesOfWords('多少钱？', <String>['多', '钱']), <String>['多少钱', '？']);
      expect(tilesOfWords('多少钱？', <String>['钱', '多少']), <String>['多少钱', '？']);
      expect(tilesOfWords('多少钱？', <String>['多少']), <String>['多少钱', '？']);
    });
  });
}
