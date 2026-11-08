// Find my level's V3 screens (wiki/Plan-Placement-V3.md, step 7): the
// questions of the run page, its pause at the soft stop, and the result, at
// 1.4x text in light and dark, with their semantics. The questions come from
// a small hand-made bank; the voice and the recogniser are the app's null
// engines.
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/placement/assurance_model.dart';
import 'package:fluenough/core/placement/joint_model.dart';
import 'package:fluenough/core/placement/placement_questions.dart';
import 'package:fluenough/core/placement/script_gate.dart';
import 'package:fluenough/core/placement/item_registry.dart';
import 'package:fluenough/core/placement/v3_result.dart';
import 'package:fluenough/core/placement/v3_session.dart';
import 'package:fluenough/features/placement/v3_question_view.dart';
import 'package:fluenough/features/placement/v3_result_page.dart';
import 'package:fluenough/features/placement/v3_run_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/find_level_fixture.dart';
import 'support/harness.dart';
import 'support/v3_small_bank.dart';

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

final RegItem _tilesItem = RegItem(
  id: 't:F8',
  format: 'F8',
  cardId: 't',
  deck: 0,
  prompt: 'a sentence',
  tiles: <String>['mo', 'ba', 'ku', 'zi', 'le'],
  answerTiles: <String>['ba', 'mo', 'ku'],
);

/// A run that only remembers the tiles it was given.
class _TilesRun implements V3Run {
  List<int>? placed;

