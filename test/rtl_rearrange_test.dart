// A deck written right to left is put in order right to left: the tiles of
// the word-order drill lay out from the right in an English app, and the
// answer a wrong order is shown quotes the sentence isolated, so that the
// interface's words never reorder it (#619).
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

const String _urdu = '''
schema: 1
id: ur-fixture-order
name: "Urdu (word order fixture)"
kind: vocab
language: { code: ur, iso639_3: urd, name: Urdu, script: perso_arabic, rtl: true, tts: ur-PK }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: ur-fixture-9001
    target: "یہ میری کتاب ہے"
    native: "this is my book"
''';

const String _spanish = '''
schema: 1
id: es-fixture-order
name: "Spanish (word order fixture)"
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-fixture-9001
    target: "esta es mi casa"
    native: "this is my house"
''';

Future<AppState> _pump(WidgetTester tester, String deck, String target) async {
  usePhone(tester);
  final state = AppState.test(
    decks: MemoryDeckSource(const <String, String>{
      'decks/ur/ur-fixture-order.yaml': _urdu,
      'decks/es/es-fixture-order.yaml': _spanish,
    }),
    tts: FixedTtsEngine(<String>{'es', 'ur'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: Skill.values.toSet(),
    ),
  );
  addTearDown(state.dispose);
  return pumpScreen(
    tester,
    DrillPage(
      request: DrillRequest.untaught(deck, skill: Skill.production),
      preset: DrillPreset(target: target, ask: Ask.rearrange),
    ),
    state: state,
  );
}

/// The placed tile showing [word], among the answer line's.
Finder _placed(WidgetTester tester, String word) => find.descendant(
  of: find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.label == l10nOf(tester).drillRearrangeAnswer,
  ),
  matching: find.text(word),
);

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an Urdu sentence builds from the right, a Spanish one from the '
      'left', (tester) async {
    for (final (deck, target, rtl) in <(String, String, bool)>[
      ('ur-fixture-order', 'یہ میری کتاب ہے', true),
      ('es-fixture-order', 'esta es mi casa', false),
    ]) {
      await _pump(tester, deck, target);
      expect(find.byType(RearrangeDrill), findsOneWidget);
      final words = target.split(' ');
      for (final word in words) {
        await tapText(tester, word);
      }
      final xs = <double>[
        for (final word in words) tester.getCenter(_placed(tester, word)).dx,
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(
          xs[i] < xs[i - 1],
          rtl,
          reason: '${words[i]} after ${words[i - 1]} in $deck',
        );
      }
    }
  });

  testWidgets('a wrong order shows the answer with the sentence isolated, '
      'right to left', (tester) async {
    await _pump(tester, 'ur-fixture-order', 'یہ میری کتاب ہے');
    for (final word in 'ہے کتاب میری یہ'.split(' ')) {
      await tapText(tester, word);
    }
    await tapText(tester, l10nOf(tester).drillCheck);
    final answer = l10nOf(tester).feedbackAnswer('⁧یہ میری کتاب ہے⁩');
    expect(find.text(answer), findsOneWidget);
  });
}
