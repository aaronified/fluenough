import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/features/profiles/spoken_languages_page.dart';
import 'package:fluenough/features/review/review_languages_page.dart';

import '../../support/deck_remote.dart';
import '../../support/harness.dart';

/// Languages you review (#462, #467): every course in the deck index, a
/// language and the one it is taught from; greyed with the reason where the
/// reviewer cannot review it; downloaded for review only; and the courses
/// on the phone with their size, Update and Remove.

final DateTime _now = DateTime(2026, 10, 10, 19);

/// A reviewer who knows [known], with reviewing on, learning Spanish, on
/// a phone that downloads from a GitHub faked with Spanish and Hindi.
Future<(AppState, MemoryDownloadedDecks)> reviewerApp({
  List<String> known = const <String>['en', 'hi'],
  Map<String, bool>? scripts,
  List<String> onPhone = const <String>[],
}) async {
  final remote = FakeDeckRemote(repoFiles(const <String>['es', 'hi']));
  final phone = MemoryDownloadedDecks();
  final setup = DeckDownloads(fetcher: remote, files: phone, clock: () => _now);
  await setup.open();
  for (final code in onPhone) {
    await setup.downloadFirst(code, known);
    await setup.downloadRest(code, known);
  }
  final settings =
      SettingsNotifier(
          spokenLanguages: known,
          learningLanguages: const <String>['es'],
        )
        ..learningChosen = true
        ..reviewDecks = true
        ..raterCode = 'FL-ABCD-EFGH-J';
  if (scripts != null) settings.scriptsRead = scripts;
  final downloads = DeckDownloads(
    fetcher: remote,
    files: phone,
    clock: () => _now,
  );
  final state = AppState.test(
    decks: DeckSources(<DeckSource>[
      MemoryDeckSource(<String, String>{
        'decks/themes.yaml': File('decks/themes.yaml').readAsStringSync(),
      }),
      phone,
    ]),
    deckDownloads: downloads,
    settings: settings,
    now: _now,
  );
  await downloads.open();
  await downloads.refreshIndex();
  return (state, phone);
}

Finder pairTile(String target, String native) => find.ancestor(
  of: find.text('$target from $native'),
  matching: find.byType(CheckboxListTile),
);

CheckboxListTile tileOf(WidgetTester tester, String target, String native) =>
    tester.widget<CheckboxListTile>(pairTile(target, native));

void main() {
  // A cached asset's future belongs to the test that first read it.
  setUp(rootBundle.clear);

  testWidgets('lists every course in the index, greyed with the reason '
      'where the reviewer cannot review it', (tester) async {
    usePhone(tester);
    final (app, _) = await reviewerApp(
      scripts: const <String, bool>{'en': true, 'hi': false},
    );
    addTearDown(app.dispose);
    final state = await pumpScreen(
      tester,
      const ReviewLanguagesPage(),
      state: app,
    );
    final l10n = l10nOf(tester);
    expect(tileOf(tester, 'Spanish', 'English').enabled, isFalse);
    expect(find.text(l10n.reviewPairUnknown('Spanish')), findsOneWidget);
    expect(tileOf(tester, 'Hindi', 'English').enabled, isFalse);
    expect(
      find.text(l10n.reviewPairNoScript('devanagari', 'Hindi')),
      findsOneWidget,
    );

    state.settings.scriptsRead = const <String, bool>{'en': true, 'hi': true};
    await tester.pumpAndSettle();
    expect(tileOf(tester, 'Hindi', 'English').enabled, isTrue);
    expect(find.text(l10n.reviewPairUnknown('Spanish')), findsOneWidget);
  });

  testWidgets('until the scripts are answered it says so, and nothing can '
      'be ticked; its button opens Languages you know', (tester) async {
    usePhone(tester);
    final (app, _) = await reviewerApp();
    addTearDown(app.dispose);
    await pumpScreen(tester, const ReviewLanguagesPage(), state: app);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.reviewScriptsGateTitle), findsOneWidget);
    expect(tileOf(tester, 'Hindi', 'English').enabled, isFalse);
    expect(tileOf(tester, 'Spanish', 'English').enabled, isFalse);

    await tester.tap(find.text(l10n.reviewOpenKnown));
    await tester.pumpAndSettle();
    expect(find.byType(SpokenLanguagesPage), findsOneWidget);
    expect(find.text(l10n.spokenTitle), findsOneWidget);
  });

  testWidgets('ticking a course not on the phone asks, then downloads it '
      'for review only: it is not learned', (tester) async {
    usePhone(tester);
    final (app, _) = await reviewerApp(
      scripts: const <String, bool>{'en': true, 'hi': true},
    );
    addTearDown(app.dispose);
    final state = await pumpScreen(
      tester,
      const ReviewLanguagesPage(),
      state: app,
    );
    final l10n = l10nOf(tester);
    expect(state.deckDownloads!.languagesOnPhone, isNot(contains('hi')));
    await tester.tap(pairTile('Hindi', 'English'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reviewDownloadTitle('Hindi')), findsOneWidget);
    await tester.tap(find.text(l10n.reviewDownload));
    await tester.pumpAndSettle();

    expect(state.settings.reviewPairs, <String>{'hi/en'});
    expect(state.deckDownloads!.languagesOnPhone, contains('hi'));
    expect(state.decks.any((d) => d.language.code == 'hi'), isTrue);
    // Not a language learned: out of Today, the language menu and lessons.
    expect(state.settings.learningLanguages, <String>['es']);
    expect(state.currentProfile.learns('hi'), isFalse);
    expect(state.languageChoices.map((l) => l.code), isNot(contains('hi')));
    expect(state.profileDecks.any((d) => d.language.code == 'hi'), isFalse);
    // Now on the phone, its row shows its size, with Remove.
    expect(find.textContaining('Up to date'), findsOneWidget);
    expect(find.text(l10n.deckDownloadsRemove), findsOneWidget);
  });

  testWidgets('a course on the phone can be removed there; a language only '
      'reviewed says so', (tester) async {
    usePhone(tester);
    final (app, _) = await reviewerApp(
      scripts: const <String, bool>{'en': true, 'hi': true},
      onPhone: const <String>['hi'],
    );
    addTearDown(app.dispose);
    final state = await pumpScreen(
      tester,
      const ReviewLanguagesPage(),
      state: app,
    );
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.deckDownloadsRemove));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.deckDownloadsRemoveReviewBody('Hindi')),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.deckDownloadsRemove).last);
    await tester.pumpAndSettle();
    expect(state.deckDownloads!.languagesOnPhone, isNot(contains('hi')));
    expect(state.settings.learningLanguages, <String>['es']);
  });
}
