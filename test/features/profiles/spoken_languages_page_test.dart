import 'dart:io';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';

import '../../support/harness.dart';

void main() {
  group('assets/languages.yaml', () {
    test('lists English, Bengali and Hindi, each by its own name too', () {
      final languages = parseSpokenLanguages(
        File(SpokenLanguagesPage.asset).readAsStringSync(),
      );
      expect(languages.map((l) => l.code), ['en', 'bn', 'hi']);
      expect(languages[1].ownName, 'বাংলা');
      expect(languages.map((l) => l.iso639_3), ['eng', 'ben', 'hin']);
    });

    test('a malformed list is refused with where it is wrong', () {
      for (final (text, why) in <(String, String)>[
        ('kind: decks\nlanguages: []\n', 'kind: languages'),
        ('kind: languages\nlanguages: []\n', 'non-empty'),
        (
          'kind: languages\nlanguages:\n  - { code: EN, iso639_3: eng, name: E, own_name: E }\n',
          'code',
        ),
        (
          'kind: languages\nlanguages:\n  - { code: en, iso639_3: eng, name: E }\n',
          'own_name',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E }\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E }\n',
          'twice',
        ),
      ]) {
        expect(
          () => parseSpokenLanguages(text),
          throwsA(
            isA<FormatException>().having((e) => e.message, 'm', contains(why)),
          ),
          reason: why,
        );
      }
    });
  });

  group('the setting', () {
    test('keeps its rank, drops repeats, and survives toStored', () {
      final settings = SettingsNotifier()..spokenLanguages = ['bn', 'en', 'bn'];
      expect(settings.spokenLanguages, ['bn', 'en']);
      expect(settings.rankOf('en'), 1);
      expect(settings.rankOf('hi'), isNull);
      final restored = SettingsNotifier()..restore(settings.toStored());
      expect(restored.spokenLanguages, ['bn', 'en']);
      final junk = SettingsNotifier()
        ..restore(const {'spoken_languages': 'bn,Bengali,,x1,hi'});
      expect(junk.spokenLanguages, ['bn', 'hi']);
    });
  });

  testWidgets('the first launch asks, and a drag puts Bengali first', (
    tester,
  ) async {
    usePhone(tester);
    final settings = SettingsNotifier();
    final state = AppState.test(settings: settings);
    addTearDown(state.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(FluenoughApp(state: state));
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);

    expect(find.text(l10n.spokenTitle), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    final go = find.widgetWithText(FilledButton, l10n.commonContinue);
    expect(
      tester.widget<FilledButton>(go).onPressed,
      isNull,
      reason: 'none ticked',
    );

    await tester.tap(find.text(l10n.spokenOption('English', 'English')));
    await tester.tap(find.text(l10n.spokenOption('Bengali', 'বাংলা')));
    await tester.pump();

    // Long-press Bengali and drag it above English.
    final bengali = find.text(l10n.spokenOption('Bengali', 'বাংলা'));
    final english = find.text(l10n.spokenOption('English', 'English'));
    final from = tester.getCenter(bengali);
    final to = tester.getCenter(english) - const Offset(0, 30);
    final drag = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var step = 1; step <= 10; step++) {
      await drag.moveTo(Offset.lerp(from, to, step / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    await tester.tap(go);
    await tester.pumpAndSettle();
    expect(settings.spokenLanguages, ['bn', 'en']);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('from Settings it can go back without saving', (tester) async {
    usePhone(tester);
    final choices = parseSpokenLanguages(
      File(SpokenLanguagesPage.asset).readAsStringSync(),
    );
    final state = await pumpScreen(
      tester,
      SpokenLanguagesPage(choices: choices),
    );
    expect(find.byType(BackButton), findsNothing, reason: 'pushed alone here');
    expect(state.settings.spokenLanguages, ['en']);
    final l10n = l10nOf(tester);
    // English, the test state's language, starts ticked and ranked 1.
    expect(find.text(l10n.spokenRank(1)), findsOneWidget);
  });

  test(
    'a Bengali-first learner sees decks taught from Bengali first',
    () async {
      String deck(String id, String native, String nativeName) =>
          '''
schema: 1
id: $id
name: "$id"
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: $native, iso639_3: ${native == 'bn' ? 'ben' : 'eng'}, name: $nativeName }
license: CC0-1.0
cards:
  - { id: $id-0001, target: "क", native: "k", reading: "k" }
''';
      AppState learner(List<String> spoken) => AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/hi/hi-bn-core.yaml': deck('hi-bn-core', 'bn', 'Bengali'),
          'decks/hi/hi-en-core.yaml': deck('hi-en-core', 'en', 'English'),
        }),
        settings: SettingsNotifier(spokenLanguages: spoken),
      );
      final bengali = learner(['bn', 'en']);
      final english = learner(['en']);
      await bengali.load();
      await english.load();
      expect(bengali.profileDecks.map((d) => d.id), [
        'hi-bn-core',
        'hi-en-core',
      ]);
      expect(english.profileDecks.map((d) => d.id), [
        'hi-en-core',
        'hi-bn-core',
      ]);
    },
  );
}
