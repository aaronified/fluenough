// A language or deck that needs a newer app than the one installed
// (`min_app` in the deck index, ADR-0052): it is not downloaded, and the
// app says "Needs app X" with a way to the newest release. At or above the
// version, and for an index without the field, everything is as before.

import 'dart:convert';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/app_version.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/features/downloads/deck_update_controls.dart';
import 'package:fluenough/features/languages/add_language_page.dart';
import 'package:fluenough/features/languages/language_skills_sheet.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';
import 'support/harness.dart';
import 'support/picker.dart';

const String _sha =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/// An index of one language, `zz`, with a deck of a core and a layer, a
/// single-file deck and a recording, each file with its `min_app` where
/// [needs] names one by path; [language] is the language's own.
String _index({String? language, Map<String, String> needs = const {}}) {
  Map<String, Object?> file(
    String path, {
    String? native,
    String? deck,
    String kind = 'vocab',
    bool core = false,
  }) => <String, Object?>{
    'path': path,
    'size': 10,
    'sha256': _sha,
    'schema': 1,
    'kind': kind,
    'native': ?native,
    'deck': ?deck,
    if (core) 'part': 'core',
    'min_app': ?needs[path],
  };
  return jsonEncode(<String, Object?>{
    'version': 1,
    'languages': <Object?>[
      <String, Object?>{
        'code': 'zz',
        'name': 'Testlang',
        'natives': <Object?>[
          <String, String>{'code': 'en', 'name': 'English'},
        ],
        'path': <String>['zz-a', 'zz-b'],
        'min_app': ?language,
        'files': <Object?>[
          file('decks/zz/zz-path.yaml', kind: 'path'),
          file('decks/zz/zz-a.yaml', deck: 'zz-a', core: true),
          file('decks/zz/en/zz-en-a.yaml', native: 'en', deck: 'zz-a'),
          file('decks/zz/zz-en-b.yaml', native: 'en', deck: 'zz-b'),
        ],
        'media': <Object?>[
          <String, Object?>{
            'path': 'decks/zz/audio/zz-0001.opus',
            'size': 5,
            'sha256': _sha,
            'kind': 'audio',
          },
        ],
      },
    ],
  });
}

/// [index], a real index of the repository's decks, with `min_app` set on
/// the languages and files named.
String _withMinApp(
  String index, {
  Map<String, String> languages = const {},
  Map<String, String> files = const {},
}) {
  final json = jsonDecode(index) as Map<String, Object?>;
  for (final language in json['languages']! as List<Object?>) {
    final map = language! as Map<String, Object?>;
    if (languages[map['code']] case final version?) map['min_app'] = version;
    for (final file in map['files']! as List<Object?>) {
      final entry = file! as Map<String, Object?>;
      if (files[entry['path']] case final version?) {
        entry['min_app'] = version;
      }
    }
  }
  return jsonEncode(json);
}

Set<String> _paths(List<IndexFile> files) => <String>{
  for (final f in files) f.path,
};

