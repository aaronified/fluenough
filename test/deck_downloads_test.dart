// Deck download and update: first launch lists GitHub's languages and
// downloads one; ready after the first decks with the rest behind it;
// offline and rate limit keep nothing and say so; a hash mismatch is thrown
// away; cut short keeps whole decks; an update keeps every card id, and a
// failed one leaves the decks as they were; a stale index is read again;
// proposals; fonts; added decks; repeated failures offer the app update.

import 'dart:convert';
import 'dart:io';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/deck_import.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/features/decks/import_page.dart';
import 'package:fluenough/features/downloads/download_page.dart';
import 'package:fluenough/features/placement/language_picker_page.dart';
import 'package:fluenough/features/placement/placement_page.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/fake_http.dart';
import 'support/harness.dart';
import 'support/picker.dart';

// From deck_downloads_flow_test.dart.
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
  await tester.pumpWidget(FluenoughApp(key: UniqueKey(), state: state));
  await tester.pumpAndSettle();
  return state;
}

/// Opens Languages I'm learning from Settings, where deck updates and
/// each language's download now are (#467).
Future<void> openLearning(WidgetTester tester) async {
  final l10n = l10nOf(tester);
  await tester.tap(find.text(l10n.navSettings));
  await tester.pumpAndSettle();
  await tapText(tester, l10n.settingsRowLanguages);
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

// From deck_downloads_test.dart.
/// [inner], calling [onFetched] once [count] deck files have been fetched:
/// to cancel a download part-way.
class _CallAfter implements DeckFetcher {
  _CallAfter(this.inner, this.count, this.onFetched);

  final DeckFetcher inner;
  final int count;
  final Future<void> Function() onFetched;
  int _fetched = 0;

  @override
  Future<Fetched> fetch(String path) async {
    final result = await inner.fetch(path);
    if (path != 'decks/index.json' && ++_fetched == count) await onFetched();
    return result;
  }
}

// From deck_index_test.dart.
const String _sha =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/// An index of one language, `zz`, with [files].
String _index(List<Map<String, Object?>> files, {int version = 1}) =>
    jsonEncode(<String, Object?>{
      'version': version,
      'languages': <Object?>[
        <String, Object?>{
          'code': 'zz',
          'name': 'Testlang',
          'natives': <Object?>[
            <String, String>{'code': 'en', 'name': 'English'},
            <String, String>{'code': 'bn', 'name': 'Bengali'},
          ],
          'path': <String>['zz-a', 'zz-b', 'zz-c'],
          'files': files,
        },
      ],
    });

Map<String, Object?> _file(
  String path, {
  String? native,
  String? deck,
  String kind = 'vocab',
  bool core = false,
  int schema = 1,
  String sha = _sha,
}) => <String, Object?>{
  'path': path,
  'size': 10,
  'sha256': sha,
  'schema': schema,
  'kind': kind,
  'native': ?native,
  'deck': ?deck,
  if (core) 'part': 'core',
};

IndexFile _phone(
  String path, {
  String? native,
  String? deck,
  String kind = 'vocab',
  bool core = false,
  String sha = _sha,
  String? content,
}) => IndexFile(
  path: path,
  size: 10,
  sha256: sha,
  contentSha256: content,
  kind: kind,
  native: native,
  deck: deck,
  core: core,
);

// From downloaded_decks_test.dart.
// From script_fonts_test.dart.
const String _devanagari = 'decks/fonts/devanagari/NotoSansDevanagari.ttf';
const String _nastaliq = 'decks/fonts/perso_arabic/NotoNastaliqUrdu.ttf';

/// The text each fake font file holds: what the remote serves.
const Map<String, String> _bytes = <String, String>{
  _devanagari: 'devanagari font',
  _nastaliq: 'nastaliq font',
};

const Map<String, String> _scripts = <String, String>{
  _devanagari: 'devanagari',
  _nastaliq: 'perso_arabic',
};

Map<String, Object?> _entry(String path) => <String, Object?>{
  'path': path,
  'size': utf8.encode(_bytes[path]!).length,
  'sha256': sha256Hex(utf8.encode(_bytes[path]!)),
  'script': _scripts[path],
  'family': 'Noto',
};

/// [index], with each language's `fonts` set from [fonts], by code.
String _withFonts(String index, Map<String, List<String>> fonts) {
  final json = jsonDecode(index) as Map<String, Object?>;
  for (final language in json['languages']! as List<Object?>) {
    final map = language! as Map<String, Object?>;
    final paths = fonts[map['code']];
    if (paths != null) {
      map['fonts'] = <Object?>[for (final path in paths) _entry(path)];
    }
  }
  return jsonEncode(json);
}

// From target_text_font_test.dart.
const LanguageInfo telugu = LanguageInfo(
  code: 'te',
  iso639_3: 'tel',
  name: 'Telugu',
  script: 'telugu',
);

const LanguageInfo spanish = LanguageInfo(
  code: 'es',
  iso639_3: 'spa',
  name: 'Spanish',
);

const IndexFont _font = IndexFont(
  path: 'decks/fonts/telugu/NotoSansTelugu.ttf',
  size: 1,
  sha256: 'a',
  script: 'telugu',
);

/// An app whose downloads have [fonts] to load from.
AppState _app(ScriptFonts fonts) => AppState.test(
  deckDownloads: DeckDownloads(
    fetcher: const NullDeckFetcher(),
    files: MemoryDownloadedDecks(),
    clock: () => DateTime(2026, 10, 19),
    scriptFonts: fonts,
  ),
);

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

// From added_decks_test.dart.
/// Answers the file dialogs from memory.
class FakeDeckFiles implements DeckFiles {
  FakeDeckFiles({this.picked});

  ({String name, String text})? picked;
  final Map<String, String> saved = <String, String>{};

  @override
  Future<bool> save(String fileName, String contents) async {
    saved[fileName] = contents;
    return true;
  }

  @override
  Future<({String name, String text})?> open({required String title}) async =>
      picked;
}

/// The template, as the learner downloads it: Hindi from English, a market
/// deck with two cards of its own and one ref. Not cached: a future cached
/// in one test's zone never completes in the next.
Future<String> template() =>
    rootBundle.loadString(deckTemplateAsset, cache: false);

// From update_escape_test.dart.
/// The way out of a failed download (0.4.0 failed every one, and left the
/// learner where Settings' update check could not be reached): "Check for
/// an app update" under every failure that traps the learner, and, once
/// it keeps failing, a line suggesting it or a report.

final DateTime _escapeNow = DateTime(2026, 10, 10, 9);

/// The app on a faked GitHub [remote], with a release check that answers
/// [release]: on first launch past the languages spoken, or as the app's
/// home downloading [learning] if given.
AppState _escapeApp({
  required FakeDeckRemote remote,
  required FixedReleaseCheck release,
  List<String>? learning,
  ThemeMode themeMode = ThemeMode.light,
}) {
  final phone = MemoryDownloadedDecks();
  final settings = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: learning ?? const <String>[],
  )..themeMode = themeMode;
  if (learning != null) settings.learningChosen = true;
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
      clock: () => _escapeNow,
    ),
    settings: settings,
    releases: release,
    now: _escapeNow,
  );
}

