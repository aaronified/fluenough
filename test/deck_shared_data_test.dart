// Deck-owned data (owner, 2026-11-11): the theme list, and any file that is
// entirely about the decks, downloads from decks-live with the decks, is
// checked before use, and falls back to the copy bundled in the app. Offline,
// a bad hash, a file the app cannot read and an app too old each leave the
// bundled copy in use and write a line to the log.

import 'dart:convert';

import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/shared_deck_source.dart';
import 'package:fluenough/core/data/themes.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/decks/shared_data.dart';
import 'package:fluenough/core/logs/log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';

const String _bundled = '''
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
''';

const String _live = '''
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: at-the-bank, name: "At the bank", tags: ["money"] }
''';

const String _newerSchema = '''
schema: 2
kind: themes
themes:
  - { id: first-words, name: "First words" }
''';

Map<String, Object?> _entry(
  String text, {
  String path = 'decks/themes.yaml',
  String? minApp,
  int schema = 1,
  String? sha,
  int? size,
}) {
  final bytes = utf8.encode(text);
  return <String, Object?>{
    'path': path,
    'size': size ?? bytes.length,
    'sha256': sha ?? sha256Hex(bytes),
    'schema': schema,
    'kind': 'themes',
    'min_app': ?minApp,
  };
}

String _index(List<Object?> shared) => jsonEncode(<String, Object?>{
  'version': 1,
  'schema': 1,
  'bundled': <String>['decks/themes.yaml'],
  'shared': shared,
  'languages': <Object?>[],
});