void main() {
  group('app versions', () {
    test('compare as three numbers, not as text', () {
      expect(compareAppVersions('0.7.0', '0.7.1'), lessThan(0));
      expect(compareAppVersions('0.7.1', '0.7.1'), 0);
      expect(compareAppVersions('0.10.0', '0.9.9'), greaterThan(0));
      expect(compareAppVersions('1.0.0', '0.99.99'), greaterThan(0));
      expect(compareAppVersions('0.7', '0.7.1'), isNull);
    });

    test('a missing or malformed minimum asks for nothing', () {
      expect(appIsOlderThan('0.7.0', null), isFalse);
      expect(appIsOlderThan('0.7.0', 'soon'), isFalse);
      expect(appIsOlderThan('0.7.0', '0.7.1'), isTrue);
      expect(appIsOlderThan('0.7.1', '0.7.1'), isFalse);
      // An app version nobody can read is taken as new enough.
      expect(appIsOlderThan('dev', '0.7.1'), isFalse);
    });
  });

  group('reading the index', () {
    const english = <String>['en'];

    test('an app older than a language does not take its files, and says '
        'the version', () {
      final index = DeckIndex.parse(
        _index(language: '0.7.1'),
        appVersion: '0.7.0',
      );
      final zz = index.language('zz')!;
      expect(zz.appTooOld, isTrue);
      expect(zz.minApp, '0.7.1');
      expect(zz.filesFor(english), isEmpty);
      expect(zz.appNeededFor(english), '0.7.1');
    });

    test('an app at or above it reads the language as before', () {
      for (final version in <String>['0.7.1', '0.7.2', '1.0.0']) {
        final zz = DeckIndex.parse(
          _index(language: '0.7.1'),
          appVersion: version,
        ).language('zz')!;
        expect(zz.appTooOld, isFalse, reason: version);
        expect(zz.appNeededFor(english), isNull);
        expect(
          _paths(zz.filesFor(english)),
          _paths(DeckIndex.parse(_index()).language('zz')!.filesFor(english)),
        );
      }
    });

    test('one file that needs a newer app is left out, and the rest are '
        'read', () {
      final zz = DeckIndex.parse(
        _index(needs: <String, String>{'decks/zz/zz-en-b.yaml': '0.7.2'}),
        appVersion: '0.7.1',
      ).language('zz')!;
      expect(zz.appTooOld, isFalse);
      expect(
        _paths(zz.filesFor(english)),
        isNot(contains('decks/zz/zz-en-b.yaml')),
      );
      expect(
        _paths(zz.filesFor(english)),
        contains('decks/zz/en/zz-en-a.yaml'),
      );
      expect(zz.needingNewerApp(english).single.deck, 'zz-b');
      expect(zz.appNeededFor(english), '0.7.2');
    });

    test('a language gone past the file asks for the newer of the two', () {
      final zz = DeckIndex.parse(
        _index(
          language: '0.7.1',
          needs: <String, String>{'decks/zz/zz-en-b.yaml': '0.7.3'},
        ),
        appVersion: '0.7.0',
      ).language('zz')!;
      expect(zz.appNeededFor(english), '0.7.3');
    });

    test('the recordings of a language that needs a newer app are not '
        'taken either', () {
      final zz = DeckIndex.parse(
        _index(language: '0.7.1'),
        appVersion: '0.7.0',
      ).language('zz')!;
      expect(
        _paths(zz.filesFor(english)),
        isNot(contains(zz.media.single.path)),
      );
      final readable = DeckIndex.parse(
        _index(),
        appVersion: '0.7.0',
      ).language('zz')!;
      expect(
        _paths(readable.filesFor(english)),
        contains(readable.media.single.path),
      );
    });

    test('an index with no min_app reads exactly as it did', () {
      final plain = DeckIndex.parse(_index());
      final checked = DeckIndex.parse(_index(), appVersion: '0.7.0');
      expect(
        _paths(checked.language('zz')!.filesFor(english)),
        _paths(plain.language('zz')!.filesFor(english)),
      );
      expect(checked.language('zz')!.appTooOld, isFalse);
      expect(checked.language('zz')!.minApp, isNull);
      expect(checked.language('zz')!.appNeededFor(english), isNull);
      expect(
        checked
            .language('zz')!
            .files
            .every((f) => f.readable && f.minApp == null),
        isTrue,
      );
    });

    test('a value that is no version is ignored, never thrown at', () {
      for (final bad in <String>['soon', '0.7', 'v0.7.1', '']) {
        final zz = DeckIndex.parse(
          _index(
            language: bad,
            needs: <String, String>{'decks/zz/zz-en-b.yaml': bad},
          ),
          appVersion: '0.7.0',
        ).language('zz')!;
        expect(zz.appTooOld, isFalse, reason: bad);
        expect(zz.filesFor(english), hasLength(5), reason: bad);
      }
    });

    test('without the app version nothing is held back', () {
      final zz = DeckIndex.parse(_index(language: '9.9.9')).language('zz')!;
      expect(zz.appTooOld, isFalse);
      expect(zz.filesFor(english), hasLength(5));
    });
  });

  group('downloading', () {
    const english = <String>['en'];
    late FakeDeckRemote remote;
    late MemoryDownloadedDecks phone;

    DeckDownloads downloads(String appVersion) => DeckDownloads(
      fetcher: remote,
      files: phone,
      clock: () => DateTime(2026, 11, 1, 9),
      appVersion: appVersion,
    );

    setUp(() {
      remote = FakeDeckRemote(repoFiles(const <String>['hi', 'es']));
      phone = MemoryDownloadedDecks();
      remote.index = _withMinApp(
        indexFor(remote.files),
        languages: <String, String>{'hi': '0.7.1'},
      );
    });

    test('a language that needs a newer app is not downloaded, and the app '
        'says so', () async {
      final d = downloads('0.7.0');
      await d.open();
      expect(await d.download('hi', english), DeckDownloadFailure.appTooOld);
      expect(
        await d.downloadRest('hi', english),
        DeckDownloadFailure.appTooOld,
      );
      expect(phone.files, isEmpty);
      expect(d.isReady('hi', english), isFalse);
      expect(d.needsNewerApp('hi', english), isTrue);
      // The language beside it, with no min_app, downloads as before.
      expect(await d.downloadFirst('es', english), isNull);
      expect(d.isReady('es', english), isTrue);
      expect(d.needsNewerApp('es', english), isFalse);
    });

    test('at the version the language downloads as before', () async {
      final d = downloads('0.7.1');
      await d.open();
      expect(await d.downloadFirst('hi', english), isNull);
      expect(d.isReady('hi', english), isTrue);
      expect(phone.files, isNotEmpty);
      expect(d.needsNewerApp('hi', english), isFalse);
      expect(d.decksNeedingApp(english), 0);
    });

    test(
      'an index without the field is read as before, on any version',
      () async {
        remote.index = null;
        final d = downloads('0.7.0');
        await d.open();
        expect(await d.downloadFirst('hi', english), isNull);
        expect(d.isReady('hi', english), isTrue);
        expect(d.needsNewerApp('hi', english), isFalse);
      },
    );

    test('one new deck that needs a newer app is left, the others come, and '
        'it is counted', () async {
      final probe = DeckIndex.parse(remote.index!);
      final es = probe.language('es')!;
      final gated = es.files
          .where(
            (f) => f.deck != null && (f.native == null || f.native == 'en'),
          )
          .toList();
      final deck = gated.firstWhere((f) => !f.core).deck!;
      final wanted = <String, String>{
        for (final f in gated)
          if (f.deck == deck) f.path: '0.7.2',
      };
      remote.index = _withMinApp(indexFor(remote.files), files: wanted);
      final d = downloads('0.7.1');
      await d.open();
      expect(await d.downloadFirst('es', english), isNull);
      expect(await d.downloadRest('es', english), isNull);
      for (final path in wanted.keys) {
        expect(phone.files, isNot(contains(path)), reason: path);
      }
      expect(phone.files, isNotEmpty);
      expect(d.needsNewerApp('es', english), isTrue);
      expect(d.decksNeedingApp(english), 1);
      // The app that is new enough takes it.
      final newer = downloads('0.7.2');
      await newer.open();
      expect(await newer.downloadRest('es', english), isNull);
      expect(phone.files.keys, containsAll(wanted.keys));
      expect(newer.decksNeedingApp(english), 0);
    });
  });

  group('what the learner sees', () {
    late FakeDeckRemote remote;
    late FixedLinks links;

    Future<AppState> app(
      WidgetTester tester, {
      String version = '0.7.0',
    }) async {
      remote = FakeDeckRemote(repoFiles(const <String>['hi', 'es']));
      remote.index = _withMinApp(
        indexFor(remote.files),
        languages: <String, String>{'hi': '0.7.1'},
      );
      links = FixedLinks();
      final downloads = DeckDownloads(
        fetcher: remote,
        files: MemoryDownloadedDecks(),
        clock: () => DateTime(2026, 11, 1, 9),
        appVersion: version,
      );
      await downloads.open();
      await downloads.refreshIndex();
      return AppState.test(
        deckDownloads: downloads,
        links: links,
        settings: SettingsNotifier(spokenLanguages: const <String>['en']),
      );
    }

    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

    testWidgets('Add a language greys a language that needs a newer app, '
        'says which, and opens the release page', (tester) async {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        AddLanguagePage(spokenList: pickerSpokenList),
        state: await app(tester),
      );
      final text = l10n(tester);
      final hi = find.byKey(const ValueKey<String>('add-hi'));
      await tester.ensureVisible(hi);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: hi,
          matching: find.text(text.appUpdateNeeded('0.7.1')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hi, matching: find.text(text.appUpdateAction)),
        findsOneWidget,
      );
      // A language with no requirement shows none.
      // The list builds rows lazily, so scroll down to Spanish first.
      final es = find.byKey(const ValueKey<String>('add-es'));
      await tester.scrollUntilVisible(es, 200);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: es, matching: find.textContaining('Needs app')),
        findsNothing,
      );
      // Tapping the greyed row opens the page, not the skills sheet.
      await tester.scrollUntilVisible(hi, -200);
      await tester.pumpAndSettle();
      await tester.tap(hi);
      await tester.pumpAndSettle();
      expect(links.asked, <String>[AppLinks.latestRelease]);
      expect(find.byType(LanguageSkillsSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an app new enough shows no such row', (tester) async {
      usePhone(tester, textScale: 1.4);
      await pumpScreen(
        tester,
        AddLanguagePage(spokenList: pickerSpokenList),
        state: await app(tester, version: '0.7.1'),
      );
      expect(find.textContaining('Needs app'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the deck updates say how many new decks need an app '
        'update, and Update opens the release page', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await app(tester);
      final downloads = state.deckDownloads!;
      final waiting = downloads.decksNeedingApp(const <String>['en']);
      expect(waiting, greaterThan(0));
      await pumpScreen(
        tester,
        Scaffold(body: DeckUpdateControls(downloads: downloads)),
        state: state,
      );
      expect(
        find.text(l10n(tester).appUpdateDecksNotice(waiting)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('app-update-notice')));
      await tester.pumpAndSettle();
      expect(links.asked, <String>[AppLinks.latestRelease]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no notice when no deck needs a newer app', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await app(tester, version: '0.7.1');
      await pumpScreen(
        tester,
        Scaffold(body: DeckUpdateControls(downloads: state.deckDownloads!)),
        state: state,
      );
      expect(
        find.byKey(const ValueKey<String>('app-update-notice')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
