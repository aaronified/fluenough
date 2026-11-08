// Find my level (owner, 2026-11-05; wiki/Plan-Placement-V2.md, steps 3 and 4)
// from a language's sheet: tapping it never changes a skill; a language
// whose decks are not on the phone is downloaded first, and the declaration
// opens straight after, on the one tap; Back cancels everything; Beginner
// asks and writes nothing; a paused run is offered back.

import 'dart:async';
import 'dart:convert';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/language_skills.dart';
import 'package:fluenough/app/placement_run_setup.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/data/course_path.dart' show Milestone;
import 'package:fluenough/core/data/spoken_languages.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/item_bank.dart';
import 'package:fluenough/core/placement/saved_run.dart'
    show placementDeckSetKey;
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/saved_v3_run.dart';
import 'package:fluenough/core/placement/v3_session.dart' show V3ScriptStart;
import 'package:fluenough/features/languages/language_skills_sheet.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:fluenough/features/placement/find_level_declaration.dart';
import 'package:fluenough/features/placement/v3_run_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/harness.dart';
import 'support/picker.dart';
import 'support/v3_small_bank.dart';

/// Holds no decks until [download] is called, which waits on [gate].
class _LateDecks extends DeckDownloads {
  _LateDecks()
    : super(
        fetcher: FakeDeckRemote(<String, String>{}),
        files: MemoryDownloadedDecks(),
        clock: DateTime.now,
      );

  final Completer<void> gate = Completer<void>();
  final List<String> downloaded = <String>[];
  bool _held = false;

  @override
  bool hasDecks(String language) => _held;

  @override
  Future<bool> ensureIndex() async => false;

  @override
  Future<DeckDownloadFailure?> download(
    String language,
    List<String> spoken,
  ) async {
    downloaded.add(language);
    await gate.future;
    _held = true;
    return null;
  }
}

B1Unit _written(Milestone? m) => B1Unit(words: 10, milestone: m, has: 10);

/// Spanish as the catalog shows it, its path written to [built] levels.
CatalogLanguage _course(int built) => CatalogLanguage(
  code: 'es',
  name: 'Spanish',
  natives: <CatalogNative>[
    (
      code: 'en',
      name: 'English',
      progress: B1Progress.of(<B1Unit>[
        if (built >= 1) _written(Milestone.a1),
        if (built >= 2) _written(Milestone.a2),
        if (built >= 3) _written(Milestone.b1),
        if (built < 3)
          B1Unit(
            planned: true,
            words: 10,
            milestone: switch (built) {
              0 => Milestone.a1,
              1 => Milestone.a2,
              _ => Milestone.b1,
            },
          ),
      ]),
    ),
  ],
);

SpokenLanguage get _es => pickerSpokenList.firstWhere((l) => l.code == 'es');

const SkillKey _readLatin = SkillKey(SkillKind.read, 'latin');

/// A learner who knows how to read Spanish, on a phone with [downloads].
Future<AppState> _pumpSheet(
  WidgetTester tester, {
  required int built,
  DeckDownloads? downloads,
  AppState? state,
  LanguageSkills? initial,
}) async {
  final s =
      state ??
      AppState.test(
        // The bank takes seconds and an isolate: the screens are given a
        // small one.
        bankRunner: (_, _, _, _) async => smallV3Bank(),
        deckDownloads: downloads,
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
      );
  addTearDown(s.dispose);
  usePhone(tester);
  await pumpScreen(
    tester,
    Scaffold(
      body: LanguageSkillsSheet(
        view: LanguageView(_es, _course(built)),
        initial:
            initial ??
            LanguageSkills(<SkillKey, SkillState>{_readLatin: SkillState.know}),
      ),
    ),
    state: s,
  );
  return s;
}

