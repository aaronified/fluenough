// The shared reading helpers (#697): readingLines decides what a word's
// reading line and IPA line are, ReadingText draws the reading line, and a
// rules table's cells follow them.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/features/drill/rule_forms.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/ipa_line.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

typedef _Lines = ({String? reading, String? ipa, bool swapped});

AppState _state({required bool ipa, required bool replaces}) => AppState.test(
  settings: SettingsNotifier()
    ..showIpa = ipa
    ..ipaReplacesReading = replaces,
);

Future<_Lines> _lines(
  WidgetTester tester, {
  bool ipa = true,
  required bool replaces,
  String? reading,
  String? ipaText,
  String target = 'పాలు',
  bool showReading = true,
}) async {
  late _Lines out;
  await pumpScreen(
    tester,
    Builder(
      builder: (context) {
        out = readingLines(
          context,
          reading: reading,
          ipa: ipaText,
          target: target,
          showReading: showReading,
        );
        return const SizedBox();
      },
    ),
    state: _state(ipa: ipa, replaces: replaces),
  );
  return out;
}

void main() {
  group('readingLines', () {
    testWidgets('switch off: the reading, and the IPA on its own line', (
      tester,
    ) async {
      final l = await _lines(
        tester,
        replaces: false,
        reading: 'pālu',
        ipaText: 'paːlu',
      );
      expect(l, (reading: 'pālu', ipa: 'paːlu', swapped: false));
    });

    testWidgets('switch on, a course with a transliteration: the IPA is the '
        'reading and the transliteration is hidden', (tester) async {
      final l = await _lines(
        tester,
        replaces: true,
        reading: 'pālu',
        ipaText: 'paːlu',
      );
      expect(l, (reading: '/paːlu/', ipa: null, swapped: true));
    });

    testWidgets('switch on, a Latin-script course with no reading: the IPA '
        'moves up as the reading', (tester) async {
      final l = await _lines(
        tester,
        replaces: true,
        ipaText: 'ˈpato',
        target: 'pato',
      );
      expect(l, (reading: '/ˈpato/', ipa: null, swapped: true));
    });

    testWidgets('switch on, no IPA given: the transliteration stays', (
      tester,
    ) async {
      final l = await _lines(tester, replaces: true, reading: 'pālu');
      expect(l, (reading: 'pālu', ipa: null, swapped: false));
    });

    testWidgets('switch on, IPA off: no IPA anywhere', (tester) async {
      final l = await _lines(
        tester,
        ipa: false,
        replaces: true,
        reading: 'pālu',
        ipaText: 'paːlu',
      );
      expect(l, (reading: 'pālu', ipa: null, swapped: false));
    });

    testWidgets('a word that is its own IPA is not swapped', (tester) async {
      final l = await _lines(
        tester,
        replaces: true,
        ipaText: 'paːlu',
        target: 'paːlu',
      );
      expect(l, (reading: null, ipa: null, swapped: false));
    });

    testWidgets('showReading false: nothing is swapped in, the reading stays '
        'hidden and the IPA keeps its own line', (tester) async {
      final l = await _lines(
        tester,
        replaces: true,
        reading: 'pālu',
        ipaText: 'paːlu',
        showReading: false,
      );
      expect(l, (reading: null, ipa: 'paːlu', swapped: false));
    });
  });

  group('ReadingText', () {
    Future<void> pump(WidgetTester tester, Widget child, TextDirection d) =>
        pumpScreen(
          tester,
          Directionality(
            textDirection: d,
            child: Scaffold(body: child),
          ),
        );

    for (final direction in TextDirection.values) {
      testWidgets('swapped IPA is left to right in a $direction app', (
        tester,
      ) async {
        await pump(
          tester,
          const ReadingText('/paːlu/', swapped: true),
          direction,
        );
        expect(
          tester.widget<Text>(find.text('/paːlu/')).textDirection,
          TextDirection.ltr,
        );
      });
    }

    testWidgets('a plain reading takes the surrounding direction', (
      tester,
    ) async {
      await pump(
        tester,
        const ReadingText('pālu', swapped: false),
        TextDirection.rtl,
      );
      expect(tester.widget<Text>(find.text('pālu')).textDirection, isNull);
    });

    testWidgets('the screen reader hears the IPA without its slashes, and '
        'only that part of a longer line', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        const ReadingText('/tʃeːjaɖam/ (to do) — ఆమె / అది', swapped: true),
        TextDirection.ltr,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ReadingText)),
      )!;
      expect(
        find.bySemanticsLabel(
          l10n.ipaSemantics('tʃeːjaɖam (to do) — ఆమె / అది'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('a rules table\'s cells', () {
    const language = LanguageInfo(
      code: 'te',
      iso639_3: 'tel',
      name: 'Telugu',
      script: 'telugu',
    );
    const forms = <Card>[
      Card(
        id: 'te-9001',
        deckId: 'te-en-probe',
        target: 'ఇల్లు',
        native: 'house',
        reading: 'illu',
        ipa: 'illu',
        rule: RuleCell(
          ruleId: 'plural',
          word: 'te-0042',
          wordTarget: 'ఇల్లు',
          slot: 'one',
        ),
      ),
      Card(
        id: 'te-9002',
        deckId: 'te-en-probe',
        target: 'ఇళ్ళు',
        native: 'houses',
        reading: 'iḷḷu',
        ipa: 'iɭɭu',
        rule: RuleCell(
          ruleId: 'plural',
          word: 'te-0042',
          wordTarget: 'ఇల్లు',
          slot: 'many',
        ),
      ),
    ];

    Future<void> pumpTable(WidgetTester tester, {required bool replaces}) =>
        pumpScreen(
          tester,
          const Scaffold(
            body: RuleFormsTable(
              forms: forms,
              asked: 'te-9001',
              language: language,
            ),
          ),
          state: _state(ipa: true, replaces: replaces),
        );

    testWidgets('switch off: each form\'s transliteration', (tester) async {
      usePhone(tester, textScale: 1.4);
      await pumpTable(tester, replaces: false);
      expect(find.text('iḷḷu'), findsOneWidget);
      expect(find.text('/iɭɭu/'), findsNothing);
    });

    testWidgets('switch on: each form\'s IPA in its place', (tester) async {
      usePhone(tester, textScale: 1.4);
      await pumpTable(tester, replaces: true);
      expect(find.text('/iɭɭu/'), findsOneWidget);
      expect(find.text('iḷḷu'), findsNothing);
    });
  });
}
