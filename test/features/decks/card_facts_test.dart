import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/fact.dart';
import 'package:fluenough/core/scheduling/daily_fact.dart';
import 'package:fluenough/features/decks/word_sheet.dart';

import '../../support/harness.dart';

/// Facts on cards (#546; owner, 2026-10-17: "A Facts section at the end of
/// the card sheet", after the examples and notes, only when a fact names the
/// card; and the daily fact prefers a fact naming a card being studied).
const facts = '''
schema: 1
id: hi-facts
name: Hindi facts
kind: facts
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
license: CC0-1.0
facts:
  - id: hi-fact-001
    text: { en: "Hindi nouns are masculine or feminine." }
  - id: hi-fact-002
    cards: [hi-en-core-0001]
    text:
      en: "घर (ghar) is also the word for a square on a board."
      bn: "ঘর শব্দের আরেক মানে বোর্ডের একটি ঘর।"
  - id: hi-fact-003
    cards: [hi-en-core-0001, hi-en-core-0002]
    text: { en: "Both of these end in a consonant." }
  - id: hi-fact-004
    cards: [hi-en-core-0002]
    contrast: bn
    text: { bn: "এই শব্দটি বাংলার মতো নয়।" }
''';

const deck = '''
schema: 1
id: hi-en-core
name: Hindi core
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: hi-en-core-0001
    target: "घर"
    native: "house"
    reading: "ghar"
    notes: A note about the word.
    examples:
      - { target: "यह मेरा घर है।", native: "This is my house." }
  - { id: hi-en-core-0002, target: "पानी", native: "water", reading: "pānī" }
  - { id: hi-en-core-0003, target: "रोटी", native: "bread", reading: "rōṭī" }
''';

AppState build({
  List<String> spoken = const <String>['en'],
  MemoryProgress? progress,
}) => AppState.test(
  decks: MemoryDeckSource(const <String, String>{
    'decks/hi/hi-en-core.yaml': deck,
    'decks/hi/hi-facts.yaml': facts,
  }),
  settings: SettingsNotifier(
    spokenLanguages: spoken,
    learningLanguages: const <String>['hi'],
  )..learningChosen = true,
  progress: progress,
);

Future<void> showSheet(
  WidgetTester tester,
  AppState state,
  String cardId, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await state.load();
  final entry = state.deckById('hi-en-core')!;
  final card = entry.cards.firstWhere((c) => c.id == cardId);
  await pumpScreen(
    tester,
    Scaffold(
      body: WordSheet(card: card, language: entry.language),
    ),
    state: state,
    themeMode: themeMode,
  );
}

