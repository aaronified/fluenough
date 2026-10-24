// Today's skill tiles with a Script skill (owner, 2026-10-24): the script
// decks' Recognition and Write are one Script tile, apart from the word
// skills' tiles, and the six tiles lay out three to a row at 1.4x text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/script_split.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';

import 'support/harness.dart';
import 'support/two_script_course.dart';

/// Hindustani with a Devanagari letter, an Urdu letter and two words, each
/// reviewed three days ago: the Devanagari letter in Recognition, the Urdu
/// letter in Write, the first word in Recognition and the second in Write.
/// So two script reviews and two word reviews are due. With [speaking],
/// Say is on too, so that Today draws six tiles.
Future<AppState> twoScriptsDue({bool speaking = false}) async {
  final progress = MemoryProgress();
  final base = DateTime(2026, 10, 24, 9);
  void review(String deck, String card, DrillMode mode) => progress.record(
    deckId: deck,
    cardId: card,
    mode: mode,
    grade: 4,
    now: base.subtract(const Duration(days: 3)),
  );
  review('hi-en-letters', 'hi-en-letters-0001', DrillMode.recognition);
  review('hi-en-urdu-letters', 'hi-en-urdu-letters-0001', DrillMode.production);
  review('hi-en-words', 'hi-en-words-0001', DrillMode.recognition);
  review('hi-en-words', 'hi-en-words-0002', DrillMode.production);
  final state = AppState.test(
    decks: MemoryDeckSource(twoScriptCourse()),
    progress: progress,
    speech: FixedSpeechEngine(onDevice: const <String>{'hi'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        if (speaking) Skill.speaking,
      },
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  if (speaking) await state.startSpeech();
  return state;
}

Set<String> idsOf(AppState state, DrillRequest request) => <String>{
  for (final item in state.buildSession(request).items) item.card.id,
};

void main() {
  group('Script on Today', () {
    test('script reading and writing are one count, kept out of Recognition '
        'and Write, and no card is counted twice', () async {
      final state = await twoScriptsDue();
      final letters = state.deckById('hi-en-letters')!;
      expect(state.needsAlphabet(letters), isTrue);
      final numbers = TodayNumbers.of(state);

      expect(numbers.script!.count, 2, reason: 'Read and Write together');
      expect(numbers.bySkill[Skill.recognition], 1);
      expect(numbers.bySkill[Skill.production], 1);
      // Every card of the session is in exactly one count.
      final counted =
          numbers.script!.count +
          numbers.bySkill.values.fold(0, (a, b) => a + b);
      expect(counted, numbers.due);
    });

    test('the Script tile drills only script decks, in Recognition and '
        'Write, and the word tiles leave them out', () async {
      final state = await twoScriptsDue();
      final script = state.buildSession(const DrillRequest.script());
      expect(script.items.map((i) => i.card.id).toSet(), <String>{
        'hi-en-letters-0001',
        'hi-en-urdu-letters-0001',
      });
      expect(
        script.items.every((i) => ScriptSplit.modes.contains(i.mode)),
        isTrue,
      );
      expect(
        idsOf(
          state,
          const DrillRequest(
            skill: Skill.recognition,
            script: ScriptScope.without,
          ),
        ),
        <String>{'hi-en-words-0001'},
      );
      expect(
        idsOf(
          state,
          const DrillRequest(
            skill: Skill.production,
            script: ScriptScope.without,
          ),
        ),
        <String>{'hi-en-words-0002'},
      );
      expect(
        TodayNumbers.of(state).script!.due,
        script.length,
        reason: 'what the tile starts is what it counts',
      );
    });

    test('a learner with no script deck has no Script tile', () async {
      final course = twoScriptCourse();
      final state = AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/hi/hi-en-words.yaml': course['decks/hi/hi-en-words.yaml']!,
        }),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
          learningChosen: true,
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      expect(TodayNumbers.of(state).script, isNull);
    });
  });

  group('the skill tiles', () {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('six thin tiles, three to a row, fit at 1.4x on 360 dp in '
          '${mode.name}', (tester) async {
        usePhone(tester, textScale: 1.4);
        tester.view.physicalSize = const Size(360 * 3, 844 * 3);
        final state = await twoScriptsDue(speaking: true);
        await pumpScreen(
          tester,
          const TodayPage(),
          state: state,
          themeMode: mode,
        );
        expect(tester.takeException(), isNull, reason: 'no overflow at 1.4x');
        final l10n = AppLocalizations.of(
          tester.element(find.byType(TodayPage)),
        )!;
        final names = <String>[
          l10n.skillRecognition,
          l10n.skillListening,
          l10n.skillSpeaking,
          l10n.skillProduction,
          l10n.skillGrammar,
          l10n.skillScript,
        ];
        final rects = <Rect>[];
        for (final name in names) {
          final label = find.descendant(
            of: find.byType(DueCard),
            matching: find.text(name),
          );
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          expect(label, findsOneWidget, reason: name);
          rects.add(
            tester.getRect(
              find.ancestor(of: label, matching: find.byType(Material)).first,
            ),
          );
        }
        // Two full rows of three, level and equal in width.
        expect(rects[0].top, rects[1].top);
        expect(rects[1].top, rects[2].top);
        expect(rects[3].top, rects[4].top);
        expect(rects[4].top, rects[5].top);
        expect(rects[3].top, greaterThan(rects[0].bottom));
        expect(rects[0].width, closeTo(rects[1].width, 0.01));
        expect(rects[2].right, lessThanOrEqualTo(360));
        // The words "Fewer reviews" and "More reviews" are not drawn.
        expect(find.text(l10n.paceFewer), findsNothing);
        expect(find.text(l10n.paceMore), findsNothing);
      });
    }

    testWidgets('tapping Script starts a drill of the script decks only', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      final state = await twoScriptsDue();
      await pumpScreen(tester, const TodayPage(), state: state);
      final l10n = AppLocalizations.of(tester.element(find.byType(TodayPage)))!;
      final label = find.descendant(
        of: find.byType(DueCard),
        matching: find.text(l10n.skillScript),
      );
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pumpAndSettle();
      final request = tester.widget<DrillPage>(find.byType(DrillPage)).request;
      expect(request.script, ScriptScope.only);
      expect(idsOf(state, request), <String>{
        'hi-en-letters-0001',
        'hi-en-urdu-letters-0001',
      });
    });
  });
}
