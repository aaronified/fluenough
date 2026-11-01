// Every icon button says what it does (owner, 2026-11-01): a tooltip of one
// word, two at most, which a long press or a hover shows and a screen reader
// reads. The scans in hint_test.dart check the source; this walks the screens
// a learner sees and checks the buttons that are really drawn.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/decks/word_sheet.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/languages/languages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/picker.dart';

/// What every icon button, floating button and popup menu button drawn now
/// says, as "screen: tooltip" lines for the ones that say too much or
/// nothing.
List<String> wordyButtons(WidgetTester tester, String screen) {
  final offenders = <String>[];
  void check(Widget widget, String? tooltip) {
    final words = (tooltip ?? '').trim().split(RegExp(r'\s+'));
    final empty = (tooltip ?? '').trim().isEmpty;
    if (empty || words.length > 2) {
      offenders.add('$screen: ${widget.runtimeType} "${tooltip ?? ''}"');
    }
  }

  for (final b in tester.widgetList<IconButton>(find.byType(IconButton))) {
    check(b, b.tooltip);
  }
  for (final b in tester.widgetList<FloatingActionButton>(
    find.byType(FloatingActionButton),
  )) {
    check(b, b.tooltip);
  }
  for (final b in tester.widgetList<PopupMenuButton<dynamic>>(
    find.byWidgetPredicate((w) => w is PopupMenuButton<dynamic>),
  )) {
    check(b, b.tooltip);
  }
  return offenders;
}

void main() {
  testWidgets(
    'the tabs: every icon button has a tooltip of two words at most',
    (tester) async {
      usePhone(tester, textScale: 1.4);
      await pumpApp(tester);
      final l10n = l10nOf(tester);
      final offenders = <String>[];
      for (final (label, screen) in <(String, String)>[
        (l10n.navToday, 'Today'),
        (l10n.navDecks, 'Decks'),
        (l10n.navProgress, 'Progress'),
        (l10n.navSettings, 'Settings'),
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        offenders.addAll(wordyButtons(tester, screen));
      }
      expect(offenders, isEmpty);
    },
  );

  testWidgets('the Languages page and its sheet', (tester) async {
    usePhone(tester, textScale: 1.4);
    await pumpScreen(
      tester,
      LanguagesPage(spokenList: pickerSpokenList),
      state: AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['es'],
          learningChosen: true,
        )..scriptsRead = <String, bool>{'en': true},
      ),
    );
    final offenders = wordyButtons(tester, 'Languages');
    final row = find.byKey(const ValueKey<String>('language-es'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    offenders.addAll(wordyButtons(tester, 'Languages sheet'));
    expect(offenders, isEmpty);
  });

  testWidgets('a drill and the word sheet', (tester) async {
    usePhone(tester, textScale: 1.4);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(
          'es-en-core-100',
          skill: Skill.recognition,
        ),
      ),
    );
    final offenders = wordyButtons(tester, 'Drill');

    final state = AppState.test();
    await state.load();
    final entry = state.deckById('hi-en-market')!;
    final card = entry.cards.firstWhere(
      (c) => c.tags.isNotEmpty && c.notes.isNotEmpty,
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: WordSheet(card: card, language: entry.language),
      ),
      state: state,
    );
    offenders.addAll(wordyButtons(tester, 'Word sheet'));
    expect(offenders, isEmpty);
  });
}
