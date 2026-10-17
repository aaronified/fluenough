// The IPA course in the language picker (ADR-0041): one language, two
// entries, "IPA: my languages" and "IPA: whole chart", with one progress
// between them. Choosing either learns the IPA; choosing the other while it
// is learned only changes its scope. It is not placed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/core/decks/ipa_course.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';

import '../../support/harness.dart';
import '../../support/ipa_course.dart';
import '../../support/picker.dart';

Future<AppState> pumpPicker(
  WidgetTester tester,
  List<String> learning, {
  IpaScope? scope,
}) async {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 3000 * 3);
  final state = ipaApp(learning, scope: scope);
  addTearDown(state.dispose);
  await pumpScreen(tester, const LanguagePickerPage(), state: state);
  return state;
}

Future<void> proceed(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the IPA is offered twice, and neither is learned yet', (
    tester,
  ) async {
    await pumpPicker(tester, <String>['hi']);
    expect(languageCard('ipa:mine'), findsOneWidget);
    expect(languageCard('ipa:whole'), findsOneWidget);
    expect(languageCard('ipa'), findsNothing);
    expect(find.text('IPA: my languages'), findsOneWidget);
    expect(find.text('IPA: whole chart'), findsOneWidget);
    expect(isPicked(tester, 'ipa:mine'), isFalse);
    expect(isPicked(tester, 'ipa:whole'), isFalse);
    expect(isPicked(tester, 'hi'), isTrue);
  });

  testWidgets('choosing "my languages" learns the IPA with that scope, and '
      'places nothing', (tester) async {
    final state = await pumpPicker(tester, <String>[
      'hi',
    ], scope: IpaScope.whole);
    await pickLanguage(tester, 'ipa:mine');
    expect(isPicked(tester, 'ipa:mine'), isTrue);
    expect(isPicked(tester, 'ipa:whole'), isFalse);
    await proceed(tester);
    expect(state.learningCodes, {'hi', 'ipa'});
    expect(state.settings.ipaScope, IpaScope.mine);
  });

  testWidgets('choosing "whole chart" learns the IPA with that scope', (
    tester,
  ) async {
    final state = await pumpPicker(tester, <String>['hi']);
    await pickLanguage(tester, 'ipa:whole');
    expect(isPicked(tester, 'ipa:whole'), isTrue);
    expect(isPicked(tester, 'ipa:mine'), isFalse);
    await proceed(tester);
    expect(state.learningCodes, {'hi', 'ipa'});
    expect(state.settings.ipaScope, IpaScope.whole);
  });

  testWidgets('choosing the other entry of a language learned changes its '
      'scope only, with nothing to confirm', (tester) async {
    final state = await pumpPicker(tester, <String>['hi', 'ipa']);
    expect(isPicked(tester, 'ipa:mine'), isTrue);
    expect(isPicked(tester, 'ipa:whole'), isFalse);
    await pickLanguage(tester, 'ipa:whole');
    expect(find.byType(AlertDialog), findsNothing);
    expect(isPicked(tester, 'ipa:whole'), isTrue);
    expect(isPicked(tester, 'ipa:mine'), isFalse);
    await proceed(tester);
    expect(state.learningCodes, {'hi', 'ipa'});
    expect(state.settings.ipaScope, IpaScope.whole);
  });

  testWidgets('un-choosing the IPA asks first, as any language learned', (
    tester,
  ) async {
    final state = await pumpPicker(tester, <String>['hi', 'ipa']);
    await pickLanguage(tester, 'ipa:mine');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    expect(isPicked(tester, 'ipa:mine'), isFalse);
    await proceed(tester);
    expect(state.learningCodes, {'hi'});
  });
}
