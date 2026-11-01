// "IPA replaces transliteration" (#697): with IPA on and the switch on, a
// word's IPA shows in its transliteration's place; off, both show as before;
// with IPA off neither shows the IPA and the switch is greyed out.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/decks/ipa_info_dot.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/settings/ipa_replaces_tile.dart';
import 'package:fluenough/features/settings/languages_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/ui/widgets/ipa_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/ipa_course.dart';

Future<void> pumpLines(
  WidgetTester tester, {
  required bool ipa,
  required bool replaces,
  String? reading = 'pālu',
  String? ipaText = 'paːlu',
}) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) {
          final l = readingLines(
            context,
            reading: reading,
            ipa: ipaText,
            target: 'పాలు',
          );
          return Column(
            children: <Widget>[
              if (l.reading != null) Text('reading:${l.reading}'),
              if (l.ipa != null) Text('ipa:${l.ipa}'),
            ],
          );
        },
      ),
    ),
    state: AppState.test(
      settings: SettingsNotifier()
        ..showIpa = ipa
        ..ipaReplacesReading = replaces,
    ),
  );
}

Future<void> pumpWordSheet(
  WidgetTester tester, {
  required bool replaces,
}) async {
  usePhone(tester);
  final state = ipaApp(<String>['hi']);
  state.settings
    ..showIpa = true
    ..ipaReplacesReading = replaces;
  await state.load();
  final entry = state.deckById('hi-en-words')!;
  await pumpScreen(
    tester,
    Scaffold(
      body: WordSheet(card: entry.cards.first, language: entry.language),
    ),
    state: state,
  );
}

void main() {
  testWidgets('word sheet, switch off: the transliteration and the IPA with '
      'its info dot', (tester) async {
    await pumpWordSheet(tester, replaces: false);
    expect(find.text('pattā'), findsOneWidget);
    expect(find.text('/pʰəɳ/'), findsOneWidget);
    expect(find.byType(IpaInfoDot), findsOneWidget);
  });

  testWidgets('word sheet, switch on: the IPA in the transliteration\'s place, '
      'still with its info dot', (tester) async {
    await pumpWordSheet(tester, replaces: true);
    expect(find.text('pattā'), findsNothing);
    expect(find.text('/pʰəɳ/'), findsOneWidget);
    expect(find.byType(IpaInfoDot), findsOneWidget);
  });

  testWidgets('IPA on and the switch on: the IPA is the reading, and the '
      'transliteration is gone', (tester) async {
    await pumpLines(tester, ipa: true, replaces: true);
    expect(find.text('reading:/paːlu/'), findsOneWidget);
    expect(find.textContaining('pālu'), findsNothing);
    expect(find.textContaining('ipa:'), findsNothing);
  });

  testWidgets('the switch off: both show as before', (tester) async {
    await pumpLines(tester, ipa: true, replaces: false);
    expect(find.text('reading:pālu'), findsOneWidget);
    expect(find.text('ipa:paːlu'), findsOneWidget);
  });

  testWidgets('IPA off: the switch changes nothing, and no IPA shows', (
    tester,
  ) async {
    await pumpLines(tester, ipa: false, replaces: true);
    expect(find.text('reading:pālu'), findsOneWidget);
    expect(find.textContaining('ipa'), findsNothing);
  });

  testWidgets('a word with no IPA keeps its transliteration', (tester) async {
    await pumpLines(tester, ipa: true, replaces: true, ipaText: null);
    expect(find.text('reading:pālu'), findsOneWidget);
  });

  testWidgets('a Latin-script word gets its IPA under the word, in the '
      "reading's place", (tester) async {
    await pumpLines(tester, ipa: true, replaces: true, reading: null);
    expect(find.text('reading:/paːlu/'), findsOneWidget);
  });

  testWidgets('the row is greyed out and explained while IPA is off', (
    tester,
  ) async {
    final settings = SettingsNotifier()
      ..showIpa = false
      ..ipaReplacesReading = true;
    await pumpScreen(
      tester,
      Scaffold(
        body: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => GroupedList.settings(
            children: <Widget>[
              ipaReplacesTile(AppLocalizations.of(context)!, settings),
            ],
          ),
        ),
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    expect(find.text(l10n.settingsIpaReplacesNeedsIpa), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

    settings.showIpa = true;
    await tester.pump();
    expect(find.text(l10n.settingsIpaReplacesOn), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(settings.ipaReplacesReading, isFalse);
  });

  testWidgets('Settings, Your languages: the row sits under IPA '
      'pronunciations, disabled while IPA is off and switchable once on', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const LanguagesSettingsPage(),
      state: AppState.test(settings: SettingsNotifier()..showIpa = false),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    final row = find.text(l10n.settingsIpaReplaces);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(tester.getTopLeft(find.text(l10n.settingsIpa)).dy),
    );
    expect(find.text(l10n.settingsIpaReplacesNeedsIpa), findsOneWidget);

    state.settings.showIpa = true;
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsIpaReplacesOff), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(state.settings.ipaReplacesReading, isTrue);
  });
}