Future<void> _tapLevel(WidgetTester tester) async {
  final row = find.byKey(const ValueKey<String>('languages-level'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one tap downloads the decks, opens the declaration, and '
      'changes no skill', (tester) async {
    final downloads = _LateDecks();
    final state = await _pumpSheet(tester, built: 3, downloads: downloads);
    final skillsBefore = state.settings.languageSkillsOf('es');

    final row = find.byKey(const ValueKey<String>('languages-level'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    await tester.pump();
    // Downloading behind the dialog; nothing has been switched on.
    expect(downloads.downloaded, <String>['es']);
    expect(find.byType(FindLevelDeclarationPage), findsNothing);
    expect(state.settings.languageSkillsOf('es'), skillsBefore);

    downloads.gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FindLevelDeclarationPage), findsOneWidget);
    expect(state.settings.languageSkillsOf('es'), skillsBefore);
  });

  group('the Find my level row', () {
    testWidgets('known skills are verified first', (tester) async {
      await _pumpSheet(
        tester,
        built: 3,
        initial: LanguageSkills(<SkillKey, SkillState>{
          const SkillKey(SkillKind.hear): SkillState.know,
        }),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.languagesVerifyKnown), findsOneWidget);
    });

    testWidgets('letters known from English are not words known: Spanish '
        'with Read in Latin known offers Find my level, not Verify', (
      tester,
    ) async {
      await _pumpSheet(tester, built: 3);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.languagesVerifyKnown), findsNothing);
      expect(find.text(l10n.languagesFindLevel), findsOneWidget);
    });

    testWidgets('a language never placed shows no labels; a placed one shows '
        'each skill\'s name and an earlier Verified mark as an earlier check', (
      tester,
    ) async {
      await _pumpSheet(tester, built: 3);
      final l10n = l10nOf(tester);
      expect(find.textContaining('${l10n.findLevelSkillHear}: '), findsNothing);

      final settings =
          SettingsNotifier(
              spokenLanguages: const <String>['en'],
              learningChosen: true,
            )
            ..setSkillLabels('es', <String, String>{
              'hear': 'verified',
              'say': 'notSureYet',
              'read': 'sure',
            })
            ..setVerifiedSkills('es', <String>{'hear'});
      await _pumpSheet(
        tester,
        built: 3,
        state: AppState.test(settings: settings),
      );
      expect(
        find.text('${l10n.findLevelSkillHear}: ${l10n.findLevelLabelVerified}'),
        findsOneWidget,
      );
      // An earlier version's mark is not a claim: no tick.
      expect(find.byIcon(Icons.verified), findsNothing);
      expect(
        find.text(
          '${l10n.findLevelSkillSay}: ${l10n.findLevelLabelNotSureYet}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('${l10n.findLevelSkillRead}: ${l10n.findLevelLabelSure}'),
        findsOneWidget,
      );
      // A percentage is never on the row.
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('is not offered below A1', (tester) async {
      await _pumpSheet(tester, built: 0);
      expect(
        find.byKey(const ValueKey<String>('languages-level')),
        findsNothing,
      );
    });

    testWidgets('is offered once A1 is written', (tester) async {
      await _pumpSheet(tester, built: 1);
      expect(
        find.byKey(const ValueKey<String>('languages-level')),
        findsOneWidget,
      );
    });
  });

  group('the declaration', () {
    testWidgets('offers only what the built path supports', (tester) async {
      await _pumpSheet(tester, built: 1);
      await _tapLevel(tester);
      expect(find.text('Amateur'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Advanced'), findsNothing);
      expect(find.text('Expert'), findsNothing);
    });

    testWidgets('Back cancels the whole of Find my level and writes nothing', (
      tester,
    ) async {
      final state = await _pumpSheet(tester, built: 3);
      await _tapLevel(tester);
      expect(find.byType(FindLevelDeclarationPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(FindLevelDeclarationPage), findsNothing);
      expect(find.byType(V3RunPage), findsNothing);
      expect(state.settings.placedDecks, isEmpty);
      expect(state.settings.placementRunOf('es'), isNull);
      expect(state.settings.verifiedSkillsOf('es'), isEmpty);
      expect(state.levelFound('es'), isFalse);
    });

    testWidgets('Beginner asks nothing, credits nothing and writes nothing', (
      tester,
    ) async {
      final state = await _pumpSheet(tester, built: 3);
      final skillsBefore = state.settings.languageSkillsOf('es');
      await _tapLevel(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('find-level-beginner')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(V3RunPage), findsNothing);
      expect(
        find.text(l10nOf(tester).findLevelBeginnerToast('Spanish')),
        findsOneWidget,
      );
      expect(state.settings.placedDecks, isEmpty);
      expect(state.settings.placementRunOf('es'), isNull);
      expect(state.settings.verifiedSkillsOf('es'), isEmpty);
      expect(state.levelFound('es'), isFalse);
      expect(state.settings.languageSkillsOf('es'), skillsBefore);
      // Find my level can be opened again.
      expect(
        find.byKey(const ValueKey<String>('languages-level')),
        findsOneWidget,
      );
    });
  });

  group('the run', () {
    testWidgets('an answer starts it; leaving pauses it, and it is offered '
        'back', (tester) async {
      final state = await _pumpSheet(tester, built: 3);
      final l10n = l10nOf(tester);
      await _tapLevel(tester);
      await tester.tap(find.byKey(const ValueKey<String>('find-level-expert')));
      await tester.pumpAndSettle();
      expect(find.byType(V3RunPage), findsOneWidget);
      expect(find.text(l10n.placementQuestionNumber(1)), findsOneWidget);

      // Closing before any answer keeps nothing.
      await tester.tap(find.byTooltip(l10n.drillEndSession));
      await tester.pumpAndSettle();
      expect(state.settings.placementRunOf('es'), isNull);

      // An answer is saved; closing pauses, and nothing is written.
      await _tapLevel(tester);
      await tester.tap(find.byKey(const ValueKey<String>('find-level-expert')));
      await tester.pumpAndSettle();
      final dontKnow = find.byKey(
        const ValueKey<String>('find-level-dont-know'),
      );
      await tester.ensureVisible(dontKnow);
      await tester.tap(dontKnow);
      await tester.pumpAndSettle();
      final saved = jsonDecode(
        state.settings.placementRunOf('es')!,
      ) as Map<String, Object?>;
      expect(saved['events'], <Object?>['d']);
      await tester.tap(find.byTooltip(l10n.drillEndSession));
      await tester.pumpAndSettle();
      expect(find.byType(V3RunPage), findsNothing);
      expect(state.settings.placedDecks, isEmpty);
      expect(state.settings.verifiedSkillsOf('es'), isEmpty);

      // Find my level again: carry on where it left off, without being asked
      // the declaration again.
      await _tapLevel(tester);
      expect(find.text(l10n.findLevelResumeTitle), findsOneWidget);
      await tester.tap(find.text(l10n.findLevelResumeGo));
      await tester.pumpAndSettle();
      expect(find.byType(FindLevelDeclarationPage), findsNothing);
      expect(find.text(l10n.placementQuestionNumber(2)), findsOneWidget);
    });

    testWidgets('"Start again" drops the paused run and asks the declaration', (
      tester,
    ) async {
      final state = await _pumpSheet(tester, built: 3);
      final l10n = l10nOf(tester);
      await _tapLevel(tester);
      await tester.tap(find.byKey(const ValueKey<String>('find-level-expert')));
      await tester.pumpAndSettle();
      final dontKnow = find.byKey(
        const ValueKey<String>('find-level-dont-know'),
      );
      await tester.ensureVisible(dontKnow);
      await tester.tap(dontKnow);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.drillEndSession));
      await tester.pumpAndSettle();
      expect(state.settings.placementRunOf('es'), isNotNull);

      await _tapLevel(tester);
      await tester.tap(find.text(l10n.findLevelResumeNew));
      await tester.pumpAndSettle();
      expect(find.byType(FindLevelDeclarationPage), findsOneWidget);
      expect(state.settings.placementRunOf('es'), isNull);
    });

    for (final starter in <bool>[false, true]) {
      testWidgets('a paused run waits for the whole bank, whether it began on '
          'the first formats ($starter) or on all of it', (tester) async {
        final gate = Completer<void>();
        final state = AppState.test(
          bankRunner: (data, onProgress, cancelled, onStarter) async {
            // The first formats are ready; the rest is not.
            onStarter(ItemBank.starterOf(smallV3Bank()));
            await gate.future;
            return smallV3Bank();
          },
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningChosen: true,
          ),
        );
        await _pumpSheet(tester, built: 3, state: state);
        final l10n = l10nOf(tester);
        final plan = state.placementRunPlan(
          'es',
          native: state.courseNative('es'),
        )!;
        state.settings.setPlacementRun(
          'es',
          jsonEncode(
            SavedV3Run(
              language: 'es',
              declaration: PlacementDeclaration.expert,
              skills: const <PlacementSkill>{PlacementSkill.read},
              seed: 1,
              audio: false,
              recogniser: false,
              scriptStart: V3ScriptStart.skip,
              starter: starter,
              deckSet: placementDeckSetKey(plan.data),
              appVersion: AppInfo.version,
              savedAt: state.now().millisecondsSinceEpoch ~/ 1000,
              events: const <String>['w'],
            ).toJson(),
          ),
        );
        await _tapLevel(tester);
        await tester.tap(find.text(l10n.findLevelResumeGo));
        await tester.pump();
        await tester.pump();
        // Not the run: the screen that waits for the whole bank.
        expect(find.byType(V3RunPage), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('find-level-preparing-progress')),
          findsOneWidget,
        );
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(V3RunPage), findsOneWidget);
      });
    }

    testWidgets('a new run begins on the first formats when the whole bank is '
        'not ready', (tester) async {
      final gate = Completer<void>();
      final state = AppState.test(
        bankRunner: (data, onProgress, cancelled, onStarter) async {
          onStarter(ItemBank.starterOf(smallV3Bank()));
          await gate.future;
          return smallV3Bank();
        },
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
      );
      await _pumpSheet(tester, built: 3, state: state);
      await _tapLevel(tester);
      await tester.tap(find.byKey(const ValueKey<String>('find-level-expert')));
      await tester.pumpAndSettle();
      expect(find.byType(V3RunPage), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(V3RunPage), findsOneWidget);
    });

    testWidgets('a paused run this phone can no longer ask is said so, and '
        'is deleted only when the new run starts', (tester) async {
      final state = await _pumpSheet(tester, built: 3);
      final l10n = l10nOf(tester);
      final plan = state.placementRunPlan(
        'es',
        native: state.courseNative('es'),
      )!;
      // Begun with a recogniser, which this phone does not have.
      final paused = jsonEncode(
        SavedV3Run(
          language: 'es',
          declaration: PlacementDeclaration.expert,
          skills: const <PlacementSkill>{PlacementSkill.read},
          seed: 1,
          audio: false,
          recogniser: true,
          scriptStart: V3ScriptStart.ask,
          deckSet: placementDeckSetKey(plan.data),
          appVersion: AppInfo.version,
          savedAt: state.now().millisecondsSinceEpoch ~/ 1000,
          events: const <String>['w'],
        ).toJson(),
      );
      state.settings.setPlacementRun('es', paused);

      await _tapLevel(tester);
      expect(find.text(l10n.findLevelResumeDeviceChanged), findsOneWidget);
      expect(find.text(l10n.findLevelResumeTitle), findsNothing);
      expect(find.byType(FindLevelDeclarationPage), findsOneWidget);
      // Nothing is deleted before the learner chooses: Back keeps it.
      expect(state.settings.placementRunOf('es'), paused);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(state.settings.placementRunOf('es'), paused);

      // Starting the new run replaces it.
      await _tapLevel(tester);
      await tester.tap(find.byKey(const ValueKey<String>('find-level-expert')));
      await tester.pumpAndSettle();
      expect(find.byType(V3RunPage), findsOneWidget);
      expect(state.settings.placementRunOf('es'), isNull);
    });
  });
}
