import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';

/// Show IPA (ADR-0025): on by default, stored, and switched in Settings.
void main() {
  test('on by default, and kept like every setting', () {
    final s = SettingsNotifier();
    expect(s.showIpa, isTrue);
    expect(s.toStored()['show_ipa'], 'true');
    final restored = SettingsNotifier()
      ..restore((SettingsNotifier()..showIpa = false).toStored());
    expect(restored.showIpa, isFalse);
    final unreadable = SettingsNotifier()
      ..restore(const <String, String>{'show_ipa': 'yes'});
    expect(unreadable.showIpa, isTrue);
  });

  testWidgets('Settings > Learning switches it', (tester) async {
    usePhone(tester);
    final state = await pumpScreen(tester, const SettingsPage());
    final l10n = l10nOf(tester);
    final row = find.ancestor(
      of: find.text(l10n.settingsIpa),
      matching: find.byType(GroupedTile),
    );
    await tester.scrollUntilVisible(
      find.text(l10n.settingsIpa),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsIpaDesc), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(state.settings.showIpa, isFalse);
  });
}
