import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/features/decks/card_bases.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/drill/taught_details.dart';

import '../../support/harness.dart';

/// A card's base words show on its card (#410): a base written in full with
/// its own meaning, a base by ref with the target and meaning of the card
/// it names, and nothing for a card without bases.
///
/// The card ids are test-only, in a range no deck uses (AGENTS.md rule 1).

const String deckId = 'hi-fixture-bases';
const String goCard = 'hi-9801';
const String sentenceCard = 'hi-9802';
const String homeCard = 'hi-9803';

const String _deck =
    '''
schema: 1
id: $deckId
name: "Hindi (bases fixture)"
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: $goCard, target: "जाना", reading: "jānā", native: "to go" }
  - id: $sentenceCard
    target: "मैं घर जाता हूँ"
    reading: "ma͠i ghar jātā hū̃"
    native: "I go home"
    pos: "phrase"
    bases:
      - { word: "जाता", ref: "$goCard" }
      - { word: "हूँ", base: "होना", reading: "honā", meaning: "to be" }
  - { id: $homeCard, target: "घर", reading: "ghar", native: "home" }
''';

Future<AppState> basesState({bool romanisation = true}) async {
  final state = AppState.test(
    decks: MemoryDeckSource(const <String, String>{
      'decks/hi/$deckId.yaml': _deck,
    }),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
      showRomanisation: romanisation,
    ),
  );
  await state.load();
  return state;
}

Card cardOf(AppState state, String id) =>
    state.deckById(deckId)!.cards.firstWhere((c) => c.id == id);

void main() {
  group('shownBases', () {
    const go = Card(
      id: goCard,
      deckId: deckId,
      target: 'जाना',
      native: 'to go',
      reading: 'jānā',
    );
    Card? find(String id) => id == goCard ? go : null;

    test('a base written in full keeps its own meaning', () {
      const card = Card(
        id: sentenceCard,
        deckId: deckId,
        target: 'मैं हूँ',
        native: 'I am',
        bases: <CardBase>[
          CardBase(
            word: 'हूँ',
            base: 'होना',
            reading: 'honā',
            meaning: 'to be',
          ),
        ],
      );
      final bases = shownBases(card, find);
      expect(bases, hasLength(1));
      expect(bases.single.base, 'होना');
      expect(bases.single.reading, 'honā');
      expect(bases.single.meaning, 'to be');
      expect(bases.single.inline, isTrue);
      expect(bases.single.word, 'हूँ');
    });

    test('a base by ref is the target and meaning of the card it names', () {
      const card = Card(
        id: sentenceCard,
        deckId: deckId,
        target: 'जाता',
        native: 'goes',
        bases: <CardBase>[CardBase(word: 'जाता', ref: goCard)],
      );
      final bases = shownBases(card, find);
      expect(bases.single.base, 'जाना');
      expect(bases.single.reading, 'jānā');
      expect(bases.single.meaning, 'to go');
      expect(bases.single.inline, isFalse);
      expect(bases.single.ref, goCard);
    });

    test('no bases, a ref not on the phone, a ref to itself and a repeat '
        'show nothing more', () {
      const plain = Card(
        id: homeCard,
        deckId: deckId,
        target: 'घर',
        native: 'home',
      );
      expect(shownBases(plain, find), isEmpty);
      const card = Card(
        id: sentenceCard,
        deckId: deckId,
        target: 'जाता जाती',
        native: 'goes',
        bases: <CardBase>[
          CardBase(word: 'जाता', ref: goCard),
          CardBase(word: 'जाती', ref: goCard),
          CardBase(word: 'x', ref: 'hi-9899'),
          CardBase(word: 'y', ref: sentenceCard),
        ],
      );
      expect(shownBases(card, find), hasLength(1));
    });
  });

  testWidgets('the word sheet shows both bases on one line, and a card '
      'without bases none', (tester) async {
    usePhone(tester);
    final state = await basesState();
    final language = state.deckById(deckId)!.language;
    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: cardOf(state, sentenceCard), language: language),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    final line = l10n.cardBases(
      2,
      l10n.cardBasesJoin(
        l10n.cardBaseReadingMeaning('जाना', 'jānā', 'to go'),
        l10n.cardBaseReadingMeaning('होना', 'honā', 'to be'),
      ),
    );
    expect(line, 'Bases: जाना (jānā) · to go, होना (honā) · to be');
    expect(find.text(line), findsOneWidget);
    expect(find.byType(BaseLine), findsOneWidget);

    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: cardOf(state, homeCard), language: language),
      ),
      state: state,
    );
    expect(find.byType(BaseLine), findsNothing);
    expect(find.textContaining('Base'), findsNothing);
  });

  testWidgets('after answering, a drill shows one base line, its readings '
      'as Latin-letter readings says', (tester) async {
    usePhone(tester);
    final state = await basesState(romanisation: false);
    final language = state.deckById(deckId)!.language;
    await pumpScreen(
      tester,
      Scaffold(
        body: TaughtDetails(
          card: cardOf(state, sentenceCard),
          language: language,
          reading: TaughtReading.bySetting,
          word: false,
        ),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    final line = l10n.cardBases(
      2,
      l10n.cardBasesJoin(
        l10n.cardBase('जाना', 'to go'),
        l10n.cardBase('होना', 'to be'),
      ),
    );
    expect(find.text(line), findsOneWidget);
    // One Text: one line, wrapping only when it must.
    expect(
      find.descendant(of: find.byType(BaseLine), matching: find.byType(Text)),
      findsOneWidget,
    );

    state.settings.showRomanisation = true;
    await tester.pumpAndSettle();
    expect(find.textContaining('जाना (jānā) · to go'), findsOneWidget);
  });

  testWidgets('the base line reads as one label, its bases in the '
      "language's voice, and meets contrast", (tester) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    final state = await basesState();
    final language = state.deckById(deckId)!.language;
    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: cardOf(state, sentenceCard), language: language),
      ),
      state: state,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Bases: जाना \(jānā\) · to go')),
      findsOneWidget,
    );
    final text = tester.widget<Text>(
      find.descendant(of: find.byType(BaseLine), matching: find.byType(Text)),
    );
    final spans = <TextSpan>[
      for (final s in (text.textSpan! as TextSpan).children!) s as TextSpan,
    ];
    final hindi = <String>[
      for (final s in spans)
        if (s.locale == const Locale('hi')) s.text!,
    ];
    expect(hindi, <String>['जाना', 'होना']);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
