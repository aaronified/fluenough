// A card's confusables are the extra tiles of the word-order drill (#348):
// mixed in with the sentence's own, never one the answer needs, and the
// order is right only with none of them in it.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const String _core = '''
schema: 1
id: "es-extras"
part: "core"
kind: "vocab"
language: { code: "es", iso639_3: "spa", name: "Spanish", script: "latin", tts: "es-ES" }
license: "CC-BY-SA-4.0"
cards:
  - id: "es-9001"
    target: "Mi casa grande."
    confusables:
      - { id: "num", word: "Mis", kind: "form" }
      - { id: "card", ref: "es-9002", kind: "word" }
      - { id: "mark", word: "?", kind: "mark" }
      - { id: "needed", word: "casa", kind: "word" }
      - { id: "again", word: "mis", kind: "form" }
  - id: "es-9002"
    target: "Perro"
  - id: "es-9003"
    target: "tu casa pequeña"
''';

const String _layer = '''
schema: 1
id: "es-en-extras"
kind: "layer"
core: "es-extras"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Spanish (extra tiles fixture)"
license: "CC-BY-SA-4.0"
cards:
  "es-9001":
    native: "my big house"
    confusables:
      "num": { why: "Plural." }
      "card": { why: "A dog." }
      "mark": { why: "A question." }
      "needed": { why: "Needed." }
      "again": { why: "Plural again." }
  "es-9002":
    native: "dog"
  "es-9003":
    native: "your small house"
''';

Future<void> _pump(
  WidgetTester tester,
  String target, {
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  usePhone(tester, textScale: textScale);
  final state = AppState.test(
    decks: MemoryDeckSource(const <String, String>{
      'decks/es/es-extras.yaml': _core,
      'decks/es/en/es-en-extras.yaml': _layer,
    }),
    tts: FixedTtsEngine(<String>{'es'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: Skill.values.toSet(),
    ),
  );
  addTearDown(state.dispose);
  await pumpScreen(
    tester,
    DrillPage(
      request: DrillRequest.untaught('es-en-extras', skill: Skill.production),
      preset: DrillPreset(target: target, ask: Ask.rearrange),
    ),
    state: state,
    themeMode: themeMode,
  );
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

bool _canCheck(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, l10nOf(tester).drillCheck),
  );
  return button.onPressed != null;
}

void main() {
  testWidgets('the card\'s confusables are tiles beside its words, once each, '
      'never one the answer needs', (tester) async {
    await _pump(tester, 'Mi casa grande.');
    expect(find.byType(RearrangeDrill), findsOneWidget);
    // Three words and the mark of the sentence, then three extras: mis (given
    // twice, shown once), perro (a card), ? (a mark). The `casa` confusable
    // is a tile the answer needs, so it is not a second one.
    expect(find.byType(WordTile), findsNWidgets(7));
    for (final tile in <String>['mi', 'casa', 'grande', '.', 'mis', 'perro']) {
      expect(find.text(tile), findsOneWidget, reason: tile);
    }
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('the needed tiles are shuffled out of the answer order, the '
      'extras among them', (tester) async {
    await _pump(tester, 'Mi casa grande.');
    final shown = <String>[
      for (final tile in tester.widgetList<WordTile>(find.byType(WordTile)))
        tile.text,
    ];
    final needed = <String>[
      for (final tile in shown)
        if (<String>['mi', 'casa', 'grande', '.'].contains(tile)) tile,
    ];
    expect(needed, isNot(<String>['mi', 'casa', 'grande', '.']));
    expect(shown, hasLength(7));
  });

  testWidgets('Check waits for as many tiles as the answer has, and the right '
      'order is right', (tester) async {
    await _pump(tester, 'Mi casa grande.');
    for (final tile in <String>['mi', 'casa', 'grande']) {
      expect(_canCheck(tester), isFalse, reason: 'before $tile');
      await _tap(tester, tile);
    }
    expect(_canCheck(tester), isFalse, reason: 'the mark is a tile too');
    await _tap(tester, '.');
    expect(_canCheck(tester), isTrue);
    await _tap(tester, l10nOf(tester).drillCheck);
    expect(find.text(l10nOf(tester).feedbackCorrect), findsOneWidget);
  });

  testWidgets('an extra tile in the answer makes it wrong, even in order', (
    tester,
  ) async {
    await _pump(tester, 'Mi casa grande.');
    for (final tile in <String>['mi', 'casa', 'grande', 'mis']) {
      await _tap(tester, tile);
    }
    expect(_canCheck(tester), isTrue);
    await _tap(tester, l10nOf(tester).drillCheck);
    expect(find.text(l10nOf(tester).feedbackWrong), findsOneWidget);
    expect(find.text(l10nOf(tester).feedbackCorrect), findsNothing);
  });

  testWidgets('more tiles than the answer has, an extra among them, is wrong', (
    tester,
  ) async {
    await _pump(tester, 'Mi casa grande.');
    for (final tile in <String>['mi', 'casa', 'grande', '.', 'perro']) {
      await _tap(tester, tile);
    }
    await _tap(tester, l10nOf(tester).drillCheck);
    expect(find.text(l10nOf(tester).feedbackWrong), findsOneWidget);
  });

  testWidgets('a card with no confusables shows only its own tiles', (
    tester,
  ) async {
    await _pump(tester, 'tu casa pequeña');
    expect(find.byType(WordTile), findsNWidgets(3));
    for (final tile in <String>['tu', 'casa', 'pequeña']) {
      await _tap(tester, tile);
    }
    expect(_canCheck(tester), isTrue);
    await _tap(tester, l10nOf(tester).drillCheck);
    expect(find.text(l10nOf(tester).feedbackCorrect), findsOneWidget);
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('at 1.4x text, ${mode.name}, the tiles fit, before and after '
        'the check', (tester) async {
      await _pump(tester, 'Mi casa grande.', textScale: 1.4, themeMode: mode);
      expect(find.byType(WordTile), findsNWidgets(7));
      expect(tester.takeException(), isNull);
      for (final tile in <String>['mis', 'perro', '?', 'mi', 'casa']) {
        await _tap(tester, tile);
      }
      expect(tester.takeException(), isNull);
      await _tap(tester, l10nOf(tester).drillCheck);
      expect(find.text(l10nOf(tester).feedbackWrong), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
