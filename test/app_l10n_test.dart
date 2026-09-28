import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/l10n/app_localizations.dart';

/// Guards the localisation wiring, not the copy.
///
/// Every string in the app is a token (AGENTS.md rule 10), which means the
/// chain from `lib/l10n/app_en.arb` through the generated `AppLocalizations`
/// to a widget has to actually be connected. Without this a missing delegate
/// or a renamed token surfaces on a device as a crash or a blank label.
///
/// It asserts against `l10n.appTitle` and `l10n.navToday` rather than the
/// literals `'Fluenough'` and `'Today'` on purpose: pinning the English text
/// here would mean every wording change breaks a test that is not about
/// wording.
void main() {
  testWidgets('interface text resolves through AppLocalizations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(FluenoughApp(state: AppState.test()));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(AppShell));
    final AppLocalizations? l10n = AppLocalizations.of(context);

    expect(
      l10n,
      isNotNull,
      reason: 'AppLocalizations.delegate is not registered on MaterialApp',
    );
    expect(tester.widget<Title>(find.byType(Title)).title, l10n!.appTitle);
    expect(find.text(l10n.navToday), findsWidgets);
    expect(find.text(l10n.navSettings), findsOneWidget);
  });

  testWidgets('English is a supported locale', (WidgetTester tester) async {
    expect(
      AppLocalizations.supportedLocales,
      contains(const Locale('en')),
      reason: 'English is the base locale and ships built in — see ADR-0006',
    );
  });

  test('each translation names its own language, for the picker', () async {
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    expect(english.localeOwnName, isNotEmpty);
    expect(english.localeOwnIso639_3, matches(RegExp(r'^[a-z]{3}$')));
  });
}
