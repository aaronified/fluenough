// The IPA course's format (ADR-0041): an example's language and whether the
// letter sounds as the card says, and a language block that is not typed.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/deck_parser.dart';

String deck(String examples, {String language = _ipa}) =>
    '''
schema: 1
id: "ipa-en-probe"
name: "Probe"
language: $language
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC0-1.0"
cards:
  - id: "ipa-0001"
    target: "ɒ"
    native: "the vowel of hot"
$examples''';

const _ipa =
    '{ code: "ipa", iso639_3: "zxx", name: "IPA", script: "ipa", '
    'typed: false, icon: "ə" }';

const _examples = '''
    examples:
      - { target: "hot", native: "hot", language: en, ipa: "hɒt" }
      - { target: "go", native: "go", language: en, sounds: false, ipa: "ɡəʊ" }
      - { target: "కాలం", native: "time", sounds: true }
''';

Matcher fails(String why) => throwsA(
  isA<DeckParseException>().having((e) => e.message, 'message', contains(why)),
);

void main() {
  test('an example keeps its language, and sounds is true unless said', () {
    final parsed = DeckParser.parse(deck(_examples), source: 'p.yaml');
    final ex = parsed.cards.single.examples;
    expect(ex.map((e) => e.language), ['en', 'en', null]);
    expect(ex.map((e) => e.sounds), [true, false, true]);
  });

  test('the IPA language block is typed: false, with no reading needed', () {
    final parsed = DeckParser.parse(deck(_examples), source: 'p.yaml');
    expect(parsed.language.typed, isFalse);
    expect(parsed.language.needsReading, isFalse);
    expect(parsed.language.script, 'ipa');
  });

  test('a language is typed unless it says otherwise', () {
    final parsed = DeckParser.parse(
      deck(
        _examples,
        language:
            '{ code: "ipa", iso639_3: "zxx", name: "IPA", script: "ipa" }',
      ),
      source: 'p.yaml',
    );
    expect(parsed.language.typed, isTrue);
  });

  test('sounds must be a boolean', () {
    expect(
      () => DeckParser.parse(
        deck(
          '    examples:\n'
          '      - { target: "hot", native: "hot", sounds: "no" }\n',
        ),
        source: 'p.yaml',
      ),
      throwsA(isA<DeckParseException>()),
    );
  });

  test('language must be a language code', () {
    expect(
      () => DeckParser.parse(
        deck(
          '    examples:\n'
          '      - { target: "hot", native: "hot", language: "English" }\n',
        ),
        source: 'p.yaml',
      ),
      fails('language code'),
    );
  });
}
