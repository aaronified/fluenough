// Find my level (owner, 2026-11-05): tapping it never changes a skill; a
// language with no decks on the phone is downloaded first, and placement
// opens straight after, on the one tap.

import 'dart:async';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/features/languages/language_skills_sheet.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/harness.dart';
import 'support/picker.dart';

/// Holds no decks until [download] is called, which waits on [gate].
class _LateDecks extends DeckDownloads {
  _LateDecks()
    : super(
        fetcher: FakeDeckRemote(<String, String>{}),
        files: MemoryDownloadedDecks(),
        clock: DateTime.now,
      );

  final Completer<void> gate = Completer<void>();
  final List<String> downloaded = <String>[];
  bool _held = false;

  @override
  bool hasDecks(String language) => _held;

  @override
  Future<bool> ensureIndex() async => false;

  @override
  Future<DeckDownloadFailure?> download(
    String language,
    List<String> spoken,
  ) async {
    downloaded.add(language);
    await gate.future;
    _held = true;
    return null;
  }
}

void main() {
  testWidgets('one tap downloads the decks, opens placement, and changes no '
      'skill', (tester) async {
    final downloads = _LateDecks();
    final state = AppState.test(
      deckDownloads: downloads,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
      ),
    );
    addTearDown(state.dispose);
    usePhone(tester);
    final es = pickerSpokenList.firstWhere((l) => l.code == 'es');
    final skillsBefore = state.settings.languageSkillsOf('es');
    await pumpScreen(
      tester,
      Scaffold(
        body: LanguageSkillsSheet(
          view: LanguageView(
            es,
            const CatalogLanguage(code: 'es', name: 'Spanish'),
          ),
        ),
      ),
      state: state,
    );

    await tester.tap(find.byKey(const ValueKey<String>('languages-level')));
    await tester.pump();
    await tester.pump();
    // Downloading behind the dialog; nothing has been switched on.
    expect(downloads.downloaded, <String>['es']);
    expect(find.byType(PlacementPage), findsNothing);
    expect(state.settings.languageSkillsOf('es'), skillsBefore);

    downloads.gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PlacementPage), findsOneWidget);
    expect(state.settings.languageSkillsOf('es'), skillsBefore);
  });
}