void main() {
  final now = DateTime(2026, 10, 17, 9);

  group('factsNamingCard', () {
    const general = Fact(id: 'a', text: {'en': 'A'});
    const named = Fact(id: 'b', text: {'en': 'B'}, cards: ['c1']);
    const bengali = Fact(
      id: 'c',
      text: {'bn': 'গ'},
      contrast: 'bn',
      cards: ['c1'],
    );
    const other = Fact(id: 'd', text: {'en': 'D'}, cards: ['c2']);
    const all = <Fact>[general, named, bengali, other];

    test('the facts that name the card, in the file\'s order', () {
      expect(factsNamingCard(all, 'c1', spoken: ['bn', 'en']), [
        named,
        bengali,
      ]);
      expect(factsNamingCard(all, 'c2', spoken: ['en']), [other]);
    });

    test('none when no fact names it, or none is for the learner', () {
      expect(factsNamingCard(all, 'c3', spoken: ['en']), isEmpty);
      expect(factsNamingCard(all, 'c1', spoken: ['en']), [named]);
    });
  });

  group('the daily fact prefers a card being studied', () {
    const first = Fact(id: 'a', text: {'en': 'A'});
    const names1 = Fact(id: 'b', text: {'en': 'B'}, cards: ['c1']);
    const names2 = Fact(id: 'c', text: {'en': 'C'}, cards: ['c2']);
    const all = <Fact>[first, names1, names2];

    Fact? today({
      Set<String> studied = const <String>{},
      Map<String, DateTime> shownAt = const <String, DateTime>{},
    }) => factForToday(
      all,
      spoken: ['en'],
      shownAt: shownAt,
      now: now,
      studied: studied,
    );

    test('with nothing studied, the first in the file\'s order', () {
      expect(today(), first);
    });

    test('a fact naming a studied card comes before the rest', () {
      expect(today(studied: {'c1'}), names1);
      expect(today(studied: {'c2'}), names2);
      expect(today(studied: {'c1', 'c2'}), names1, reason: 'file order');
      expect(today(studied: {'c9'}), first, reason: 'a card no fact names');
    });

    test('only among facts never shown, and today\'s fact stays', () {
      final shown = {'b': now.subtract(const Duration(days: 1))};
      expect(today(studied: {'c1'}, shownAt: shown), first);
      final sameDay = {'a': now.subtract(const Duration(hours: 1))};
      expect(today(studied: {'c1'}, shownAt: sameDay), first);
    });

    test('once every fact was shown, the one shown longest ago', () {
      final shown = {
        'a': now.subtract(const Duration(days: 2)),
        'b': now.subtract(const Duration(days: 3)),
        'c': now.subtract(const Duration(days: 9)),
      };
      expect(today(studied: {'c1'}, shownAt: shown), names2);
    });

    test('a card is studied when its state is not new, in any skill', () async {
      final progress = MemoryProgress()
        ..record(
          deckId: 'hi-en-core',
          cardId: 'hi-en-core-0002',
          mode: DrillMode.listening,
          grade: 4,
          now: now,
        );
      final state = build(progress: progress);
      await state.load();
      final fact = state.todaysFacts().single.fact;
      expect(fact.id, 'hi-fact-003', reason: 'names the studied card 0002');
      // Nothing studied: the first in the file's order, as before.
      final fresh = build();
      await fresh.load();
      expect(fresh.todaysFacts().single.fact.id, 'hi-fact-001');
    });
  });

  group('the card sheet', () {
    for (final dark in <bool>[false, true]) {
      testWidgets('ends with the facts that name the card, at 1.4x text'
          '${dark ? ', dark' : ''}', (tester) async {
        usePhone(tester, textScale: 1.4);
        await showSheet(
          tester,
          build(spoken: const <String>['bn', 'en']),
          'hi-en-core-0001',
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        final l10n = l10nOf(tester);
        final heading = find.text(l10n.wordSheetFacts);
        await tester.scrollUntilVisible(
          heading,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(heading);
        await tester.pumpAndSettle();
        expect(heading, findsOneWidget);
        // The facts that name the card, and only those.
        final bengali = find.text('ঘর শব্দের আরেক মানে বোর্ডের একটি ঘর।');
        final english = find.text(
          'घर (ghar) is also the word for a square on a board.',
        );
        final both = find.text('Both of these end in a consonant.');
        for (final finder in <Finder>[bengali, english, both]) {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(finder, findsOneWidget);
        }
        expect(
          find.text('Hindi nouns are masculine or feminine.'),
          findsNothing,
        );
        // Card 0002's own contrast fact is not this card's.
        expect(find.text('এই শব্দটি বাংলার মতো নয়।'), findsNothing);
        expect(tester.widget<Text>(bengali).locale, const Locale('bn'));
        // The heading is below the note and the example, the first fact
        // below the heading.
        final note = tester.getTopLeft(find.text('A note about the word.')).dy;
        final example = tester
            .getTopLeft(find.textContaining('मेरा', findRichText: true))
            .dy;
        final top = tester.getTopLeft(heading).dy;
        expect(top, greaterThan(example));
        expect(top, greaterThan(note));
        expect(tester.getTopLeft(bengali).dy, greaterThan(top));
        // Best known language first.
        expect(
          tester.getTopLeft(bengali).dy,
          lessThan(tester.getTopLeft(english).dy),
        );
        // Nothing clipped: every fact inside the screen's width, and no
        // overflow reported.
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        for (final finder in <Finder>[heading, bengali, english, both]) {
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a card no fact names has no Facts section', (tester) async {
      usePhone(tester);
      await showSheet(tester, build(), 'hi-en-core-0003');
      final l10n = l10nOf(tester);
      expect(find.text(l10n.wordSheetFacts), findsNothing);
      expect(find.text('Hindi nouns are masculine or feminine.'), findsNothing);
    });

    testWidgets('a fact is shown only to a learner it is for', (tester) async {
      usePhone(tester);
      await showSheet(tester, build(), 'hi-en-core-0002');
      final l10n = l10nOf(tester);
      // 0002 is named by one fact for everyone and one that contrasts with
      // Bengali: an English-only learner sees the first.
      expect(find.text(l10n.wordSheetFacts), findsOneWidget);
      expect(find.text('Both of these end in a consonant.'), findsOneWidget);
      expect(find.text('এই শব্দটি বাংলার মতো নয়।'), findsNothing);
    });
  });
}
