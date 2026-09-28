import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/profiles/pin_page.dart';

import '../../support/harness.dart';
import 'support.dart';

/// Aro's PIN pad, with Mira current.
Future<AppState> _pump(WidgetTester tester, {bool wrongPin = false}) =>
    pumpProfiles(
      tester,
      PinPage(profileId: 'aro', wrongPin: wrongPin),
      currentProfileId: 'mira',
    );

Finder _key(String digit) => find.widgetWithText(TextButton, digit);

Future<void> _enter(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(_key(digit));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the right PIN opens the profile', (tester) async {
    final state = await _pump(tester);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.pinGreeting('Aro')), findsOneWidget);
    expect(find.text(l10n.pinPrompt(4)), findsOneWidget);

    await _enter(tester, '1234');

    expect(state.currentProfile.id, 'aro');
    expect(find.text(l10n.pinWrong), findsNothing);
  });

  testWidgets('a wrong PIN says so, clears the dots, and opens nothing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = await _pump(tester);
    final l10n = l10nOf(tester);

    await _enter(tester, '1111');

    expect(state.currentProfile.id, 'mira');
    expect(find.text(l10n.pinWrong), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.pinEntered(0, 4)), findsOneWidget);

    // The next digit starts again, and the prompt comes back.
    await _enter(tester, '1');
    expect(find.text(l10n.pinPrompt(4)), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.pinEntered(1, 4)), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('backspace removes the last digit', (tester) async {
    final semantics = tester.ensureSemantics();
    final state = await _pump(tester);
    final l10n = l10nOf(tester);

    await _enter(tester, '12');
    expect(find.bySemanticsLabel(l10n.pinEntered(2, 4)), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.pinDeleteDigit));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(l10n.pinEntered(1, 4)), findsOneWidget);

    // 1, then 234: the deleted 2 was not counted.
    await _enter(tester, '234');
    expect(state.currentProfile.id, 'aro');
    semantics.dispose();
  });

  testWidgets('every key is a labelled button of at least 48 px', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    final l10n = l10nOf(tester);

    for (var d = 0; d <= 9; d++) {
      final key = _key('$d');
      expect(key, findsOneWidget);
      expect(
        tester.getSemantics(key),
        isSemantics(label: '$d', isButton: true, hasTapAction: true),
      );
      final size = tester.getSize(key);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final back = find.byTooltip(l10n.pinDeleteDigit);
    expect(
      tester.getSemantics(back),
      isSemantics(
        tooltip: l10n.pinDeleteDigit,
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  testWidgets('the pin-error preset starts on the wrong-PIN message', (
    tester,
  ) async {
    await _pump(tester, wrongPin: true);
    expect(find.text(l10nOf(tester).pinWrong), findsOneWidget);
  });

  testWidgets('Forgot PIN? explains, in a dialog', (tester) async {
    await _pump(tester);
    final l10n = l10nOf(tester);

    await tester.tap(find.text(l10n.pinForgot));
    await tester.pumpAndSettle();
    expect(find.text(l10n.pinForgotBody), findsOneWidget);

    await tester.tap(find.text(l10n.commonGotIt));
    await tester.pumpAndSettle();
    expect(find.text(l10n.pinForgotBody), findsNothing);
  });
}
