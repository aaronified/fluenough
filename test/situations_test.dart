import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/situations/situation_inspect_page.dart';
import 'package:fluenough/features/situations/situation_page.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/situations_parser.dart';

import 'support/harness.dart';
import 'support/ipa_course.dart';

const String _file = '''
schema: 1
id: te-situations
name: "Telugu situations"
kind: situations
language: { code: te, iso639_3: tel, name: Telugu, script: telugu, tts: te-IN }
license: "CC-BY-SA-4.0"
situations:
  - id: taxi
    icon: taxi
    title: { en: "Taxi", bn: "ট্যাক্সি" }
    phrases: ["te-0275"]
    words: ["te-0273", "te-0274"]
''';

void main() {
  test('a situations file lists card ids, phrases then words, and titles '
      'in the learner\'s language', () {
    final file = parseSituations(_file, source: 'te-situations.yaml');
    final taxi = file.byId('taxi')!;
    expect(taxi.cardIds, <String>['te-0275', 'te-0273', 'te-0274']);
    expect(taxi.titleFor(<String>['hi', 'bn']), 'ট্যাক্সি');
    expect(taxi.titleFor(<String>['hi']), 'Taxi');
    expect(file.withIcon('taxi'), same(taxi));
  });

  test('a sheet that lists no card is refused, as a broken file', () {
    final broken = _file
        .replaceAll('    phrases: ["te-0275"]\n', '')
        .replaceAll('    words: ["te-0273", "te-0274"]\n', '');
    expect(
      () => parseSituations(broken, source: 'te-situations.yaml'),
      throwsA(isA<DeckParseException>()),
    );
    expect(
      DeckCatalog.checkFile('decks/te/te-situations.yaml', broken),
      isNotNull,
    );
    expect(DeckCatalog.checkFile('decks/te/te-situations.yaml', _file), isNull);
  });

  group('a sheet\'s cards', () {
    const hindi = '''
schema: 1
id: hi-situations
name: "Hindi situations"
kind: situations
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
license: "CC-BY-SA-4.0"
situations:
  - id: rail
    icon: rail
    title: { en: "Rail station" }
    phrases: ["hi-0001", "hi-0002"]
    words: ["hi-0003"]
''';

    Future<void> pumpInspect(WidgetTester tester) async {
      usePhone(tester);
      final state = AppState.test(
        decks: MemoryDeckSource(<String, String>{
          ...ipaFiles,
          'decks/hi/hi-en-words.yaml': ipaFiles['decks/hi/hi-en-words.yaml']!
              .replaceFirst(
                'ipa: "pʰəɳ",',
                'ipa: "pʰəɳ", bases: [{ word: "पत्ता", base: "पत्र", '
                    'reading: "patra" }],',
              ),
          'decks/hi/hi-situations.yaml': hindi,
        }),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
          learningChosen: true,
        ),
        tts: const NullTtsEngine(),
      );
      await pumpScreen(
        tester,
        const SituationInspectPage(
          request: SituationRequest(language: 'hi', situationId: 'rail'),
        ),
        state: state,
      );
    }

    testWidgets('are swiped between, with no chevrons and no Open in deck, '
        'and the IPA\'s sounds are behind its info dot', (tester) async {
      await pumpInspect(tester);
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.situationInspectTitle('Rail station', 1, 3)),
        findsOneWidget,
      );
      // The meaning shows, and the root word, which the page scrolls to;
      // nothing else of the word sheet.
      expect(find.text('leaf'), findsOneWidget);
      expect(find.textContaining('पत्र', findRichText: true), findsOneWidget);
      expect(find.text(l10n.cardReport), findsNothing);
      expect(find.textContaining('hi-0001'), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text('Open in deck'), findsNothing);
      // The sounds are not drawn until the dot is tapped.
      expect(find.text(l10n.ipaSymbolPractise), findsNothing);
      await tester.tap(find.byTooltip(l10n.ipaInfoDot));
      await tester.pumpAndSettle();
      expect(find.text('the sound ɳ'), findsOneWidget);
      expect(find.text(l10n.ipaSymbolPractise), findsWidgets);
      await tester.tap(find.text(l10n.commonClose));
      await tester.pumpAndSettle();

      await tester.fling(find.text('leaf'), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.situationInspectTitle('Rail station', 2, 3)),
        findsOneWidget,
      );
      expect(find.text('tomorrow'), findsOneWidget);
    });
  });
}
