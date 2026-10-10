import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/placement/native_choice.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/today/today_page.dart';

import '../../support/harness.dart';
import '../../support/hindi_courses.dart';
import '../../support/picker.dart';

/// The question of which native language to learn a course from (ADR-0036,
/// B1 format spec 9.5): in placement, on Today, and in Settings.

AppState bengaliFirst({bool chosen = false, Map<String, String>? decks}) {
  final state = AppState.test(
    decks: MemoryDeckSource(decks ?? hindi(bengali: const <String>{'a'})),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['bn', 'en'],
      learningLanguages: chosen ? const <String>['hi'] : const <String>[],
      learningChosen: chosen,
    ),
  );
  addTearDown(state.dispose);
  return state;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final found = find.text(text);
  await tester.ensureVisible(found.first);
  await tester.pumpAndSettle();
  await tester.tap(found.first);
  await tester.pumpAndSettle();
}

Radio<String> radioOf(WidgetTester tester, String code) => tester
    .widgetList<Radio<String>>(find.byType(Radio<String>))
    .singleWhere((r) => r.value == code);

void main() {
  testWidgets('choosing a course asks on its card which language to learn '
      'it from, the best covered chosen, and placement does not ask again', (
    tester,
  ) async {
    usePhone(tester);
    final state = bengaliFirst();
    await tester.pumpWidget(FluenoughApp(state: state));
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);

    await pickLanguage(tester, 'hi');
    final choice = find.byType(SegmentedButton<String>);
    await scrollToInPicker(tester, choice);
    final buttons = tester.widget<SegmentedButton<String>>(choice);
    expect(buttons.segments.map((s) => s.value), <String>['bn', 'en']);
    expect(buttons.selected, <String>{'en'}, reason: 'the best covered');

    await tester.tap(
      find.descendant(of: choice, matching: find.text('Bengali')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<String>>(choice).selected, <String>{
      'bn',
    });
    await tapText(tester, l10n.commonContinue);
    expect(find.text(l10n.nativeChoiceTitle('Hindi')), findsNothing);
    expect(find.text(l10n.placementAskTitle('Hindi')), findsOneWidget);
    expect(state.settings.courseNative('hi'), isNull, reason: 'not yet saved');

    await tapText(tester, l10n.placementNew('Hindi'));
    await tapText(tester, l10n.placementDone);
    expect(state.settings.courseNative('hi'), 'bn');
    expect(state.settings.nativesOffered('hi'), <String>{'bn', 'en'});
    expect(state.needsNativeChoice('hi'), isFalse);
    expect(state.courseUnits('hi').single.single.id, 'hi-bn-a');
  });

  testWidgets('placement asks which language to learn a course from when '
      'nothing has, each with its coverage, the best covered chosen', (
    tester,
  ) async {
    usePhone(tester);
    final state = bengaliFirst();
    await pumpScreen(
      tester,
      PlacementPage(languages: const <String>['hi'], onFinished: (_) {}),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.nativeChoiceTitle('Hindi')), findsOneWidget);
    expect(find.text(l10n.nativeChoiceCoverageAll(3)), findsOneWidget);
    expect(find.text(l10n.nativeChoiceCoverage(1, 3)), findsOneWidget);
    final group = tester.widget<RadioGroup<String>>(
      find.byType(RadioGroup<String>),
    );
    expect(group.groupValue, 'en', reason: 'the best covered');
    expect(radioOf(tester, 'bn').value, 'bn');
  });

  testWidgets('with one language the learner speaks teaching it, placement '
      'asks nothing about it', (tester) async {
    usePhone(tester);
    final state = AppState.test(
      decks: MemoryDeckSource(hindi(bengali: const <String>{'a'})),
      settings: SettingsNotifier(spokenLanguages: const <String>['en']),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(FluenoughApp(state: state));
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    await tapText(tester, 'Hindi');
    await tapText(tester, l10n.commonContinue);
    expect(find.text(l10n.nativeChoiceTitle('Hindi')), findsNothing);
    expect(find.text(l10n.placementAskTitle('Hindi')), findsOneWidget);
  });

  testWidgets('Today asks once a course already learned is taught from '
      'another language the learner speaks', (tester) async {
    usePhone(tester);
    final state = bengaliFirst(chosen: true);
    await pumpScreen(tester, const TodayPage(), state: state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.nativeChoiceNew('Hindi')), findsOneWidget);

    await tapText(tester, l10n.nativeChoiceChoose);
    expect(find.byType(NativeChoicePage), findsOneWidget);
    await tapText(tester, l10n.commonContinue);
    expect(state.settings.courseNative('hi'), 'en');
    expect(find.text(l10n.nativeChoiceNew('Hindi')), findsNothing);
  });

  testWidgets('Settings changes it per course: "Learn Hindi from"', (
    tester,
  ) async {
    usePhone(tester);
    final state = bengaliFirst(
      chosen: true,
      decks: hindi(bengali: const <String>{'a', 'b'}),
    );
    await pumpScreen(tester, const SettingsPage(), state: state);
    final l10n = l10nOf(tester);
    final row = find.text(l10n.nativeChoiceTitle('Hindi'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.ancestor(of: row, matching: find.byType(InkWell)).first,
        matching: find.text('English'),
      ),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text(l10n.nativeChoiceCoverage(2, 3)), findsOneWidget);
    await tapText(tester, 'Bengali');
    await tapText(tester, l10n.commonContinue);
    expect(find.byType(NativeChoicePage), findsNothing);
    expect(state.settings.courseNative('hi'), 'bn');
    expect(state.courseUnits('hi').map((u) => u.single.id), <String>[
      'hi-bn-a',
      'hi-bn-b',
    ]);
    expect(find.text('Bengali'), findsOneWidget);
  });

  testWidgets('the question meets the tap-target, label and contrast '
      'guidelines', (tester) async {
    usePhone(tester);
    final state = bengaliFirst(chosen: true);
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: NativeChoice(
            language: state.languages.single,
            onChosen: (_) {},
          ),
        ),
      ),
      state: state,
    );
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
