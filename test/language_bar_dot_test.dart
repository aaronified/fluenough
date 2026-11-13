// The language bar's dot (#681): a language with a review due or a new card
// waiting has a dot on its glyph, and says so to a screen reader; one with
// neither has none. The IPA's glyph is drawn larger, to the others' height.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/language_work.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/ui/widgets/language_bar.dart';
import 'package:fluenough/ui/widgets/language_glyph.dart';

import 'support/harness.dart';

final DateTime _now = DateTime(2026, 9, 28, 19);

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

/// A learner of Hindustani whose one word was last reviewed [daysAgo] days
/// ago in every skill, or never when [daysAgo] is null.
AppState _learner({int? daysAgo}) {
  final progress = MemoryProgress();
  if (daysAgo != null) {
    for (final mode in DrillMode.values) {
      progress.record(
        deckId: 'hi-en-words',
        cardId: 'hi-en-words-0001',
        mode: mode,
        grade: 4,
        now: _now.subtract(Duration(days: daysAgo)),
      );
    }
  }
  final state = AppState.test(
    decks: MemoryDeckSource(<String, String>{
      'decks/hi/hi-en-words.yaml': _words,
    }),
    progress: progress,
    now: _now,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
      languageChoice: 'hi',
    ),
  );
  addTearDown(state.dispose);
  return state;
}

Future<AppState> _pumpBar(
  WidgetTester tester,
  AppState state, {
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) {
  usePhone(tester, textScale: textScale);
  return pumpScreen(
    tester,
    const Scaffold(
      body: LanguageBarFrame(
        screen: LanguageBarScreen.today,
        reportDetail: 'Test',
        child: SizedBox.expand(),
      ),
    ),
    state: state,
    themeMode: themeMode,
  );
}

void main() {
  for (final scale in <double>[1.0, 1.4]) {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('a language with a card due shows the dot, and its label '
          'says so (${mode.name}, ${scale}x)', (tester) async {
        final semantics = tester.ensureSemantics();
        final state = await _pumpBar(
          tester,
          _learner(daysAgo: 60),
          textScale: scale,
          themeMode: mode,
        );
        expect(state.languageHasWork('hi'), isTrue);
        expect(
          find.byKey(const ValueKey<String>('language-dot')),
          findsWidgets,
        );
        final l10n = l10nOf(tester);
        expect(
          find.bySemanticsLabel(RegExp(l10n.languageHasCardsToDo('.*'))),
          findsWidgets,
        );
        semantics.dispose();
      });
    }
  }

  testWidgets('a language with a new card waiting shows the dot', (
    tester,
  ) async {
    await _pumpBar(tester, _learner());
    expect(find.byKey(const ValueKey<String>('language-dot')), findsWidgets);
  });

  testWidgets('a language with nothing due and nothing new shows no dot', (
    tester,
  ) async {
    final state = await _pumpBar(tester, _learner(daysAgo: 0));
    expect(state.languageHasWork('hi'), isFalse);
    expect(find.byKey(const ValueKey<String>('language-dot')), findsNothing);
  });

  testWidgets('the IPA\'s glyph is set larger than another language\'s', (
    tester,
  ) async {
    const ipa = LanguageInfo(
      code: 'ipa',
      iso639_3: 'zxx',
      name: 'IPA',
      script: 'ipa',
      icon: 'ə',
    );
    const hindi = LanguageInfo(
      code: 'hi',
      iso639_3: 'hin',
      name: 'Hindustani',
      script: 'devanagari',
    );
    expect(glyphScaleOf(ipa), greaterThan(glyphScaleOf(hindi)));
    await pumpScreen(
      tester,
      const Scaffold(
        body: Row(
          children: <Widget>[
            LanguageGlyphTile(
              glyph: 'ə',
              language: ipa,
              background: Colors.white,
              foreground: Colors.black,
            ),
            LanguageGlyphTile(
              glyph: 'क',
              language: hindi,
              background: Colors.white,
              foreground: Colors.black,
              hasWork: true,
            ),
          ],
        ),
      ),
    );
    double size(String glyph) =>
        tester.widget<Text>(find.text(glyph)).style!.fontSize!;
    expect(size('ə'), greaterThan(size('क')));
    expect(find.byKey(const ValueKey<String>('language-dot')), findsWidgets);
  });
}
