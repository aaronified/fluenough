// Find my level's screens (wiki/Plan-Placement-V2.md, steps 3 and 4): the
// declaration question, the run page with its checkpoint and result, and
// pausing. The decks are a small fixture, the voice and the recogniser are
// the app's null engines.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/assurance_readout.dart';
import 'package:fluenough/core/placement/generated_question.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/placement_run.dart';
import 'package:fluenough/core/placement/placement_session.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/features/placement/find_level_declaration.dart';
import 'package:fluenough/features/placement/find_level_run_page.dart';
import 'package:fluenough/features/placement/find_level_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/find_level_fixture.dart';
import 'support/harness.dart';

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

/// Opens [page] from a button, as the sheet does, and says what it popped
/// with in [popped].
Future<void> _open(
  WidgetTester tester,
  Widget Function() page,
  List<Object?> popped, {
  AppState? state,
}) async {
  usePhone(tester);
  await pumpScreen(
    tester,
    state: state,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const ValueKey<String>('open'),
            onPressed: () async {
              final result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute<Object?>(builder: (_) => page()),
              );
              popped.add(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey<String>('open')));
  await tester.pumpAndSettle();
}

FindLevelRunPage _runPage(
  PlacementSession session, {
  List<List<String>>? progress,
  List<PlacementSession>? finished,
}) => FindLevelRunPage(
  session: session,
  languageName: 'Xish',
  language: _language,
  native: _native,
  onProgress: (s) => progress?.add(s.events),
  onFinish: (s) => finished?.add(s),
);

/// A voice that cannot say anything.
class _BrokenVoice extends NullTtsEngine {
  const _BrokenVoice();

  @override
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) async => throw const TtsFailure('synthesis-failed');
}

/// A session that is at its 25-question checkpoint from the start, so that
/// the page's handling of it is tested whatever the course (the fixture's
/// six decks may end before 25 questions): it shows 25 asked until Keep
/// going, then goes on as the real session does.
class _CheckpointSession extends PlacementSession {
  _CheckpointSession() : super(findLevelConfig(), findLevelData());

  bool _paused = true;
  final List<String> _kept = <String>[];

  @override
  bool get atCheckpoint => _paused;

  @override
  GeneratedQuestion? get question => _paused ? null : super.question;

  @override
  bool get isDone => !_paused && super.isDone;

  @override
  int get asked => _paused ? 25 : super.asked;

  @override
  void keepGoing() {
    _paused = false;
    _kept.add('k');
  }

  @override
  List<String> get events => <String>[..._kept, ...super.events];
}

/// A run that reads out what it is told, to put a skill at a name the
/// fixture's answers do not reach.
class _FixedRun extends PlacementRun {
  _FixedRun(
    super.config,
    this.fixed, {
    this.unavailable = const <PlacementSkill>{},
  });

  final Map<PlacementSkill, SkillAssurance> fixed;
  final Set<PlacementSkill> unavailable;

  @override
  Set<PlacementSkill> get unavailableSkills => unavailable;