Future<AppState> _pump(
  WidgetTester tester,
  AppState state, {
  double textScale = 1.0,
}) async {
  usePhone(tester, textScale: textScale);
  addTearDown(state.dispose);
  await tester.pumpWidget(FluenoughApp(key: UniqueKey(), state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Not built yet: further down a list, at a large text size.
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Finder _check(AppLocalizations l10n) => find.text(l10n.downloadsCheckAppUpdate);

void main() {
  group('first launch and Languages on the phone', () {
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
        // Its size and whether it is on the phone are in a language's sheet.
        for (final code in <String>['es', 'hi']) {
          await openSheet(tester, code);
          expect(find.textContaining('Not on the phone'), findsOneWidget);
          await closeSheet(tester);
        }

        await pickLanguage(tester, 'es');
        expect(remote.asked, contains('decks/es/es-path.yaml'));
        await tapText(tester, l10n.commonContinue);

        // Ready after the first decks: placement asks, on the decks now in.
        expect(find.byType(PlacementPage), findsOneWidget);
        expect(find.byType(DownloadPage), findsNothing);
        expect(state.languages.map((l) => l.code), <String>['es']);
        expect(
          phone.files.keys.where((p) => p.startsWith('decks/hi/')),
          isEmpty,
        );
        expect(remote.asked, isNot(contains('decks/hi/hi-path.yaml')));
      });

      testWidgets('with no network, or GitHub limiting it, says so', (
        tester,
      ) async {
        remote.failAll = FetchFailure.offline;
        await pump(tester, downloadingApp(remote: remote, phone: phone));
        final l10n = l10nOf(tester);
        expect(find.text(l10n.downloadsIndexFailed), findsOneWidget);
        expect(find.text(l10n.downloadsOffline), findsOneWidget);

        remote.failAll = null;
        await tapText(tester, l10n.commonRetry);
        await openFamilies(tester);
        expect(languageCard('es'), findsWidgets);

        final limited = FakeDeckRemote(repoFiles(const <String>['es', 'hi']))
          ..failAll = FetchFailure.rateLimited;
        await pump(
          tester,
          downloadingApp(remote: limited, phone: MemoryDownloadedDecks()),
        );
        expect(find.text(l10nOf(tester).downloadsRateLimited), findsOneWidget);
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
            matching: find.byKey(const ValueKey<String>('remove-es')),
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

        expect(
          phone.files.keys.where((p) => p.startsWith('decks/es/')),
          isEmpty,
        );
        expect(state.deckById('es-en-core-100'), isNull);
        expect(state.currentProfile.learns('es'), isFalse);
        expect(
          state.progress.stateOf(card.id, DrillMode.recognition),
          isNotNull,
        );

        expect(await state.downloadLanguage('es'), isNull);
        await tester.pumpAndSettle();
        final again = state.deckById('es-en-core-100')!;
        expect(state.countsFor(again).learned, greaterThan(0));
      });

      testWidgets(
        'with the daily check off the app does not look, and a deck removed '
        'upstream stays on the phone',
        (tester) async {
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

          {
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
            expect(
              find.text(l10nOf(tester).deckUpdatePromptTitle),
              findsNothing,
            );
            expect(state.deckById('es-en-grammar-present-ar'), isNotNull);
          }
        },
      );
    });
  });

  group('downloads', () {
    late FakeDeckRemote remote;
    late MemoryDownloadedDecks phone;
    late DateTime now;
    late int reloads;

    DeckDownloads downloads() =>
        DeckDownloads(fetcher: remote, files: phone, clock: () => now)
          ..onFilesChanged = () async => reloads++;

    const english = <String>['en'];

    setUp(() {
      remote = FakeDeckRemote(repoFiles(const <String>['hi', 'es']));
      phone = MemoryDownloadedDecks();
      now = DateTime(2026, 10, 9, 9);
      reloads = 0;
    });

    group('a language', () {
      test('is ready once its first decks are in, and downloads the rest '
          'behind it', () async {
        final d = downloads();
        await d.open();
        expect(d.isReady('hi', english), isFalse);
        expect(await d.downloadFirst('hi', english), isNull);
        expect(d.isReady('hi', english), isTrue);
        final hi = d.index!.language('hi')!;
        expect(
          phone.files.keys.toSet(),
          hi.firstFiles(english).map((f) => f.path).toSet(),
        );
        expect(d.missing('hi', english), isNotEmpty);
        expect(d.stateOf('hi', english), LanguageDownloadState.partial);
        expect(remote.asked.first, 'decks/index.json');
        expect(reloads, 1);

        {
          final d = downloads();
          await d.open();
          expect(await d.download('hi', english), isNull);
          expect(await d.downloadRest('hi', english), isNull);
          final hi = d.index!.language('hi')!;
          expect(
            phone.files.keys.toSet(),
            hi.filesFor(english).map((f) => f.path).toSet(),
          );
          expect(d.missing('hi', english), isEmpty);
          expect(d.stateOf('hi', english), LanguageDownloadState.upToDate);
          // What came down reads as the bundled decks did.
          final catalog = DeckCatalog.parseAll(<String, String>{
            for (final path in await phone.list()) path: await phone.read(path),
          });
          expect(catalog.broken, isEmpty);
          expect(catalog.languages.single.code, 'hi');
        }
      });

      test(
        'with no network it says so, keeps nothing, and tries again',
        () async {
          remote.failAll = FetchFailure.offline;
          final d = downloads();
          await d.open();
          expect(
            await d.downloadFirst('hi', english),
            DeckDownloadFailure.offline,
          );
          expect(d.indexStatus, IndexStatus.failed);
          expect(d.indexFailure, DeckDownloadFailure.offline);
          expect(phone.files, isEmpty);
          remote.failAll = null;
          expect(await d.downloadFirst('hi', english), isNull);
          expect(d.isReady('hi', english), isTrue);
        },
      );

      test(
        'says when GitHub limits it, keeping nothing of the batch',
        () async {
          remote.failAfter = 3;
          remote.failAfterWith = FetchFailure.rateLimited;
          final d = downloads();
          await d.open();
          expect(
            await d.downloadFirst('hi', english),
            DeckDownloadFailure.rateLimited,
          );
          expect(d.failureOf('hi'), DeckDownloadFailure.rateLimited);
          expect(d.stateOf('hi', english), LanguageDownloadState.failed);
          expect(phone.files, isEmpty);
        },
      );

      test('a download cut short keeps the decks that came whole', () async {
        final d = downloads();
        await d.open();
        await d.downloadFirst('hi', english);
        final first = phone.files.length;
        // Cut short a few files before the end: the layers of the rest come
        // before their cores in the index, so decks are whole only near it.
        remote.failAfter =
            remote.asked.length + d.missing('hi', english).length - 5;
        expect(
          await d.downloadRest('hi', english),
          DeckDownloadFailure.offline,
        );
        expect(phone.files.length, greaterThan(first));
        expect(d.missing('hi', english), isNotEmpty);
        // Read as the app would, what is in is whole.
        final catalog = DeckCatalog.parseAll(<String, String>{
          for (final path in await phone.list()) path: await phone.read(path),
        });
        expect(catalog.broken, isEmpty);
        // The next launch finishes it.
        remote.failAfter = null;
        await d.resume(const <String>['hi'], english);
        expect(d.missing('hi', english), isEmpty);
      });

      test('throws away a file that does not match its hash', () async {
        final path = remote.files.keys.firstWhere(
          (p) => p.endsWith('hi-path.yaml'),
        );
        remote.served[path] = remote.files[path]!.substring(0, 100);
        final d = downloads();
        await d.open();
        expect(
          await d.downloadFirst('hi', english),
          DeckDownloadFailure.badFile,
        );
        expect(phone.files, isEmpty);
        // The index was read again once, in case it was old, and no more.
        expect(
          remote.asked.where((p) => p == 'decks/index.json'),
          hasLength(2),
        );
      });
    });

    group('updates', () {
      Future<DeckDownloads> withEs() async {
        final d = downloads();
        await d.open();
        await d.download('es', english);
        await d.downloadRest('es', english);
        return d;
      }

      const deck = 'decks/es/en/es-en-core-100.yaml';

      test('an update replaces the files and keeps every card id; one that '
          'fails its check leaves the decks as they were', () async {
        final d = await withEs();
        final before = DeckCatalog.parseAll(<String, String>{
          for (final path in await phone.list()) path: await phone.read(path),
        });
        remote.files[deck] = '${remote.files[deck]!}# a fix\n';
        await d.checkForUpdates(english, force: true);
        reloads = 0;
        expect(await d.update(), isNull);
        expect(await phone.read(deck), endsWith('# a fix\n'));
        expect(d.updates, isEmpty);
        expect(d.stateOf('es', english), LanguageDownloadState.upToDate);
        expect(reloads, 1);
        final after = DeckCatalog.parseAll(<String, String>{
          for (final path in await phone.list()) path: await phone.read(path),
        });
        expect(
          after.decks.expand((e) => e.cards).map((c) => c.id).toSet(),
          before.decks.expand((e) => e.cards).map((c) => c.id).toSet(),
        );

        {
          final d = await withEs();
          final was = await phone.read(deck);
          remote.files[deck] = 'schema: 1\nid: es-en-core-100\n';
          await d.checkForUpdates(english, force: true);
          expect(await d.update(), DeckDownloadFailure.invalid);
          expect(await phone.read(deck), was);
          expect(d.updates, isNotEmpty);
        }
      });

      group('and proposals (#444)', () {
        // A reviewer's proposal is written into the deck file, so it changes
        // the file's sha256, but a learner never sees it.
        const field = '    native: "the man"';

        test('a proposal alone is no update for a learner, but is for a '
            'reviewer', () async {
          final d = await withEs();
          final was = await phone.read(deck);
          final original = remote.files[deck]!;
          remote.files[deck] = withProposal(original, field);
          await d.checkForUpdates(english, force: true);
          expect(d.updates, isEmpty);
          expect(d.askToUpdate, isFalse);
          expect(d.stateOf('es', english), LanguageDownloadState.upToDate);
          expect(await phone.read(deck), was);

          {
            final d = await withEs();
            d.reviewer = true;
            final base = original;
            remote.files[deck] = withProposal(base, field);
            await d.checkForUpdates(english, force: true);
            expect(d.updates['es']!.fetch.single.path, deck);
            expect(d.askToUpdate, isTrue);
            expect(await d.update(), isNull);
            expect(await phone.read(deck), remote.files[deck]);
            // Turned off, a further proposal no longer is.
            d.reviewer = false;
            remote.files[deck] = withProposal(base, field, to: 'other');
            await d.checkForUpdates(english, force: true);
            expect(d.updates, isEmpty);
          }
        });
      });
    });

    group('an index read before a file changed on GitHub', () {
      const path = 'decks/hi/hi-path.yaml';

      test('is read again, and the download goes on', () async {
        final d = downloads();
        await d.open();
        await d.download('es', english);
        // A day later, main has moved; the index kept has not.
        remote.files[path] = '${remote.files[path]!}# a fix\n';
        final again = downloads();
        await again.open();
        expect(await again.downloadFirst('hi', english), isNull);
        expect(await phone.read(path), endsWith('# a fix\n'));
        expect(again.failureOf('hi'), isNull);
      });
    });

    group('cancel', () {
      test('a cancel keeps the decks that came whole and stops the rest; the '
          'state survives a restart', () async {
        final d0 = downloads();
        await d0.open();
        await d0.downloadFirst('hi', english);
        final first = phone.files.length;
        late DeckDownloads d;
        d = DeckDownloads(
          fetcher: _CallAfter(remote, 12, () => d.cancel('hi')),
          files: phone,
          clock: () => now,
        );
        await d.open();
        expect(await d.downloadRest('hi', english), isNull);
        expect(d.isPaused('hi'), isTrue);
        expect(phone.files.length, greaterThan(first));
        expect(d.missing('hi', english), isNotEmpty);
        expect(d.stateOf('hi', english), LanguageDownloadState.partial);
        final catalog = DeckCatalog.parseAll(<String, String>{
          for (final path in await phone.list()) path: await phone.read(path),
        });
        expect(catalog.broken, isEmpty, reason: 'only whole decks are kept');

        // Launching again does not resume it: the rest waits on Settings.
        final again = downloads();
        await again.open();
        expect(again.isPaused('hi'), isTrue);
        remote.asked.clear();
        await again.resume(const <String>['hi'], english);
        expect(remote.asked.where((p) => p.startsWith('decks/hi/')), isEmpty);

        // Its card in Languages I'm learning asks for the rest.
        expect(await again.retry('hi', english), isNull);
        expect(again.isPaused('hi'), isFalse);
        expect(again.missing('hi', english), isEmpty);

        {
          final d = downloads();
          await d.open();
          await d.download('es', english);
          await d.downloadRest('es', english);
          final again = downloads();
          await again.open();
          expect(again.checkedAt, now);
          expect(again.stateOf('es', english), LanguageDownloadState.upToDate);
          expect(again.index!.language('es'), isNotNull);
        }
      });
    });

    group('files download in parallel', () {
      /// Updates 20 files of each of [codes] at once, through a fetcher that
      /// counts the requests in flight, by language.
      Future<_Traffic> updateTogether(List<String> codes) async {
        final d = downloads();
        await d.open();
        for (final code in codes) {
          await d.download(code, english);
          await d.downloadRest(code, english);
        }
        for (final code in codes) {
          for (final path
              in (phone.files.keys.toList()..sort())
                  .where((p) => p.startsWith('decks/$code/'))
                  .take(20)) {
            remote.files[path] = '${remote.files[path]!}# a fix\n';
          }
        }
        await d.checkForUpdates(english, force: true);
        final traffic = _Traffic(remote, <String, int>{
          for (final code in codes) code: d.updates[code]!.fetch.length,
        });
        final slow = DeckDownloads(
          fetcher: traffic,
          files: phone,
          clock: () => now,
        );
        await slow.open();
        await slow.checkForUpdates(english, force: true);
        expect(await slow.update(), isNull);
        expect(slow.updates, isEmpty);
        for (final path in remote.files.keys) {
          if (phone.files.containsKey(path)) {
            expect(await phone.read(path), remote.files[path], reason: path);
          }
        }
        return traffic;
      }

      test('a language has several in flight, within the bound', () async {
        final traffic = await updateTogether(<String>['es']);
        expect(traffic.peak, greaterThan(1));
        expect(
          traffic.peak,
          lessThanOrEqualTo(DeckDownloads.maxConcurrentFetches),
        );
      });

      test('two languages are in flight together, neither over its '
          'share', () async {
        final traffic = await updateTogether(<String>['es', 'hi']);
        expect(
          traffic.peak,
          lessThanOrEqualTo(DeckDownloads.maxConcurrentFetches),
        );
        expect(traffic.bothInFlight, isTrue);
        expect(traffic.unfair, isEmpty);
      });
    });
  });

  group('fetching from GitHub', () {
    Future<(Fetched, FakeHttpClient)> fetch(
      Future<(int, List<int>)> Function() reply, {
      int? claims,
      bool compressed = false,
    }) async {
      final client = FakeHttpClient(reply)
        ..contentLength = claims
        ..compressed = compressed;
      final fetcher = GitHubDeckFetcher(
        userAgent: 'fluenough/test',
        retryDelays: const <Duration>[],
      );
      final fetched = await withFakeClient(client, () async {
        final fetched = await fetcher.fetch('decks/hi/hi-path.yaml');
        fetcher.close();
        return fetched;
      });
      return (fetched, client);
    }

    test('downloads a file from main, and says why when GitHub limits it, '
        'the file is gone, or there is no network', () async {
      final (fetched, client) = await fetch(
        () async => (200, utf8.encode('kind: path\n')),
      );
      expect(utf8.decode(fetched.bytes!), 'kind: path\n');
      expect(
        client.asked.toString(),
        'https://raw.githubusercontent.com/aaronified/fluenough/main/'
        'decks/hi/hi-path.yaml',
      );
      expect(client.sent[HttpHeaders.userAgentHeader], 'fluenough/test');
      expect(
        client.sent.keys,
        isNot(contains(HttpHeaders.authorizationHeader)),
      );
      expect(client.closed, isTrue);

      for (final status in <int>[403, 429]) {
        final (fetched, _) = await fetch(() async => (status, <int>[]));
        expect(fetched.failure, FetchFailure.rateLimited, reason: '$status');
      }

      final (gone, _) = await fetch(() async => (404, <int>[]));
      expect(gone.failure, FetchFailure.notFound);

      final (offline, offlineClient) = await fetch(
        () async => throw const SocketException('Failed host lookup'),
      );
      expect(offline.failure, FetchFailure.offline);
      expect(offlineClient.closed, isTrue);
    });

    test('refuses a file too large to be a deck', () async {
      final small = GitHubDeckFetcher(userAgent: 'fluenough/test', maxBytes: 4);
      final client = FakeHttpClient(() async => (200, utf8.encode('12345')));
      final fetched = await withFakeClient(
        client,
        () => small.fetch('decks/hi/hi-path.yaml'),
      );
      expect(fetched.failure, FetchFailure.badReply);
    });

    test('tries a dropped connection again, up to four times, but not a '
        'file that is gone', () async {
      Future<(Fetched, int)> fetchWith(
        Future<(int, List<int>)> Function(int attempt) reply,
      ) async {
        var attempts = 0;
        final client = FakeHttpClient(() => reply(++attempts));
        final fetcher = GitHubDeckFetcher(
          userAgent: 'fluenough/test',
          retryDelays: const <Duration>[
            Duration.zero,
            Duration.zero,
            Duration.zero,
          ],
        );
        final fetched = await withFakeClient(
          client,
          () => fetcher.fetch('decks/hi/hi-path.yaml'),
        );
        return (fetched, attempts);
      }

      final (arrived, tries) = await fetchWith(
        (n) async => n <= 2
            ? throw const SocketException('Connection reset')
            : (200, utf8.encode('kind: path\n')),
      );
      expect(utf8.decode(arrived.bytes!), 'kind: path\n');
      expect(tries, 3);

      final (dropped, droppedTries) = await fetchWith(
        (_) async => throw const SocketException('Connection reset'),
      );
      expect(dropped.failure, FetchFailure.offline);
      expect(dropped.cause, 'SocketException');
      expect(droppedTries, 4);

      final (gone, goneTries) = await fetchWith((_) async => (404, <int>[]));
      expect(gone.failure, FetchFailure.notFound);
      expect(goneTries, 1);
    });
  });

  group('the index', () {
    group('parsing', () {
      test('refuses a path outside a language folder, and a bad hash', () {
        for (final path in <String>[
          'decks/zz/../../evil.yaml',
          '/etc/passwd',
          'decks/zz/a.json',
          'decks/zz/en/fr/a.yaml',
          'decks/themes.yaml',
        ]) {
          expect(
            () => DeckIndex.parse(_index(<Map<String, Object?>>[_file(path)])),
            throwsFormatException,
            reason: path,
          );
        }

        expect(
          () => DeckIndex.parse(
            _index(<Map<String, Object?>>[
              _file('decks/zz/zz-en-a.yaml', sha: 'nothex'),
            ]),
          ),
          throwsFormatException,
        );
      });

      test('asks for an app update for a newer index', () {
        expect(
          () => DeckIndex.parse(
            _index(const <Map<String, Object?>>[], version: 2),
          ),
          throwsA(isA<IndexTooNewException>()),
        );
      });
    });

    group('changes', () {
      final old = 'b' * 64;
      final wanted = <IndexFile>[
        _phone('decks/zz/zz-path.yaml', kind: 'path'),
        _phone('decks/zz/zz-a.yaml', deck: 'zz-a', core: true),
        _phone(
          'decks/zz/en/zz-en-a.yaml',
          native: 'en',
          deck: 'zz-a',
          kind: 'layer',
        ),
      ];

      test('an update fetches new and changed files only, and keeps a deck '
          'GitHub no longer lists', () {
        final changes = changesFor('zz', wanted, <String, IndexFile>{
          'decks/zz/zz-path.yaml': _phone(
            'decks/zz/zz-path.yaml',
            kind: 'path',
          ),
          'decks/zz/zz-a.yaml': _phone(
            'decks/zz/zz-a.yaml',
            deck: 'zz-a',
            core: true,
            sha: old,
          ),
        });
        expect(changes.fetch.map((f) => f.path), <String>[
          'decks/zz/zz-a.yaml',
          'decks/zz/en/zz-en-a.yaml',
        ]);
        expect(changes.remove, isEmpty);
        expect(changes.bytes, 20);

        {
          final changes = changesFor('zz', wanted, <String, IndexFile>{
            'decks/zz/zz-en-gone.yaml': _phone(
              'decks/zz/zz-en-gone.yaml',
              native: 'en',
              deck: 'zz-gone',
            ),
          });
          expect(changes.remove, isEmpty);
        }
      });
    });
  });

  group('the files on the phone', () {
    late Directory dir;
    late FileDownloadedDecks store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('fluenough-downloads');
      store = FileDownloadedDecks(Directory('${dir.path}/downloaded'));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('a download cut short leaves no file in use', () async {
      // What a crash mid-write leaves: the file written beside its place.
      final part = File('${dir.path}/downloaded/decks/hi/hi-en-a.yaml.part')
        ..createSync(recursive: true)
        ..writeAsStringSync('half a fi');
      expect(await store.list(), isEmpty);
      await store.clean();
      expect(part.existsSync(), isFalse);
    });
  });

  group('script fonts', () {
    late FakeDeckRemote remote;
    late MemoryDownloadedDecks phone;
    late Map<String, Uint8List> registered;
    late DateTime now;
    const english = <String>['en'];

    DeckDownloads downloads() => DeckDownloads(
      fetcher: remote,
      files: phone,
      clock: () => now,
      scriptFonts: ScriptFonts(
        register: (family, bytes) async => registered[family] = bytes,
      ),
    );

    /// The remote serving [fonts] for each language, and the font files.
    void serve(Map<String, List<String>> fonts) {
      remote.index = _withFonts(indexFor(remote.files), fonts);
      remote.served.addAll(_bytes);
    }

    setUp(() {
      remote = FakeDeckRemote(repoFiles(const <String>['hi', 'mr']));
      phone = MemoryDownloadedDecks();
      registered = <String, Uint8List>{};
      now = DateTime(2026, 10, 19, 9);
    });

    group('downloading a course', () {
      test('brings its font, checked and kept beside the decks, and loads '
          'it', () async {
        serve(<String, List<String>>{
          'hi': <String>[_devanagari, _nastaliq],
          'mr': <String>[_devanagari],
        });
        final d = downloads();
        await d.open();
        final scripts = <String>[];
        d.addListener(() {
          if (d.fontDownloading('hi') case final script?) scripts.add(script);
        });
        expect(await d.downloadFirst('hi', english), isNull);
        expect(phone.fontFiles.keys.toSet(), <String>{_devanagari, _nastaliq});
        expect(utf8.decode(phone.fontFiles[_devanagari]!), 'devanagari font');
        // Not among the language's deck files, which the old app reads.
        expect(phone.files.keys.where((p) => p.contains('/fonts/')), isEmpty);
        expect(registered.keys.toSet(), <String>{
          'FluenoughScript-devanagari',
          'FluenoughScript-perso_arabic',
        });
        expect(d.fonts.familyFor('devanagari'), 'FluenoughScript-devanagari');
        // The downloads said a font was coming, then stopped saying it.
        expect(scripts, contains('devanagari'));
        expect(d.fontDownloading('hi'), isNull);
        expect(d.stateOf('hi', english), LanguageDownloadState.partial);
      });

      test('a font that does not match the index is thrown away and fails '
          'the download', () async {
        serve(<String, List<String>>{
          'hi': <String>[_devanagari],
        });
        remote.served[_devanagari] = 'something else';
        final d = downloads();
        await d.open();
        expect(
          await d.downloadFirst('hi', english),
          DeckDownloadFailure.badFile,
        );
        expect(phone.fontFiles, isEmpty);
        expect(registered, isEmpty);
        expect(d.fonts.familyFor('devanagari'), isNull);
      });
    });
  });

  group('a downloaded font', () {
    testWidgets('TargetText draws a script in its font once it is loaded', (
      tester,
    ) async {
      final fonts = ScriptFonts(register: (family, bytes) async {});
      await pumpScreen(
        tester,
        const Scaffold(body: TargetText.hero('తెలుగు', language: telugu)),
        state: _app(fonts),
      );
      // No font yet: the phone's own.
      expect(_styleOf(tester, 'తెలుగు').fontFamily, isNull);
      expect(_styleOf(tester, 'తెలుగు').fontVariations, isNull);

      await fonts.load(_font, Uint8List(1));
      await tester.pump();
      final style = _styleOf(tester, 'తెలుగు');
      expect(style.fontFamily, 'FluenoughScript-telugu');
      expect(style.fontVariations, <FontVariation>[
        const FontVariation.weight(600),
      ]);
      // The weight is the font's axis alone, with no synthetic bold on top.
      expect(style.fontWeight, FontWeight.normal);
    });
  });

  group('added decks', () {
    testWidgets(
      'an added deck joins the bottom of its unit; a file that is not a '
      'deck is refused, saying why',
      (tester) async {
        final state = AppState.test();
        await state.load();
        final text = await template();

        final check = state.checkDeck(text, 'my-words.yaml');
        expect(check, isA<DeckAccepted>());
        check as DeckAccepted;
        expect(check.deck.id, 'hi-en-my-words');
        expect(check.cardCount, 3);
        expect(check.replaces, isFalse);

        await state.addDeck(check.deck, text);
        final added = state.deckById('hi-en-my-words')!;
        expect(added.bundled, isFalse);
        expect(added.cards.map((c) => c.id), [
          'hi-my-0001',
          'hi-my-0002',
          'hi-0231',
        ]);
        final path = state.pathOf(added)!;
        final unit = path.units[path.unitOf('hi-en-market')!];
        expect(unit.last, 'hi-en-my-words');
        final order = state.decks.map((e) => e.id).toList();
        expect(
          order.indexOf('hi-en-my-words'),
          order.indexOf(unit[unit.length - 2]) + 1,
        );

        {
          final state = AppState.test();
          await state.load();
          final text = await template();

          expect(
            state.checkDeck('schema: 1\nkind: path\n', 'x.yaml'),
            isA<DeckUnreadable>(),
          );
          expect(
            state.checkDeck(
              text.replaceFirst('id: hi-en-my-words', 'id: hi-en-market'),
              'x.yaml',
            ),
            isA<DeckIdBundled>().having(
              (c) => c.deckId,
              'deckId',
              'hi-en-market',
            ),
          );
          expect(
            state.checkDeck(
              text.replaceFirst('id: hi-my-0002', 'id: hi-0232'),
              'x.yaml',
            ),
            isA<DeckCardTaken>().having((c) => c.cardId, 'cardId', 'hi-0232'),
          );

          // A deck added before is replaced, and so may keep its own cards.
          await state.addDeck(
            (state.checkDeck(text, 'x.yaml') as DeckAccepted).deck,
            text,
          );
          expect(
            state.checkDeck(text, 'x.yaml'),
            isA<DeckAccepted>().having((c) => c.replaces, 'replaces', isTrue),
          );
        }
      },
    );
  });

  group('the way out to an app update', () {
    late FakeDeckRemote remote;

    setUp(() {
      remote = FakeDeckRemote(repoFiles(const <String>['es', 'hi']));
    });

    group('"Getting your decks", failed', () {
      testWidgets('once Try again has failed twice, suggests updating the app; a '
          'language that downloads starts the count again', (tester) async {
        remote.failAll = FetchFailure.offline;
        await _pump(
          tester,
          _escapeApp(
            remote: remote,
            release: FixedReleaseCheck(const LatestRelease(AppInfo.version)),
            learning: const <String>['es'],
          ),
        );
        final l10n = l10nOf(tester);
        await _tap(tester, find.text(l10n.commonRetry));
        expect(find.text(l10n.downloadsKeepsFailing), findsNothing);
        expect(find.text(l10n.downloadsReportProblem), findsNothing);
        await _tap(tester, find.text(l10n.commonRetry));
        expect(find.text(l10n.downloadsKeepsFailing), findsOneWidget);
        expect(find.text(l10n.downloadsReportProblem), findsOneWidget);
        expect(_check(l10n), findsOneWidget);

        // The report is the bug icon's.
        await _tap(tester, find.text(l10n.downloadsReportProblem));
        expect(find.byType(ReportPage), findsOneWidget);

        {
          // The page itself, as when languages are added: as the app's home it
          // is rebuilt for each language still missing.
          remote.failAll = FetchFailure.offline;
          usePhone(tester);
          await pumpScreen(
            tester,
            DownloadPage(languages: const <String>['es', 'hi'], onReady: () {}),
            state: _escapeApp(
              remote: remote,
              release: FixedReleaseCheck(const LatestRelease(AppInfo.version)),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = l10nOf(tester);
          expect(
            find.byKey(const ValueKey<String>('failure-es')),
            findsOneWidget,
          );
          await _tap(tester, find.text(l10n.commonRetry));
          expect(
            find.byKey(const ValueKey<String>('failure-es')),
            findsOneWidget,
          );

          remote.failAll = null;
          for (final path in remote.files.keys) {
            if (path.startsWith('decks/hi/')) {
              remote.failures[path] = FetchFailure.offline;
            }
          }
          await _tap(tester, find.text(l10n.commonRetry));
          expect(
            find.byKey(const ValueKey<String>('failure-hi')),
            findsOneWidget,
          );
          expect(find.text(l10n.downloadsKeepsFailing), findsNothing);
          expect(find.text(l10n.downloadsReportProblem), findsNothing);
          expect(_check(l10n), findsOneWidget);
        }
      });
    });
  });
}

/// [inner], slowed, counting the requests in flight and noting when one
/// language has more than its share while another still has files to start.
class _Traffic implements DeckFetcher {
  _Traffic(this.inner, this.totals) : _started = <String, int>{};

  final DeckFetcher inner;

  /// How many files each language is to fetch.
  final Map<String, int> totals;
  final Map<String, int> _started;
  final Map<String, int> _inFlight = <String, int>{};
  int _starts = 0;

  int peak = 0;
  bool bothInFlight = false;
  final List<String> unfair = <String>[];

  @override
  Future<Fetched> fetch(String path) async {
    if (path == 'decks/index.json') return inner.fetch(path);
    final code = path.split('/')[1];
    _inFlight[code] = (_inFlight[code] ?? 0) + 1;
    _started[code] = (_started[code] ?? 0) + 1;
    final total = _inFlight.values.fold(0, (a, b) => a + b);
    if (total > peak) peak = total;
    if (_inFlight.values.where((n) => n > 0).length > 1) bothInFlight = true;
    // Once the first slots are filled, while every language still has
    // files to start, none has more than its share in flight.
    if (++_starts > DeckDownloads.maxConcurrentFetches &&
        totals.entries.every((e) => (_started[e.key] ?? 0) < e.value)) {
      final share = DeckDownloads.maxConcurrentFetches ~/ totals.length;
      for (final language in totals.keys) {
        final n = _inFlight[language] ?? 0;
        if (n > share) unfair.add('$language has $n');
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final result = await inner.fetch(path);
    _inFlight[code] = _inFlight[code]! - 1;
    return result;
  }
}
