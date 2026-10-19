import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/ui/script_name.dart';

import '../../support/harness.dart';
import '../../support/two_script_course.dart';

/// Drills in the scripts a language is learned in (#623): a card shown in
/// Perso-Arabic, and Write offering one option for each script learned.

AppState learning(Set<String> scripts) => AppState.test(
  decks: MemoryDeckSource(twoScriptCourse()),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi'],
    learningChosen: true,
    scriptsLearned: <String, Set<String>>{'hi': scripts},
  ),
);

const String devanagari = 'किताब';
const String persoArabic = 'کتاب';
const Set<String> urdu = <String>{'perso_arabic'};
const Set<String> both = <String>{'devanagari', 'perso_arabic'};

Future<AppState> pump(
  WidgetTester tester,
  Set<String> scripts,
  Skill skill,
) async {
  usePhone(tester);
  final state = learning(scripts);
  await state.load();
  final entry = state.deckById('hi-en-words')!;
  await pumpScreen(
    tester,
    DrillPage(
      request: DrillRequest.deck(entry.id, skill: skill),
      preset: const DrillPreset(target: devanagari),
    ),
    state: state,
  );
  return state;
}

void main() {
  testWidgets('a card is shown in Perso-Arabic, not Devanagari, to a '
      'learner of Perso-Arabic only', (tester) async {
    await pump(tester, urdu, Skill.recognition);
    expect(find.text(persoArabic), findsOneWidget);
    expect(find.text(devanagari), findsNothing);
  });

  testWidgets('with both scripts learned, the primary is shown and the other '
      'beneath it', (tester) async {
    await pump(tester, both, Skill.recognition);
    // A long word is given its breaks between aksharas, so it is found as a
    // target, not as plain text.
    expect(findTarget(devanagari), findsOneWidget);
    expect(find.text(persoArabic), findsOneWidget);
  });

  testWidgets('Write offers one option for each script learned, and '
      'Transliteration', (tester) async {
    await pump(tester, both, Skill.production);
    final l10n = l10nOf(tester);
    String label(String script) =>
        l10n.drillInputScript(l10n.scriptNameOr(script, 'Hindustani'));
    expect(find.text(label('devanagari')), findsOneWidget);
    expect(find.text(label('perso_arabic')), findsOneWidget);
    expect(find.text(l10n.drillInputTranslit), findsOneWidget);
  });

  testWidgets('Write offers only the script learned, and an answer is '
      'checked against its spelling', (tester) async {
    final state = await pump(tester, urdu, Skill.production);
    final l10n = l10nOf(tester);
    String label(String script) =>
        l10n.drillInputScript(l10n.scriptNameOr(script, 'Hindustani'));
    expect(find.text(label('devanagari')), findsNothing);
    expect(find.text(label('perso_arabic')), findsOneWidget);
    await tester.tap(find.text(label('perso_arabic')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), persoArabic);
    await tester.pump();
    await tester.tap(find.text(l10n.drillCheck));
    await tester.pumpAndSettle();
    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    expect(state.progress.log.single.grade, 5);
  });
}
