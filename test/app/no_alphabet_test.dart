import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';
import 'package:fluenough/ui/widgets/reading_first.dart';

import '../support/harness.dart';

/// Learning a language without its alphabet (#47): its path leaves out the
/// decks that need it, cards show the reading first, and answers in Latin
/// letters count in full.

Set<String> decksOf(Iterable<List<DeckEntry>> units) => <String>{
  for (final unit in units)
    for (final entry in unit) entry.id,
};

AppState hindiWithout() => AppState.test(
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi', 'es'],
    learningChosen: true,
    noAlphabet: const <String>{'hi', 'ja'},
  ),
);

void main() {
  test('every course in a script marks its script, spelling and reading '
      'decks, and only those', () async {
    final state = AppState.test();
    addTearDown(state.dispose);
    await state.load();
    for (final code in <String>[
      'as',
      'bn',
      'hi',
      'te',
      'mr',
      'kn',
      'gu',
      'ja',
    ]) {
      expect(state.hasAlphabet(code), isTrue, reason: code);
    }
    expect(state.hasAlphabet('es'), isFalse);
    for (final entry in state.decks) {
      final path = state.pathOf(entry);
      if (path == null) continue;
      final marked = path.alphabet.contains(entry.id);
      final id = entry.id;
      final needs = RegExp(r'-(script-|spelling$|reading-|hiragana$)')
          .hasMatch(id);
      expect(marked, needs, reason: id);
    }
  });

  test('without its alphabet, the course leaves those decks out, and only '
      'for that language', () async {
    final state = hindiWithout();
    addTearDown(state.dispose);
    await state.load();
    final hindi = decksOf(state.courseUnits('hi'));
    final all = decksOf(state.courseUnits('hi', alphabet: true));
    final left = all.difference(hindi);
    expect(left, isNotEmpty);
    expect(left.every((id) => state.leavesOut(state.deckById(id)!)), isTrue);
    expect(decksOf(state.pendingUnits).intersection(left), isEmpty);
    // Japanese has nothing yet but its script.
    expect(state.courseUnits('ja'), isEmpty);
    expect(state.courseUnits('bn'), state.courseUnits('bn', alphabet: true));
  });

  testWidgets('Today does not list a deck the course leaves out', (
    tester,
  ) async {
    usePhone(tester);
    // Everything else placed as known: only the decks left out are not, so
    // without the filter they would be the ones listed.
    final base = hindiWithout();
    await base.load();
    final placed = <String>{
      for (final entry in base.decks)
        if (entry.language.code == 'hi' && !base.needsAlphabet(entry)) entry.id,
    };
    base.dispose();
    final state = await pumpScreen(
      tester,
      const TodayPage(),
      state: AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
          learningChosen: true,
          noAlphabet: const <String>{'hi'},
          placedDecks: placed,
        ),
      ),
    );
    expect(state.decks.where(state.leavesOut), isNotEmpty);
    expect(
      tester
          .widgetList<DeckTile>(find.byType(DeckTile, skipOffstage: false))
          .map((tile) => tile.entry)
          .where(state.leavesOut),
      isEmpty,
    );
  });

  testWidgets('the grammar drill shows the readings first', (tester) async {
    usePhone(tester);
    final state = hindiWithout();
    await state.load();
    final entry = state.decks.firstWhere(
      (e) =>
          e.language.code == 'hi' &&
          e.deck.pattern != null &&
          e.deck.pattern!.entries.any((row) => row.reading != null),
    );
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.deck(entry.id, skill: Skill.grammar)),
      state: state,
    );
    final first = tester.widget<ReadingFirst>(find.byType(ReadingFirst));
    // The lemma in Latin letters; the slot, a pronoun, has no reading.
    expect(first.reading, isNot(first.target));
    expect(first.reading, matches(RegExp('^[a-z]')));
  });

  testWidgets('a word is typed in Latin letters by default, counts in full, '
      'and shows its reading first', (tester) async {
    usePhone(tester);
    final state = hindiWithout();
    await state.load();
    final entry = state.courseUnits('hi').first.first;
    final card = entry.cards.firstWhere((c) => c.reading != null);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.deck(entry.id, skill: Skill.production),
        preset: DrillPreset(target: card.target),
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.drillInputTranslit), findsOneWidget);
    await tester.enterText(find.byType(TextField), card.reading!);
    await tester.pump();
    await tester.tap(find.text(l10n.drillCheck));
    await tester.pumpAndSettle();
    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    expect(state.progress.log.single.grade, 5);
    expect(state.progress.log.single.grade, isNot(DrillSession.romanisedGrade));
    expect(find.byType(ReadingFirst), findsOneWidget);
  });

  testWidgets('recognition shows the reading first, then the script', (
    tester,
  ) async {
    usePhone(tester);
    final state = hindiWithout();
    await state.load();
    final entry = state.courseUnits('hi').first.first;
    final card = entry.cards.firstWhere((c) => c.reading != null);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.deck(entry.id, skill: Skill.recognition),
        preset: DrillPreset(target: card.target),
      ),
      state: state,
    );
    final first = tester.widget<ReadingFirst>(find.byType(ReadingFirst));
    expect(first.reading, card.reading);
    expect(first.target, card.target);
  });

  testWidgets('Settings switches a language to Latin letters only, and '
      'back', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const SettingsPage(),
      state: AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi', 'es'],
          learningChosen: true,
        ),
      ),
    );
    final l10n = l10nOf(tester);
    final row = find.text(l10n.settingsAlphabet);
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsAlphabetAll), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    // Spanish has no alphabet decks, so it is not offered.
    expect(find.widgetWithText(SwitchListTile, 'Spanish'), findsNothing);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Hindi'));
    await tester.pumpAndSettle();
    expect(state.settings.learnsAlphabet('hi'), isFalse);
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsAlphabetLatin('Hindi')), findsOneWidget);
  });
}
