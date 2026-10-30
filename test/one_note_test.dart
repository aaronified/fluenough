// The one note the teach card and the answer reveal show (#421): one at a
// time, from the pool each screen has, never changed by a rebuild.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/features/drill/taught_details.dart';
import 'package:fluenough/features/drill/teach_card.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const String _deck = 'es-en-probe';

Future<AppState> _state() async {
  final state = AppState.test(
    decks: MemoryDeckSource(<String, String>{
      'decks/es/$_deck.yaml':
          '''
schema: 1
id: $_deck
name: "Probe"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: es-9004, target: "mesa", native: "table" }
''',
    }),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

CardNote _note(String id, NoteKind kind, String text, {String? ref}) =>
    CardNote(id: id, kind: kind, text: text, ref: ref);

const String _first = 'Zorp takes a soft ending.';
const String _second = 'Zorp is only said at dusk.';
const String _look = 'zorp is spelled with an s; zorb with a b.';

Card _card(List<CardNote> notes) => Card(
  id: 'es-9001',
  deckId: _deck,
  target: 'zorp',
  native: 'thing',
  notes: notes,
);

Card _two() => _card(<CardNote>[
  _note('a', NoteKind.usage, _first),
  _note('b', NoteKind.usage, _second),
]);

Widget _teach(AppState state, Card card) => Scaffold(
  body: TeachCard(
    card: card,
    language: state.deckById(_deck)!.language,
    reading: TaughtReading.first,
  ),
);

Widget _reveal(AppState state, Card card) => Scaffold(
  body: SingleChildScrollView(
    child: TaughtDetails(
      card: card,
      language: state.deckById(_deck)!.language,
      reading: TaughtReading.first,
    ),
  ),
);

int _shown(List<String> texts) =>
    <Finder>[for (final t in texts) find.text(t)]
        .where((f) => f.evaluate().isNotEmpty)
        .length;

void main() {
  testWidgets('the teach card shows one of two prose notes, then the answer '
      'reveal shows the other', (tester) async {
    usePhone(tester);
    final state = await _state();
    final card = _two();
    await pumpScreen(tester, _teach(state, card), state: state);
    expect(_shown(<String>[_first, _second]), 1);
    final onTeach = find.text(_first).evaluate().isNotEmpty ? _first : _second;

    await pumpScreen(tester, _reveal(state, card), state: state);
    expect(_shown(<String>[_first, _second]), 1);
    // The round holds each note once before any repeats.
    expect(find.text(onTeach), findsNothing);
  });

  testWidgets('the answer reveal shows a lookalike note, which the teach '
      'card leaves to its warning', (tester) async {
    usePhone(tester);
    final state = await _state();
    final card = _card(<CardNote>[
      _note('l', NoteKind.lookalike, _look, ref: 'es-9004'),
    ]);
    await pumpScreen(tester, _reveal(state, card), state: state);
    expect(find.text(_look), findsOneWidget);

    await pumpScreen(tester, _teach(state, card), state: state);
    expect(find.text(_look), findsNothing);
  });

  testWidgets('a card with only a pair note shows no note', (tester) async {
    usePhone(tester);
    final state = await _state();
    final card = _card(<CardNote>[
      _note('p', NoteKind.pair, 'Do not say zorb.', ref: 'es-9004'),
    ]);
    await pumpScreen(tester, _reveal(state, card), state: state);
    expect(find.text('Do not say zorb.'), findsNothing);
    await pumpScreen(tester, _teach(state, card), state: state);
    expect(find.text('Do not say zorb.'), findsNothing);
  });

  testWidgets('a rebuild does not pick another note', (tester) async {
    usePhone(tester);
    final state = await _state();
    final card = _two();
    final rebuilds = ValueNotifier<int>(0);
    addTearDown(rebuilds.dispose);
    await pumpScreen(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: rebuilds,
        builder: (context, _, _) => _reveal(state, card),
      ),
      state: state,
    );
    final before = find.text(_first).evaluate().isNotEmpty ? _first : _second;
    for (var i = 0; i < 5; i++) {
      rebuilds.value++;
      await tester.pump();
    }
    expect(find.text(before), findsOneWidget);
  });
}
