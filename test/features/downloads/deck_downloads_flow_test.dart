import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/downloads/download_fixtures.dart';
import 'package:fluenough/features/downloads/download_page.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/placement_page.dart';

import '../../support/deck_remote.dart';
import '../../support/harness.dart';
import '../../support/picker.dart';

/// Deck downloads (#210, ADR-0037), through the app: the
/// first launch, a language added and removed, updates, and every failure
/// on the way, on a faked GitHub. Nothing here reaches the network.

final DateTime _now = DateTime(2026, 9, 28, 19);

/// The app as a phone has it: the theme list bundled, the decks in [phone],
/// downloaded from [remote]. A first launch past the languages spoken,
/// unless [settings] says otherwise.
AppState downloadingApp({
  required FakeDeckRemote remote,
  required MemoryDownloadedDecks phone,
  SettingsNotifier? settings,
  MemoryProgress? progress,
  DateTime? now,
}) {
  final clock = now ?? _now;
  return AppState.test(
    decks: DeckSources(<DeckSource>[
      MemoryDeckSource(<String, String>{
        'decks/themes.yaml': File('decks/themes.yaml').readAsStringSync(),
      }),
      phone,
    ]),
    deckDownloads: DeckDownloads(
      fetcher: remote,
      files: phone,
      clock: () => clock,
    ),
    settings:
        settings ?? SettingsNotifier(spokenLanguages: const <String>['en']),
    progress: progress,
    now: clock,
  );
}

/// Settings of a learner past the first launch, learning [languages].
SettingsNotifier learning(List<String> languages) => SettingsNotifier(
  spokenLanguages: const <String>['en'],
  learningLanguages: languages,
)..learningChosen = true;

