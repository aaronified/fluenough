// Grammar understood where skills are shown (B1 format spec 4.7, 4.8 item
// 7): the Grammar switch in Settings and the Grammar tile on Today cover it
// with grammar produced; its own row on the Adjust sheet and on How you
// learn, where each schedule is fitted, named in the learner's words.
import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/theme.dart';

import '../support/fit_learner.dart';
import '../support/harness.dart';
import 'settings/support.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';
const rulesDeck = 'zz-en-grammar-case-endings';

/// Every file of Appendix A, keyed as the catalog keys bundled decks.
Map<String, String> appendixFiles() => <String, String>{
  for (final file in Directory(appendix).parent.listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/${file.path.substring(Directory(appendix).parent.path.length + 1)}':
          file.readAsStringSync(),
};

/// FSRS-6's defaults, with a right answer keeping a word longer.
final List<double> keepsLonger = <double>[
  for (final (i, w) in Fsrs.w.indexed) i == 8 ? w + 0.6 : w,
];

final DateTime now = DateTime(2026, 10, 9, 18);

/// A Testlang learner whose rules cells were answered three days ago, the
/// first four understood and the last four produced, so that all are due;
/// with grammar understood fitted to keep forms longer when [fitted].
Future<AppState> zzLearner({bool fitted = false}) async {
  AppState build(MemoryProgress progress) => AppState.test(
    decks: MemoryDeckSource(appendixFiles()),
    progress: progress,
    now: now,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['zz'],
    )..learningChosen = true,
  );
  final base = build(MemoryProgress());
  await base.load();
  final at = now.subtract(const Duration(days: 3));
  final progress = MemoryProgress();
  final cells = base.deckById(rulesDeck)!.cards;
  expect(cells, hasLength(8));
  for (final (i, card) in cells.indexed) {
    progress.record(
      deckId: card.deckId,
      cardId: card.id,
      mode: i < 4 ? DrillMode.grammarUnderstood : DrillMode.grammar,
      grade: 3,
      now: at,
    );
  }
  if (fitted) {
    await progress.putFitted(
      (language: 'zz', mode: DrillMode.grammarUnderstood),
      FittedParameters(
        values: keepsLonger,
        fittedAt: now,
        reviewCount: 4,
        lossBefore: 0.4,
        lossAfter: 0.3,
      ),
    );
  }
  final state = build(progress);
  await state.load();
  return state;
}

