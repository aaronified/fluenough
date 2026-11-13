// The situations picker (#1145): a pencil at the top right of Today's
// Situations card opens a grid of every situation, chosen ones first and in
// order, the rest faded; the card shows the first six chosen, per language.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/situations/situations_editor.dart';
import 'package:fluenough/features/today/situations_card.dart';

import 'support/harness.dart';

const String _words = '''
schema: 1
id: hi-en-words
name: "Words"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-words-0001, target: "कख", native: "word 1", reading: "kakha" }
''';

/// Eight situations, so that two are past the card's six.
String _situations() {
  const icons = <String>[
    'taxi',
    'shops',
    'eat',
    'doctor',
    'traffic',
    'rail',
    'office',
    'bank',
  ];
  final rows = <String>[
    for (var i = 0; i < icons.length; i++)
      '  - id: s${i + 1}\n'
          '    icon: ${icons[i]}\n'
          '    title: { en: "Scene ${i + 1}" }\n'
          '    words: ["hi-en-words-0001"]',
  ];
  return '''
schema: 1
id: hi-situations
name: "Hindustani situations"
kind: situations
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
license: "CC-BY-SA-4.0"
situations:
${rows.join('\n')}
''';
}

AppState _learner() {
  final state = AppState.test(
    decks: MemoryDeckSource(<String, String>{
      'decks/hi/hi-en-words.yaml': _words,
      'decks/hi/hi-situations.yaml': _situations(),
    }),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
    ),
  );
  addTearDown(state.dispose);
  return state;
}

Future<AppState> _pumpCard(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
  AppState? state,
}) {
  usePhone(tester, textScale: 1.4);
  return pumpScreen(
    tester,
    const Scaffold(body: SingleChildScrollView(child: SituationsCard())),
    state: state ?? _learner(),
    themeMode: themeMode,
  );
}

void main() {
  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the card shows the first six situations, and a pencil '
        'opens the editor with all eight (${mode.name}, 1.4x)', (tester) async {
      await _pumpCard(tester, themeMode: mode);
      final l10n = l10nOf(tester);
      for (var i = 1; i <= 6; i++) {
        expect(find.text('Scene $i'), findsOneWidget);
      }
      expect(find.text('Scene 7'), findsNothing);
      expect(find.byTooltip(l10n.hintEdit), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.hintEdit));
      await tester.pumpAndSettle();
      expect(find.text(l10n.situationsEditTitle), findsOneWidget);
      expect(find.byType(SituationsEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping a faded tile adds it and a chosen one removes it, '
      'and Done saves the choice for the language', (tester) async {
    final state = await _pumpCard(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.byTooltip(l10n.hintEdit));
    await tester.pumpAndSettle();

    final editor = find.byType(SituationsEditor);
    Finder tile(String title) =>
        find.descendant(of: editor, matching: find.text(title));
    await tester.ensureVisible(tile('Scene 7'));
    await tester.tap(tile('Scene 7'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(tile('Scene 1'));
    await tester.tap(tile('Scene 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();

    expect(state.settings.situationsShownOf('hi'), <String>[
      's2',
      's3',
      's4',
      's5',
      's6',
      's7',
    ]);
    expect(find.text('Scene 1'), findsNothing);
    expect(find.text('Scene 7'), findsOneWidget);
    expect(find.text('Scene 8'), findsNothing);
  });

  testWidgets('Reset to defaults and Done leave no choice stored, so the '
      'card follows the deck again', (tester) async {
    final state = _learner();
    state.settings.setSituationsShown('hi', <String>['s8', 's7']);
    await _pumpCard(tester, state: state);
    final l10n = l10nOf(tester);
    expect(find.text('Scene 8'), findsOneWidget);
    expect(find.text('Scene 1'), findsNothing);

    await tester.tap(find.byTooltip(l10n.hintEdit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.situationsEditReset));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();

    expect(state.settings.situationsShownOf('hi'), isNull);
    expect(find.text('Scene 1'), findsOneWidget);
    expect(find.text('Scene 8'), findsNothing);
  });

  testWidgets('a long press drags a chosen tile to another place', (
    tester,
  ) async {
    final state = await _pumpCard(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.byTooltip(l10n.hintEdit));
    await tester.pumpAndSettle();

    final editor = find.byType(SituationsEditor);
    final from = tester.getCenter(
      find.descendant(of: editor, matching: find.text('Scene 1')),
    );
    final to = tester.getCenter(
      find.descendant(of: editor, matching: find.text('Scene 3')),
    );
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(to, timeStamp: const Duration(milliseconds: 800));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();

    expect(state.settings.situationsShownOf('hi'), <String>[
      's2',
      's3',
      's1',
      's4',
      's5',
      's6',
    ]);
  });

  test('the choice survives a backup, per language, and a language\'s '
      'settings reset forgets it', () {
    final settings = SettingsNotifier()
      ..setSituationsShown('hi', <String>['s2', 's1']);
    final stored = settings.toStored();
    final back = SettingsNotifier()..restore(stored);
    expect(back.situationsShownOf('hi'), <String>['s2', 's1']);
    expect(back.situationsShownOf('bn'), isNull);
    back.clearLanguageSettings('hi');
    expect(back.situationsShownOf('hi'), isNull);
  });

  test('a situation a deck update adds never joins a chosen list, and an id '
      'the file no longer writes is left out', () async {
    final state = _learner();
    await state.load();
    state.settings.setSituationsShown('hi', <String>['s8', 'gone', 's2']);
    expect(
      <String>[for (final s in state.pickedSituations('hi')) s.id],
      <String>['s8', 's2'],
    );
  });
}
