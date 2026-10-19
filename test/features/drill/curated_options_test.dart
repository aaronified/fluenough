import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/drill/drill_session.dart';

/// A choice question's wrong options are the card's hand-picked confusables
/// that name cards of the course first, then the pool's.

const String core = '''
schema: 1
id: "zz-curated"
part: "core"
kind: "vocab"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
license: "CC-BY-SA-4.0"
cards:
  - id: "zz-8001"
    target: "ఇల్లు"
    reading: "illu"
    pos: "noun"
    confusables:
      - { id: "a", ref: "zz-8002" }
      - { id: "b", ref: "zz-8003" }
      - { id: "c", ref: "zz-8004" }
      - { id: "d", word: "ఇంటి", reading: "iṇṭi" }
  - id: "zz-8002"
    target: "అమ్మ"
    reading: "amma"
    pos: "noun"
  - id: "zz-8003"
    target: "నేను"
    reading: "nēnu"
    pos: "pronoun"
  - id: "zz-8004"
    target: "వెళ్ళు"
    reading: "veḷḷu"
    pos: "verb"
  - id: "zz-8005"
    target: "పిల్లి"
    reading: "pilli"
    pos: "noun"
  - id: "zz-8006"
    target: "కుక్క"
    reading: "kukka"
    pos: "noun"
''';

const String layer = '''
schema: 1
id: "zz-en-curated"
kind: "layer"
core: "zz-curated"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Curated"
license: "CC-BY-SA-4.0"
cards:
  "zz-8001":
    native: "house"
    confusables:
      "a": { why: "Not the mother." }
      "b": { why: "Not the I." }
      "c": { why: "Not the verb." }
      "d": { why: "The stem." }
  "zz-8002":
    native: "mother"
  "zz-8003":
    native: "I"
  "zz-8004":
    native: "to go"
  "zz-8005":
    native: "cat"
  "zz-8006":
    native: "dog"
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a card whose confusables name three cards is offered exactly those '
      'as wrong options', () async {
    final state = AppState.test(
      decks: MemoryDeckSource(const <String, String>{
        'decks/zz/zz-curated.yaml': core,
        'decks/zz/en/zz-en-curated.yaml': layer,
      }),
    );
    addTearDown(state.dispose);
    await state.load();
    final card = state
        .deckById('zz-en-curated')!
        .cards
        .firstWhere((c) => c.id == 'zz-8001');
    // The pool alone would also offer the cat and the dog.
    expect(state.choicePool(card, Ask.chooseMeaning), hasLength(5));
    for (var seed = 0; seed < 8; seed++) {
      final session = DrillSession(
        state: state,
        items: <SessionItem>[
          SessionItem(
            card: card,
            mode: DrillMode.recognition,
            state: null,
            ask: Ask.chooseMeaning,
          ),
        ],
        random: Random(seed),
      );
      addTearDown(session.dispose);
      expect(session.options, hasLength(DrillSession.optionCount));
      expect(
        session.options.map((c) => c.id),
        unorderedEquals(<String>['zz-8001', 'zz-8002', 'zz-8003', 'zz-8004']),
      );
    }
  });
}
