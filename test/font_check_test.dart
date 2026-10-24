// The font check (#611, ADR-0042): a course asks, once, whether the phone
// draws a script, and downloads the script's font only when it does not;
// Settings, Script fonts, lists each script and asks again.

import 'dart:convert';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/font_check.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/features/fonts/font_check_sheet.dart';
import 'package:fluenough/features/fonts/script_fonts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/harness.dart';

const String _devanagari = 'decks/fonts/devanagari/NotoSansDevanagari.ttf';
const String _nastaliq = 'decks/fonts/perso_arabic/NotoNastaliqUrdu.ttf';

const Map<String, String> _scripts = <String, String>{
  _devanagari: 'devanagari',
  _nastaliq: 'perso_arabic',
};

/// The remote's index with the fonts of Hindustani, and the font files.
void _serveFonts(FakeDeckRemote remote) {
  final json = jsonDecode(indexFor(remote.files)) as Map<String, Object?>;
  for (final language in json['languages']! as List<Object?>) {
    final map = language! as Map<String, Object?>;
    if (map['code'] != 'hi') continue;
    map['fonts'] = <Object?>[
      for (final path in _scripts.keys)
        <String, Object?>{
          'path': path,
          'size': utf8.encode(path).length,
          'sha256': sha256Hex(utf8.encode(path)),
          'script': _scripts[path],
          'family': 'Noto',
        },
    ];
  }
  remote.index = jsonEncode(json);
  remote.served.addAll(<String, String>{for (final p in _scripts.keys) p: p});
}

void main() {
  late FakeDeckRemote remote;
  late MemoryDownloadedDecks phone;
  late SettingsNotifier settings;
  late AppState state;

  setUp(() async {
    remote = FakeDeckRemote(repoFiles(const <String>['hi']));
    _serveFonts(remote);
    phone = MemoryDownloadedDecks();
    settings = SettingsNotifier(spokenLanguages: const <String>['en']);
    final downloads = DeckDownloads(
      fetcher: remote,
      files: phone,
      clock: () => DateTime(2026, 10, 24),
      scriptFonts: ScriptFonts(register: (family, bytes) async {}),
    );
    await downloads.open();
    await downloads.ensureIndex();
    state = AppState.test(deckDownloads: downloads, settings: settings);
  });

  tearDown(() => state.dispose());

  test('a course asks about the script the learner reads and brings no '
      'font until they say it shows boxes', () async {
    expect(await state.downloadLanguage('hi'), isNull);
    await Future<void>.delayed(Duration.zero);
    // Hindustani has two scripts; Devanagari is the one read by default.
    expect(state.fontCheck.pending, 'devanagari');
    expect(phone.fontFiles, isEmpty);
    expect(state.fontCheck.stateOf('devanagari'), FontCheckState.notChecked);

    expect(
      await state.fontCheck.choose('devanagari', FontChoice.download),
      isNull,
    );
    expect(phone.fontFiles.keys, <String>[_devanagari]);
    expect(
      state.deckDownloads!.fonts.familyFor('devanagari'),
      'FluenoughScript-devanagari',
    );
    expect(state.fontCheck.stateOf('devanagari'), FontCheckState.downloaded);

    // Saying the phone draws it stops using the downloaded font.
    await state.fontCheck.choose('devanagari', FontChoice.phone);
    expect(state.deckDownloads!.fonts.familyFor('devanagari'), isNull);
    expect(state.fontCheck.stateOf('devanagari'), FontCheckState.phoneFont);
  });

  test('a download that fails leaves the script unchecked', () async {
    remote.failures[_devanagari] = FetchFailure.offline;
    final failure = await state.fontCheck.choose(
      'devanagari',
      FontChoice.download,
    );
    expect(failure, DeckDownloadFailure.offline);
    expect(settings.fontChoice('devanagari'), isNull);
    expect(state.fontCheck.stateOf('devanagari'), FontCheckState.notChecked);
  });

  test('what the learner said is kept with the settings', () {
    settings.setFontChoice('kana', FontChoice.phone);
    final restored = SettingsNotifier()..restore(settings.toStored());
    expect(restored.fontChoice('kana'), FontChoice.phone);
  });

  testWidgets('the sheet downloads the font on No and asks again in it', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const Scaffold(body: FontCheckSheet(script: 'devanagari')),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text('नमस्ते'), findsOneWidget);

    await tester.tap(find.text(l10n.fontCheckNo));
    await tester.pumpAndSettle();
    expect(find.text(l10n.fontCheckReadNow), findsOneWidget);
    expect(phone.fontFiles.keys, <String>[_devanagari]);
    expect(
      tester.widget<Text>(find.text('नमस्ते')).style?.fontFamily,
      'FluenoughScript-devanagari',
    );

    await tester.tap(find.text(l10n.fontCheckStillBoxes));
    await tester.pumpAndSettle();
    expect(find.text(l10n.fontCheckBoxesTitle), findsOneWidget);
    expect(settings.fontChoice('devanagari'), FontChoice.boxes);
  });

  testWidgets('the sheet keeps the phone font on Yes', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(body: FontCheckSheet(script: 'devanagari')),
      state: state,
    );
    await tester.tap(find.text(l10nOf(tester).fontCheckYes));
    await tester.pumpAndSettle();
    expect(settings.fontChoice('devanagari'), FontChoice.phone);
    expect(phone.fontFiles, isEmpty);
  });

  testWidgets('Script fonts lists the scripts of the courses with where '
      'each stands', (tester) async {
    await state.downloadLanguage('hi');
    await pumpScreen(tester, const ScriptFontsPage(), state: state);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.scriptName('devanagari')), findsOneWidget);
    expect(find.text(l10n.scriptName('perso_arabic')), findsOneWidget);
    expect(find.textContaining(l10n.fontsState('notChecked')), findsWidgets);
    expect(find.text(l10n.fontsCheck), findsWidgets);
  });
}
