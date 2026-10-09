import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/sounds_parser.dart';
import 'package:fluenough/core/models/sound_contrasts.dart';

/// Sound contrasts (#89, ADR-0015): which sound a wrong word heard differs
/// from the answer by, read from a language's sounds file.

const String bengali = '''
schema: 1
kind: sounds
id: bn-sounds
language: bn
contrasts:
  - id: aspiration
    name: "a breath after the consonant"
    pairs: [["ক", "খ"], ["ব", "ভ"]]
  - id: dental-retroflex
    name: "the tongue on the teeth or curled back"
    pairs: [["দ", "ড"]]
  - id: inherent-vowel
    name: "the open o against a"
    within_word: true
    pairs: [["", "া"]]
  - id: nasal
    name: "a vowel said through the nose"
    pairs: [["", "ঁ"]]
''';

void main() {
  final sounds = parseSounds(bengali, source: 'bn-sounds.yaml');
  String? between(String heard, String expected) =>
      sounds.between(heard, expected)?.id;

  group('a word heard instead of the answer', () {
    test('one swapped letter names its contrast, either way round', () {
      expect(between('খাল', 'কাল'), 'aspiration');
      expect(between('কাল', 'খাল'), 'aspiration');
      expect(between('বাত', 'ভাত'), 'aspiration');
      expect(between('ডান', 'দান'), 'dental-retroflex');
    });

    test('a sign added or taken away names its contrast', () {
      expect(between('জাল', 'জল'), 'inherent-vowel');
      expect(between('জল', 'জাল'), 'inherent-vowel');
      expect(between('বাঁধা', 'বাধা'), 'nasal');
      expect(between('বাধা', 'বাঁধা'), 'nasal');
    });

    test('within a word only: a vowel sign at the end adds a syllable', () {
      expect(between('কলা', 'কল'), isNull);
      expect(between('কল', 'কলা'), isNull);
      // The end of any word, not just the last.
      expect(between('আমি কলা খাই', 'আমি কল খাই'), isNull);
      // Swaps at the end still count; so does a nasal mark.
      expect(between('ভাব', 'ভাভ'), 'aspiration');
    });

    test('in a sentence, and with the full stop the recogniser leaves out', () {
      expect(between('আমি খাল যাব', 'আমি কাল যাব।'), 'aspiration');
    });

    test(
      'an e said for an o is not an a added: letters are compared whole',
      () {
        // Taken apart, ো is ে and া.
        expect(between('কোন', 'কেন'), isNull);
        expect(between('কেন', 'কোন'), isNull);
        expect(between('লোক', 'লেক'), isNull);
        expect(between('মোটা', 'মেটা'), isNull);
      },
    );

    test('a pair in the file matches however its letters are encoded', () {
      final split = parseSounds('''
schema: 1
kind: sounds
id: bn-sounds
language: bn
contrasts:
  - id: flap
    name: "the flapped r"
    pairs: [["\u09A1", "\u09A1\u09BC"]]
''', source: 'bn-sounds.yaml');
      // ড় precomposed in the words, taken apart in the file.
      expect(split.between('ব\u09DC', 'বড')?.id, 'flap');
      expect(split.between('ব\u09A1\u09BC', 'বড')?.id, 'flap');
    });

    test('nothing for the same word, two changes, or another word', () {
      expect(between('কাল', 'কাল।'), isNull);
      expect(between('খাড', 'কাল'), isNull, reason: 'two changes');
      expect(between('খাল', 'খালি'), isNull, reason: 'an added i');
      expect(between('মাছ', 'কাল'), isNull);
      expect(between('', 'কাল'), isNull);
    });
  });

  group('a sounds file', () {
    test('reads its contrasts in order, with their names', () {
      expect(sounds.language, 'bn');
      expect(sounds.contrasts.map((c) => c.id), <String>[
        'aspiration',
        'dental-retroflex',
        'inherent-vowel',
        'nasal',
      ]);
      expect(sounds.contrasts.first.name, 'a breath after the consonant');
      expect(sounds.contrasts[2].withinWord, isTrue);
      expect(sounds.contrasts.first.withinWord, isFalse);
    });

    test('a malformed one is refused, as the catalog reports it', () {
      for (final bad in <String>[
        bengali.replaceFirst('id: bn-sounds', 'id: bengali'),
        bengali.replaceFirst('[["দ", "ড"]]', '[["দ", "দ"]]'),
        bengali.replaceFirst('[["দ", "ড"]]', '[["", ""]]'),
        bengali.replaceFirst('within_word: true', 'within_word: 3'),
        bengali.replaceFirst('id: nasal', 'id: aspiration'),
        bengali.replaceFirst('schema: 1', 'schema: 2'),
        '$bengali\nextra: 1\n',
      ]) {
        expect(
          () => parseSounds(bad, source: 'bn-sounds.yaml'),
          throwsA(isA<DeckParseException>()),
        );
      }
    });

    test('the catalog keeps it by language, and a broken one as broken', () {
      final catalog = DeckCatalog.parseAll(<String, String>{
        'decks/bn/bn-sounds.yaml': bengali,
        'decks/hi/hi-sounds.yaml': 'schema: 1\nkind: sounds\nid: x\n',
      });
      expect(catalog.sounds.keys, <String>['bn']);
      expect(catalog.broken.single.path, 'decks/hi/hi-sounds.yaml');
    });
  });

  test('the bundled Bengali, Hindi and Telugu sounds files load', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final catalog = await DeckCatalog(RepositoryDeckSource()).load();
    expect(catalog.broken, isEmpty);
    expect(catalog.sounds.keys, containsAll(<String>['bn', 'hi', 'te']));
    final hindi = catalog.sounds['hi']!;
    String? hi(String heard, String expected) =>
        hindi.between(heard, expected)?.id;
    expect(hi('फल', 'पल'), 'aspiration');
    expect(hi('डाल', 'दाल'), 'dental-retroflex');
    expect(hi('दीन', 'दिन'), 'vowel-length');
    expect(hi('काम', 'कम'), 'vowel-length');
    expect(hi('पक्का', 'पका'), 'gemination');
    expect(hi('बच्चा', 'बचा'), 'gemination');
    expect(hi('हैं', 'है'), 'nasal');
    expect(hi('पढ़ना', 'पड़ना'), 'aspiration');
    expect(hi('सरक', 'सड़क'), 'flap');
    expect(hi('अच्छा', 'अछा'), 'gemination');
    final bengali = catalog.sounds['bn']!;
    expect(bengali.between('বর', 'বড়')?.id, 'flap');
    expect(bengali.between('পরা', 'পড়া')?.id, 'flap');
    expect(bengali.between('ঢ', 'ঢ়')?.id, 'flap');
    expect(bengali.between('কোন', 'কেন'), isNull);
    // ঢ় is not said like ড়: as with ঢ and ড, the tongue goes further in.
    expect(bengali.between('আষাড়', 'আষাঢ়')?.id, 'aspiration');
    final telugu = catalog.sounds['te']!;
    expect(telugu.between('పాలు', 'పలు')?.id, 'vowel-length');
    // Telugu says its final vowels, so a long one at the end counts.
    expect(telugu.between('అమ్మా', 'అమ్మ')?.id, 'vowel-length');
    expect(telugu.between('పాట', 'పాత')?.id, 'dental-retroflex');
    expect(telugu.between('కళ', 'కల')?.id, 'lateral');
    expect(telugu.between('అక్క', 'అక')?.id, 'gemination');
  });

  test('comparison ignores the final full stop and extra spaces', () {
    expect(normaliseForContrast(' আমি  কাল যাব। '), 'আমি কাল যাব');
  });
}
