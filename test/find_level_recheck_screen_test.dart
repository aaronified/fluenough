// Check again (wiki/Plan-Placement-V2.md, point 17.5): the languages sheet
// row for an unconfirmed placement, and "Your level, before and now" at the
// end of the run, with its two choices. Nothing is written until one is
// pressed. Drawn at 1.4x text, light and dark, with the screen reader's
// guidelines.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/placement_recheck.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/course_path.dart' show Milestone;
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';
import 'package:fluenough/core/placement/placement_session.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/placement_withdrawal.dart';
import 'package:fluenough/features/languages/language_skills_sheet.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:fluenough/features/placement/find_level_comparison.dart';
import 'package:fluenough/features/placement/find_level_declaration.dart';
import 'package:fluenough/features/placement/find_level_run_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/accessibility_shared.dart';
import 'support/find_level_fixture.dart';
import 'support/harness.dart';
import 'support/picker.dart';

const LanguageInfo _language = LanguageInfo(
  code: 'xx',
  iso639_3: 'xxx',
  name: 'Xish',
  script: 'devanagari',
);
const LanguageInfo _native = LanguageInfo(
  code: 'en',
  iso639_3: 'eng',
  name: 'English',
);

/// A run that reads out what it is told.
class _FixedRun extends PlacementRun {
  _FixedRun(super.config, this.fixed);

  final Map<PlacementSkill, SkillAssurance> fixed;

  @override
  Map<PlacementSkill, SkillAssurance> get readout => fixed;
}

SkillAssurance _found(
  PlacementSkill skill, {
  required int level,
  AssuranceLabel label = AssuranceLabel.notSureYet,
  bool lowerBound = false,
}) => SkillAssurance(
  skill: skill,
  label: label,
  mass: 0.3,
  leadingClass: lowerBound ? level + 3 : level + 1,
  placedClass: level + 1,
  placedLevel: level,
  questions: 20,
);

PlacementRun _run(Map<PlacementSkill, SkillAssurance> fixed) =>
    _FixedRun(findLevelConfig(skills: fixed.keys.toSet()), fixed);

