// The PIN keypad's delete button: a one-word tooltip, and the full phrase
// for a screen reader (AGENTS.md, rule 10).
import 'package:fluenough/features/profiles/pin_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  testWidgets('delete is found by its full phrase, with a one-word tooltip', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var deleted = 0;
    var digits = '';
    usePhone(tester, textScale: 1.4);
    await pumpScreen(
      tester,
      Scaffold(
        body: PinKeypad(onDigit: (d) => digits += d, onDelete: () => deleted++),
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(PinKeypad)))!;

    final delete = find.bySemanticsLabel(l10n.pinDeleteLabel);
    expect(delete, findsOneWidget);
    expect(l10n.pinDeleteLabel.split(' ').length, greaterThan(2));
    expect(find.byTooltip(l10n.brailleBackspace), findsOneWidget);
    expect(l10n.brailleBackspace.split(' ').length, 1);
    // The tooltip's word is not a second thing a screen reader stops on.
    expect(find.bySemanticsLabel(l10n.brailleBackspace), findsNothing);

    await tester.tap(delete);
    expect(deleted, 1);
    await tester.tap(find.text('7'));
    expect(digits, '7');
    semantics.dispose();
  });
}
