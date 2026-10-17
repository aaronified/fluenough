import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';
import 'package:fluenough/features/profiles/spoken_languages_picker.dart';

import '../../support/harness.dart';

void main() {
  // A cached asset's future belongs to the test that first read it.
  setUp(rootBundle.clear);

  group('assets/languages.yaml', () {
    final languages = parseSpokenLanguages(
      File(SpokenLanguagesPage.asset).readAsStringSync(),
    );

    /// The Unicode blocks each script id is written in.
    const blocks = <String, List<(int, int)>>{
      'latin': <(int, int)>[(0x41, 0x24F), (0x1E00, 0x1EFF)],
      'bengali': <(int, int)>[(0x980, 0x9FF)],
      'devanagari': <(int, int)>[(0x900, 0x97F)],
      'gujarati': <(int, int)>[(0xA80, 0xAFF)],
      'gurmukhi': <(int, int)>[(0xA00, 0xA7F)],
      'odia': <(int, int)>[(0xB00, 0xB7F)],
      'tamil': <(int, int)>[(0xB80, 0xBFF)],
      'telugu': <(int, int)>[(0xC00, 0xC7F)],
      'kannada': <(int, int)>[(0xC80, 0xCFF)],
      'malayalam': <(int, int)>[(0xD00, 0xD7F)],
      'ol_chiki': <(int, int)>[(0x1C50, 0x1C7F)],
      'arabic': <(int, int)>[(0x600, 0x6FF), (0x750, 0x77F), (0xFB50, 0xFDFF)],
    };

    /// Whether every letter and mark of [text] is in [script].
    bool inScript(String text, String script) {
      final ranges = blocks[script]!;
      for (final rune in text.runes) {
        final ch = String.fromCharCode(rune);
        if (!RegExp(r'[\p{L}\p{M}]', unicode: true).hasMatch(ch)) continue;
        if (rune == 0x200C || rune == 0x200D) continue;
        if (!ranges.any((r) => rune >= r.$1 && rune <= r.$2)) return false;
      }
      return true;
    }

    test('lists English, India\'s 22 scheduled languages and the others the '
        'owner approved (#490)', () {
      final codes = languages.map((l) => l.code).toSet();
      const scheduled = <String>{
        'as',
        'bn',
        'brx',
        'doi',
        'gu',
        'hi',
        'kn',
        'ks',
        'kok',
        'mai',
        'ml',
        'mni',
        'mr',
        'ne',
        'or',
        'pa',
        'sa',
        'sat',
        'sd',
        'ta',
        'te',
        'ur',
      };
      const others = <String>{
        'bho',
        'tcy',
        'raj',
        'mag',
        'hne',
        'awa',
        'bgc',
        'kfy',
        'gbm',
        'lus',
        'kha',
        'gom',
      };
      expect(codes, <String>{'en', ...scheduled, ...others});
      expect(languages, hasLength(35));
      final bengali = languages.firstWhere((l) => l.code == 'bn');
      expect(bengali.ownName, 'বাংলা');
      expect(bengali.iso639_3, 'ben');
      expect(bengali.script, 'bengali');
    });

    test('every entry has its fields, its own name in its own script, a '
        'valid and unique ISO 639-3 code, and a known family', () {
      const families = <String>{
        'indo_aryan',
        'dravidian',
        'tibeto_burman',
        'austroasiatic',
        'germanic',
      };
      final isos = <String>{};
      for (final l in languages) {
        expect(l.name, isNotEmpty, reason: l.code);
        expect(l.script, isNotNull, reason: l.code);
        expect(blocks, contains(l.script), reason: '${l.code} script');
        expect(inScript(l.ownName, l.script!), isTrue, reason: l.code);
        expect(RegExp(r'^[a-z]{3}$').hasMatch(l.iso639_3), isTrue);
        expect(isos.add(l.iso639_3), isTrue, reason: '${l.iso639_3} twice');
        expect(families, contains(l.family), reason: l.code);
      }
    });

    test('a sentence of the sheet is in the language\'s own script, and '
        'the approved Bengali and Hindi ones are as approved', () {
      for (final l in languages.where((l) => l.asksInOwnScript)) {
        expect(inScript(l.scriptQuestion!, l.script!), isTrue, reason: l.code);
        expect(inScript(l.scriptCanRead!, l.script!), isTrue, reason: l.code);
      }
      final bn = languages.firstWhere((l) => l.code == 'bn');
      expect(bn.scriptQuestion, 'আপনি কি বাংলা লিপি পড়তে পারেন?');
      expect(bn.scriptCanRead, 'আমি বাংলা লিপি পড়তে পারি');
      final hi = languages.firstWhere((l) => l.code == 'hi');
      expect(hi.scriptQuestion, 'क्या आपको हिंदी लिपि पढ़नी आती है?');
      expect(hi.scriptCanRead, 'मुझे हिंदी लिपि पढ़नी आती है');
    });

    test('a script is named as the deck files name it', () {
      final used = <String>{
        for (final f in Directory('decks').listSync(recursive: true))
          if (f is File && f.path.endsWith('.yaml'))
            ...RegExp(r'language:.*?script: "?([a-z_]+)')
                .allMatches(f.readAsStringSync())
                .map((m) => m.group(1)!),
      };
      final ours = <String, String>{
        for (final l in languages) l.code: l.script!,
      };
      expect(ours['te'], 'telugu');
      expect(ours['gu'], 'gujarati');
      expect(ours['kn'], 'kannada');
      // The IPA course's script is no spoken language's (ADR-0041).
      for (final script in used.difference(<String>{'kana', 'ipa'})) {
        expect(ours.values, contains(script), reason: script);
      }
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
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'script_question: "Q?" }\n',
          'come together',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'family: "Not A Family" }\n',
          'family',
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

  /// The language [text] is marked as, for a screen reader, or null.
  Locale? markedAs(WidgetTester tester, Finder text) {
    Locale? found;
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)).first,
    );
    paragraph.text.visitChildren((span) {
      if (span is TextSpan && span.locale != null) found = span.locale;
      return true;
    });
    return found;
  }

  Future<AppState> openPage(WidgetTester tester, [SettingsNotifier? s]) =>
      pumpScreen(
        tester,
        const SpokenLanguagesPage(),
        state: AppState.test(settings: s ?? SettingsNotifier()),
      );

  group('Languages you know (#490)', () {
    testWidgets('is named so, in Settings and on the first launch', (
      tester,
    ) async {
      usePhone(tester);
      await openPage(
        tester,
        SettingsNotifier(spokenLanguages: const <String>['en']),
      );
      final l10n = l10nOf(tester);
      expect(find.text('Languages you know'), findsOneWidget);
      expect(l10n.settingsSpoken, 'Languages I know');
      expect(l10n.onboardingSpokenTitle, contains('know'));
    });

    testWidgets('starts with every family folded, and says so', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await openPage(tester);
      final l10n = l10nOf(tester);
      for (final id in <String>[
        'indo_aryan',
        'dravidian',
        'tibeto_burman',
        'austroasiatic',
        'germanic',
      ]) {
        expect(find.byKey(ValueKey<String>('family-$id')), findsOneWidget);
      }
      // No language row is shown: only the top picks' chips.
      expect(find.byType(ActionChip), findsWidgets);
      expect(find.byKey(const ValueKey<String>('lang-bn')), findsNothing);
      final indoAryan = l10n.knownFamily('indo_aryan');
      expect(
        find.bySemanticsLabel(l10n.knownFamilyCollapsed(indoAryan, 24)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('family-indo_aryan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('lang-bn')), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.knownFamilyExpanded(indoAryan, 24)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('family-indo_aryan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('lang-bn')), findsNothing);
      semantics.dispose();
    });

    testWidgets('the search finds a language by its English or its own '
        'name, whatever is folded', (tester) async {
      usePhone(tester);
      await openPage(tester);
      final l10n = l10nOf(tester);
      final search = find.byKey(const ValueKey<String>('known-search'));
      await tester.enterText(search, 'hin');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('lang-hi')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('lang-bn')), findsNothing);
      await tester.enterText(search, 'বাং');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('lang-bn')), findsOneWidget);
      await tester.enterText(search, 'tel');
      await tester.pumpAndSettle();
      // Telugu is Dravidian, which was folded.
      expect(find.byKey(const ValueKey<String>('lang-te')), findsOneWidget);
      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text(l10n.knownSearchNone('zzz')), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('lang-te')), findsNothing);
    });

    testWidgets('a tap opens the sheet, which asks in the language\'s own '
        'script only, and one tap answers language and script', (tester) async {
      usePhone(tester);
      final state = await openPage(tester);
      final l10n = l10nOf(tester);
      for (final (name, code, question, read, speak, answered)
          in <(String, String, String, String, String, String)>[
            (
              'Bengali',
              'bn',
              'আপনি কি বাংলা লিপি পড়তে পারেন?',
              'আমি বাংলা লিপি পড়তে পারি',
              'I can only speak Bengali',
              'Can read the Bengali script',
            ),
            (
              'Hindi',
              'hi',
              'क्या आपको हिंदी लिपि पढ़नी आती है?',
              'मुझे हिंदी लिपि पढ़नी आती है',
              'I can only speak Hindi',
              'Can only speak Hindi',
            ),
          ]) {
        await tester.enterText(
          find.byKey(const ValueKey<String>('known-search')),
          name,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey<String>('lang-$code')));
        await tester.pumpAndSettle();
        // The question and "can read" are in the language's own script,
        // marked as that language, with no English under either.
        expect(find.text(question), findsOneWidget);
        expect(find.text(read), findsOneWidget);
        expect(markedAs(tester, find.text(question)), Locale(code));
        expect(markedAs(tester, find.text(read)), Locale(code));
        expect(find.text(speak), findsOneWidget);
        expect(find.text(l10n.knownReadsScript('x', name)), findsNothing);
        expect(find.text(l10n.knownCanReadFallback(name)), findsNothing);
        // Never Yes or No.
        expect(find.text('Yes'), findsNothing);
        expect(find.text('No'), findsNothing);
        // Not chosen yet: nothing to remove.
        expect(find.byKey(const ValueKey<String>('know-remove')), findsNothing);
        await tester.tap(
          find.byKey(
            ValueKey<String>(code == 'bn' ? 'know-read' : 'know-speak'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(question), findsNothing, reason: 'the sheet closed');
        await tester.enterText(
          find.byKey(const ValueKey<String>('known-search')),
          '',
        );
        await tester.pumpAndSettle();
        expect(find.text(answered), findsOneWidget, reason: name);
      }
      // Saved only by Save.
      expect(state.settings.spokenLanguages, isEmpty);
      await tester.tap(find.text(l10n.knownSave));
      await tester.pumpAndSettle();
      expect(state.settings.spokenLanguages, ['bn', 'hi']);
      expect(state.settings.scriptsRead, <String, bool>{
        'bn': true,
        'hi': false,
      });
    });

    testWidgets('a language with no sentences of its own yet is asked in '
        'English', (tester) async {
      usePhone(tester);
      await openPage(tester);
      final l10n = l10nOf(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Telugu',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-te')));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.knownReadsScript('telugu', 'Telugu')),
        findsOneWidget,
      );
      expect(find.text(l10n.knownCanReadFallback('Telugu')), findsOneWidget);
      expect(find.text(l10n.knownSpeakOnly('Telugu')), findsOneWidget);
    });

    testWidgets('a chosen language reopens its sheet, marked, and can be '
        'removed; Cancel changes nothing', (tester) async {
      usePhone(tester);
      final settings = SettingsNotifier(spokenLanguages: const <String>['bn'])
        ..scriptsRead = const <String, bool>{'bn': false};
      final state = await openPage(tester, settings);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.knownYourLanguages), findsOneWidget);
      expect(find.text(l10n.knownAnswerSpeak('Bengali')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('lang-bn')));
      await tester.pumpAndSettle();
      // Its answer is marked.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('know-cancel')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.knownAnswerSpeak('Bengali')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('lang-bn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.knownRemove('Bengali')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.knownYourLanguages), findsNothing);
      final save = find.widgetWithText(FilledButton, l10n.knownSave);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.text(l10n.onboardingSpokenNeedOne), findsOneWidget);
      expect(state.settings.spokenLanguages, ['bn'], reason: 'not saved');
    });

    testWidgets('a chosen language\'s answer can be changed in one tap', (
      tester,
    ) async {
      usePhone(tester);
      final settings = SettingsNotifier(spokenLanguages: const <String>['bn'])
        ..scriptsRead = const <String, bool>{'bn': false};
      await openPage(tester, settings);
      final l10n = l10nOf(tester);
      await tester.tap(find.byKey(const ValueKey<String>('lang-bn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('know-read')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.knownSave));
      await tester.pumpAndSettle();
      expect(settings.scriptsRead, <String, bool>{'bn': true});
      expect(settings.spokenLanguages, ['bn']);
    });

    testWidgets('both answers stay in view at 2x text', (tester) async {
      usePhone(tester, textScale: 2.0, navBar: true);
      await openPage(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Bengali',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-bn')));
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(BottomSheet));
      for (final key in <String>['know-read', 'know-speak']) {
        final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
        expect(rect.height, greaterThanOrEqualTo(48), reason: key);
        expect(sheet.contains(rect.center), isTrue, reason: key);
        // Above the 3-button bar (#489).
        expect(rect.bottom, lessThanOrEqualTo(844 - navBarHeight), reason: key);
      }
    });

    testWidgets('Back leaves without saving, Save waits for a language and '
        'text starts on the 24 px line', (tester) async {
      usePhone(tester);
      final state = await pumpApp(tester);
      final l10n = l10nOf(tester);
      unawaited(
        AppNavigator.openSpokenLanguages(tester.element(find.byType(AppShell))),
      );
      await tester.pumpAndSettle();
      expect(textStart(tester, find.text(l10n.spokenBody)), 24);
      expect(textStart(tester, find.text(l10n.knownYourLanguages)), 24);
      // English, the test state's language, starts chosen.
      await knowLanguage(tester, 'Hindi', reads: false);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.spokenTitle), findsNothing);
      expect(state.settings.spokenLanguages, ['en']);
    });

    testWidgets('Save keeps the order chosen in and goes back', (tester) async {
      usePhone(tester);
      final state = await pumpApp(tester);
      final l10n = l10nOf(tester);
      unawaited(
        AppNavigator.openSpokenLanguages(tester.element(find.byType(AppShell))),
      );
      await tester.pumpAndSettle();
      await knowLanguage(tester, 'Hindi');
      await tester.tap(find.text(l10n.knownSave));
      await tester.pumpAndSettle();
      expect(state.settings.spokenLanguages, ['en', 'hi']);
      expect(state.settings.scriptsRead['hi'], isTrue);
      expect(find.text(l10n.spokenTitle), findsNothing);
    });

    testWidgets('the first launch shows the same screen, with Continue', (
      tester,
    ) async {
      usePhone(tester);
      final choices = parseSpokenLanguages(
        File(SpokenLanguagesPage.asset).readAsStringSync(),
      );
      await pumpScreen(
        tester,
        OnboardingFlow(startAt: 'spoken', choices: choices),
      );
      final l10n = l10nOf(tester);
      expect(find.byType(SpokenLanguagesPicker), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('known-search')),
        findsOneWidget,
      );
      expect(textStart(tester, find.text(l10n.onboardingSpokenTitle)), 24);
      expect(textStart(tester, find.text(l10n.onboardingSpokenBody)), 24);
      expect(find.text(l10n.onboardingSpokenNeedOne), findsOneWidget);
      await knowLanguage(tester, 'Bengali');
      expect(find.text(l10n.onboardingSpokenNeedOne), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.commonContinue),
            )
            .onPressed,
        isNotNull,
      );
    });

    test('the top picks are the phone\'s language, English, then its '
        'region\'s, only of the languages listed', () {
      final all = parseSpokenLanguages(
        File(SpokenLanguagesPage.asset).readAsStringSync(),
      );
      expect(topPicksFor(const <(String, String?)>[('en', 'IN')], all), [
        'en',
        'hi',
        'bn',
        'te',
      ]);
      expect(topPicksFor(const <(String, String?)>[('te', 'IN')], all), [
        'te',
        'en',
        'hi',
        'bn',
      ]);
      expect(topPicksFor(const <(String, String?)>[('fr', 'FR')], all), ['en']);
      expect(topPicksFor(const <(String, String?)>[], all), ['en']);
    });

    testWidgets('the top picks open the sheet too', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        SpokenLanguagesPage(
          choices: parseSpokenLanguages(
            File(SpokenLanguagesPage.asset).readAsStringSync(),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('pick-en')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('know-read')), findsOneWidget);
    });
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
