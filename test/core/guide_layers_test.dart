import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/guide_layers.dart';
import 'package:fluenough/core/models/script_guide.dart';
import 'package:flutter_test/flutter_test.dart';

// A script guide and a sounds file split into a core and an English layer
// (#498, DECK-FORMAT.md, Script guides and Sounds files).
const scriptCore = '''
schema: 1
kind: "script"
part: "core"
id: "bn-script"
language: "bn"
features:
  - id: "headline"
    term: "মাত্রা"
    reading: "mātrā"
    example: "ক"
    letters: ["ক", "খ"]
  - id: "knot"
    example: "ত"
''';

const scriptLayer = '''
schema: 1
id: "bn-en-script"
kind: "layer"
core: "bn-script"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "How Bengali script works"
intro: "A few ideas come back in letter after letter."
features:
  "headline":
    name: "The headline"
    text: "Most letters hang from a line along the top."
  "knot":
    name: "The knot"
    text: "A small loop that tells letters apart."
''';

const soundsCore = '''
schema: 1
kind: "sounds"
part: "core"
id: "bn-sounds"
language: "bn"
contrasts:
  - id: "aspiration"
    pairs: [["ক", "খ"]]
  - id: "inherent-vowel"
    within_word: true
    pairs: [["", "া"]]
''';

const soundsLayer = '''
schema: 1
id: "bn-en-sounds"
kind: "layer"
core: "bn-sounds"
native: { code: "en", iso639_3: "eng", name: "English" }
contrasts:
  "aspiration": "a breath after the consonant"
  "inherent-vowel": "the open o against a"
''';

const sylhetiCore = '''
schema: 1
kind: "script"
part: "core"
id: "bn-sylheti-script"
language: "bn"
features:
  - id: "slope"
    example: "ꠍ"
    letters: ["ꠍ"]
''';

const sylhetiLayer = '''
schema: 1
id: "bn-en-sylheti-script"
kind: "layer"
core: "bn-sylheti-script"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "How Sylheti script works"
intro: "A few ideas of its own."
features:
  "slope":
    name: "The slope"
    text: "Words lean to one side."
''';

