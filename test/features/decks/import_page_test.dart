import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/features/decks/import_error_card.dart';
import 'package:fluenough/features/decks/import_fixture.dart';
import 'package:fluenough/features/decks/import_page.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/ui/widgets/incoming.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('a file is live, and the other three sources are incoming', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const ImportPage());
    final l10n = l10nOf(tester);

    for (final source in ImportSource.values) {
      final incoming = source != ImportSource.file;
      final row = find.widgetWithText(GroupedTile, source.label(l10n));
      expect(row, findsOneWidget, reason: source.name);
      expect(
        find.descendant(of: row, matching: find.byType(IncomingBadge)),
        incoming ? findsOneWidget : findsNothing,
        reason: source.name,
      );
      expect(
        tester
            .widget<Radio<ImportSource>>(
              find.descendant(
                of: row,
                matching: find.byType(Radio<ImportSource>),
              ),
            )
            .enabled,
        !incoming,
        reason: source.name,
      );
    }

    // It opens on a file: the help, the template and Choose file.
    expect(find.text(l10n.importFileHelp), findsOneWidget);
    expect(find.text(l10n.importTemplate), findsOneWidget);
    final choose = find.widgetWithText(FilledButton, l10n.importChoose);
    expect(tester.widget<FilledButton>(choose).onPressed, isNotNull);
    expect(find.byType(ImportErrorCard), findsNothing);

    // A tap on an incoming source says so and changes nothing.
    await tester.tap(find.widgetWithText(GroupedTile, l10n.importAnki));
    await tester.pumpAndSettle();
    expect(find.text(l10n.incomingSnackBar), findsOneWidget);
    expect(find.text(l10n.importAnkiHelp), findsNothing);
  });

  testWidgets('a link opens disabled: its field and Fetch', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const ImportPage(initialSource: ImportSource.url));
    final l10n = l10nOf(tester);
    expect(find.text(l10n.importLinkLabel), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    final fetch = find.widgetWithText(FilledButton, l10n.importFetch);
    expect(tester.widget<FilledButton>(fetch).onPressed, isNull);
  });

  testWidgets('a spreadsheet source says which columns it reads', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const ImportPage(initialSource: ImportSource.csv));
    final l10n = l10nOf(tester);
    expect(
      find.text(
        l10n.importCsvHelp(importCsvColumns.join(l10n.commonListSeparator)),
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, l10n.importChoose),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('the error is laid out from a real DeckParseException', (
    tester,
  ) async {
    usePhone(tester);
    final error = importErrorFixture();
    await pumpScreen(tester, ImportPage(error: error));
    final l10n = l10nOf(tester);

    expect(error.line, isNotNull);
    expect(error.message, contains('native'));
    await tester.scrollUntilVisible(
      find.byType(ImportErrorCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.importErrorTitle), findsOneWidget);
    expect(
      find.text(l10n.importErrorAt(error.source, error.line!, error.message)),
      findsOneWidget,
    );
    expect(find.text(l10n.importErrorNothingAdded), findsOneWidget);
  });

  testWidgets('an error the parser could not place names the file alone', (
    tester,
  ) async {
    usePhone(tester);
    const error = DeckParseException(
      'could not be read as YAML',
      source: importErrorFixtureFile,
    );
    await pumpScreen(tester, const ImportPage(error: error));
    final l10n = l10nOf(tester);
    await tester.scrollUntilVisible(
      find.byType(ImportErrorCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(l10n.importErrorIn(error.source, error.message)),
      findsOneWidget,
    );
  });
}