FindLevelComparison _comparison({
  required PlacementRun run,
  Map<PlacementSkill, int> before = const <PlacementSkill, int>{
    PlacementSkill.read: 107,
  },
  VoidCallback? onUse,
  VoidCallback? onKeep,
}) => FindLevelComparison(
  run: run,
  recheck: FindLevelRecheck(
    before: before,
    onUse: onUse ?? () {},
    onKeep: onKeep ?? () {},
  ),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

B1Unit _written(Milestone? m) => B1Unit(words: 10, milestone: m, has: 10);

CatalogLanguage _course() => CatalogLanguage(
  code: 'es',
  name: 'Spanish',
  natives: <CatalogNative>[
    (
      code: 'en',
      name: 'English',
      progress: B1Progress.of(<B1Unit>[
        _written(Milestone.a1),
        _written(Milestone.a2),
        _written(Milestone.b1),
      ]),
    ),
  ],
);

SpokenLanguage get _es => pickerSpokenList.firstWhere((l) => l.code == 'es');

/// 0.9.0's credit for Spanish: a few cards of one deck, at [at].
Future<AppState> _creditedState(DateTime at) async {
  final state = AppState.test(
    now: DateTime.utc(2026, 11, 8, 9),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  final deck = state.deckById('es-en-core-100')!;
  for (final card in deck.cards.take(3)) {
    state.progress.record(
      deckId: deck.id,
      cardId: card.id,
      mode: DrillMode.recognition,
      grade: 5,
      now: at,
      asked: Ask.own,
    );
  }
  state.settings.addPlacedAt('es', momentOf(at));
  return state;
}

Future<void> _pumpSheet(WidgetTester tester, AppState state) async {
  usePhone(tester);
  await pumpScreen(
    tester,
    Scaffold(
      body: LanguageSkillsSheet(
        view: LanguageView(_es, _course()),
        initial: LanguageSkills(<SkillKey, SkillState>{
          const SkillKey(SkillKind.read, 'latin'): SkillState.know,
        }),
      ),
    ),
    state: state,
  );
}

void main() {
  final t1 = DateTime.utc(2026, 11, 7, 6, 0, 0, 125);

  group('"Your level, before and now"', () {
    testWidgets('says each tested skill before and now, and that nothing '
        'changes until the learner chooses', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        _comparison(
          run: _run(<PlacementSkill, SkillAssurance>{
            PlacementSkill.read: _found(PlacementSkill.read, level: -1),
          }),
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.findLevelCompareTitle), findsOneWidget);
      expect(
        find.text('Read: unit 108 → from the start · Not sure yet'),
        findsOneWidget,
      );
      expect(find.text('Nothing changes until you choose.'), findsOneWidget);
      // Less than before: no reassurance.
      expect(find.text('The check found at least what you had.'), findsNothing);
      expect(find.text('Use the new level'), findsOneWidget);
      expect(find.text('Keep the old level'), findsOneWidget);
    });

    testWidgets('says "at least unit" while a higher class is more probable, '
        'and that the check found at least what the learner had', (
      tester,
    ) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        _comparison(
          before: const <PlacementSkill, int>{PlacementSkill.read: 3},
          run: _run(<PlacementSkill, SkillAssurance>{
            PlacementSkill.read: _found(
              PlacementSkill.read,
              level: 119,
              label: AssuranceLabel.sure,
              lowerBound: true,
            ),
          }),
        ),
      );
      expect(
        find.text('Read: unit 4 → at least unit 120 · Sure'),
        findsOneWidget,
      );
      expect(
        find.text('The check found at least what you had.'),
        findsOneWidget,
      );
    });

    testWidgets('each button is a button, and does what it says', (
      tester,
    ) async {
      var used = 0;
      var kept = 0;
      final semantics = tester.ensureSemantics();
      usePhone(tester);
      await pumpScreen(
        tester,
        _comparison(
          onUse: () => used++,
          onKeep: () => kept++,
          run: _run(<PlacementSkill, SkillAssurance>{
            PlacementSkill.read: _found(PlacementSkill.read, level: -1),
          }),
        ),
      );
      expect(
        tester.getSemantics(find.text('Use the new level')),
        isSemantics(label: 'Use the new level', isButton: true),
      );
      expect(
        tester.getSemantics(find.text('Your level, before and now')),
        isSemantics(label: 'Your level, before and now', isHeader: true),
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-keep-old')),
      );
      expect(kept, 1);
      expect(used, 0);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-use-new')),
      );
      expect(used, 1);
      semantics.dispose();
    });

    screen(
      'the comparison screen',
      page(
        _comparison(
          run: _run(<PlacementSkill, SkillAssurance>{
            PlacementSkill.read: _found(PlacementSkill.read, level: -1),
            PlacementSkill.write: _found(
              PlacementSkill.write,
              level: 40,
              lowerBound: true,
              label: AssuranceLabel.fairlySure,
            ),
          }),
          before: const <PlacementSkill, int>{
            PlacementSkill.read: 107,
            PlacementSkill.write: 107,
          },
        ),
      ),
    );
  });

  group('the run page of a Check again', () {
    Future<List<Object?>> open(
      WidgetTester tester,
      FindLevelRecheck recheck,
      List<PlacementSession> finished,
    ) async {
      final popped = <Object?>[];
      usePhone(tester);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey<String>('open'),
                onPressed: () async {
                  final result = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute<Object?>(
                      builder: (_) => FindLevelRunPage(
                        session: PlacementSession(
                          findLevelConfig(),
                          findLevelData(),
                        ),
                        languageName: 'Xish',
                        language: _language,
                        native: _native,
                        onProgress: (_) {},
                        onFinish: finished.add,
                        recheck: recheck,
                      ),
                    ),
                  );
                  popped.add(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, find.byKey(const ValueKey<String>('open')));
      final use = find.byKey(const ValueKey<String>('find-level-use-new'));
      final keep = find.byKey(const ValueKey<String>('find-level-keep-going'));
      var taps = 0;
      while (use.evaluate().isEmpty && taps++ < 400) {
        await _tap(
          tester,
          keep.evaluate().isNotEmpty
              ? keep
              : find.byKey(const ValueKey<String>('find-level-dont-know')),
        );
      }
      return popped;
    }

    testWidgets('ends on the comparison and writes nothing until Use the new '
        'level', (tester) async {
      var used = 0;
      var kept = 0;
      final finished = <PlacementSession>[];
      final popped = await open(
        tester,
        FindLevelRecheck(
          before: const <PlacementSkill, int>{PlacementSkill.read: 4},
          onUse: () => used++,
          onKeep: () => kept++,
        ),
        finished,
      );
      expect(find.text(l10nOf(tester).findLevelCompareTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('find-level-done')),
        findsNothing,
      );
      expect(finished, isEmpty, reason: 'the run itself writes nothing');
      expect(used + kept, 0);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-use-new')),
      );
      expect(used, 1);
      expect(kept, 0);
      expect(popped, <Object?>[true]);
    });

    testWidgets('Keep the old level writes only that choice', (tester) async {
      var used = 0;
      var kept = 0;
      final popped = await open(
        tester,
        FindLevelRecheck(
          before: const <PlacementSkill, int>{PlacementSkill.read: 4},
          onUse: () => used++,
          onKeep: () => kept++,
        ),
        <PlacementSession>[],
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-keep-old')),
      );
      expect(kept, 1);
      expect(used, 0);
      expect(popped, <Object?>[true]);
    });

    testWidgets('Back pauses the run and writes nothing', (tester) async {
      var used = 0;
      var kept = 0;
      final popped = await open(
        tester,
        FindLevelRecheck(
          before: const <PlacementSkill, int>{PlacementSkill.read: 4},
          onUse: () => used++,
          onKeep: () => kept++,
        ),
        <PlacementSession>[],
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(used + kept, 0);
      expect(popped, <Object?>[false]);
    });

    testWidgets('a choice that cannot be written says so and keeps the '
        'comparison', (tester) async {
      await open(
        tester,
        FindLevelRecheck(
          before: const <PlacementSkill, int>{PlacementSkill.read: 4},
          onUse: () => throw StateError('disk full'),
          onKeep: () {},
        ),
        <PlacementSession>[],
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-use-new')),
      );
      expect(find.text(l10nOf(tester).findLevelFinishFailed), findsOneWidget);
      expect(find.text(l10nOf(tester).findLevelCompareTitle), findsOneWidget);
    });
  });

  group('the language sheet\'s level row', () {
    testWidgets('reads "Check your level again" for an unconfirmed '
        'placement, and runs the check on tap', (tester) async {
      final state = await _creditedState(t1);
      await _pumpSheet(tester, state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.languagesCheckAgain), findsOneWidget);
      expect(find.text(l10n.languagesCheckAgainSub), findsOneWidget);
      expect(find.text(l10n.languagesFindLevel), findsNothing);

      final row = find.byKey(const ValueKey<String>('languages-level'));
      await _tap(tester, row);
      expect(find.byType(FindLevelDeclarationPage), findsOneWidget);
      // Nothing changes until a button is pressed: Back writes nothing.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(state.progress.withdrawals, isEmpty);
      expect(state.unconfirmedMomentsOf('es'), <int>{momentOf(t1)});
    });

    testWidgets('is back to Find or Fit my level once the old level is '
        'kept', (tester) async {
      final state = await _creditedState(t1);
      state.keepOldLevel('es');
      await _pumpSheet(tester, state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.languagesCheckAgain), findsNothing);
      expect(
        find.text(l10n.languagesFitMyLevel).evaluate().length +
            find.text(l10n.languagesFindLevel).evaluate().length,
        1,
      );
    });

    testWidgets('a placement stamped by this version is never flagged', (
      tester,
    ) async {
      final state = await _creditedState(t1);
      state.settings.stampPlacedBy('es', momentOf(t1), 2);
      await _pumpSheet(tester, state);
      expect(find.text(l10nOf(tester).languagesCheckAgain), findsNothing);
    });

    testWidgets('a placement from before 0.9.0 is not flagged', (tester) async {
      final state = await _creditedState(DateTime.utc(2026, 10, 1, 8));
      await _pumpSheet(tester, state);
      expect(find.text(l10nOf(tester).languagesCheckAgain), findsNothing);
    });
  });
}
