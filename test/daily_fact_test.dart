import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/facts_parser.dart';
import 'package:fluenough/core/models/fact.dart';
import 'package:fluenough/core/scheduling/daily_fact.dart';
import 'package:fluenough/features/today/today_page.dart';

import 'support/harness.dart';

const facts = '''
schema: 1
id: hi-facts
name: Hindi facts
kind: facts
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
license: CC0-1.0
facts:
  - id: hi-fact-001
    text:
      en: "No Hindi word begins with ड़."
      bn: "কোনো হিন্দি শব্দ ড় দিয়ে শুরু হয় না।"
  - id: hi-fact-002
    text: { en: "Hindi writes conjuncts." }
  - id: hi-fact-101
    contrast: bn
    text: { bn: "হিন্দিতে স সবসময় 's'।" }
''';

const deck = '''
schema: 1
id: hi-en-core
name: Hindi core
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-core-0001, target: "घर", native: "house", reading: "ghar" }
''';

Fact fact(String id, Map<String, String> text, {String? contrast}) =>
    Fact(id: id, text: text, contrast: contrast);

void main() {
  final now = DateTime(2026, 9, 29, 9);
  final general = fact('a', {'en': 'A', 'bn': 'অ'});
  final englishOnly = fact('b', {'en': 'B'});
  final bengaliContrast = fact('c', {'bn': 'গ'}, contrast: 'bn');
  final all = [general, englishOnly, bengaliContrast];

  group('factForToday', () {
    test('the first fact never shown, in file order', () {
      expect(factForToday(all, spoken: ['en'], shownAt: {}, now: now), general);
      expect(
        factForToday(
          all,
          spoken: ['en'],
          shownAt: {'a': now.subtract(const Duration(days: 1))},
          now: now,
        ),
        englishOnly,
      );
    });

    test('a fact shown today stays today\'s fact', () {
      expect(
        factForToday(
          all,
          spoken: ['en'],
          shownAt: {'b': now.subtract(const Duration(hours: 2))},
          now: now,
        ),
        englishOnly,
      );
    });

    test('after the last, the one shown longest ago', () {
      final shown = {
        'a': now.subtract(const Duration(days: 2)),
        'b': now.subtract(const Duration(days: 5)),
      };
      expect(
        factForToday(all, spoken: ['en'], shownAt: shown, now: now),
        englishOnly,
      );
    });

    test('a contrast fact only for someone who speaks that language', () {
      expect(factIsFor(bengaliContrast, ['en']), isFalse);
      expect(factIsFor(bengaliContrast, ['bn', 'en']), isTrue);
      expect(
        factIsFor(englishOnly, ['bn']),
        isFalse,
        reason: 'not written in bn',
      );
      expect(
        factForToday([englishOnly], spoken: ['bn'], shownAt: {}, now: now),
        isNull,
      );
    });

    test('text in each spoken language, best known first', () {
      expect(factTexts(general, ['bn', 'en']).map((t) => t.code), ['bn', 'en']);
      expect(factTexts(general, ['en', 'hi']).map((t) => t.code), ['en']);
    });
  });

  group('parseFacts', () {
    test('reads the facts in order', () {
      final file = parseFacts(facts, source: 'hi-facts.yaml');
      expect(file.languageCode, 'hi');
      expect(file.facts.map((f) => f.id), [
        'hi-fact-001',
        'hi-fact-002',
        'hi-fact-101',
      ]);
      expect(file.facts.last.contrast, 'bn');
    });

    test('refuses a fact whose contrast has no text', () {
      expect(
        () => parseFacts(
          facts.replaceFirst('contrast: bn', 'contrast: en'),
          source: 'x',
        ),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  test('which facts were shown survives the settings table', () {
    final settings = SettingsNotifier()
      ..markFactShown('hi', 'hi-fact-001', now);
    final restored = SettingsNotifier()..restore(settings.toStored());
    expect(restored.factShownAt('hi', 'hi-fact-001'), now);
    expect(restored.factsShownFor('hi'), {'hi-fact-001': now});
    expect(restored.factsShownFor('bn'), isEmpty);
  });

  testWidgets('Today shows the fact in Bengali then English, and records it', (
    tester,
  ) async {
    usePhone(tester);
    final settings = SettingsNotifier(spokenLanguages: const ['bn', 'en']);
    final state = AppState.test(
      decks: MemoryDeckSource(const <String, String>{
        'decks/hi/hi-en-core.yaml': deck,
        'decks/hi/hi-facts.yaml': facts,
      }),
      settings: settings,
    );
    await pumpScreen(tester, const TodayPage(), state: state);
    final l10n = l10nOf(tester);
    expect(state.brokenDecks, isEmpty);
    expect(find.text(l10n.todayFactFor('Hindi')), findsOneWidget);
    final bengali = find.text('কোনো হিন্দি শব্দ ড় দিয়ে শুরু হয় না।');
    final english = find.text('No Hindi word begins with ड़.');
    expect(bengali, findsOneWidget);
    expect(english, findsOneWidget);
    expect(
      tester.getTopLeft(bengali).dy,
      lessThan(tester.getTopLeft(english).dy),
    );
    expect(tester.widget<Text>(bengali).locale, const Locale('bn'));
    await tester.pump();
    expect(settings.factShownAt('hi', 'hi-fact-001'), isNotNull);
    settings.dispose();
  });
}
