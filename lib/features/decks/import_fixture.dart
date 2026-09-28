import '../../core/data/deck_parser.dart';

/// The error the `import-error` gallery entry shows: a real
/// [DeckParseException], raised by parsing a small deck with the design's
/// own mistake in it, a bare `native: no`, which YAML reads as the boolean
/// false.
///
/// A fixture, never bundled and never under `decks/`; its ids say so. The
/// file is named after the design's example, `ja-kana.yaml`.
DeckParseException importErrorFixture() {
  try {
    DeckParser.parse(_brokenYaml, source: importErrorFixtureFile);
  } on DeckParseException catch (e) {
    return e;
  }
  throw StateError('the import-error fixture parsed; it must not');
}

/// The file name the fixture's error names.
const String importErrorFixtureFile = 'ja-kana.yaml';

const String _brokenYaml = '''
schema: 1
id: ja-kana-fixture
name: Japanese kana (import fixture)
kind: vocab
language: { code: ja, iso639_3: jpn, name: Japanese, script: kana, tts: ja-JP }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [fixture]

cards:
  - id: ja-kana-fixture-0001
    target: "の"
    native: no
    reading: "no"
''';