  @override
  void answerTiles(List<int> placed) => this.placed = placed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

V3Run _run({
  int seed = 3,
  Set<PlacementSkill> skills = const <PlacementSkill>{
    PlacementSkill.read,
    PlacementSkill.write,
  },
  Set<String>? formats,
  bool yesNoBlock = false,
}) => V3Run(
  data: findLevelData(),
  skills: skills,
  audio: false,
  recogniser: false,
  seed: seed,
  scriptStart: V3ScriptStart.skip,
  yesNoBlock: yesNoBlock,
  items: smallV3Bank(formats: formats),
);

/// Answers by the API until the question is of [mode].
void _advanceTo(V3Run run, V3Mode mode) {
  for (var i = 0; i < 40 && !run.finished; i++) {
    if (run.atCheckpoint) run.keepGoing();
    if (run.question!.mode == mode) return;
    run.dontKnow();
  }
  fail('no $mode question came up');
}

Future<void> _open(
  WidgetTester tester,
  Widget Function() page,
  List<Object?> popped, {
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  usePhone(tester, textScale: textScale);
  await pumpScreen(
    tester,
    themeMode: themeMode,
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

V3RunPage _page(
  V3Run run, {
  List<List<String>>? progress,
  List<V3Result>? written,
  List<V3ScriptStart>? restarts,
}) => V3RunPage(
  run: run,
  languageName: 'Xish',
  language: _language,
  native: _native,
  restart: (start) {
    restarts?.add(start);
    return _run(seed: 9);
  },
  onProgress: (r) => progress?.add(List<String>.of(r.events)),
  onFinish: (result, overrides) => written?.add(result),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

void main() {
  for (final (label, mode, scale) in <(String, ThemeMode, double)>[
    ('light at 1x', ThemeMode.light, 1.0),
    ('dark at 1.4x', ThemeMode.dark, 1.4),
  ]) {
    group('the questions, $label', () {
      testWidgets('a pick records the answer and goes on', (tester) async {
        final run = _run();
        _advanceTo(run, V3Mode.pick);
        final progress = <List<String>>[];
        await _open(
          tester,
          () => _page(run, progress: progress),
          <Object?>[],
          textScale: scale,
          themeMode: mode,
        );
        expect(_key('find-level-option-3'), findsOneWidget);
        final before = run.answered;
        await _tap(tester, _key('find-level-option-0'));
        expect(run.answered, before + 1);
        expect(progress, isNotEmpty);
        expect(progress.last.length, run.events.length);
      });

      testWidgets('a typed word is checked, "I don\'t know" is a miss', (
        tester,
      ) async {
        final run = _run(seed: 5, formats: <String>{'F7'});
        _advanceTo(run, V3Mode.type);
        await _open(
          tester,
          () => _page(run),
          <Object?>[],
          textScale: scale,
          themeMode: mode,
        );
        expect(_key('find-level-check'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(_key('find-level-check')).onPressed,
          isNull,
        );
        await tester.enterText(_key('find-level-answer'), 'whatever');
        await tester.pump();
        final before = run.answered;
        await _tap(tester, _key('find-level-check'));
        expect(run.answered, before + 1);
        expect(run.events.last, 'w');
      });

      testWidgets('a gap is typed and graded as a unit', (tester) async {
        final run = _run(seed: 8);
        _advanceTo(run, V3Mode.gap);
        await _open(
          tester,
          () => _page(run),
          <Object?>[],
          textScale: scale,
          themeMode: mode,
        );
        await tester.enterText(_key('find-level-answer'), 'a');
        await tester.pump();
        await _tap(tester, _key('find-level-check'));
        expect(run.events.last, 'r');
      });

      testWidgets('yes and no, with "I don\'t know" a miss that hides no '
          'guess', (tester) async {
        final run = _run(
          seed: 2,
          formats: <String>{'F1', 'F2'},
          yesNoBlock: true,
        );
        _advanceTo(run, V3Mode.yesNo);
        await _open(
          tester,
          () => _page(run),
          <Object?>[],
          textScale: scale,
          themeMode: mode,
        );
        await _tap(tester, _key('find-level-yes'));
        expect(run.events.last, 'r');
        if (!run.finished && run.question?.mode == V3Mode.yesNo) {
          await _tap(tester, _key('find-level-dont-know'));
          expect(run.events.last, 'd');
        }
      });

      testWidgets('tiles are placed in order, decoys left, and checked', (
        tester,
      ) async {
        final run = _TilesRun();
        usePhone(tester, textScale: scale);
        await pumpScreen(
          tester,
          themeMode: mode,
          Scaffold(
            body: V3QuestionView(
              question: V3Run.questionOf(_tilesItem),
              number: 1,
              language: _language,
              native: _native,
              run: run,
              onChanged: () {},
              onListened: ({required heard}) {},
            ),
          ),
        );
        expect(
          tester.widget<FilledButton>(_key('find-level-check')).onPressed,
          isNull,
        );
        for (final t in _tilesItem.answerTiles) {
          await _tap(tester, find.text(t).first);
        }
        await _tap(tester, _key('find-level-check'));
        final shown = _tilesItem.tiles;
        expect(
          <String>[for (final i in run.placed!) shown[i]],
          <String>['ba', 'mo', 'ku'],
        );
      });
    });
  }

  group('the run page', () {
    testWidgets('closing pauses: nothing is written and the host is told', (
      tester,
    ) async {
      final run = _run();
      final written = <V3Result>[];
      final popped = <Object?>[];
      await _open(tester, () => _page(run, written: written), popped);
      await _tap(tester, find.byIcon(Icons.close).first);
      expect(popped, <Object?>[false]);
      expect(written, isEmpty);
    });

    testWidgets('a run that ends shows the result, and Done writes once', (
      tester,
    ) async {
      final run = _run();
      while (!run.finished) {
        if (run.atCheckpoint) run.stop();
        if (run.finished) break;
        run.dontKnow();
      }
      final written = <V3Result>[];
      final popped = <Object?>[];
      await _open(tester, () => _page(run, written: written), popped);
      expect(_key('find-level-result-read'), findsOneWidget);
      await _tap(tester, _key('find-level-done'));
      expect(written, hasLength(1));
      expect(popped, <Object?>[true]);
    });

    testWidgets('the soft stop offers the result or more questions', (
      tester,
    ) async {
      final stops = <String>[];
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        V3SoftStop(
          onKeepGoing: () => stops.add('keep'),
          onStop: () => stops.add('stop'),
        ),
      );
      await _tap(tester, _key('find-level-keep-going'));
      await _tap(tester, _key('find-level-see-result'));
      expect(stops, <String>['keep', 'stop']);
    });

    testWidgets('a run at its soft stop pauses before the next question', (
      tester,
    ) async {
      final run = _run(seed: 6);
      var guard = 0;
      while (!run.atCheckpoint && !run.finished && guard++ < 60) {
        run.dontKnow();
      }
      if (!run.atCheckpoint) return; // the small bank ended first
      await _open(tester, () => _page(run), <Object?>[]);
      expect(_key('find-level-see-result'), findsOneWidget);
      await _tap(tester, _key('find-level-keep-going'));
      expect(run.atCheckpoint, isFalse);
    });
  });

  group('the result', () {
    final levels = PlacementLevels(30, maxParts: 20);
    V3Result result({List<V3SkillResult>? skills, ScriptGateResult? script}) =>
        V3Result(
          skills:
              skills ??
              const <V3SkillResult>[
                V3SkillResult(
                  skill: PlacementSkill.read,
                  status: V3Status.placed,
                  startUnit: 14,
                  lowUnit: 11,
                  highUnit: 17,
                  startClass: 9,
                  confidence: PlacementConfidence.medium,
                  rangeShown: true,
                ),
                V3SkillResult(
                  skill: PlacementSkill.say,
                  status: V3Status.selfRated,
                  why: V3Why.selfRated,
                ),
                V3SkillResult(
                  skill: PlacementSkill.hear,
                  status: V3Status.notTested,
                  why: V3Why.noDevice,
                ),
              ],
          levels: levels,
          readout: null,
          script: script,
          items: 20,
          seconds: 120,
          endReason: null,
        );

    for (final (label, mode, scale) in <(String, ThemeMode, double)>[
      ('light at 1x', ThemeMode.light, 1.0),
      ('dark at 1.4x', ThemeMode.dark, 1.4),
    ]) {
      testWidgets('says the unit, the range and the confidence word, $label', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _open(
          tester,
          () =>
              V3ResultPage(result: result(), onDone: (_) {}, onRestart: (_) {}),
          <Object?>[],
          textScale: scale,
          themeMode: mode,
        );
        await tester.scrollUntilVisible(
          find.text('Hear: not tested (no sound on this phone)'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.scrollUntilVisible(
          find.text('Read: start at unit 14'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Read: start at unit 14'), findsOneWidget);
        expect(find.text('Likely between unit 11 and unit 17'), findsOneWidget);
        expect(find.text('Fairly sure'), findsOneWidget);
        expect(
          find.text('Say: self-rated, not placed', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text(
            'Hear: not tested (no sound on this phone)',
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        // Never a percentage of "none" or Verified.
        expect(find.textContaining('Verified'), findsNothing);
        final label = tester.getSemantics(_key('find-level-result-read')).label;
        expect(label, contains('Read: start at unit 14'));
        expect(label, contains('Likely between unit 11 and unit 17'));
        expect(label, contains('Fairly sure'));
        semantics.dispose();
      });
    }

    testWidgets('a start can be changed, and Done hands the change on', (
      tester,
    ) async {
      final done = <Map<PlacementSkill, int>>[];
      await _open(
        tester,
        () =>
            V3ResultPage(result: result(), onDone: done.add, onRestart: (_) {}),
        <Object?>[],
      );
      await _tap(tester, _key('find-level-change-read'));
      await _tap(tester, _key('find-level-change-less'));
      await _tap(tester, _key('find-level-change-use'));
      await _tap(tester, _key('find-level-done'));
      expect(done.single.keys, <PlacementSkill>[PlacementSkill.read]);
      expect(done.single[PlacementSkill.read], lessThan(9));
    });

    testWidgets('Read and Write that need the script say why and offer a '
        're-check', (tester) async {
      final restarts = <V3ScriptStart>[];
      await _open(
        tester,
        () => V3ResultPage(
          result: result(
            skills: const <V3SkillResult>[
              V3SkillResult(
                skill: PlacementSkill.read,
                status: V3Status.needsScript,
                why: V3Why.needsScript,
              ),
              V3SkillResult(
                skill: PlacementSkill.write,
                status: V3Status.needsScript,
                why: V3Why.needsScript,
              ),
            ],
          ),
          onDone: (_) {},
          onRestart: restarts.add,
        ),
        <Object?>[],
      );
      expect(
        find.text('Read: needs the script first', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('letters of this script', skipOffstage: false),
        findsWidgets,
      );
      await _tap(tester, _key('find-level-i-read-it'));
      await _tap(tester, _key('find-level-check-letters'));
      expect(restarts, <V3ScriptStart>[V3ScriptStart.skip, V3ScriptStart.ask]);
    });

    testWidgets('a run that asks again replaces the result with a new run', (
      tester,
    ) async {
      final run = _run();
      while (!run.finished) {
        if (run.atCheckpoint) run.stop();
        if (run.finished) break;
        run.dontKnow();
      }
      final restarts = <V3ScriptStart>[];
      await _open(tester, () => _page(run, restarts: restarts), <Object?>[]);
      // The tiny bank asks Read and Write with the script skipped: the
      // re-check buttons are only for a script that blocks them.
      expect(_key('find-level-i-read-it'), findsNothing);
    });
  });
}