void main() {
  group('the learner\'s words', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('grammar understood is named apart from grammar used', () {
      expect(l10n.paceSkillName('grammarUnderstood'), 'Grammar understood');
      expect(l10n.paceSkillName('grammar'), 'Grammar used');
      expect(Skill.grammar.label(l10n), 'Grammar');
      // Never the fallback, "Words", in any of the pace strings.
      for (final mode in ['grammarUnderstood', 'grammar']) {
        expect(l10n.adjustedNotYet(mode), isNot(startsWith('Words')));
        expect(l10n.adjustedSame(mode), isNot(startsWith('Words')));
        expect(l10n.adjustedMore(mode), isNot(startsWith('Words')));
        expect(l10n.adjustedFewer(mode), isNot(contains(' words well')));
        expect(
          l10n.settingsAdjusting('Telugu', mode, 1, 2),
          isNot(contains('words')),
        );
        expect(l10n.paceComesBack(mode, 6, 4), isNot(startsWith('A word ')));
        expect(l10n.paceComesBackSame(mode, 6), isNot(startsWith('A word ')));
      }
      expect(
        l10n.paceComesBack('grammarUnderstood', 6, 4),
        "A form's meaning you get right comes back in 6 days, not 4.",
      );
      expect(
        l10n.paceComesBack('grammar', 6, 4),
        'A form you get right comes back in 6 days, not 4.',
      );
    });

    test('it is Grammar\'s skill: its colour, icon and label', () {
      expect(Skill.of(DrillMode.grammarUnderstood), Skill.grammar);
      expect(
        Skill.values.map((s) => s.name),
        isNot(contains('grammarUnderstood')),
      );
      for (final colours in [ModeColors.light, ModeColors.dark]) {
        expect(
          colours.forSkill(Skill.of(DrillMode.grammarUnderstood)),
          colours.forSkill(Skill.grammar),
        );
      }
    });
  });

  testWidgets('Settings\' one Grammar switch stops both schedules', (
    tester,
  ) async {
    usePhone(tester);
    final state = await zzLearner();
    await pumpScreen(tester, const SettingsPage(), state: state);
    final l10n = l10nOf(tester);
    final title = find.text(l10n.skillGrammar);
    await scrollTo(tester, title);
    expect(title, findsOneWidget);
    expect(find.text(l10n.skillGrammarSettingsOn), findsOneWidget);
    expect(
      state.sessionModes,
      containsAll(<DrillMode>[DrillMode.grammarUnderstood, DrillMode.grammar]),
    );
    final toggle = find.ancestor(of: title, matching: find.byType(GroupedTile));
    await tester.tap(toggle.first);
    await tester.pumpAndSettle();
    expect(state.settings.isEnabled(Skill.grammar), isFalse);
    expect(state.sessionModes, isNot(contains(DrillMode.grammarUnderstood)));
    expect(state.sessionModes, isNot(contains(DrillMode.grammar)));
    expect(state.buildSession(const DrillRequest.today()).items, isEmpty);
  });

  testWidgets('Today\'s Grammar tile counts and starts both', (tester) async {
    usePhone(tester);
    final state = await zzLearner();
    await pumpScreen(tester, const SizedBox(), state: state);
    var numbers = TodayNumbers.of(state);
    // Today's session asks some cells understood and some produced: one
    // tile counts them all, and starts both.
    final byMode = state.buildSession(const DrillRequest.today()).countByMode();
    expect(byMode[DrillMode.grammarUnderstood], 4);
    expect(byMode[DrillMode.grammar], 4);
    expect(numbers.bySkill[Skill.grammar], 8);
    expect(numbers.dueIn[Skill.grammar], 8);
    expect(
      state
          .buildSession(const DrillRequest(skill: Skill.grammar))
          .items
          .map((i) => i.mode)
          .toSet(),
      {DrillMode.grammarUnderstood, DrillMode.grammar},
    );

    // Grammar switched off: neither is counted or asked.
    state.settings.setSkillEnabled(Skill.grammar, false);
    numbers = TodayNumbers.of(state);
    expect(numbers.bySkill[Skill.grammar], 0);
    expect(numbers.dueIn[Skill.grammar], 0);
  });

  testWidgets('How you learn names it, and its fit marks the Grammar tile', (
    tester,
  ) async {
    usePhone(tester);
    final state = await zzLearner(fitted: true);
    await pumpScreen(tester, const HowYouLearnPage(), state: state);
    final l10n = l10nOf(tester);
    final understood = find.text(l10n.paceSkillName('grammarUnderstood'));
    final used = find.text(l10n.paceSkillName('grammar'));
    await tester.scrollUntilVisible(
      used,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(understood, findsOneWidget);
    expect(used, findsOneWidget);
    // Understood is listed before produced, as on the Grammar tile.
    expect(
      tester.getTopLeft(understood).dy,
      lessThan(tester.getTopLeft(used).dy),
    );
    expect(find.text(l10n.adjustedNotYet('grammar')), findsOneWidget);
    // Fitted on its own: grammar used keeps the start's pace.
    expect(state.progress.parameters.sourceOf('zz', DrillMode.grammar), isNull);

    final pace = todayPaceOf(state);
    expect(pace, isNotNull);
    expect(pace!.marks.keys, [Skill.grammar]);
  });

  testWidgets('the Adjust sheet names it in the learner\'s words', (
    tester,
  ) async {
    usePhone(tester);
    final start = DateTime(2026, 1, 1, 9);
    final progress = MemoryProgress();
    for (final r in simulate(
      language: 'hi',
      start: start,
      until: now,
      mode: DrillMode.grammarUnderstood,
    )) {
      progress.record(
        deckId: r.deckId,
        cardId: r.key.cardId,
        mode: r.key.mode,
        grade: r.grade,
        now: r.at,
        answerGiven: r.answerGiven,
      );
    }
    final state = AppState.test(progress: progress, now: now);
    await pumpScreen(tester, const SettingsPage(), state: state);
    final l10n = l10nOf(tester);
    final button = find.widgetWithText(FilledButton, l10n.settingsAdjustButton);
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(l10n.adjustedTitle), findsOneWidget);
    const mode = 'grammarUnderstood';
    expect(
      find.textContaining(
        RegExp(
          '^(${RegExp.escape(l10n.adjustedFewer(mode))}|'
          '${RegExp.escape(l10n.adjustedMore(mode))}|'
          '${RegExp.escape(l10n.adjustedSame(mode))})\$',
        ),
      ),
      findsOneWidget,
    );
    expect(
      state.progress.parameters.fitted[(
        language: 'hi',
        mode: DrillMode.grammarUnderstood,
      )],
      isNotNull,
    );
    expect(state.progress.parameters.fitted.keys.map((k) => k.mode), [
      DrillMode.grammarUnderstood,
    ]);
  });

  group('the questions on screen (4.8, 6)', () {
    testWidgets('the meaning: the form with its reading, then meanings', (
      tester,
    ) async {
      usePhone(tester);
      final state = await zzLearner();
      await pumpScreen(
        tester,
        const DrillPage(
          request: DrillRequest(deckIds: {rulesDeck}, untaught: true),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      // The first four cells were understood three days ago: due in it.
      expect(find.byType(ChoiceDrill), findsOneWidget);
      expect(find.text(l10n.drillChooseMeaning), findsOneWidget);
      expect(find.text('iṇṭlō'), findsWidgets);
      for (final meaning in [
        'at home',
        'home (going there)',
        'with home',
        'from home',
      ]) {
        expect(find.text(meaning), findsOneWidget);
      }
      await tester.tap(find.text('at home'));
      await tester.pumpAndSettle();
      final review = state.progress.log.last;
      expect(review.mode, DrillMode.grammarUnderstood);
      expect(review.grade, 4);
    });

    testWidgets('the form: the word and the meaning, then forms; typed once '
        'remembered, with the word shown', (tester) async {
      usePhone(tester);
      final state = await zzLearner();
      // Every cell understood just now, so the produced cells come first.
      for (final card in state.deckById(rulesDeck)!.cards) {
        state.progress.record(
          deckId: card.deckId,
          cardId: card.id,
          mode: DrillMode.grammarUnderstood,
          grade: 3,
          now: now,
        );
      }
      await pumpScreen(
        tester,
        const DrillPage(
          request: DrillRequest(deckIds: {rulesDeck}, untaught: true),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      // A cell remembered three days ago: typed, its word and reading shown.
      expect(find.byType(TypedDrill), findsOneWidget);
      expect(find.text('అమ్మ (amma): in mother'), findsOneWidget);
      // ...and the cells never produced are chosen.
      final items = state.sessionItems(
        const DrillRequest(deckIds: {rulesDeck}, untaught: true),
      );
      final chosen = items.firstWhere((i) => i.ask == Ask.chooseForm);
      expect(chosen.mode, DrillMode.grammar);
      expect(chosen.card.rule!.word, 'zz-9001');
      expect(l10n.drillChooseForm, isNotEmpty);
    });
  });
}
