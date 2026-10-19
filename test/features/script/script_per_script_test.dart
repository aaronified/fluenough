import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/script/script_guide_page.dart';

import '../../support/harness.dart';

/// A language written in two scripts has a script guide for each (ADR-0016):
/// a deck's Tips, and the drill, show the guide of the deck's own script, and
/// the language's default guide where the script has none.

String guideOf(String id, String name) =>
    '''
schema: 1
kind: script
id: $id
language: bn
name: "$name"
intro: "A few ideas come back again and again."
features:
  - id: headline
    name: "Feature of $id"
    example: "ক"
    text: "Most letters hang from a line along the top."
''';

String deck(String id, String writing) =>
    '''
schema: 1
id: $id
name: "Probe"
language: { code: bn, iso639_3: ben, name: Bengali, script: $writing, tts: bn-IN }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
tags: [script]
cards:
  - { id: $id-0001, target: "ক", native: "k (ko)", reading: "ko" }
  - { id: $id-0002, target: "খ", native: "kh (kho)", reading: "kho" }
''';

final String bengaliGuide = guideOf('bn-script', 'How Bengali works');
final String sylhetiGuide = guideOf('bn-sylheti-script', 'How Sylheti works');

AppState twoScripts({bool withSylheti = true}) {
  return AppState.test(
    decks: MemoryDeckSource(<String, String>{
      'decks/bn/bn-en-letters.yaml': deck('bn-en-letters', 'bengali'),
      'decks/bn/bn-en-syloti.yaml': deck('bn-en-syloti', 'sylheti'),
      'decks/bn/bn-script.yaml': bengaliGuide,
      if (withSylheti) 'decks/bn/bn-sylheti-script.yaml': sylhetiGuide,
    }),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
    ),
  );
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  test('the app state picks a guide by the deck script', () async {
    final state = twoScripts();
    await state.load();
    final letters = state.decks.firstWhere((e) => e.id == 'bn-en-letters');
    final syloti = state.decks.firstWhere((e) => e.id == 'bn-en-syloti');
    expect(state.scriptGuideFor(letters.language)?.key, 'bn');
    expect(state.scriptGuideFor(syloti.language)?.key, 'bn-sylheti');
    expect(state.scriptGuideByKey('bn-sylheti')?.$2.script, 'sylheti');
    expect(state.scriptGuideByKey('bn')?.$1.name, 'How Bengali works');
    final without = twoScripts(withSylheti: false);
    await without.load();
    final other = without.decks.firstWhere((e) => e.id == 'bn-en-syloti');
    expect(without.scriptGuideFor(other.language)?.key, 'bn');
  });

  testWidgets('the drill shows the guide of its own script', (tester) async {
    usePhone(tester);
    final state = twoScripts();
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.untaught('bn-en-syloti')),
      state: state,
    );
    expect(find.text('How Sylheti works'), findsOneWidget);
    expect(find.text('How Bengali works'), findsNothing);
    await tapText(tester, l10nOf(tester).scriptGuideStart);
    expect(state.settings.hasSeenScriptGuide('bn-sylheti'), isTrue);
    expect(state.settings.hasSeenScriptGuide('bn'), isFalse);
  });

  testWidgets('each script has its own seen guide', (tester) async {
    usePhone(tester);
    final state = twoScripts();
    state.settings.markScriptGuideSeen('bn-sylheti');
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.untaught('bn-en-letters')),
      state: state,
    );
    expect(find.text('How Bengali works'), findsOneWidget);
  });

  testWidgets('a script with no guide of its own shows the default', (
    tester,
  ) async {
    usePhone(tester);
    final state = twoScripts(withSylheti: false);
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.untaught('bn-en-syloti')),
      state: state,
    );
    expect(find.text('How Bengali works'), findsOneWidget);
    await tapText(tester, l10nOf(tester).scriptGuideStart);
    expect(state.settings.hasSeenScriptGuide('bn'), isTrue);
  });

  testWidgets('Tips opens the guide of the deck script', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const DeckDetailPage(deckId: 'bn-en-syloti'),
      state: twoScripts(),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.deckScriptTips('How Bengali works')), findsNothing);
    await tapText(tester, l10n.deckScriptTips('How Sylheti works'));
    expect(find.byType(ScriptGuidePage), findsOneWidget);
    expect(find.text('Feature of bn-sylheti-script'), findsOneWidget);
    expect(find.text('Feature of bn-script'), findsNothing);
  });

  test('which guides were seen, by script, survives a restart', () {
    const key = 'hi-perso-arabic';
    final settings = SettingsNotifier()..markScriptGuideSeen(key);
    final restored = SettingsNotifier()..restore(settings.toStored());
    expect(restored.hasSeenScriptGuide(key), isTrue);
    expect(restored.hasSeenScriptGuide('hi'), isFalse);
  });
}