  @override
  Map<PlacementSkill, SkillAssurance> get readout => fixed;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('the declaration screen', () {
    Future<List<Object?>> pump(
      WidgetTester tester,
      List<PlacementDeclaration> options,
    ) async {
      final popped = <Object?>[];
      await _open(
        tester,
        () => FindLevelDeclarationPage(language: 'Bengali', options: options),
        popped,
      );
      return popped;
    }

    testWidgets('asks "How well do you know it?" with the labels as decided, '
        'and no Skip', (tester) async {
      await pump(tester, PlacementDeclaration.values);
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.findLevelDeclarationTitle('Bengali')),
        findsOneWidget,
      );
      expect(find.text('Expert'), findsOneWidget);
      expect(find.text('I use it easily'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(
        find.text('I follow most of it and can say what I need'),
        findsOneWidget,
      );
      expect(find.text('Amateur'), findsOneWidget);
      expect(find.text('I know some words and phrases'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('I am starting from nothing'), findsOneWidget);
      expect(find.text(l10n.placementStartAtBeginning), findsNothing);
      expect(find.textContaining('Skip'), findsNothing);
    });

    testWidgets('offers only the options it is given', (tester) async {
      await pump(tester, const <PlacementDeclaration>[
        PlacementDeclaration.amateur,
        PlacementDeclaration.beginner,
      ]);
      expect(find.text('Amateur'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Advanced'), findsNothing);
      expect(find.text('Expert'), findsNothing);
    });

    testWidgets('an answer is handed back', (tester) async {
      final popped = await pump(tester, PlacementDeclaration.values);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-advanced')),
      );
      expect(popped, <Object?>[PlacementDeclaration.advanced]);
    });

    testWidgets('Back leaves with no answer', (tester) async {
      final popped = await pump(tester, PlacementDeclaration.values);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(popped, <Object?>[null]);
    });
  });

  group('the run page', () {
    testWidgets('shows question 1 with no total, and each answer is told to '
        'the host so that the run can be saved', (tester) async {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      final progress = <List<String>>[];
      final finished = <PlacementSession>[];
      await _open(
        tester,
        () => _runPage(session, progress: progress, finished: finished),
        <Object?>[],
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.placementQuestionNumber(1)), findsOneWidget);
      expect(find.text('1/', findRichText: true), findsNothing);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-dont-know')),
      );
      expect(find.text(l10n.placementQuestionNumber(2)), findsOneWidget);
      expect(progress, <List<String>>[
        <String>['a0'],
      ]);
      expect(finished, isEmpty, reason: 'nothing is written while it runs');
    });

    testWidgets('closing pauses: nothing is written and the host is told', (
      tester,
    ) async {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      final finished = <PlacementSession>[];
      final popped = <Object?>[];
      await _open(tester, () => _runPage(session, finished: finished), popped);
      await _tap(tester, find.byTooltip(l10nOf(tester).drillEndSession));
      expect(popped, <Object?>[false]);
      expect(finished, isEmpty);
    });

    testWidgets('a run that ends writes once and shows where the learner '
        'starts', (tester) async {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      final finished = <PlacementSession>[];
      final popped = <Object?>[];
      await _open(tester, () => _runPage(session, finished: finished), popped);
      final l10n = l10nOf(tester);
      final done = find.byKey(const ValueKey<String>('find-level-done'));
      final keep = find.byKey(const ValueKey<String>('find-level-keep-going'));
      var taps = 0;
      while (done.evaluate().isEmpty && taps++ < 400) {
        await _tap(
          tester,
          keep.evaluate().isNotEmpty
              ? keep
              : find.byKey(const ValueKey<String>('find-level-dont-know')),
        );
      }
      expect(done, findsOneWidget);
      expect(finished, hasLength(1));
      expect(find.text(l10n.findLevelSummaryTitle), findsOneWidget);
      // Not one right answer: every skill starts from the beginning.
      expect(
        find.textContaining('${l10n.findLevelSkillRead}: from the beginning'),
        findsOneWidget,
      );
      await _tap(tester, done);
      expect(popped, <Object?>[true]);
    });

    testWidgets('a checkpoint says where the learner stands and offers '
        'Keep going and Stop here', (tester) async {
      var kept = 0;
      var stopped = 0;
      usePhone(tester);
      await pumpScreen(
        tester,
        FindLevelCheckpoint(
          count: 25,
          lines: const <String>['Read: unit 80 · Very sure'],
          onKeepGoing: () => kept++,
          onStop: () => stopped++,
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.findLevelCheckpointTitle(25)), findsOneWidget);
      expect(find.text(l10n.findLevelCheckpointBody), findsOneWidget);
      expect(find.text('Read: unit 80 · Very sure'), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-keep-going')),
      );
      expect(kept, 1);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-stop-here')),
      );
      expect(stopped, 1);
    });
  });

  group('the run page at a checkpoint', () {
    testWidgets('Keep going carries on, and the run is saved as it goes', (
      tester,
    ) async {
      final session = _CheckpointSession();
      final progress = <List<String>>[];
      final finished = <PlacementSession>[];
      await _open(
        tester,
        () => _runPage(session, progress: progress, finished: finished),
        <Object?>[],
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.findLevelCheckpointTitle(25)), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-keep-going')),
      );
      expect(find.text(l10n.findLevelCheckpointTitle(25)), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('find-level-dont-know')),
        findsOneWidget,
      );
      expect(progress.last, <String>['k']);
      expect(finished, isEmpty);
    });

    testWidgets('Stop here writes the run once and shows where the learner '
        'stands', (tester) async {
      final session = _CheckpointSession();
      final finished = <PlacementSession>[];
      await _open(
        tester,
        () => _runPage(session, finished: finished),
        <Object?>[],
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-stop-here')),
      );
      expect(finished, hasLength(1));
      expect(
        find.byKey(const ValueKey<String>('find-level-done')),
        findsOneWidget,
      );
    });
  });

  group('the microphone', () {
    testWidgets('two listens in a row that heard nothing, on different '
        'questions, give it up', (tester) async {
      final session = PlacementSession(
        findLevelConfig(
          skills: const <PlacementSkill>{PlacementSkill.say},
          microphone: true,
        ),
        findLevelData(),
      );
      final progress = <List<String>>[];
      final finished = <PlacementSession>[];
      await _open(
        tester,
        () => _runPage(session, progress: progress, finished: finished),
        <Object?>[],
      );
      final speak = find.byKey(const ValueKey<String>('find-level-speak'));
      // The null recogniser hears nothing. One listen on the first question
      // is not enough.
      await _tap(tester, speak);
      expect(progress, isEmpty);
      // The learner answers it another way, and the next question to be said
      // is listened to once more: two in a row over the run.
      var guard = 0;
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-dont-know')),
      );
      while (speak.evaluate().isEmpty && guard++ < 20) {
        await _tap(
          tester,
          find.byKey(const ValueKey<String>('find-level-dont-know')),
        );
      }
      expect(speak, findsOneWidget);
      await _tap(tester, speak);
      expect(progress.last, contains('m'));
    });
  });

  group('a heard question whose sound will not play', () {
    testWidgets('says so and is skipped, never marked wrong', (tester) async {
      final session = PlacementSession(
        findLevelConfig(skills: const <PlacementSkill>{PlacementSkill.hear}),
        findLevelData(),
      );
      final progress = <List<String>>[];
      await _open(
        tester,
        () => _runPage(session, progress: progress),
        <Object?>[],
        state: AppState.test(tts: const _BrokenVoice()),
      );
      expect(
        find.byKey(const ValueKey<String>('find-level-audio-failed')),
        findsOneWidget,
      );
      // Nothing to guess at, and no "I don't know" that would count a miss.
      expect(
        find.byKey(const ValueKey<String>('find-level-dont-know')),
        findsNothing,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-skip-audio')),
      );
      expect(progress.first, <String>['u']);
      expect(session.events, isNot(contains('a0')));
      expect(session.asked, 0);
    });
  });

  group('a run whose outcome cannot be written', () {
    testWidgets('shows an error with Retry, keeps the run, and Retry writes '
        'again', (tester) async {
      final session = PlacementSession(findLevelConfig(), findLevelData());
      var writes = 0;
      final popped = <Object?>[];
      await _open(
        tester,
        () => FindLevelRunPage(
          session: session,
          languageName: 'Xish',
          language: _language,
          native: _native,
          onProgress: (_) {},
          onFinish: (_) {
            writes++;
            if (writes == 1) throw StateError('the write failed');
          },
        ),
        popped,
      );
      final l10n = l10nOf(tester);
      final retry = find.byKey(const ValueKey<String>('find-level-retry'));
      final done = find.byKey(const ValueKey<String>('find-level-done'));
      final keep = find.byKey(const ValueKey<String>('find-level-keep-going'));
      var taps = 0;
      while (retry.evaluate().isEmpty && taps++ < 400) {
        await _tap(
          tester,
          keep.evaluate().isNotEmpty
              ? keep
              : find.byKey(const ValueKey<String>('find-level-dont-know')),
        );
      }
      // Not a spinner: the learner is told, and the run is still there.
      expect(retry, findsOneWidget);
      expect(find.text(l10n.findLevelFinishFailed), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(writes, 1);
      expect(popped, isEmpty);

      await _tap(tester, retry);
      expect(writes, 2);
      expect(done, findsOneWidget);
      expect(find.text(l10n.findLevelSummaryTitle), findsOneWidget);
    });
  });

  group('the result lists each skill in play', () {
    testWidgets('as a unit and a name, in the plan\'s words', (tester) async {
      final session = PlacementSession(
        findLevelConfig(decks: 12),
        findLevelData(decks: 12, words: 36),
      );
      while (!session.isDone) {
        if (session.atCheckpoint) {
          session.keepGoing();
        } else {
          session.answer(true);
        }
      }
      usePhone(tester);
      await pumpScreen(
        tester,
        FindLevelSummary(run: session.run, onDone: () {}),
      );
      final l10n = l10nOf(tester);
      for (final name in <String>[
        l10n.findLevelSkillRead,
        l10n.findLevelSkillHear,
        l10n.findLevelSkillWrite,
      ]) {
        expect(
          find.textContaining('$name: unit 12 · '),
          findsOneWidget,
          reason: name,
        );
      }
      // Say and Script were not marked: they are not listed at all.
      expect(find.textContaining(l10n.findLevelSkillSay), findsNothing);
      expect(find.textContaining(l10n.findLevelSkillScript), findsNothing);
    });

    testWidgets('a low name is explained calmly, and the percentage waits in '
        'a detail a tap opens', (tester) async {
      // A first guess: a fixed readout, so that the name is the one under
      // test whatever the fixture's answers reach.
      final run = _FixedRun(
        findLevelConfig(skills: const <PlacementSkill>{PlacementSkill.read}),
        <PlacementSkill, SkillAssurance>{
          PlacementSkill.read: const SkillAssurance(
            skill: PlacementSkill.read,
            label: AssuranceLabel.notSureYet,
            mass: 0.4,
            leadingClass: 1,
            placedLevel: 1,
            questions: 3,
          ),
        },
      );
      usePhone(tester);
      await pumpScreen(tester, FindLevelSummary(run: run, onDone: () {}));
      final l10n = l10nOf(tester);
      expect(find.textContaining('% sure'), findsNothing);
      expect(find.text(l10n.findLevelNoteNotSureYet), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('find-level-result-read')),
      );
      expect(find.textContaining('% sure'), findsOneWidget);
      expect(find.text(l10n.findLevelLabelVerified), findsNothing);
    });

    testWidgets('a Verified skill is marked, and Say with no microphone says '
        'it was not tested and why', (tester) async {
      final session = PlacementSession(
        findLevelConfig(
          decks: 12,
          skills: const <PlacementSkill>{
            PlacementSkill.read,
            PlacementSkill.say,
          },
        ),
        findLevelData(decks: 12, words: 36),
      );
      while (!session.isDone) {
        if (session.atCheckpoint) {
          session.keepGoing();
        } else {
          session.answer(true);
        }
      }
      expect(
        session.run.readout[PlacementSkill.read]!.label,
        AssuranceLabel.verified,
      );
      usePhone(tester);
      await pumpScreen(
        tester,
        FindLevelSummary(run: session.run, onDone: () {}),
      );
      final l10n = l10nOf(tester);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      // The line already says Verified: the icon is not announced again.
      expect(
        find.ancestor(
          of: find.byIcon(Icons.verified),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      expect(find.text(l10n.findLevelNoteVerified), findsOneWidget);
      expect(
        find.text('${l10n.findLevelSkillSay}: not tested'),
        findsOneWidget,
      );
      expect(find.text(l10n.findLevelNotTestedNoMic), findsOneWidget);
    });
    testWidgets('a skill whose questions could not be asked says so, and one '
        'that was just not asked says that', (tester) async {
      SkillAssurance notTested(PlacementSkill skill) => SkillAssurance(
        skill: skill,
        label: AssuranceLabel.notTested,
        mass: 0,
        leadingClass: 0,
        placedLevel: -1,
        questions: 0,
      );
      final run = _FixedRun(
        findLevelConfig(
          skills: const <PlacementSkill>{
            PlacementSkill.read,
            PlacementSkill.hear,
          },
        ),
        <PlacementSkill, SkillAssurance>{
          PlacementSkill.read: notTested(PlacementSkill.read),
          PlacementSkill.hear: notTested(PlacementSkill.hear),
        },
        unavailable: const <PlacementSkill>{PlacementSkill.hear},
      );
      usePhone(tester);
      await pumpScreen(tester, FindLevelSummary(run: run, onDone: () {}));
      final l10n = l10nOf(tester);
      expect(find.text(l10n.findLevelNotTestedUnavailable), findsOneWidget);
      expect(find.text(l10n.findLevelNotTestedNotAsked), findsOneWidget);
    });
  });
}
