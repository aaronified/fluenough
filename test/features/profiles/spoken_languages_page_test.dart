import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/placement/learn_languages_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';

import '../../support/harness.dart';

void main() {
  // A cached asset's future belongs to the test that first read it.
  setUp(rootBundle.clear);

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

    // The welcome, then straight past the tour.
    expect(find.text(l10n.appTitle), findsOneWidget);
    await tester.tap(find.text(l10n.onboardingStart));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.onboardingSkip));
    await tester.pumpAndSettle();

    expect(find.text(l10n.onboardingSpokenTitle), findsOneWidget);
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
    expect(settings.spokenLanguages, isEmpty, reason: 'nothing saved yet');

    await tester.tap(go);
    await tester.pumpAndSettle();
    expect(settings.spokenLanguages, ['bn', 'en']);
    // Then what to learn (#117), before the app.
    expect(find.byType(LearnLanguagesPage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  Future<void> openFromSettings(WidgetTester tester) async {
    unawaited(
      AppNavigator.openSpokenLanguages(tester.element(find.byType(AppShell))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('from Settings, Back leaves without saving', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester);
    final l10n = l10nOf(tester);
    await openFromSettings(tester);
    // English, the test state's language, starts ticked and ranked 1.
    expect(find.text(l10n.spokenRank(1)), findsOneWidget);
    await tester.tap(find.text(l10n.spokenOption('Hindi', 'हिन्दी')));
    await tester.pump();
    expect(find.text(l10n.spokenRank(2)), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(l10n.spokenTitle), findsNothing);
    expect(state.settings.spokenLanguages, ['en']);
  });

  testWidgets('from Settings, Continue waits for a language, and its text '
      'starts on the 24 px line', (tester) async {
    usePhone(tester);
    await pumpApp(tester);
    final l10n = l10nOf(tester);
    await openFromSettings(tester);
    expect(textStart(tester, find.text(l10n.spokenBody)), 24);
    await tester.tap(find.text(l10n.spokenOption('English', 'English')));
    await tester.pump();
    final go = find.widgetWithText(FilledButton, l10n.commonContinue);
    expect(tester.widget<FilledButton>(go).onPressed, isNull);
  });

  testWidgets('from Settings, Continue saves the ranking and goes back', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpApp(tester);
    final l10n = l10nOf(tester);
    await openFromSettings(tester);
    expect(find.text(l10n.spokenTitle), findsOneWidget);

    await tester.tap(find.text(l10n.spokenOption('Hindi', 'हिन्दी')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(state.settings.spokenLanguages, ['en', 'hi']);
    expect(find.text(l10n.spokenTitle), findsNothing);
  });

  group('one line', () {
    final choices = parseSpokenLanguages(
      File(SpokenLanguagesPage.asset).readAsStringSync(),
    );
    for (final rtl in <bool>[false, true]) {
      testWidgets(
        'heading, body and boxes on 24, every name on 72, ticked or not'
        '${rtl ? ', right to left' : ''}',
        (tester) async {
          usePhone(tester);
          await pumpScreen(
            tester,
            Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: OnboardingFlow(
                startAt: 'spoken',
                spoken: const <String>['en'],
                choices: choices,
              ),
            ),
          );
          final l10n = l10nOf(tester);
          // Distance from the start edge, of the glyphs themselves.
          double start(Finder f) => textStart(tester, f);
          expect(start(find.text(l10n.onboardingSpokenTitle)), 24);
          expect(start(find.text(l10n.onboardingSpokenBody)), 24);
          for (final box in tester.widgetList(find.byType(Checkbox))) {
            final centre = tester.getCenter(find.byWidget(box)).dx;
            expect(rtl ? 390 - centre : centre, 24 + 9, reason: 'box');
          }
          // English is ticked and ranked, Hindi is not: both names on 72.
          expect(start(find.text(l10n.spokenOption('English', 'English'))), 72);
          expect(start(find.text(l10n.spokenOption('Hindi', 'हिन्दी'))), 72);
        },
      );
    }
  });

  testWidgets('the rank hint comes with the second tick', (tester) async {
    usePhone(tester);
    final choices = parseSpokenLanguages(
      File(SpokenLanguagesPage.asset).readAsStringSync(),
    );
    await pumpScreen(
      tester,
      OnboardingFlow(startAt: 'spoken', choices: choices),
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.spokenOption('English', 'English')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.spokenRankHint), findsNothing);
    await tester.tap(find.text(l10n.spokenOption('Bengali', 'বাংলা')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.spokenRankHint), findsOneWidget);
  });

  testWidgets('with a screen reader, the hint names the move actions', (
    tester,
  ) async {
    usePhone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final choices = parseSpokenLanguages(
      File(SpokenLanguagesPage.asset).readAsStringSync(),
    );
    await pumpScreen(
      tester,
      OnboardingFlow(
        startAt: 'spoken',
        spoken: const <String>['bn', 'en'],
        choices: choices,
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.spokenRankHintActions), findsOneWidget);
    expect(find.text(l10n.spokenRankHint), findsNothing);
  });

  testWidgets('a tap on a drag handle does not untick its language', (
    tester,
  ) async {
    usePhone(tester);
    final choices = parseSpokenLanguages(
      File(SpokenLanguagesPage.asset).readAsStringSync(),
    );
    await pumpScreen(
      tester,
      OnboardingFlow(
        startAt: 'spoken',
        spoken: const <String>['bn', 'en'],
        choices: choices,
      ),
    );
    final l10n = l10nOf(tester);
    final handle = find.byIcon(Icons.drag_handle);
    // A target of its own, 48 square, so a tap lands on it, not the row.
    expect(
      tester.getSize(
        find.ancestor(of: handle.first, matching: find.byType(SizedBox)).first,
      ),
      const Size.square(48),
    );
    await tester.tap(handle.first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.spokenRank(2)), findsOneWidget);
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
