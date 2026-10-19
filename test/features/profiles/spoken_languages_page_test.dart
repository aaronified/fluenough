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
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/script_name.dart';

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
      'perso_arabic': <(int, int)>[
        (0x600, 0x6FF),
        (0x750, 0x77F),
        (0xFB50, 0xFDFF),
      ],
      'gujarati': <(int, int)>[(0xA80, 0xAFF)],
      'gurmukhi': <(int, int)>[(0xA00, 0xA7F)],
      'odia': <(int, int)>[(0xB00, 0xB7F)],
      'tamil': <(int, int)>[(0xB80, 0xBFF)],
      'telugu': <(int, int)>[(0xC00, 0xC7F)],
      'kannada': <(int, int)>[(0xC80, 0xCFF)],
      'malayalam': <(int, int)>[(0xD00, 0xD7F)],
      'ol_chiki': <(int, int)>[(0x1C50, 0x1C7F)],
      'arabic': <(int, int)>[(0x600, 0x6FF), (0x750, 0x77F), (0xFB50, 0xFDFF)],
      'shahmukhi': <(int, int)>[
        (0x600, 0x6FF),
        (0x750, 0x77F),
        (0xFB50, 0xFDFF),
      ],
      'meitei_mayek': <(int, int)>[(0xABC0, 0xABFF), (0xAAE0, 0xAAFF)],
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
      expect(languages, hasLength(34));
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
        for (final script in l.scripts) {
          expect(blocks, contains(script), reason: '${l.code} $script');
        }
        // Its own name is in one of its scripts, or in two, joined by a dot
        // (Hindustani: Devanagari and Perso-Arabic).
        for (final part in l.ownName.split(' · ')) {
          expect(
            l.scripts.any((s) => inScript(part, s)),
            isTrue,
            reason: '${l.code} $part',
          );
        }
        expect(RegExp(r'^[a-z]{3}$').hasMatch(l.iso639_3), isTrue);
        expect(isos.add(l.iso639_3), isTrue, reason: '${l.iso639_3} twice');
        expect(families, contains(l.family), reason: l.code);
      }
    });

    test('a sentence of the sheet is in the language\'s own script, and '
        'the approved Bengali one is as approved', () {
      for (final l in languages.where((l) => l.asksInOwnScript)) {
        expect(inScript(l.scriptQuestion!, l.script!), isTrue, reason: l.code);
        expect(inScript(l.scriptCanRead!, l.script!), isTrue, reason: l.code);
      }
      final bn = languages.firstWhere((l) => l.code == 'bn');
      expect(bn.scriptQuestion, 'আপনি কি পূর্ব নাগরী লিপি পড়তে পারেন?');
      expect(bn.scriptCanRead, 'আমি পূর্ব নাগরী লিপি পড়তে পারি');
      // Hindustani reads in two scripts (#623): the Devanagari answer is the
      // approved Hindi one.
      final hi = languages.firstWhere((l) => l.code == 'hi');
      expect(hi.canReadIn('devanagari'), 'मुझे देवनागरी लिपि पढ़नी आती है');
    });

    test('Urdu has no entry of its own: a search for Urdu or Hindi finds '
        'Hindustani (#623)', () {
      expect(languages.any((l) => l.code == 'ur'), isFalse);
      for (final query in ['Urdu', 'urdu', 'Hindi', 'اردو', 'हिन्दी']) {
        expect(languages.where((l) => l.matches(query)).map((l) => l.code), [
          'hi',
        ], reason: query);
      }
    });

    test('every language not written in Latin has both texts of its sheet, '
        'in its own first script (#552)', () {
      for (final l in languages.where((l) => l.script != 'latin')) {
        final script = l.script!;
        if (l.hasSeveralScripts) {
          expect(l.scriptsQuestion, isNotNull, reason: l.code);
          expect(inScript(l.scriptsQuestion!, script), isTrue, reason: l.code);
          for (final s in l.scripts) {
            final text = l.scriptCanReadFor[s];
            expect(text, isNotNull, reason: '${l.code} $s');
            expect(inScript(text!, script), isTrue, reason: '${l.code} $s');
          }
        } else {
          expect(l.scriptQuestion, isNotNull, reason: l.code);
          expect(l.scriptCanRead, isNotNull, reason: l.code);
          expect(inScript(l.scriptQuestion!, script), isTrue, reason: l.code);
          expect(inScript(l.scriptCanRead!, script), isTrue, reason: l.code);
        }
      }
    });

    test('an entry marked unchecked still shows its own texts: only en and bn '
        'are checked, and every entry with texts asks in its own script '
        '(owner, 2026-10-18)', () {
      for (final l in languages) {
        final checked = <String>{'en', 'bn'}.contains(l.code);
        expect(
          l.scriptTextUnchecked,
          !checked && l.script != 'latin',
          reason: l.code,
        );
        if (l.script == 'latin' && !checked) continue;
        if (l.hasSeveralScripts) {
          expect(l.asksScriptsInOwnScript, isTrue, reason: l.code);
          for (final s in l.scripts) {
            expect(l.canReadIn(s), isNotNull, reason: '${l.code} $s');
          }
        } else {
          expect(l.asksInOwnScript, isTrue, reason: l.code);
        }
      }
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
      // A deck may be in any of its language's scripts, as Hindustani's
      // Perso-Arabic script decks are (#623).
      final listed = <String>{for (final l in languages) ...l.scripts};
      // The IPA course's script is no spoken language's (ADR-0041).
      for (final script in used.difference(<String>{'kana', 'ipa'})) {
        expect(listed, contains(script), reason: script);
      }
    });

    test('a language lists its scripts, its own first, as the owner set '
        'them (#551)', () {
      const several = <String, List<String>>{
        'pa': <String>['gurmukhi', 'shahmukhi'],
        'hi': <String>['devanagari', 'perso_arabic'],
        'sd': <String>['arabic', 'devanagari'],
        'ks': <String>['arabic', 'devanagari'],
        'kok': <String>['devanagari', 'kannada', 'malayalam'],
        'sat': <String>['ol_chiki', 'latin', 'devanagari', 'bengali'],
        'mni': <String>['bengali', 'meitei_mayek'],
      };
      const one = <String, String>{
        'en': 'latin',
        'bn': 'bengali',
        'as': 'bengali',
        'gu': 'gujarati',
        'kn': 'kannada',
        'tcy': 'kannada',
        'ml': 'malayalam',
        'or': 'odia',
        'ta': 'tamil',
        'te': 'telugu',
        'gom': 'latin',
        'kha': 'latin',
        'lus': 'latin',
      };
      for (final l in languages) {
        if (several[l.code] case final scripts?) {
          expect(l.scripts, scripts, reason: l.code);
          expect(l.hasSeveralScripts, isTrue, reason: l.code);
        } else {
          expect(l.scripts, [one[l.code] ?? 'devanagari'], reason: l.code);
          expect(l.hasSeveralScripts, isFalse, reason: l.code);
        }
        expect(l.script, l.scripts.first, reason: l.code);
      }
    });

    test('every script is named by its own name, never by a language\'s '
        '(#551)', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final names = <String, String>{
        for (final l in languages)
          for (final s in l.scripts) s: l10n.scriptName(s),
      };
      expect(names, <String, String>{
        'latin': 'Latin',
        'bengali': 'Eastern Nagari',
        'devanagari': 'Devanagari',
        'perso_arabic': 'Perso-Arabic',
        'gujarati': 'Gujarati',
        'kannada': 'Kannada',
        'arabic': 'Perso-Arabic',
        'malayalam': 'Malayalam',
        'meitei_mayek': 'Meitei Mayek',
        'odia': 'Odia',
        'gurmukhi': 'Gurmukhi',
        'shahmukhi': 'Shahmukhi',
        'ol_chiki': 'Ol Chiki',
        'tamil': 'Tamil',
        'telugu': 'Telugu',
      });
      // A script no language here uses yet has no name, and is named after
      // its language.
      expect(l10n.scriptName('zz_script'), isEmpty);
      expect(l10n.scriptNameOr('zz_script', 'Testlang'), 'Testlang');
      expect(l10n.scriptNameOr(null, 'Testlang'), 'Testlang');
      expect(l10n.scriptNameOr('bengali', 'Assamese'), 'Eastern Nagari');
    });

    test('a list written before #551, with one `script`, still reads', () {
      final old = parseSpokenLanguages(
        'kind: languages\nlanguages:\n'
        '  - { code: bn, iso639_3: ben, name: B, own_name: B, '
        'script: bengali }\n'
        '  - { code: en, iso639_3: eng, name: E, own_name: E }\n',
      );
      expect(old.first.scripts, ['bengali']);
      expect(old.first.script, 'bengali');
      expect(old.last.scripts, isEmpty);
      expect(old.last.script, isNull);
      // A language with no script listed is still answered under its code.
      expect(old.last.readAnswers(['']), <String, bool>{'en': true});
      expect(old.last.scriptsReadIn(const <String, bool>{'en': true}), ['']);
      expect(old.last.scriptsReadIn(const <String, bool>{'en': false}), []);
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
              'scripts_question: "Q?", script_can_read: { latin: "R" } }\n',
          'only for several scripts',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'scripts: [latin, kana], script_can_read: { latin: "R" } }\n',
          'come together',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'script_text: "checked" }\n',
          'script_text',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'family: "Not A Family" }\n',
          'family',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'script: latin, scripts: [latin] }\n',
          'both given',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'scripts: [] }\n',
          'scripts is malformed',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'scripts: [latin, latin] }\n',
          'scripts is malformed',
        ),
        (
          'kind: languages\nlanguages:\n'
              '  - { code: en, iso639_3: eng, name: E, own_name: E, '
              'scripts: [Latin] }\n',
          'scripts is malformed',
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

    test('a learner who knew Urdu knows Hindustani, reading its Perso-Arabic '
        'script, at Urdu\'s rank (#623)', () {
      final one = SettingsNotifier()
        ..restore(const {
          'spoken_languages': 'bn,ur,en',
          'scripts_read': '{"bn":true,"ur":true}',
        });
      expect(one.spokenLanguages, ['bn', 'hi', 'en']);
      expect(one.rankOf('hi'), 1);
      expect(one.scriptsRead, <String, bool>{
        'bn': true,
        'hi': false,
        'hi:perso_arabic': true,
      });
      final hindustani = parseSpokenLanguages(
        File(SpokenLanguagesPage.asset).readAsStringSync(),
      ).firstWhere((l) => l.code == 'hi');
      expect(hindustani.scriptsReadIn(one.scriptsRead), ['perso_arabic']);
      // Both known: Hindustani keeps the better rank and its own answers.
      final both = SettingsNotifier()
        ..restore(const {
          'spoken_languages': 'ur,bn,hi',
          'scripts_read': '{"hi":true,"hi:perso_arabic":false,"ur":true}',
        });
      expect(both.spokenLanguages, ['hi', 'bn']);
      expect(hindustani.scriptsReadIn(both.scriptsRead), [
        'devanagari',
        'perso_arabic',
      ]);
      expect(both.scriptsRead.containsKey('ur'), isFalse);
      // Knowing Urdu without reading its script says nothing more.
      final spoken = SettingsNotifier()
        ..restore(const {
          'spoken_languages': 'ur',
          'scripts_read': '{"ur":false}',
        });
      expect(spoken.spokenLanguages, ['hi']);
      expect(hindustani.scriptsReadIn(spoken.scriptsRead), isEmpty);
      // Saved again, it reads the same.
      final again = SettingsNotifier()..restore(one.toStored());
      expect(again.spokenLanguages, one.spokenLanguages);
      expect(again.scriptsRead, one.scriptsRead);
    });

    test('keeps the scripts read per language and script (#551), and reads '
        'a save from before as the language\'s own script', () {
      final punjabi = parseSpokenLanguages(
        File(SpokenLanguagesPage.asset).readAsStringSync(),
      ).firstWhere((l) => l.code == 'pa');
      expect(punjabi.readKey('gurmukhi'), 'pa');
      expect(punjabi.readKey('shahmukhi'), 'pa:shahmukhi');
      expect(punjabi.readAnswers(['shahmukhi']), <String, bool>{
        'pa': false,
        'pa:shahmukhi': true,
      });
      // Before #551 a language had one answer, under its code.
      final old = SettingsNotifier()
        ..restore(const {'scripts_read': '{"pa":true,"bn":false}'});
      expect(punjabi.scriptsReadIn(old.scriptsRead), ['gurmukhi']);
      expect(punjabi.scriptsReadIn(const <String, bool>{}), isNull);
      final settings = SettingsNotifier()
        ..scriptsRead = const <String, bool>{
          'pa': false,
          'pa:shahmukhi': true,
          'bn': true,
        };
      final back = SettingsNotifier()..restore(settings.toStored());
      expect(back.scriptsRead, settings.scriptsRead);
      expect(punjabi.scriptsReadIn(back.scriptsRead), ['shahmukhi']);
      final junk = SettingsNotifier()
        ..restore(const {
          'scripts_read': '{"pa:Shahmukhi":true,"x:":true,"pa:x":1}',
        });
      expect(junk.scriptsRead, isEmpty);
      expect(readAnswersOf(['pa'], settings.scriptsRead), <String, bool>{
        'pa': false,
        'pa:shahmukhi': true,
      });
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
        find.bySemanticsLabel(l10n.knownFamilyCollapsed(indoAryan, 23)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('family-indo_aryan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('lang-bn')), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.knownFamilyExpanded(indoAryan, 23)),
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
        'script with the English under it, and one tap answers language and '
        'script', (tester) async {
      usePhone(tester);
      final state = await openPage(tester);
      final l10n = l10nOf(tester);
      for (final (name, code, question, read, speak, answered, english)
          in <(String, String, String, String, String, String, String)>[
            (
              'Bengali',
              'bn',
              'আপনি কি পূর্ব নাগরী লিপি পড়তে পারেন?',
              'আমি পূর্ব নাগরী লিপি পড়তে পারি',
              'I can only speak Bengali',
              'Can read the Eastern Nagari script',
              'Eastern Nagari',
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
        // marked as that language, with the English under each.
        expect(find.text(question), findsOneWidget);
        expect(find.text(read), findsOneWidget);
        expect(markedAs(tester, find.text(question)), Locale(code));
        expect(markedAs(tester, find.text(read)), Locale(code));
        expect(find.text(speak), findsOneWidget);
        expect(find.text('Do you read the $english script?'), findsOne);
        expect(find.text('I can read the $english script'), findsOne);
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
      expect(state.settings.spokenLanguages, ['bn']);
      expect(state.settings.scriptsRead, <String, bool>{'bn': true});
    });

    testWidgets('a language with no sentences of its own is asked in '
        'English, naming its script by the script\'s own name (#551, #552)', (
      tester,
    ) async {
      usePhone(tester);
      await openPage(tester);
      final l10n = l10nOf(tester);
      for (final (name, code, question, read)
          in <(String, String, String, String)>[
            // A language with no texts of its own: the Latin ones.
            (
              'Mizo',
              'lus',
              'Do you read the Latin script?',
              'I can read the Latin script',
            ),
            (
              'Khasi',
              'kha',
              'Do you read the Latin script?',
              'I can read the Latin script',
            ),
          ]) {
        await tester.enterText(
          find.byKey(const ValueKey<String>('known-search')),
          name,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey<String>('lang-$code')));
        await tester.pumpAndSettle();
        expect(find.text(question), findsOneWidget, reason: name);
        expect(find.text(read), findsOneWidget, reason: name);
        expect(find.text(l10n.knownSpeakOnly(name)), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey<String>('know-cancel')));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the unchecked Assamese texts are shown, with the English '
        'under them (owner, 2026-10-18)', (tester) async {
      usePhone(tester);
      await openPage(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Assamese',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-as')));
      await tester.pumpAndSettle();
      final own = find.text('আপুনি পূব নাগৰী লিপি পঢ়িব পাৰেনে?');
      expect(own, findsOne);
      expect(markedAs(tester, own), const Locale('as'));
      expect(find.text('Do you read the Eastern Nagari script?'), findsOne);
      expect(find.text('I can read the Eastern Nagari script'), findsOne);
    });

    testWidgets('a checked multi-script entry (no script_text) asks in its own '
        'script, heading and rows (#552)', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        SpokenLanguagesPage(
          choices: parseSpokenLanguages(
            'kind: languages\nlanguages:\n'
            '  - { code: "pa", iso639_3: "pan", name: "Punjabi", '
            'own_name: "ਪੰਜਾਬੀ", scripts: ["gurmukhi", "shahmukhi"], '
            'scripts_question: "ਕਿਹੜੀਆਂ ਲਿਪੀਆਂ?", script_can_read: { '
            'gurmukhi: "ਗੁਰਮੁਖੀ ਪੜ੍ਹਨੀ ਆਉਂਦੀ ਹੈ" } }\n',
          ),
        ),
        state: AppState.test(settings: SettingsNotifier()),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Punjabi',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-pa')));
      await tester.pumpAndSettle();
      final heading = find.text('ਕਿਹੜੀਆਂ ਲਿਪੀਆਂ?');
      expect(heading, findsOneWidget);
      expect(markedAs(tester, heading), const Locale('pa'));
      expect(find.text('ਗੁਰਮੁਖੀ ਪੜ੍ਹਨੀ ਆਉਂਦੀ ਹੈ'), findsOneWidget);
      // The script with no text of its own is asked in English.
      expect(find.text('I can read the Shahmukhi script'), findsOneWidget);
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
      await knowLanguage(tester, 'Hindustani', reads: false);
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
      await knowLanguage(tester, 'Hindustani');
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

  group(
    'the sheet asks in the own script, English below (owner, 2026-10-18)',
    () {
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        testWidgets('Kannada at 1.4x text, ${mode.name}: the own-script '
            'question with the English below, then both answers', (
          tester,
        ) async {
          usePhone(tester, textScale: 1.4, navBar: true);
          await pumpScreen(
            tester,
            const SpokenLanguagesPage(),
            state: AppState.test(settings: SettingsNotifier()),
            themeMode: mode,
          );
          final l10n = l10nOf(tester);
          await tester.enterText(
            find.byKey(const ValueKey<String>('known-search')),
            'Kannada',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey<String>('lang-kn')));
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          final box = tester.getRect(sheet);
          final own = find.text('ನೀವು ಕನ್ನಡ ಲಿಪಿಯನ್ನು ಓದಬಲ್ಲಿರಾ?');
          final english = find.text('Do you read the Kannada script?');
          expect(own, findsOneWidget);
          expect(english, findsOneWidget);
          expect(markedAs(tester, own), const Locale('kn'));
          expect(
            tester.getRect(own).bottom,
            lessThanOrEqualTo(tester.getRect(english).top),
          );
          final read = find.byKey(const ValueKey<String>('know-read'));
          expect(
            find.descendant(
              of: read,
              matching: find.text('ನಾನು ಕನ್ನಡ ಲಿಪಿಯನ್ನು ಓದಬಲ್ಲೆ'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: read,
              matching: find.text('I can read the Kannada script'),
            ),
            findsOneWidget,
          );
          // A learner who only speaks Kannada picks the English answer.
          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('know-speak')),
              matching: find.text(l10n.knownSpeakOnly('Kannada')),
            ),
            findsOneWidget,
          );
          for (final f in <Finder>[own, english, read]) {
            final rect = tester.getRect(f);
            expect(rect.top, greaterThanOrEqualTo(box.top));
            expect(rect.right, lessThanOrEqualTo(box.right));
            expect(rect.left, greaterThanOrEqualTo(box.left));
            expect(rect.bottom, lessThanOrEqualTo(844 - navBarHeight));
          }
        });
      }
    },
  );

  group('Report a mistake on unchecked texts (owner, 2026-10-18)', () {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('Kannada, unchecked: a bug icon of 48 dp opens the report '
          'with the language and the texts; at 1.4x, ${mode.name}', (
        tester,
      ) async {
        usePhone(tester, textScale: 1.4, navBar: true);
        await pumpScreen(
          tester,
          const SpokenLanguagesPage(),
          state: AppState.test(settings: SettingsNotifier()),
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        await tester.enterText(
          find.byKey(const ValueKey<String>('known-search')),
          'Kannada',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey<String>('lang-kn')));
        await tester.pumpAndSettle();
        final icon = find.byKey(const ValueKey<String>('know-report'));
        expect(icon, findsOneWidget);
        expect(find.byTooltip(l10n.knownReportMistake), findsOneWidget);
        final rect = tester.getRect(icon);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(
          rect.right,
          lessThanOrEqualTo(tester.getRect(find.byType(BottomSheet)).right),
        );
        await tester.tap(icon);
        await tester.pumpAndSettle();
        final detail = tester
            .widget<ReportPage>(find.byType(ReportPage))
            .request
            .detail!;
        expect(detail, contains('kn'));
        expect(detail, contains('question: ನೀವು ಕನ್ನಡ ಲಿಪಿಯನ್ನು ಓದಬಲ್ಲಿರಾ?'));
        expect(detail, contains('can read: ನಾನು ಕನ್ನಡ ಲಿಪಿಯನ್ನು ಓದಬಲ್ಲೆ'));
      });
    }

    testWidgets('Bengali, checked: no bug icon', (tester) async {
      usePhone(tester);
      await openPage(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Bengali',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-bn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('know-read')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('know-report')), findsNothing);
    });
  });

  group('the sheet names its language (#553)', () {
    for (final (code, query, name, asks) in <(String, String, String, String)>[
      (
        'as',
        'Assamese',
        'Assamese · অসমীয়া',
        'Do you read the Eastern Nagari script?',
      ),
      (
        'pa',
        'Punjabi',
        'Punjabi · ਪੰਜਾਬੀ',
        'Which scripts do you read Punjabi in?',
      ),
    ]) {
      for (final scale in <double>[1.0, 1.4]) {
        for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
          testWidgets('$query: "$name" above the question; at ${scale}x, '
              '${mode.name}', (tester) async {
            usePhone(tester, textScale: scale, navBar: true);
            final semantics = tester.ensureSemantics();
            await pumpScreen(
              tester,
              const SpokenLanguagesPage(),
              state: AppState.test(settings: SettingsNotifier()),
              themeMode: mode,
            );
            await tester.enterText(
              find.byKey(const ValueKey<String>('known-search')),
              query,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(ValueKey<String>('lang-$code')));
            await tester.pumpAndSettle();
            final sheet = find.byType(BottomSheet);
            final line = find.descendant(of: sheet, matching: find.text(name));
            expect(line, findsOneWidget);
            final rect = tester.getRect(line);
            final box = tester.getRect(sheet);
            expect(rect.top, greaterThanOrEqualTo(box.top));
            expect(rect.right, lessThanOrEqualTo(box.right));
            // Above the question.
            final question = tester.getRect(
              find.descendant(of: sheet, matching: find.text(asks)),
            );
            expect(rect.bottom, lessThanOrEqualTo(question.top));
            // A screen reader hears the language first.
            expect(tester.getSemantics(line), matchesSemantics(label: name));
            final nodes = tester.getSemantics(
              find.byKey(const ValueKey<String>('know-language')),
            );
            expect(nodes.rect.top, lessThan(question.top));
            semantics.dispose();
          });
        }
      }
    }
  });

  group('a language written in several scripts (#551)', () {
    Future<void> openPunjabi(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Punjabi',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-pa')));
      await tester.pumpAndSettle();
    }

    FilledButton done(WidgetTester tester) => tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('know-done')),
    );

    for (final (scale, mode) in <(double, ThemeMode)>[
      (1.0, ThemeMode.light),
      (1.0, ThemeMode.dark),
      (1.4, ThemeMode.light),
      (1.4, ThemeMode.dark),
    ]) {
      testWidgets('asks which of Punjabi\'s scripts are read, each by its '
          'own name, and keeps them; at ${scale}x, ${mode.name}', (
        tester,
      ) async {
        usePhone(tester, textScale: scale, navBar: true);
        final state = await pumpScreen(
          tester,
          const SpokenLanguagesPage(),
          state: AppState.test(settings: SettingsNotifier()),
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        await openPunjabi(tester);
        // The unchecked texts are shown, with English under them, naming
        // each script by its own name (#552, owner, 2026-10-18).
        expect(find.text('Which scripts do you read Punjabi in?'), findsOne);
        expect(find.textContaining('ਤੁਸੀਂ'), findsOneWidget);
        final sheet = tester.getRect(find.byType(BottomSheet));
        for (final (key, text) in <(String, String)>[
          ('know-script-gurmukhi', 'I can read the Gurmukhi script'),
          ('know-script-shahmukhi', 'I can read the Shahmukhi script'),
          ('know-speak', 'I can only speak Punjabi'),
          ('know-cancel', l10n.commonCancel),
          ('know-done', l10n.knownScriptsDone),
        ]) {
          final at = find.byKey(ValueKey<String>(key));
          expect(
            find.descendant(of: at, matching: find.text(text)),
            findsOneWidget,
            reason: key,
          );
          final rect = tester.getRect(at);
          expect(rect.height, greaterThanOrEqualTo(48), reason: key);
          expect(rect.top, greaterThanOrEqualTo(sheet.top), reason: key);
          expect(rect.bottom, lessThanOrEqualTo(sheet.bottom), reason: key);
          expect(rect.left, greaterThanOrEqualTo(sheet.left), reason: key);
          expect(rect.right, lessThanOrEqualTo(sheet.right), reason: key);
          // Above the 3-button bar (#489).
          expect(rect.bottom, lessThanOrEqualTo(844 - navBarHeight));
        }
        // No answer read in one tap: nothing is ticked, and Done waits.
        expect(find.byKey(const ValueKey<String>('know-read')), findsNothing);
        expect(done(tester).onPressed, isNull);
        await tester.tap(
          find.byKey(const ValueKey<String>('know-script-shahmukhi')),
        );
        await tester.pumpAndSettle();
        expect(done(tester).onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey<String>('know-done')));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey<String>('known-search')),
          '',
        );
        await tester.pumpAndSettle();
        expect(find.text('Can read the Shahmukhi script'), findsOneWidget);
        await tester.tap(find.text(l10n.knownSave));
        await tester.pumpAndSettle();
        expect(state.settings.spokenLanguages, ['pa']);
        expect(state.settings.scriptsRead, <String, bool>{
          'pa': false,
          'pa:shahmukhi': true,
        });
      });
    }

    testWidgets('Hindustani offers Devanagari and Perso-Arabic, and one who '
        'reads only the second keeps that (#623)', (tester) async {
      usePhone(tester);
      final state = await openPage(tester);
      final l10n = l10nOf(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Hindustani',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-hi')));
      await tester.pumpAndSettle();
      expect(find.text('I can read the Devanagari script'), findsOneWidget);
      expect(find.text('I can read the Perso-Arabic script'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('know-script-perso_arabic')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('know-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.knownSave));
      await tester.pumpAndSettle();
      expect(state.settings.spokenLanguages, contains('hi'));
      expect(state.settings.scriptsRead, <String, bool>{
        'hi': false,
        'hi:perso_arabic': true,
      });
    });

    test('a language with no texts of its own has none to show, so the sheet '
        'falls back to English (#552)', () {
      final l = parseSpokenLanguages(
        'kind: languages\nlanguages:\n'
        '  - { code: "pa", iso639_3: "pan", name: "Punjabi", own_name: "P", '
        'scripts: ["gurmukhi", "shahmukhi"] }\n',
      ).single;
      expect(l.asksScriptsInOwnScript, isFalse);
      expect(l.asksInOwnScript, isFalse);
      expect(l.scriptCanReadFor, isEmpty);
    });

    testWidgets('an entry with no texts is asked in English, heading and '
        'rows (#552)', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        SpokenLanguagesPage(
          choices: parseSpokenLanguages(
            'kind: languages\nlanguages:\n'
            '  - { code: "pa", iso639_3: "pan", name: "Punjabi", '
            'own_name: "ਪੰਜਾਬੀ", scripts: ["gurmukhi", "shahmukhi"] }\n',
          ),
        ),
        state: AppState.test(settings: SettingsNotifier()),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('known-search')),
        'Punjabi',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('lang-pa')));
      await tester.pumpAndSettle();
      expect(find.text('Which scripts do you read Punjabi in?'), findsOne);
      expect(find.text('I can read the Gurmukhi script'), findsOneWidget);
      expect(find.text('I can read the Shahmukhi script'), findsOneWidget);
    });

    testWidgets('reopens with the scripts read ticked, and both read show '
        'both', (tester) async {
      usePhone(tester);
      final settings = SettingsNotifier(spokenLanguages: const <String>['pa'])
        ..scriptsRead = const <String, bool>{'pa': false, 'pa:shahmukhi': true};
      await openPage(tester, settings);
      final l10n = l10nOf(tester);
      await tester.tap(find.byKey(const ValueKey<String>('lang-pa')));
      await tester.pumpAndSettle();
      bool? ticked(String script) => tester
          .widget<CheckboxListTile>(
            find.byKey(ValueKey<String>('know-script-$script')),
          )
          .value;
      expect(ticked('gurmukhi'), isFalse);
      expect(ticked('shahmukhi'), isTrue);
      await tester.tap(
        find.byKey(const ValueKey<String>('know-script-gurmukhi')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('know-done')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          l10n.knownAnswerReadSeveral(
            'Gurmukhi${l10n.commonListSeparator}Shahmukhi',
          ),
        ),
        findsOneWidget,
      );
      // "I can only speak" is one tap, and unticks them all.
      await tester.tap(find.byKey(const ValueKey<String>('lang-pa')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('know-speak')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.knownAnswerSpeak('Punjabi')), findsOneWidget);
      await tester.tap(find.text(l10n.knownSave));
      await tester.pumpAndSettle();
      expect(settings.scriptsRead, <String, bool>{
        'pa': false,
        'pa:shahmukhi': false,
      });
    });

    testWidgets('a save from before #551 reads as the language\'s own '
        'script, and removing the language drops every answer', (tester) async {
      usePhone(tester);
      final settings = SettingsNotifier(
        spokenLanguages: const <String>['pa', 'as'],
      )..restore(const {'scripts_read': '{"pa":true,"as":true}'});
      await openPage(tester, settings);
      final l10n = l10nOf(tester);
      expect(find.text('Can read the Gurmukhi script'), findsOneWidget);
      expect(find.text('Can read the Eastern Nagari script'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('lang-pa')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey<String>('know-script-gurmukhi')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey<String>('know-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.knownSave));
      await tester.pumpAndSettle();
      expect(settings.spokenLanguages, ['as']);
      expect(settings.scriptsRead, <String, bool>{'as': true});
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
