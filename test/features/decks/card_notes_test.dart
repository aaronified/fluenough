import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/features/decks/card_notes.dart';
import 'package:fluenough/features/decks/inspect_page.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/drill/taught_details.dart';
import 'package:fluenough/features/review/alike_warning.dart';
import 'package:fluenough/features/review/review_words.dart';

import '../../support/harness.dart';

/// The notes a card's face shows, and its pairs, now that the B1 format
/// makes a card's notes a list of typed notes and pair notes the source of
/// pairs (ADR-0036). Test-only card ids, in a range no deck uses (AGENTS.md
/// rule 1).

Card _card({String? pair, List<CardNote> notes = const <CardNote>[]}) => Card(
  id: 'zz-9001',
  deckId: 'zz-en-test',
  target: 'a',
  native: 'a',
  pair: pair,
  notes: notes,
);

CardNote _note(
  NoteKind kind,
  String text, {
  String id = '1',
  String? ref,
  List<String> regions = const <String>[],
}) => CardNote(id: id, kind: kind, text: text, ref: ref, regions: regions);

/// A deck whose words each name another by a pair note: one rude, one not.
const String _header = '''
schema: 1
language: { code: te, iso639_3: tel, name: Telugu, script: telugu }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0''';

Map<String, String> _decks() => <String, String>{
  'decks/te/te-en-notes-words.yaml':
      '''
$_header
id: te-en-notes-words
name: "Words"
cards:
  - id: te-9911
    target: "విధవ"
    native: "widow"
    reading: "vidhava"
    notes:
      - { kind: "usage", text: "Said of a woman whose husband has died." }
      - { kind: "pair", ref: "te-9951", text: "Keep the i short." }
      - { kind: "pair", ref: "te-9912", text: "Not the word for a pen." }
  - { id: te-9912, target: "కలం", native: "pen", reading: "kalam" }
  - id: te-9913
    target: "విధవా"
    native: "widow (calling her)"
    reading: "vidhavā"
    notes:
      - { kind: "pair", ref: "te-9951", text: "Keep the i short." }
      - { kind: "usage", text: "Rare as a form of address." }
      - { kind: "note", text: "Many find it unkind." }
''',
  'decks/te/te-en-notes-rude.yaml':
      '''
$_header
id: te-en-notes-rude
name: "Rude words"
tags: [offensive]
cards:
  - { id: te-9951, target: "వెధవ", native: "idiot", reading: "vedhava", modes: [recognition] }
''',
};

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

Future<AppState> _state() async {
  final state = AppState.test(
    decks: MemoryDeckSource(_decks()),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['te'],
      learningChosen: true,
    ),
  );
  await state.load();
  return state;
}

void main() {
  group('a card\'s notes', () {
    test('a card face shows every note but a pair note, in order', () {
      final card = _card(
        notes: <CardNote>[
          _note(NoteKind.usage, 'First.'),
          _note(NoteKind.pair, 'Care.', id: '2', ref: 'zz-9002'),
          _note(NoteKind.culture, 'Second.', id: '3'),
          _note(NoteKind.note, '  ', id: '4'),
        ],
      );
      expect(shownNotes(card), <String>['First.', 'Second.']);
      expect(notesText(card), 'First.\nSecond.');
      expect(notesText(_card()), isNull);
    });

    test('its pairs: its pair, then each pair note\'s partner, each once, '
        'with the note\'s text as the care note', () {
      final card = _card(
        pair: 'zz-9002',
        notes: <CardNote>[
          _note(NoteKind.pair, '', ref: 'zz-9002'),
          _note(NoteKind.usage, 'Not a pair.', id: '2'),
          _note(NoteKind.pair, 'Keep it short.', id: '3', ref: 'zz-9003'),
        ],
      );
      expect(pairsOf(card), <({String id, String? care})>[
        (id: 'zz-9002', care: null),
        (id: 'zz-9003', care: 'Keep it short.'),
      ]);
      expect(pairsOf(_card()), isEmpty);
    });

    test('its region note is the first note naming regions', () {
      final card = _card(
        notes: <CardNote>[
          _note(NoteKind.usage, 'Everywhere.'),
          _note(NoteKind.usage, 'Here.', id: '2', regions: <String>['north']),
          _note(NoteKind.usage, 'There.', id: '3', regions: <String>['south']),
        ],
      );
      expect(regionNoteOf(card)?.text, 'Here.');
      expect(regionNoteOf(_card()), isNull);
    });
  });

  test(
    'a pair note to a rude word warns of it, with the note\'s text',
    () async {
      final state = await _state();
      final word = state.deckById('te-en-notes-words')!.cards.first;
      final alikes = rudeAlikesOf(state, word);
      expect(alikes, hasLength(1));
      expect(alikes.single.partner.id, 'te-9951');
      expect(alikes.single.care, 'Keep the i short.');
    },
  );

  testWidgets('a word\'s card shows its notes, the rude pair\'s warning with '
      'its care note, and the other pair with its own', (tester) async {
    usePhone(tester);
    final state = await _state();
    final entry = state.deckById('te-en-notes-words')!;
    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: entry.cards.first, language: entry.language),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(
      find.text('Said of a woman whose husband has died.'),
      findsOneWidget,
    );
    expect(find.byType(AlikeWarning), findsOneWidget);
    expect(find.text('Keep the i short.'), findsOneWidget);
    expect(find.textContaining('వెధవ'), findsNothing);
    expect(find.text(l10n.wordSheetSoundsLikeTitle), findsOneWidget);
    expect(find.text('Not the word for a pen.'), findsOneWidget);
  });

  testWidgets('a drill\'s card shows every note but the pair note, whose '
      'text shows once, in the warning', (tester) async {
    usePhone(tester);
    final state = await _state();
    final entry = state.deckById('te-en-notes-words')!;
    final card = entry.cards.firstWhere((c) => c.id == 'te-9913');
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: TaughtDetails(
            card: card,
            language: entry.language,
            reading: TaughtReading.always,
          ),
        ),
      ),
      state: state,
    );
    expect(find.text('Rare as a form of address.'), findsOneWidget);
    expect(find.text('Many find it unkind.'), findsOneWidget);
    expect(find.byType(AlikeWarning), findsOneWidget);
    expect(find.text('Keep the i short.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlikeWarning),
        matching: find.text('Keep the i short.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Inspect shows every note but the pair note, a note a line', (
    tester,
  ) async {
    usePhone(tester);
    final state = await _state();
    await pumpScreen(
      tester,
      const InspectPage(deckId: 'te-en-notes-words'),
      state: state,
    );
    final l10n = l10nOf(tester);
    await _scrollTo(tester, find.text(l10n.inspectId('te-9913')));
    await tester.tap(find.text(l10n.inspectId('te-9913')));
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      find.textContaining('Rare as a form of address.\nMany find it unkind.'),
    );
    expect(find.textContaining('Keep the i short.'), findsNothing);
  });
}
