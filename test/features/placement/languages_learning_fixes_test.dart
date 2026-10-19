import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/placement/course_line.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/placement_page.dart';

import '../../support/harness.dart';
import '../../support/picker.dart';

/// What the review of #633 asked for in Languages I'm learning (#626): a
/// language the learner speaks is placed, a learned language can stop a
/// script, "Find my level" keeps a passed script test, and a chosen
/// language's choices survive closing its sheet.

/// A learner who speaks [spoken], learning [learning] (none chosen yet when
/// empty).
Future<AppState> pumpPicker(
  WidgetTester tester, {
  List<String> spoken = const <String>['en'],
  List<String> learning = const <String>[],
  Set<String> noAlphabet = const <String>{},
}) async {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 6000 * 3);
  final state = AppState.test(
    settings: SettingsNotifier(
      spokenLanguages: spoken,
      learningLanguages: learning,
      learningChosen: learning.isNotEmpty,
      noAlphabet: noAlphabet,
    ),
  );
  addTearDown(state.dispose);
  await pumpScreen(
    tester,
    KeyedSubtree(
      key: UniqueKey(),
      child: LanguagePickerPage(
        firstRun: learning.isEmpty,
        spokenList: pickerSpokenList,
      ),
    ),
    state: state,
  );
  return state;
}

void main() {
  group('a language the learner speaks', () {
    testWidgets('goes through placement when Find my level is chosen, for '
        'its script too', (tester) async {
      await pumpPicker(tester, spoken: const <String>['en', 'hi']);
      final l10n = l10nOf(tester);
      await pickLanguage(tester, 'hi');
      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();
      expect(find.byType(PlacementPage), findsOneWidget);
    });

    testWidgets('is not placed when the learner starts at the beginning', (
      tester,
    ) async {
      final state = await pumpPicker(
        tester,
        spoken: const <String>['en', 'es'],
      );
      final l10n = l10nOf(tester);
      await pickLanguage(tester, 'es', begin: true);
      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();
      expect(find.byType(PlacementPage), findsNothing);
      expect(state.settings.learningLanguages, contains('es'));
    });

    testWidgets('a language without script decks is asked where to start', (
      tester,
    ) async {
      await pumpPicker(tester, spoken: const <String>['en', 'es']);
      await openSheet(tester, 'es');
      await tapSheet(tester, 'sheet-learn');
      expect(
        find.byKey(const ValueKey<String>('sheet-find-language')),
        findsOneWidget,
      );
    });
  });

  testWidgets("the course line reads its shares with the app's percent", (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const Scaffold(body: CourseLine(levels: <double>[0.5, 0.25, 0.0])),
      state: AppState.test(),
    );
    final l10n = l10nOf(tester);
    String percent(double v) => l10n.commonPercent(v);
    expect(
      find.bySemanticsLabel(
        l10n.pickerCourseLineLabel(
          <String>[
            'A1 ${percent(0.5)}',
            'A2 ${percent(0.25)}',
            'B1 ${percent(0)}',
            '${l10n.pickerLevelCulture} ${percent(0)}',
          ].join(l10n.commonListSeparator),
        ),
      ),
      findsOneWidget,
    );
  });
}
