import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/decks/decks_page.dart';
import 'package:fluenough/features/decks/path_model.dart';
import 'package:fluenough/features/decks/path_parts.dart';
import 'package:fluenough/features/decks/unit_page.dart';

import '../../support/harness.dart';

/// The Decks path reads a course's plan from its language's path
/// (ADR-0036): where each level ends, and each unit coming, planned or
/// written with no deck in the course's native language yet. On the
/// B1 format's Appendix A, whose path marks A1, A2 and B1 and plans a
/// Health unit, and a Bengali deck for its first unit only.

const String appendix = 'test/fixtures/b1/appendix-a';

/// Every file of Appendix A, keyed as the catalog keys bundled decks, with
/// [path] in place of its path where given.
Map<String, String> appendixFiles({String? path}) => <String, String>{
  for (final file in Directory(appendix).listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/${file.path.substring(appendix.length + 1)}':
          path != null && file.path.endsWith('zz-path.yaml')
          ? path
          : file.readAsStringSync(),
  // Testlang from Bengali: its first unit's deck only. A test-only card id.
  'decks/zz/bn/zz-bn-home.yaml': '''
schema: 1
id: "zz-bn-home"
name: "ঘর"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
native: { code: "bn", iso639_3: "ben", name: "Bengali" }
license: "CC0-1.0"
cards:
  - { id: "zz-9801", target: "ఇల్లు", reading: "illu", native: "ঘর" }
''',
};

/// A Testlang learner from [native].
Future<AppState> learner({String native = 'en', String? path}) async {
  final settings = SettingsNotifier(
    spokenLanguages: <String>[native],
    learningLanguages: const <String>['zz'],
  )..learningChosen = true;
  settings.setCourseNative('zz', native, offered: const <String>['en', 'bn']);
  final state = AppState.test(
    decks: MemoryDeckSource(appendixFiles(path: path)),
    settings: settings,
  );
  await state.load();
  return state;
}

void main() {
  test('the plan comes from the path: each level ends at its last unit '
      'taught, and the planned unit is coming, in its level', () async {
    final state = await learner();
    expect(state.brokenDecks, isEmpty);
    final plan = coursePlanOf(state, 'zz');
    expect(plan.levelEnds, <CefrLevel, String>{
      CefrLevel.a1: 'zz-en-home',
      CefrLevel.a2: 'zz-en-grammar-case-endings',
    });
    expect(plan.coming, <ComingUnit>[
      (title: 'Health', level: CefrLevel.b1, words: 60),
    ]);
  });

  test('a written unit with no deck in the course\'s language is coming, '
      'named from another course\'s deck for it', () async {
    final state = await learner(native: 'bn');
    expect(state.courseUnits('zz').map((u) => u.map((e) => e.id)), [
      ['zz-bn-home'],
    ]);
    final plan = coursePlanOf(state, 'zz');
    // A2 has no unit taught from Bengali, so nothing marks where it ends.
    expect(plan.levelEnds, <CefrLevel, String>{CefrLevel.a1: 'zz-bn-home'});
    expect(plan.coming, <ComingUnit>[
      (
        title: 'In, to, with, from: case endings',
        level: CefrLevel.a2,
        words: null,
      ),
      (title: 'Health', level: CefrLevel.b1, words: 60),
    ]);
  });

  test('on a path that marks no level, coming units follow the units, with '
      'no level', () async {
    final path = File('$appendix/zz/zz-path.yaml')
        .readAsStringSync()
        .replaceAll(RegExp(r'\n\s*milestone: "[AB][12]"'), '');
    final state = await learner(path: path);
    final plan = coursePlanOf(state, 'zz');
    expect(plan.levelEnds, isEmpty);
    expect(plan.coming, <ComingUnit>[
      (title: 'Health', level: null, words: 60),
    ]);
    final steps = courseView(state, 'zz')!.steps;
    expect(steps.whereType<LevelStep>(), isEmpty);
    expect(steps.last, isA<ComingStep>());
  });

  test(
    'every bundled path has its B1 plan, and a course a plan to show',
    () async {
      final app = AppState.test();
      await app.load();
      // A path that marks no level and plans no unit shows no plan (the first
      // test above); since ADR-0036 every language that has a core has its
      // plan, so none of the bundled paths is one.
      final unplanned = <String>{
        for (final language in app.languages)
          if (app.languagePathOf(language.code)?.plan case final plan?)
            if (plan.every((u) => u.milestone == null && u.planned == null))
              language.code,
      };
      expect(unplanned, isEmpty);
      for (final code in <String>[
        'as',
        'bn',
        'es',
        'gu',
        'hi',
        'kn',
        'mr',
        'te',
      ]) {
        expect(coursePlanOf(app, code).isEmpty, isFalse, reason: code);
      }
    },
  );

  testWidgets('the Decks path shows the levels the path marks, and the '
      'planned unit as coming, not opened', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const DecksPage(), state: await learner());
    final l10n = l10nOf(tester);
    expect(find.byType(LevelHeader), findsNWidgets(3));
    for (final level in <String>[
      l10n.pathLevelA1,
      l10n.pathLevelA2,
      l10n.pathLevelB1,
    ]) {
      expect(find.text(level), findsOneWidget, reason: level);
    }
    final health = find.text('Health');
    await tester.scrollUntilVisible(
      health,
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(health, findsOneWidget);
    expect(find.text(l10n.pathComingWords(60)), findsOneWidget);
    await tester.tap(health);
    await tester.pumpAndSettle();
    expect(find.byType(UnitPage), findsNothing);
  });

  testWidgets('from Bengali, the unit not written in it yet is coming', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const DecksPage(),
      state: await learner(native: 'bn'),
    );
    // Also listed below the path, among the decks the course leaves out.
    final title = find.text('In, to, with, from: case endings').first;
    await tester.scrollUntilVisible(
      title,
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    final coming = find.text(l10nOf(tester).pathComing);
    expect(coming, findsOneWidget);
    expect(
      tester.getTopLeft(coming).dy,
      greaterThan(tester.getTopLeft(title).dy),
    );
  });
}