void main() {
  group('the index\'s shared list', () {
    test('lists the files the app reads, with their checks', () {
      final found = parseSharedFiles(<Object?>[_entry(_live)]);
      expect(found.problems, isEmpty);
      expect(found.files.single.path, 'decks/themes.yaml');
      expect(found.files.single.kind, 'themes');
      expect(found.files.single.unusableReason, isNull);
    });

    test('passes by a file only a later app reads, without a fault', () {
      final found = parseSharedFiles(<Object?>[
        _entry(_live, path: 'decks/tags.yaml'),
      ]);
      expect(found.files, isEmpty);
      expect(found.problems, isEmpty);
    });

    test('names what is wrong with a bad entry and keeps the rest', () {
      final found = parseSharedFiles(<Object?>[
        'not an object',
        <String, Object?>{'size': 1},
        _entry(_live, sha: 'nothex'),
        _entry(_live),
        _entry(_live),
      ]);
      expect(found.files, hasLength(1));
      expect(found.problems, hasLength(4));
    });

    test('is empty for no list, and a fault for one that is not a list', () {
      expect(parseSharedFiles(null).files, isEmpty);
      expect(parseSharedFiles(null).problems, isEmpty);
      expect(parseSharedFiles('x').problems, hasLength(1));
    });

    test('holds back a file that needs a newer app or a newer schema', () {
      final old = parseSharedFiles(<Object?>[
        _entry(_live, minApp: '0.9.5'),
      ], appVersion: '0.9.0').files.single;
      expect(old.appTooOld, isTrue);
      expect(old.unusableReason, contains('needs app 0.9.5'));
      final fine = parseSharedFiles(<Object?>[
        _entry(_live, minApp: '0.9.0'),
      ], appVersion: '0.9.0').files.single;
      expect(fine.unusableReason, isNull);
      final later = parseSharedFiles(<Object?>[_entry(_live, schema: 2)])
          .files
          .single;
      expect(later.unusableReason, contains('schema 2'));
    });

    test('refuses a file over the size limit', () {
      final big = parseSharedFiles(<Object?>[
        _entry(_live, size: maxSharedFileBytes + 1),
      ]).files.single;
      expect(big.unusableReason, contains('over the'));
    });

    test('the index carries it, and an index without it has none', () {
      final index = DeckIndex.parse(_index(<Object?>[_entry(_live)]));
      expect(index.shared.single.path, 'decks/themes.yaml');
      final plain = DeckIndex.parse(
        jsonEncode(<String, Object?>{'version': 1, 'languages': <Object?>[]}),
      );
      expect(plain.shared, isEmpty);
      expect(plain.sharedProblems, isEmpty);
    });

    test('a bad shared list never costs the index', () {
      final index = DeckIndex.parse(
        jsonEncode(<String, Object?>{
          'version': 1,
          'shared': 5,
          'languages': <Object?>[],
        }),
      );
      expect(index.shared, isEmpty);
      expect(index.sharedProblems, isNotEmpty);
    });
  });

  group('checking a shared file', () {
    test('accepts a themes file', () {
      expect(checkSharedText('decks/themes.yaml', _live), isNull);
    });

    test('says what is wrong with one it cannot read', () {
      expect(
        checkSharedText('decks/themes.yaml', 'not: a themes file'),
        isNotNull,
      );
      expect(checkSharedText('decks/themes.yaml', ': : :'), isNotNull);
      expect(
        checkSharedText('decks/themes.yaml', _newerSchema),
        contains('newer'),
      );
      expect(checkSharedText('decks/other.yaml', _live), isNotNull);
    });

    test('parses the themes it lists', () {
      final themes = parseThemes(_live);
      expect(themes.map((t) => t.id), <String>['first-words', 'at-the-bank']);
      expect(themes.last.tags, <String>['money']);
    });

    test('keeps a file under a name apart from the decks', () {
      expect(sharedNoteName('decks/themes.yaml'), 'shared-themes.yaml');
    });
  });

  group('downloading with the decks', () {
    late FakeDeckRemote remote;
    late MemoryDownloadedDecks phone;
    late AppLog log;
    late int changed;

    DeckDownloads downloads({String appVersion = '0.9.0'}) {
      final d = DeckDownloads(
        fetcher: remote,
        files: phone,
        clock: () => DateTime(2026, 11, 11),
        log: log,
        appVersion: appVersion,
      );
      d.onFilesChanged = () async => changed++;
      return d;
    }

    setUp(() {
      remote = FakeDeckRemote(<String, String>{'decks/themes.yaml': _live})
        ..index = _index(<Object?>[_entry(_live)]);
      phone = MemoryDownloadedDecks();
      log = AppLog(clock: () => DateTime.utc(2026, 11, 11));
      changed = 0;
    });

    bool logged(String part) => log.entries.any(
      (e) => e.level == LogLevel.warning && e.message.contains(part),
    );

    test('reading the index downloads, keeps and offers the file', () async {
      final d = downloads();
      expect(await d.refreshIndex(), isTrue);
      expect(d.sharedTexts['decks/themes.yaml'], _live);
      expect(phone.notes['shared-themes.yaml'], _live);
      expect(changed, 1);
    });

    test('asks again only when the index lists another hash', () async {
      final d = downloads();
      await d.refreshIndex();
      await d.refreshIndex();
      expect(remote.asked.where((p) => p == 'decks/themes.yaml'), hasLength(1));
      expect(changed, 1);
      final next = '$_live  - { id: more, name: "More" }\n';
      remote
        ..files['decks/themes.yaml'] = next
        ..index = _index(<Object?>[_entry(next)]);
      await d.refreshIndex();
      expect(d.sharedTexts['decks/themes.yaml'], next);
      expect(changed, 2);
    });

    test('a restart reads the kept file with no network', () async {
      await downloads().refreshIndex();
      remote.failAll = FetchFailure.offline;
      final again = downloads();
      await again.open();
      expect(again.sharedTexts['decks/themes.yaml'], _live);
    });

    test('offline, nothing is kept and the bundled copy stays', () async {
      remote.failAll = FetchFailure.offline;
      final d = downloads();
      expect(await d.refreshIndex(), isFalse);
      expect(d.sharedTexts, isEmpty);
      expect(changed, 0);
    });

    test(
      'a file whose hash is not the index\'s is thrown away and logged',
      () async {
        remote.served['decks/themes.yaml'] = _bundled;
        final d = downloads();
        expect(await d.refreshIndex(), isTrue);
        expect(d.sharedTexts, isEmpty);
        expect(phone.notes.containsKey('shared-themes.yaml'), isFalse);
        expect(logged('did not match the index'), isTrue);
      },
    );

    test('a file the app cannot read is not kept, and is logged', () async {
      const broken = 'schema: 1\nkind: themes\nthemes: []\n';
      remote
        ..files['decks/themes.yaml'] = broken
        ..index = _index(<Object?>[_entry(broken)]);
      final d = downloads();
      await d.refreshIndex();
      expect(d.sharedTexts, isEmpty);
      expect(phone.notes.containsKey('shared-themes.yaml'), isFalse);
      expect(logged('not used'), isTrue);
    });

    test('a file of a newer schema is left alone and logged', () async {
      remote
        ..files['decks/themes.yaml'] = _newerSchema
        ..index = _index(<Object?>[_entry(_newerSchema, schema: 2)]);
      final d = downloads();
      await d.refreshIndex();
      expect(d.sharedTexts, isEmpty);
      expect(remote.asked, isNot(contains('decks/themes.yaml')));
      expect(logged('schema 2'), isTrue);
    });

    test(
      'a file needing a newer app is not downloaded, and is logged',
      () async {
        remote.index = _index(<Object?>[_entry(_live, minApp: '0.9.5')]);
        final d = downloads();
        await d.refreshIndex();
        expect(d.sharedTexts, isEmpty);
        expect(remote.asked, isNot(contains('decks/themes.yaml')));
        expect(logged('needs app 0.9.5'), isTrue);
      },
    );

    test('an index that lists nothing shared changes nothing', () async {
      await downloads().refreshIndex();
      remote.index = _index(const <Object?>[]);
      final d = downloads();
      await d.open();
      await d.refreshIndex();
      expect(d.sharedTexts['decks/themes.yaml'], _live);
    });

    test(
      'a kept file the app can no longer read is ignored and logged',
      () async {
        phone.notes['shared-themes.yaml'] = 'garbage: [';
        final d = downloads();
        await d.open();
        expect(d.sharedTexts, isEmpty);
        expect(logged('bundled copy'), isTrue);
      },
    );

    test('a failure while keeping the file never escapes', () async {
      final failing = _FailingNotes();
      final d = DeckDownloads(
        fetcher: remote,
        files: failing,
        clock: () => DateTime(2026, 11, 11),
        log: log,
      );
      expect(await d.refreshIndex(), isTrue);
      expect(d.sharedTexts, isEmpty);
      expect(logged('failed'), isTrue);
    });
  });

  group('the catalog reads it before the bundled copy', () {
    Future<List<String>> themeIds(Map<String, String> shared) async {
      final catalog = DeckCatalog(
        DeckSources(<DeckSource>[
          SharedDeckSource(() => shared),
          MemoryDeckSource(<String, String>{'decks/themes.yaml': _bundled}),
        ]),
      );
      return (await catalog.load()).themes.map((t) => t.id).toList();
    }

    test('a downloaded theme list replaces the bundled one', () async {
      expect(
        await themeIds(<String, String>{'decks/themes.yaml': _live}),
        <String>['first-words', 'at-the-bank'],
      );
    });

    test('with none downloaded, the bundled list is used', () async {
      expect(await themeIds(const <String, String>{}), <String>['first-words']);
    });
  });
}

/// Notes that cannot be written: a full phone.
class _FailingNotes extends MemoryDownloadedDecks {
  @override
  Future<void> writeNote(String name, String text) async =>
      throw StateError('disk full');
}
