import '../../app/deck_catalog.dart';

/// The id of [rtlFixtureDecks]'s one deck.
const String rtlFixtureDeckId = 'ur-fixture-rtl';

/// A small right-to-left deck, in memory, for the `drill-rtl` gallery entry
/// and the right-to-left tests.
///
/// No right-to-left deck ships yet: Urdu is #40's. This one is a fixture,
/// never bundled and never under `decks/`, and its ids say so. The words are
/// the design's own sample Urdu.
MemoryDeckSource rtlFixtureDecks() => MemoryDeckSource(const <String, String>{
  'fixtures/ur/ur-fixture-rtl.yaml': _yaml,
});

const String _yaml = '''
schema: 1
id: ur-fixture-rtl
name: Urdu (right-to-left fixture)
kind: vocab
language: { code: ur, iso639_3: urd, name: Urdu, script: arabic, rtl: true, tts: ur-PK }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [fixture]

cards:
  - id: ur-fixture-0001
    target: "کتاب"
    native: "book"
    reading: "kitaab"
  - id: ur-fixture-0002
    target: "گھر"
    native: "house"
    reading: "ghar"
    alt_native: ["home"]
  - id: ur-fixture-0003
    target: "ا"
    native: "alif"
    reading: "alif"
    notes: "Alif never joins the letter after it."
''';
