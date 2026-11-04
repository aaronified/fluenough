// Split out of accessibility_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: Learn, Drills, Profiles.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/scheduling/session_queue.dart' show Ask;
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/ui/widgets/braille_keyboard.dart';
import 'support/braille_course.dart';
import 'support/harness.dart';
import 'support/accessibility_shared.dart';

/// A drill of [request] from [preset].
DrawScreen drill(
  DrillRequest request, [
  DrillPreset preset = const DrillPreset(),
]) => page(
  DrillPage(request: request, preset: preset),
  state: () async => AppState.test(tts: FixedTtsEngine(<String>{'es', 'hi'})),
);

/// The design's Telugu learner, on the path (PathFixtures).
Future<AppState> teluguLearner() async {
  final app = AppState.test();
  await app.load();
  return PathFixtures.state(app);
}

/// The example set's files with a set card of five words, split over two
/// cards, added to its home deck (#515).
Map<String, String> setFiles() {
  const appendix = 'test/fixtures/b1/appendix-a/zz';
  final out = <String, String>{
    for (final file in Directory(appendix).listSync(recursive: true))
      if (file is File && file.path.endsWith('.yaml'))
        'decks/zz/${file.path.substring(appendix.length + 1)}': file
            .readAsStringSync(),
  };
  const members = <String>[
    'zz-9001',
    'zz-9004',
    'zz-9006',
    'zz-9003',
    'zz-9002',
  ];
  out['decks/zz/zz-home.yaml'] =
      '${out['decks/zz/zz-home.yaml']}'
      '  - id: "zz-9201"\n'
      '    kind: "set"\n'
      '    members: [${members.map((m) => '{ ref: "$m" }').join(', ')}]\n';
  out['decks/zz/en/zz-en-home.yaml'] = out['decks/zz/en/zz-en-home.yaml']!
      .replaceFirst(
        'cards:\n',
        'cards:\n'
            '  "zz-9201":\n'
            '    native: "First words"\n'
            '    explanation: "Words you meet first, together."\n',
      );
  return out;
}

void main() {
  group('Learn', () {
    screen('Today', tab(ShellTab.today));
    screen(
      'the Decks path',
      page(const DecksPage(planOf: PathFixtures.planOf), state: teluguLearner),
    );
    screen(
      'a unit',
      page(
        const UnitPage(
          deckId: PathFixtures.familyDeck,
          plan: PathFixtures.telugu,
        ),
        state: teluguLearner,
      ),
    );
    screen('a deck', page(const DeckDetailPage(deckId: 'hi-en-market')));
    screen('Languages on the phone', gallery('learning-deck-updates'));
    screen(
      'the summary',
      page(
        SummaryPage(
          result: SessionResult(
            answers: const <SessionAnswer>[
              SessionAnswer(skill: Skill.recognition, grade: 4),
              SessionAnswer(skill: Skill.production, grade: 1),
            ],
            startedAt: DateTime(2026, 9, 28, 18, 50),
            endedAt: DateTime(2026, 9, 28, 19),
          ),
        ),
      ),
    );
  });

  group('Drills', () {
    screen('the teach card', gallery('drill-lesson'));
    screen(
      'recognition, revealed',
      drill(
        DrillRequest.deck('es-en-core-100', skill: Skill.recognition),
        const DrillPreset(target: 'la casa', reveal: true),
      ),
    );
    screen('choosing the meaning', gallery('drill-choose-meaning'));
    screen(
      'match pairs, with its tap-to-hear button',
      drill(
        DrillRequest.untaught('es-en-core-100', skill: Skill.recognition),
        const DrillPreset(target: 'la casa', ask: Ask.matchPairs),
      ),
    );
    screen('rearranging', gallery('drill-rearrange'));
    // A typed answer with the keyboard open: the prompt, the field and
    // Check stay in view above it; then its feedback.
    screen('typed production, the keyboard open, then its feedback', (
      tester,
      mode,
    ) async {
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'te-en-first-words',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: 'నమస్కారం'),
        ),
        themeMode: mode,
      );
      await tester.enterText(find.byType(TextField), 'nama');
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      for (final shown in <Finder>[
        find.byType(TextField),
        find.text(l10n.drillCheck),
      ]) {
        expect(shown.hitTestable(), findsOneWidget);
        expect(tester.getRect(shown).bottom, lessThanOrEqualTo(844 - 336));
      }
      expect(tester.takeException(), isNull);
      await meetsEveryGuideline(tester);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.drillCheck));
      await tester.pumpAndSettle();
    });
    screen(
      'listening',
      drill(DrillRequest.deck('es-en-core-100', skill: Skill.listening)),
    );
    screen('speaking', gallery('drill-speaking'));
    screen('grammar, answered', gallery('drill-grammar-right'));
    screen('minimal pairs, a wrong pick', gallery('drill-pair-wrong'));
    screen(
      'a reading passage, its glossary open',
      gallery('drill-reading-glossary'),
    );
    screen(
      'a split set card',
      page(
        DrillPage(
          request: DrillRequest.lesson(language: 'zz', deckId: 'zz-en-home'),
        ),
        state: () async => AppState.test(
          decks: MemoryDeckSource(setFiles()),
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningLanguages: const <String>['zz'],
          ),
        ),
      ),
    );
    screen('the script guide', gallery('script-guide'));
    screen('braille typed on its keyboard', (tester, mode) async {
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'qbe-en-letters',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: '⠃'),
        ),
        state: brailleApp(<String>['qbe']),
        themeMode: mode,
      );
      expect(find.byType(BrailleKeyboard), findsOneWidget);
    });
  });

  group('Profiles', () {
    screen('the PIN', gallery('pin'));
  });
}