Future<AppState> pump(WidgetTester tester, AppState state) async {
  usePhone(tester);
  addTearDown(state.dispose);
  await tester.pumpWidget(FluenoughApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

/// Opens Languages I'm learning from Settings, where deck updates and
/// each language's download now are (#467).
Future<void> openLearning(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  await tester.tap(find.text(l10n.navSettings));
  await tester.pumpAndSettle();
  await tapText(tester, l10n.settingsLearn);
  expect(find.byType(LanguagePickerPage), findsOneWidget);
}

/// [code]'s card in Languages I'm learning, scrolled into view.
Future<Finder> cardOf(WidgetTester tester, String code) async {
  await scrollToInPicker(tester, languageCard(code));
  return languageCard(code);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final found = find.text(text);
  await tester.ensureVisible(found.first);
  await tester.pumpAndSettle();
  await tester.tap(found.first);
  await tester.pumpAndSettle();
}

/// [phone] with [languages] downloaded whole from [remote], as a phone
/// that used the app before.
Future<void> downloaded(
  FakeDeckRemote remote,
  MemoryDownloadedDecks phone,
  List<String> languages,
) async {
  final d = DeckDownloads(fetcher: remote, files: phone, clock: () => _now);
  await d.open();
  for (final code in languages) {
    await d.downloadFirst(code, const <String>['en']);
    await d.downloadRest(code, const <String>['en']);
  }
  remote.asked.clear();
}

void main() {
  late FakeDeckRemote remote;
  late MemoryDownloadedDecks phone;

  setUp(() {
    remote = FakeDeckRemote(repoFiles(const <String>['es', 'hi']));
    phone = MemoryDownloadedDecks();
  });

  group('first launch', () {
    testWidgets('lists every language on GitHub, downloads the one chosen '
        'as it is chosen, then places', (tester) async {
      final state = await pump(
        tester,
        downloadingApp(remote: remote, phone: phone),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.learnTitle), findsOneWidget);
      expect(state.decks, isEmpty, reason: 'no deck ships in the app');
      for (final code in <String>['es', 'hi']) {
        await scrollToInPicker(tester, languageCard(code));
        expect(
          find.descendant(
            of: languageCard(code),
            matching: find.textContaining('Not on the phone'),
          ),
          findsOneWidget,
        );
      }

      await pickLanguage(tester, 'es');
      expect(remote.asked, contains('decks/es/es-path.yaml'));
      await tapText(tester, l10n.commonContinue);

      // Ready after the first decks: placement asks, on the decks now in.
      expect(find.byType(PlacementPage), findsOneWidget);
      expect(find.byType(DownloadPage), findsNothing);
      expect(state.languages.map((l) => l.code), <String>['es']);
      expect(phone.files.keys.where((p) => p.startsWith('decks/hi/')), isEmpty);
      expect(remote.asked, isNot(contains('decks/hi/hi-path.yaml')));
    });

    testWidgets('with no network, says so and tries again', (tester) async {
      remote.failAll = FetchFailure.offline;
      await pump(tester, downloadingApp(remote: remote, phone: phone));
      final l10n = l10nOf(tester);
      expect(find.text(l10n.downloadsIndexFailed), findsOneWidget);
      expect(find.text(l10n.downloadsOffline), findsOneWidget);

      remote.failAll = null;
      await tapText(tester, l10n.commonRetry);
      expect(find.text('Spanish'), findsOneWidget);
    });

    testWidgets('says when GitHub limits it', (tester) async {
      remote.failAll = FetchFailure.rateLimited;
      await pump(tester, downloadingApp(remote: remote, phone: phone));
      expect(find.text(l10nOf(tester).downloadsRateLimited), findsOneWidget);
    });

    testWidgets('a download cut short says so on its card, keeps nothing, '
        'and tries again', (tester) async {
      final state = await pump(
        tester,
        downloadingApp(remote: remote, phone: phone),
      );
      final l10n = l10nOf(tester);
      remote.failAfter = 1;
      await pickLanguage(tester, 'hi');
      final card = languageCard('hi');
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            l10n.pickerDownloadFailed(
              l10n.pickerNoConnection,
              l10n.pickerDecksOnPhone(0),
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(phone.files, isEmpty);
      final go = find.widgetWithText(FilledButton, l10n.commonContinue);
      expect(tester.widget<FilledButton>(go).onPressed, isNull);
      expect(state.settings.learningChosen, isFalse);

      remote.failAfter = null;
      final retry = find.descendant(
        of: card,
        matching: find.text(l10n.commonRetry),
      );
      await scrollToInPicker(tester, retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(isPicked(tester, 'hi'), isTrue);
      await tapText(tester, l10n.commonContinue);
      expect(find.byType(PlacementPage), findsOneWidget);
    });

    testWidgets('a deck that fails its check changes nothing', (tester) async {
      remote = FakeDeckRemote(<String, String>{
        ...repoFiles(const <String>['es']),
        'decks/es/en/es-en-core-100.yaml': 'schema: 1\nid: es-en-core-100\n',
      });
      await pump(tester, downloadingApp(remote: remote, phone: phone));
      final l10n = l10nOf(tester);
      await pickLanguage(tester, 'es');
      expect(
        find.descendant(
          of: languageCard('es'),
          matching: find.textContaining(l10n.downloadsInvalid),
        ),
        findsOneWidget,
      );
      expect(phone.files, isEmpty);
      final go = find.widgetWithText(FilledButton, l10n.commonContinue);
      expect(tester.widget<FilledButton>(go).onPressed, isNull);
    });
  });

  group('after updating from a version that bundled its decks', () {
    testWidgets('downloads what the learner learns before it opens, and '
        'their progress is there', (tester) async {
      // A review of a Spanish card, recorded when the decks were bundled.
      final progress = MemoryProgress();
      progress.record(
        deckId: 'es-en-core-100',
        cardId: 'es-0001',
        mode: DrillMode.recognition,
        grade: 4,
        now: _now.subtract(const Duration(days: 3)),
      );
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
          progress: progress,
        ),
      );
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(DownloadPage), findsNothing);
      final deck = state.deckById('es-en-core-100')!;
      expect(state.countsFor(deck).learned, greaterThan(0));
      expect(
        state.progress.stateOf('es-0001', DrillMode.recognition),
        isNotNull,
      );
    });

    testWidgets('offline, says so, and opens once it can', (tester) async {
      remote.failAll = FetchFailure.offline;
      await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.byType(DownloadPage), findsOneWidget);
      expect(find.text(l10n.downloadsOffline), findsOneWidget);
      expect(find.text(l10n.downloadsChooseOther), findsOneWidget);

      remote.failAll = null;
      await tapText(tester, l10n.commonRetry);
      expect(find.byType(AppShell), findsOneWidget);
    });
  });

  group('offline, with decks on the phone', () {
    testWidgets('opens and works as before', (tester) async {
      await downloaded(remote, phone, const <String>['es']);
      remote.failAll = FetchFailure.offline;
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
          now: _now.add(const Duration(days: 2)),
        ),
      );
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(DownloadPage), findsNothing);
      expect(state.deckById('es-en-core-100'), isNotNull);
      expect(find.text(l10nOf(tester).deckUpdatePromptTitle), findsNothing);
    });
  });

  group('a language with some of its decks in', () {
    testWidgets('opens offline, though a language the learner now speaks '
        'teaches decks not yet downloaded', (tester) async {
      remote = FakeDeckRemote(<String, String>{
        for (final file in Directory(
          'test/fixtures/b1/appendix-a/zz',
        ).listSync(recursive: true))
          if (file is File && file.path.endsWith('.yaml'))
            'decks/zz/${file.path.substring('test/fixtures/b1/appendix-a/zz/'.length)}':
                file.readAsStringSync(),
        'decks/zz/bn/zz-bn-home.yaml': '''
schema: 1
id: "zz-bn-home"
name: "ঘর"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
native: { code: "bn", iso639_3: "ben", name: "Bengali" }
license: "CC0-1.0"
cards:
  - { id: "zz-9801", target: "ఇల్లు", reading: "illu", native: "ঘর" }
''',
      });
      await downloaded(remote, phone, const <String>['zz']);
      remote.failAll = FetchFailure.offline;
      final settings = SettingsNotifier(
        spokenLanguages: const <String>['bn', 'en'],
        learningLanguages: const <String>['zz'],
      )..learningChosen = true;
      final state = await pump(
        tester,
        downloadingApp(remote: remote, phone: phone, settings: settings),
      );
      expect(
        state.deckDownloads!.isReady('zz', settings.spokenLanguages),
        isFalse,
      );
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(DownloadPage), findsNothing);
    });
  });

  group('a language added later', () {
    testWidgets('downloads before placement', (tester) async {
      await downloaded(remote, phone, const <String>['es']);
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
        ),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.navSettings));
      await tester.pumpAndSettle();
      await tapText(tester, l10n.settingsLearn);
      expect(find.byType(LanguagePickerPage), findsOneWidget);
      await pickLanguage(tester, 'hi');
      await tapText(tester, l10n.commonContinue);
      expect(find.byType(PlacementPage), findsOneWidget);
      expect(
        state.languages.map((l) => l.code),
        containsAll(<String>['es', 'hi']),
      );
    });
  });

  group('Languages I\'m learning, where Deck downloads was (#467)', () {
    Future<AppState> openPage(WidgetTester tester, {DateTime? now}) async {
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es', 'hi']),
          now: now,
        ),
      );
      await openLearning(tester);
      return state;
    }

    testWidgets('lists each language with its size and state', (tester) async {
      await downloaded(remote, phone, const <String>['es', 'hi']);
      await openPage(tester);
      final l10n = l10nOf(tester);
      // Check for deck updates and Check automatically lead the page.
      expect(find.text(l10n.deckDownloadsCheck), findsOneWidget);
      expect(find.text(l10n.deckDownloadsAuto), findsOneWidget);
      for (final code in <String>['es', 'hi']) {
        final card = await cardOf(tester, code);
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('Up to date'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(l10n.deckDownloadsRemove),
          ),
          findsOneWidget,
        );
      }
      // The separate page is gone, and Settings no longer links to it.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Deck downloads'), findsNothing);
    });

    testWidgets('removing a language deletes its decks, keeps its '
        'progress, and downloading it again brings it back', (tester) async {
      await downloaded(remote, phone, const <String>['es', 'hi']);
      final state = await openPage(tester);
      final l10n = l10nOf(tester);
      final card = state.deckById('es-en-core-100')!.cards.first;
      state.progress.record(
        deckId: 'es-en-core-100',
        cardId: card.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: _now,
      );

      final spanish = await cardOf(tester, 'es');
      await tester.tap(
        find.descendant(
          of: spanish,
          matching: find.text(l10n.deckDownloadsRemove),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.deckDownloadsRemoveTitle('Spanish')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.deckDownloadsRemove),
        ),
      );
      await tester.pumpAndSettle();

      expect(phone.files.keys.where((p) => p.startsWith('decks/es/')), isEmpty);
      expect(state.deckById('es-en-core-100'), isNull);
      expect(state.currentProfile.learns('es'), isFalse);
      expect(state.progress.stateOf(card.id, DrillMode.recognition), isNotNull);

      expect(await state.downloadLanguage('es'), isNull);
      await tester.pumpAndSettle();
      final again = state.deckById('es-en-core-100')!;
      expect(state.countsFor(again).learned, greaterThan(0));
    });

    testWidgets('an update waits there after "Not now", and updates there', (
      tester,
    ) async {
      await downloaded(remote, phone, const <String>['es', 'hi']);
      const deck = 'decks/es/en/es-en-core-100.yaml';
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      // A day after the last check, the app looks again, and asks.
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es', 'hi']),
          now: _now.add(const Duration(days: 2)),
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.deckUpdatePromptTitle), findsOneWidget);
      await tapText(tester, l10n.deckUpdatePromptLater);
      expect(find.text(l10n.deckUpdatePromptTitle), findsNothing);

      await openLearning(tester);
      final spanish = await cardOf(tester, 'es');
      expect(
        find.descendant(
          of: spanish,
          matching: find.textContaining('Update waiting'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: spanish,
          matching: find.text(l10n.deckDownloadsUpdate),
        ),
      );
      await tester.pumpAndSettle();
      expect(await phone.read(deck), endsWith('# a fix\n'));
      expect(
        find.descendant(
          of: spanish,
          matching: find.textContaining('Up to date'),
        ),
        findsOneWidget,
      );
      expect(state.deckDownloads!.updates, isEmpty);
    });

    testWidgets('a reviewer\'s proposal alone asks a learner nothing, and '
        'a reviewer it does (#444)', (tester) async {
      await downloaded(remote, phone, const <String>['es']);
      const deck = 'decks/es/en/es-en-core-100.yaml';
      final was = await phone.read(deck);
      remote.files[deck] = withProposal(
        remote.files[deck]!,
        '    native: "the man"',
      );
      final settings = learning(const <String>['es']);
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: settings,
          now: _now.add(const Duration(days: 2)),
        ),
      );
      final l10n = l10nOf(tester);
      expect(remote.asked, contains('decks/index.json'));
      expect(find.text(l10n.deckUpdatePromptTitle), findsNothing);
      expect(state.deckDownloads!.updates, isEmpty);
      expect(await phone.read(deck), was);

      // Reviewing, the same change is an update: reviewers see proposals.
      settings.reviewDecks = true;
      await tester.pumpAndSettle();
      expect(state.deckDownloads!.reviewer, isTrue);
      expect(state.deckDownloads!.updates.keys, <String>['es']);
      settings.reviewDecks = false;
      await tester.pumpAndSettle();
      expect(state.deckDownloads!.updates, isEmpty);
    });

    testWidgets('a reviewer is asked about a proposal (#444)', (tester) async {
      await downloaded(remote, phone, const <String>['es']);
      const deck = 'decks/es/en/es-en-core-100.yaml';
      remote.files[deck] = withProposal(
        remote.files[deck]!,
        '    native: "the man"',
      );
      await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es'])..reviewDecks = true,
          now: _now.add(const Duration(days: 2)),
        ),
      );
      expect(find.text(l10nOf(tester).deckUpdatePromptTitle), findsOneWidget);
    });

    testWidgets('"Update" in the question updates', (tester) async {
      await downloaded(remote, phone, const <String>['es']);
      const deck = 'decks/es/en/es-en-core-100.yaml';
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
          now: _now.add(const Duration(days: 2)),
        ),
      );
      final l10n = l10nOf(tester);
      await tapText(tester, l10n.deckUpdatePromptUpdate);
      expect(await phone.read(deck), endsWith('# a fix\n'));
      expect(find.text(l10n.deckDownloadsUpdated), findsOneWidget);
    });

    testWidgets('Try again after a failed update updates', (tester) async {
      await downloaded(remote, phone, const <String>['es']);
      const deck = 'decks/es/en/es-en-core-100.yaml';
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
          now: _now.add(const Duration(days: 2)),
        ),
      );
      final l10n = l10nOf(tester);
      await tapText(tester, l10n.deckUpdatePromptLater);
      await openLearning(tester);
      await cardOf(tester, 'es');

      remote.failAll = FetchFailure.offline;
      await tapText(tester, l10n.deckDownloadsUpdate);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      expect(find.text(l10n.deckDownloadsUpdate), findsNothing);

      remote.failAll = null;
      await tapText(tester, l10n.commonRetry);
      expect(await phone.read(deck), endsWith('# a fix\n'));
      expect(find.textContaining('Up to date'), findsOneWidget);
      expect(state.deckDownloads!.updates, isEmpty);
    });

    testWidgets('with the daily check off, the app does not look', (
      tester,
    ) async {
      await downloaded(remote, phone, const <String>['es']);
      final before = DeckDownloads(
        fetcher: remote,
        files: phone,
        clock: () => _now,
      );
      await before.open();
      await before.setChecksAutomatically(false);
      const deck = 'decks/es/en/es-en-core-100.yaml';
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
          now: _now.add(const Duration(days: 2)),
        ),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.deckUpdatePromptTitle), findsNothing);
      expect(remote.asked, isEmpty);

      // Check for deck updates still looks, when asked.
      await openLearning(tester);
      await tapText(tester, l10n.deckDownloadsCheck);
      expect(remote.asked, <String>['decks/index.json']);
      expect(state.deckDownloads!.updates.keys, <String>['es']);
    });

    testWidgets('the daily check is switched on the page', (tester) async {
      await downloaded(remote, phone, const <String>['es']);
      final state = await openPage(tester);
      final l10n = l10nOf(tester);
      expect(state.deckDownloads!.checksAutomatically, isTrue);
      await tapText(tester, l10n.deckDownloadsAuto);
      expect(state.deckDownloads!.checksAutomatically, isFalse);
      final again = DeckDownloads(
        fetcher: remote,
        files: phone,
        clock: () => _now,
      );
      await again.open();
      expect(again.checksAutomatically, isFalse);
    });

    testWidgets('a deck removed upstream stays on the phone', (tester) async {
      await downloaded(remote, phone, const <String>['es']);
      remote.files.remove('decks/es/en/es-en-grammar-present-ar.yaml');
      final state = await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
          now: _now.add(const Duration(days: 2)),
        ),
      );
      expect(find.text(l10nOf(tester).deckUpdatePromptTitle), findsNothing);
      expect(state.deckById('es-en-grammar-present-ar'), isNotNull);
    });
  });

  group('accessibility', () {
    Future<void> meetsGuidelines(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    testWidgets('the download page, failed, meets the guidelines', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      remote.failAll = FetchFailure.offline;
      await pump(
        tester,
        downloadingApp(
          remote: remote,
          phone: phone,
          settings: learning(const <String>['es']),
        ),
      );
      expect(find.byType(DownloadPage), findsOneWidget);
      await meetsGuidelines(tester);
      semantics.dispose();
    });

    testWidgets('Languages I\'m learning, with an update waiting, meets the '
        'guidelines, at twice the text size too', (tester) async {
      final semantics = tester.ensureSemantics();
      await downloaded(remote, phone, const <String>['es', 'hi']);
      const deck = 'decks/es/en/es-en-core-100.yaml';
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      final state = downloadingApp(
        remote: remote,
        phone: phone,
        settings: learning(const <String>['es', 'hi']),
      );
      await state.deckDownloads!.open();
      await state.deckDownloads!.checkForUpdates(const <String>[
        'en',
      ], force: true);
      await state.deckDownloads!.declineUpdate();
      addTearDown(state.dispose);
      await pumpScreen(tester, const LanguagePickerPage(), state: state);
      final l10n = l10nOf(tester);
      // At the top: the check, the switch and Update all.
      expect(find.text(l10n.deckDownloadsCheck), findsOneWidget);
      await meetsGuidelines(tester);
      await cardOf(tester, 'es');
      expect(find.textContaining('Update waiting'), findsOneWidget);
      usePhone(tester, textScale: 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('the gallery', () {
    testWidgets('shows an update waiting for Hindi, Telugu up to date', (
      tester,
    ) async {
      final app = AppState.test();
      addTearDown(app.dispose);
      final state = DownloadFixtures.updateWaiting(app);
      addTearDown(state.dispose);
      await pumpScreen(tester, const LanguagePickerPage(), state: state);
      await tester.pumpAndSettle();
      await cardOf(tester, 'hi');
      expect(find.textContaining('Update waiting'), findsOneWidget);
      await cardOf(tester, 'te');
      expect(find.textContaining('Up to date'), findsOneWidget);
    });

    testWidgets('shows the first decks failing with no network', (
      tester,
    ) async {
      final app = AppState.test();
      addTearDown(app.dispose);
      final state = DownloadFixtures.offline(app);
      addTearDown(state.dispose);
      await pumpScreen(
        tester,
        const DownloadPage(languages: <String>['es']),
        state: state,
      );
      expect(find.text(l10nOf(tester).downloadsOffline), findsOneWidget);
    });
  });
}
