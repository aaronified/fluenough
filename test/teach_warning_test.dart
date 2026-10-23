// The one warning a word's teach card shows (#691; owner, 2026-10-23: "Deck
// field picks it"): the card's `warning`, or without it the fixed order.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/features/decks/card_blocks.dart';
import 'package:fluenough/features/drill/taught_details.dart'
    show TaughtReading;
import 'package:fluenough/features/drill/teach_card.dart';
import 'package:fluenough/features/review/alike_warning.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const String _deck = 'es-en-probe';

/// "gatu" is a rude word, "gata" and "casa" are plain ones.
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
  - { id: es-9002, target: "gatu", native: "a rude word", tags: ["offensive"] }
  - { id: es-9003, target: "gata", native: "she-cat" }
  - { id: es-9004, target: "casa", native: "house" }
''',
    }),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

CardNote _note(String id, NoteKind kind, String ref) =>
    CardNote(id: id, kind: kind, text: '', ref: ref);

/// "gato", which sounds like a rude word and a plain one, is spelt like
/// another, and has another meaning.
Card _gato({String? warning, bool rude = true}) => Card(
  id: 'es-9001',
  deckId: _deck,
  target: 'gato',
  native: 'cat',
  altNative: const <String>['kitty'],
  warning: warning,
  notes: <CardNote>[
    _note('plain', NoteKind.pair, 'es-9003'),
    if (rude) _note('rude', NoteKind.pair, 'es-9002'),
    _note('same', NoteKind.homograph, 'es-9004'),
  ],
);

void main() {
  group('teachWarningOf', () {
    test('without the key the fixed order holds: a rude word it is like '
        'comes first, and nothing else', () async {
      final state = await _state();
      final shown = teachWarningOf(state, _gato());
      expect(shown.rude.map((r) => r.partner.id), <String>['es-9002']);
      expect(shown.similar, isNull);
    });

    test('without the key and without a rude word, the word it sounds like '
        'comes before the one it looks like', () async {
      final state = await _state();
      final shown = teachWarningOf(state, _gato(rude: false));
      expect(shown.rude, isEmpty);
      expect(shown.similar?.kind, SimilarKind.sound);
      expect(shown.similar?.partner?.id, 'es-9003');
    });

    test('a note id names the sound-alike, ahead of the rude word', () async {
      final state = await _state();
      final shown = teachWarningOf(state, _gato(warning: 'plain'));
      expect(shown.rude, isEmpty);
      expect(shown.similar?.kind, SimilarKind.sound);
      expect(shown.similar?.partner?.id, 'es-9003');
    });

    test('the id of the rude pair shows the rude warning alone', () async {
      final state = await _state();
      final shown = teachWarningOf(state, _gato(warning: 'rude'));
      expect(shown.rude.map((r) => r.partner.id), <String>['es-9002']);
      expect(shown.similar, isNull);
    });

    test('the id of a homograph shows the word it looks like', () async {
      final state = await _state();
      final shown = teachWarningOf(state, _gato(warning: 'same'));
      expect(shown.rude, isEmpty);
      expect(shown.similar?.kind, SimilarKind.look);
      expect(shown.similar?.partner?.id, 'es-9004');
    });

    test('a note with no id is named by its place', () async {
      final state = await _state();
      final card = Card(
        id: 'es-9001',
        deckId: _deck,
        target: 'gato',
        native: 'cat',
        warning: '2',
        notes: <CardNote>[
          _note('1', NoteKind.pair, 'es-9003'),
          _note('2', NoteKind.homograph, 'es-9004'),
        ],
      );
      expect(teachWarningOf(state, card).similar?.partner?.id, 'es-9004');
    });

    test('"senses" shows its other meanings, ahead of every note', () async {
      final state = await _state();
      final shown = teachWarningOf(state, _gato(warning: 'senses'));
      expect(shown.rude, isEmpty);
      expect(shown.similar?.kind, SimilarKind.meanings);
      expect(shown.similar?.meanings, <String>['kitty']);
    });

    test('"none" shows nothing, whatever the card is like', () async {
      final state = await _state();
      final shown = teachWarningOf(state, _gato(warning: 'none'));
      expect(shown.rude, isEmpty);
      expect(shown.similar, isNull);
    });

    test('a name that is no note of the card, or no warning, shows '
        'nothing', () async {
      final state = await _state();
      for (final name in <String>['nowhere', 'usage', 'senses ']) {
        final card = _gato(warning: name);
        final shown = teachWarningOf(state, card);
        expect(shown.rude, isEmpty, reason: name);
        expect(shown.similar, isNull, reason: name);
      }
    });
  });

  group('the teach card', () {
    Future<void> pump(WidgetTester tester, Card card) async {
      usePhone(tester);
      final state = await _state();
      await pumpScreen(
        tester,
        Scaffold(
          body: TeachCard(
            card: card,
            language: state.deckById(_deck)!.language,
            reading: TaughtReading.first,
          ),
        ),
        state: state,
      );
    }

    Finder similar(SimilarKind kind) => find.byWidgetPredicate(
      (w) => w is SimilarBlock && w.similar.kind == kind,
    );

    testWidgets('shows the warning the card names, and only that', (
      tester,
    ) async {
      await pump(tester, _gato(warning: 'senses'));
      expect(similar(SimilarKind.meanings), findsOneWidget);
      expect(similar(SimilarKind.sound), findsNothing);
      expect(find.byType(AlikeWarning), findsNothing);
    });

    testWidgets('without the key shows the rude word, as it always has', (
      tester,
    ) async {
      await pump(tester, _gato());
      expect(find.byType(AlikeWarning), findsOneWidget);
      expect(find.byType(SimilarBlock), findsNothing);
    });

    testWidgets('"none" shows no warning', (tester) async {
      await pump(tester, _gato(warning: 'none'));
      expect(find.byType(AlikeWarning), findsNothing);
      expect(find.byType(SimilarBlock), findsNothing);
    });
  });
}
