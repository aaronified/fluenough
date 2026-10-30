// Settings' Sources page credits Wiktionary for the narrow IPA in [ ]
// (owner, 2026-10-30): the line is on the page, tapping it opens
// en.wiktionary.org, and the licence row opens the CC BY-SA 4.0 text.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/features/settings/sources_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Sources page credits Wiktionary for pronunciations', () {
    testWidgets('it says the IPA in [ ] is adapted from Wiktionary, '
        'CC BY-SA 4.0, and the links open', (tester) async {
      usePhone(tester);
      final links = FixedLinks();
      await pumpScreen(
        tester,
        const SourcesPage(),
        state: AppState.test(links: links),
      );
      final l10n = l10nOf(tester);
      expect(
        find.text(
          'Pronunciations in [ ] adapted from Wiktionary, '
          'licensed CC BY-SA 4.0.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.ancestor(
          of: find.text(l10n.sourcesPhonetic),
          matching: find.byType(GroupedTile),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text(l10n.sourcesLicence),
          matching: find.byType(GroupedTile),
        ),
      );
      await tester.pumpAndSettle();
      expect(links.asked, <String>[AppLinks.wiktionary, AppLinks.ccBySa]);
    });
  });
}
