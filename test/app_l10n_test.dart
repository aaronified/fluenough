import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/main.dart';

/// Guards the localisation wiring, not the copy.
///
/// Every string in the app is a token (AGENTS.md rule 10), which means the
/// chain from `lib/l10n/app_en.arb` through the generated `AppLocalizations`
/// to a widget has to actually be connected. Nothing else in the suite touches
/// a widget, so without this a missing delegate or a renamed token surfaces on
/// a device as a crash or a blank label.
///
/// It asserts against `l10n.appTitle` rather than the literal `'Fluenough'` on
/// purpose: pinning the English text here would mean every wording change
/// breaks a test that is not about wording.
void main() {
  testWidgets('interface text resolves through AppLocalizations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FluenoughApp());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(Scaffold));
    final AppLocalizations? l10n = AppLocalizations.of(context);

    expect(
      l10n,
      isNotNull,
      reason: 'AppLocalizations.delegate is not registered on MaterialApp',
    );
    expect(find.text(l10n!.appTitle), findsWidgets);
    expect(find.text(l10n.scaffoldingTagline), findsOneWidget);
    expect(find.text(l10n.scaffoldingNotice), findsOneWidget);
  });

  testWidgets('English is a supported locale', (WidgetTester tester) async {
    expect(
      AppLocalizations.supportedLocales,
      contains(const Locale('en')),
      reason: 'English is the base locale and ships built in — see ADR-0006',
    );
  });
}