void main() {
  Map<String, String> files({String script = scriptLayer}) => {
    'decks/bn/bn-script.yaml': scriptCore,
    'decks/bn/en/bn-en-script.yaml': script,
    'decks/bn/bn-sounds.yaml': soundsCore,
    'decks/bn/en/bn-en-sounds.yaml': soundsLayer,
  };

  test('the catalog merges a guide core with its layer', () {
    final catalog = DeckCatalog.parseAll(files());
    expect(catalog.broken, isEmpty, reason: '${catalog.broken}');
    expect(catalog.decks, isEmpty);
    final guide = catalog.scriptGuides['bn']!;
    expect(guide.name, 'How Bengali script works');
    expect(guide.features.map((f) => f.id), ['headline', 'knot']);
    expect(guide.features.first.name, 'The headline');
    expect(guide.features.first.term, 'মাত্রা');
    expect(guide.features.first.letters, ['ক', 'খ']);
    expect(guide.features.last.text, 'A small loop that tells letters apart.');
    final sounds = catalog.sounds['bn']!;
    expect(sounds.contrasts.map((c) => c.name), [
      'a breath after the consonant',
      'the open o against a',
    ]);
    expect(sounds.contrasts.last.withinWord, isTrue);
    expect(sounds.between('খ', 'ক')?.id, 'aspiration');
  });

  test('each file checks on its own', () {
    for (final MapEntry(:key, :value) in files().entries) {
      expect(DeckCatalog.checkFile(key, value), isNull, reason: key);
    }
  });

  test('a layer that leaves out a feature, or names another, is broken', () {
    for (final bad in [
      scriptLayer.replaceFirst('  "knot":\n', '  "loop":\n'),
      scriptLayer.substring(0, scriptLayer.indexOf('  "knot":')),
    ]) {
      final catalog = DeckCatalog.parseAll(files(script: bad));
      expect(catalog.scriptGuides, isEmpty);
      expect(catalog.broken.single.path, 'decks/bn/en/bn-en-script.yaml');
    }
  });

  test('a core gives no text, and a layer no letters', () {
    expect(
      DeckCatalog.checkFile(
        'decks/bn/bn-script.yaml',
        scriptCore.replaceFirst('features:', 'name: "x"\nfeatures:'),
      ),
      isNotNull,
    );
    expect(
      () => parseGuideLayer(
        scriptLayer.replaceFirst(
          '    name: "The knot"',
          '    name: "The knot"\n    example: "ত"',
        ),
        source: 'bn-en-script.yaml',
      ),
      throwsA(isA<DeckParseException>()),
    );
    expect(
      () => parseGuideLayer(
        soundsLayer.replaceFirst('id: "bn-en-sounds"', 'id: "bn-sounds-en"'),
        source: 'bn-en-sounds.yaml',
      ),
      throwsA(isA<DeckParseException>()),
    );
  });

  test('a layer without its core is broken', () {
    final catalog = DeckCatalog.parseAll({
      'decks/bn/en/bn-en-script.yaml': scriptLayer,
    });
    expect(catalog.scriptGuides, isEmpty);
    expect(catalog.broken.single.path, 'decks/bn/en/bn-en-script.yaml');
  });

  Map<String, String> withSylheti() => {
    ...files(),
    'decks/bn/bn-sylheti-script.yaml': sylhetiCore,
    'decks/bn/en/bn-en-sylheti-script.yaml': sylhetiLayer,
  };

  test('a language has a guide for each of its scripts', () {
    final catalog = DeckCatalog.parseAll(withSylheti());
    expect(catalog.broken, isEmpty, reason: '${catalog.broken}');
    expect(catalog.scriptGuides.keys, unorderedEquals(['bn', 'bn-sylheti']));
    final guide = catalog.scriptGuides['bn-sylheti']!;
    expect(guide.language, 'bn');
    expect(guide.script, 'sylheti');
    expect(guide.name, 'How Sylheti script works');
    expect(catalog.scriptGuides['bn']!.script, isNull);
    expect(catalog.scriptGuides['bn']!.name, 'How Bengali script works');
  });

  test("a deck's guide is its own script's, else the language's", () {
    final catalog = DeckCatalog.parseAll(withSylheti());
    expect(catalog.scriptGuideFor('bn', 'sylheti')?.key, 'bn-sylheti');
    expect(catalog.scriptGuideFor('bn', 'bengali')?.key, 'bn');
    expect(catalog.scriptGuideFor('hi', 'devanagari'), isNull);
    final only = DeckCatalog.parseAll({
      'decks/bn/bn-sylheti-script.yaml': sylhetiCore,
      'decks/bn/en/bn-en-sylheti-script.yaml': sylhetiLayer,
    });
    expect(only.scriptGuideFor('bn', 'bengali'), isNull);
    expect(only.scriptGuideFor('bn', 'sylheti')?.key, 'bn-sylheti');
  });

  test('a script is hyphenated in its guide key', () {
    expect(scriptGuideKey('hi', 'perso_arabic'), 'hi-perso-arabic');
    expect(scriptGuideKey('hi', null), 'hi');
  });

  test("a guide's id is its language and one script", () {
    for (final id in ['bn-sylheti', 'bn-script-sylheti']) {
      expect(
        DeckCatalog.checkFile(
          'decks/bn/$id.yaml',
          sylhetiCore.replaceFirst('bn-sylheti-script', id),
        ),
        isNotNull,
        reason: id,
      );
    }
    for (final MapEntry(:key, :value) in withSylheti().entries) {
      expect(DeckCatalog.checkFile(key, value), isNull, reason: key);
    }
  });

  test("a layer's id follows its core's", () {
    final catalog = DeckCatalog.parseAll({
      'decks/bn/bn-sylheti-script.yaml': sylhetiCore,
      'decks/bn/en/bn-en-script.yaml': sylhetiLayer.replaceFirst(
        'bn-en-sylheti-script',
        'bn-en-script',
      ),
    });
    expect(catalog.scriptGuides, isEmpty);
    expect(catalog.broken.single.path, 'decks/bn/en/bn-en-script.yaml');
  });

  test('only a script or sounds core is a guide core', () {
    expect(isGuideCoreId('hi-script'), isTrue);
    expect(isGuideCoreId('hi-sounds'), isTrue);
    expect(isGuideCoreId('hi-perso-arabic-script'), isTrue);
    expect(isGuideCoreId('hi-script-vowels'), isFalse);
    expect(isGuideCoreId('hi-script-perso-arabic-letters'), isFalse);
    expect(isGuideCoreId('hi-perso-arabic-sounds'), isFalse);
    expect(isGuideCoreId('hi-home'), isFalse);
  });
}
