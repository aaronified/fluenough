import '../../core/data/deck_parser.dart';

/// The error the `import-error` gallery entry shows: a real
/// [DeckParseException], raised by parsing a small deck with rule 2's
/// mistake in it, a bare `native: true`, which YAML reads as the
/// boolean true. (The design's own example, a bare `native: no`, is text
/// now that decks are read as YAML 1.2 reads them.)
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
    target: "ほんとう"
    native: true
    reading: "hontō"
''';
