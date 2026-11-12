// The index's deck kinds (wiki/Plan-Deck-Kinds-And-Topics.md, D9, T12):
// `shelves` (decks with a genre, hidden ones too), a language's `topics`
// file and the top-level `shared_media`. A visible shelf downloads with the
// language; a hidden one only when a learner adds it, and only a hidden deck
// is ever fetched or removed that way. A bad entry costs itself; a release
// that reads `files` never sees any of it.

import 'dart:convert';
import 'dart:io';

import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/levels.dart';
import 'package:fluenough/core/logs/log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';

const String _root = 'test/fixtures/deck-kinds/';

/// The fixture language's files by path (`decks/zz/...`), those [only] names
/// when given, as the faked GitHub serves them.
Map<String, String> _files({Set<String>? only}) {
  final files = <String, String>{};
  for (final entity in Directory(
    '${_root}decks/zz',
  ).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.yaml')) continue;
    final path = entity.path.substring(_root.length);
    final name = path.split('/').last.replaceAll('.yaml', '');
    if (only != null && !only.contains(name)) continue;
    files[path] = entity.readAsStringSync();
  }
  return files;
}

const String _medicineCore = 'decks/zz/zz-medicine-registro.yaml';
const String _medicineLayer = 'decks/zz/en/zz-en-medicine-registro.yaml';
const String _cultureCore = 'decks/zz/zz-culture-ejemplo.yaml';
const String _cultureLayer = 'decks/zz/en/zz-en-culture-ejemplo.yaml';

/// What the downloads read: words, a visible culture deck and a hidden
/// professional deck, each a core and its English layer.
Set<String> get _decks => <String>{
  'zz-words',
  'zz-en-words',
  'zz-culture-ejemplo',
  'zz-en-culture-ejemplo',
  'zz-medicine-registro',
  'zz-en-medicine-registro',
};

IndexLanguage _zz(String text, {String? appVersion}) =>
    DeckIndex.parse(text, appVersion: appVersion).language('zz')!;

/// [text], an index, with [change] applied to its language's JSON.
String _edited(String text, void Function(Map<String, Object?> zz) change) {
  final json = jsonDecode(text) as Map<String, Object?>;
  change((json['languages'] as List<Object?>).single! as Map<String, Object?>);
  return jsonEncode(json);
}

void main() {
  final everything = indexFor(_files());

  group('reading the shelves', () {
    final zz = _zz(everything);

    test('lists every deck with a genre, hidden ones too', () {
      expect(zz.shelves.map((s) => s.file.path).toSet(), <String>{
        'decks/zz/en/zz-en-culture-ejemplo.yaml',
        'decks/zz/en/zz-en-medicine-registro.yaml',
        'decks/zz/en/zz-en-multiword-ejemplo.yaml',
        'decks/zz/en/zz-en-proverbs-ejemplo.yaml',
        'decks/zz/zz-culture-ejemplo.yaml',
        'decks/zz/zz-en-culture-lectura.yaml',
        'decks/zz/zz-medicine-registro.yaml',
        'decks/zz/zz-multiword-ejemplo.yaml',
        'decks/zz/zz-proverbs-ejemplo.yaml',
      });
    });

    test('keeps what search needs before the file is downloaded', () {
      final layer = zz.shelves.firstWhere(
        (s) => s.file.path == 'decks/zz/en/zz-en-culture-ejemplo.yaml',
      );
      expect(layer.genre, 'culture');
      expect(layer.level, Level.a2);
      expect(layer.hidden, isFalse);
      expect(layer.professional, isNull);
      expect(layer.section, 'beyond-basics');
      expect(layer.weave, isTrue);
      expect(layer.title, 'Culture: examples');
      expect(layer.cards, 3);
      expect(layer.coreId, 'zz-culture-ejemplo');
      expect(layer.deckKey, 'zz-culture-ejemplo');
      expect(layer.file.native, 'en');
      expect(layer.isCore, isFalse);
    });

    test('knows a core, which is never a deck of its own', () {
      final core = zz.shelves.firstWhere((s) => s.file.path == _cultureCore);
      expect(core.isCore, isTrue);
      expect(core.file.core, isTrue);
    });

    test('keeps a hidden professional deck\'s profession and level', () {
      final entry = zz.shelves.firstWhere((s) => s.file.path == _medicineLayer);
      expect(entry.hidden, isTrue);
      expect(entry.professional, 'medicine');
      expect(entry.level, Level.b1);
      expect(entry.section, 'professional');
      expect(entry.weave, isFalse);
    });

    test('counts the passages of a reading deck', () {
      final reading = zz.shelves.firstWhere(
        (s) => s.file.path == 'decks/zz/zz-en-culture-lectura.yaml',
      );
      expect(reading.file.kind, 'reading');
      expect(reading.cards, 1);
    });

    test(
      'lists a visible deck with the language\'s files, a hidden one not',
      () {
        final paths = zz.files.map((f) => f.path).toSet();
        expect(paths, contains(_cultureCore));
        expect(paths, contains(_cultureLayer));
        expect(paths, contains('decks/zz/zz-words.yaml'));
        expect(paths, isNot(contains(_medicineCore)));
        expect(paths, isNot(contains(_medicineLayer)));
      },
    );

    test(
      'counts the visible decks in the size, and the hidden ones in none',
      () {
        expect(zz.size, zz.files.fold<int>(0, (sum, f) => sum + f.size));
        final hidden = zz.shelves
            .where((s) => s.hidden)
            .fold<int>(0, (sum, s) => sum + s.file.size);
        expect(hidden, greaterThan(0));
      },
    );

    test('lists the topics file apart, and downloads it with the language', () {
      expect(zz.topics.map((f) => f.path), <String>['decks/zz/zz-topics.yaml']);
      expect(zz.topics.single.kind, 'topics');
      expect(zz.files.map((f) => f.path), contains(zz.topics.single.path));
      expect(zz.topics.single.isLanguageFile, isTrue);
    });

    test('is read from an index with none of the new keys, as before', () {
      final plain = _zz(
        indexFor(_files(only: <String>{'zz-words', 'zz-en-words'})),
      );
      expect(plain.shelves, isEmpty);
      expect(plain.topics, isEmpty);
      expect(plain.problems, isEmpty);
      expect(plain.hiddenDecksFor(<String>['en']), isEmpty);
    });

    test(
      'has no hidden deck in what a learner downloads with the language',
      () {
        final wanted = zz.filesFor(<String>['en']).map((f) => f.path).toSet();
        expect(wanted, contains(_cultureLayer));
        expect(wanted, isNot(contains(_medicineLayer)));
        final first = zz.firstFiles(<String>['en']).map((f) => f.path).toSet();
        expect(first, isNot(contains(_medicineLayer)));
      },
    );
  });

  group('the hidden decks', () {
    final zz = _zz(everything);

    test('are listed once each for a learner\'s native languages', () {
      final decks = zz.hiddenDecksFor(<String>['en']);
      expect(decks.map((s) => s.file.path), <String>[_medicineLayer]);
      expect(zz.hiddenDecksFor(<String>['bn']), isEmpty);
    });

    test('have a core and a layer to fetch', () {
      final files = zz.hiddenFilesFor('zz-medicine-registro', <String>['en']);
      expect(files.map((f) => f.path).toSet(), <String>{
        _medicineCore,
        _medicineLayer,
      });
    });

    test('have only the core when no layer is of a native language', () {
      final files = zz.hiddenFilesFor('zz-medicine-registro', <String>['bn']);
      expect(files.map((f) => f.path), <String>[_medicineCore]);
    });

    test('are never a visible deck\'s files', () {
      expect(zz.hiddenFilesFor('zz-culture-ejemplo', <String>['en']), isEmpty);
      expect(zz.hiddenFilesFor('zz-nada', <String>['en']), isEmpty);
    });
  });

  group('min_app', () {
    final gated = _edited(everything, (zz) {
      for (final key in <String>['shelves', 'topics']) {
        for (final entry in zz[key]! as List<Object?>) {
          (entry! as Map<String, Object?>)['min_app'] = '0.9.6';
        }
      }
    });

    test('holds back the files of an app too old, and says what it needs', () {
      final zz = _zz(gated, appVersion: '0.9.5');
      expect(
        zz.hiddenFilesFor('zz-medicine-registro', <String>['en']),
        isEmpty,
      );
      expect(
        zz.hiddenAppNeeded('zz-medicine-registro', <String>['en']),
        '0.9.6',
      );
      expect(zz.needingNewerApp(<String>['en']), isNotEmpty);
    });

    test('lets an app that reads them have them', () {
      final zz = _zz(gated, appVersion: '0.9.6');
      expect(
        zz.hiddenFilesFor('zz-medicine-registro', <String>['en']),
        hasLength(2),
      );
      expect(
        zz.hiddenAppNeeded('zz-medicine-registro', <String>['en']),
        isNull,
      );
    });

    test('is no requirement where the index names none', () {
      final zz = _zz(everything, appVersion: '0.9.0');
      expect(
        zz.hiddenAppNeeded('zz-medicine-registro', <String>['en']),
        isNull,
      );
    });
  });

  group('a bad entry', () {
    test('costs itself, and every other entry is read', () {
      final broken = _edited(everything, (zz) {
        (zz['shelves']! as List<Object?>).addAll(<Object?>[
          'not an object',
          <String, Object?>{'size': 1},
          <String, Object?>{
            'path': 'decks/zz/zz-nogenre.yaml',
            'size': 3,
            'sha256': 'a' * 64,
          },
          <String, Object?>{
            'path': 'decks/xx/xx-other.yaml',
            'size': 3,
            'sha256': 'a' * 64,
            'genre': 'culture',
          },
        ]);
        (zz['topics']! as List<Object?>).add(<String, Object?>{'path': '../x'});
      });
      final zz = _zz(broken);
      expect(zz.shelves, hasLength(9));
      expect(zz.topics, hasLength(1));
      expect(zz.problems, hasLength(5));
      expect(zz.problems.every((p) => p.startsWith('zz:')), isTrue);
    });

    test('is named for the log through the index', () {
      final broken = _edited(everything, (zz) {
        (zz['shelves']! as List<Object?>).add(5);
      });
      expect(DeckIndex.parse(broken).problems, hasLength(1));
    });

    test('a level that is no level is left out, not refused', () {
      final odd = _edited(everything, (zz) {
        (zz['shelves']! as List<Object?>).first! as Map<String, Object?>
          ..['level'] = 'Z9'
          ..['cards'] = -3
          ..['weave'] = 'maybe';
      });
      final first = _zz(odd).shelves.first;
      expect(first.level, isNull);
      expect(first.cards, 0);
      expect(first.weave, isFalse);
    });
  });

  group('shared_media', () {
    test('lists the creators\' images, and skips what is not one', () {
      final text = jsonEncode(<String, Object?>{
        'version': 1,
        'shared_media': <Object?>[
          <String, Object?>{
            'path': 'decks/creators/images/zz-ejemplo-autora.png',
            'size': 120,
            'sha256': 'b' * 64,
            'kind': 'image',
            'language': 'zz',
          },
          <String, Object?>{
            'path': 'decks/zz/elsewhere.png',
            'size': 120,
            'sha256': 'b' * 64,
          },
          <String, Object?>{
            'path': 'decks/creators/images/../x.png',
            'size': 120,
            'sha256': 'b' * 64,
          },
          <String, Object?>{
            'path': 'decks/creators/images/zero.png',
            'size': 0,
            'sha256': 'b' * 64,
          },
          'junk',
        ],
        'languages': <Object?>[],
      });
      final index = DeckIndex.parse(text);
      expect(index.sharedMedia, hasLength(1));
      expect(index.sharedMedia.single.language, 'zz');
      expect(index.sharedMedia.single.kind, 'image');
      expect(index.problems, hasLength(4));
    });

    test('is empty for an index that lists none', () {
      expect(DeckIndex.parse(everything).sharedMedia, isEmpty);
    });
  });

  group('adding a hidden deck from search', () {
    late FakeDeckRemote remote;
    late MemoryDownloadedDecks phone;
    late AppLog log;

    DeckDownloads downloads({String appVersion = '0.9.6'}) => DeckDownloads(
      fetcher: remote,
      files: phone,
      clock: () => DateTime(2026, 11, 12),
      log: log,
      appVersion: appVersion,
    );

    bool logged(String part) =>
        log.entries.any((e) => e.message.contains(part));

    setUp(() {
      remote = FakeDeckRemote(_files(only: _decks));
      phone = MemoryDownloadedDecks();
      log = AppLog(clock: () => DateTime.utc(2026, 11, 12));
    });

    test(
      'downloads the visible decks with the language, and not the hidden',
      () async {
        final d = downloads();
        expect(await d.downloadRest('zz', <String>['en']), isNull);
        final onPhone = (await phone.manifest()).keys.toSet();
        expect(onPhone, contains(_cultureLayer));
        expect(onPhone, isNot(contains(_medicineCore)));
        expect(onPhone, isNot(contains(_medicineLayer)));
        expect(remote.asked, isNot(contains(_medicineLayer)));
        expect(d.hiddenDecksOnPhone('zz'), isEmpty);
      },
    );

    test(
      'fetches its core and its layer, checked, and keeps them together',
      () async {
        final d = downloads();
        await d.downloadRest('zz', <String>['en']);
        expect(
          await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']),
          isNull,
        );
        final onPhone = (await phone.manifest()).keys.toSet();
        expect(onPhone, containsAll(<String>[_medicineCore, _medicineLayer]));
        expect(d.hiddenDecksOnPhone('zz'), <String>{'zz-medicine-registro'});
        expect(d.hasHiddenDeck('zz', 'zz-medicine-registro'), isTrue);
        expect(d.hasHiddenDeck('zz', 'zz-culture-ejemplo'), isFalse);
        expect(logged('Hidden deck added from search'), isTrue);
      },
    );

    test(
      'works before anything else of the language is on the phone',
      () async {
        final d = downloads();
        expect(
          await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']),
          isNull,
        );
        expect(
          (await phone.manifest()).keys,
          containsAll(<String>[_medicineCore]),
        );
      },
    );

    test('does not fetch a deck that is on the phone again', () async {
      final d = downloads();
      await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']);
      await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']);
      expect(remote.asked.where((p) => p == _medicineLayer), hasLength(1));
    });

    test(
      'says a deck the index does not list as hidden is not offered',
      () async {
        final d = downloads();
        expect(
          await d.fetchHidden('zz', 'zz-nada', <String>['en']),
          DeckDownloadFailure.notOffered,
        );
        // A visible deck is never fetched this way.
        expect(
          await d.fetchHidden('zz', 'zz-culture-ejemplo', <String>['en']),
          DeckDownloadFailure.notOffered,
        );
        expect(
          await d.fetchHidden('xx', 'zz-medicine-registro', <String>['en']),
          DeckDownloadFailure.notOffered,
        );
        expect(logged('is not offered'), isTrue);
        expect(await phone.manifest(), isEmpty);
      },
    );

    test('waits for the app its min_app names, and fetches nothing', () async {
      remote.index = _edited(indexFor(_files(only: _decks)), (zz) {
        for (final entry in zz['shelves']! as List<Object?>) {
          (entry! as Map<String, Object?>)['min_app'] = '0.9.6';
        }
      });
      final d = downloads(appVersion: '0.9.5');
      expect(
        await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']),
        DeckDownloadFailure.appTooOld,
      );
      expect(remote.asked, isNot(contains(_medicineCore)));
      expect(logged('needs app 0.9.6'), isTrue);
    });

    test('fails offline without throwing, and keeps nothing', () async {
      remote.failAll = FetchFailure.offline;
      final d = downloads();
      expect(
        await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']),
        DeckDownloadFailure.offline,
      );
      expect(await phone.manifest(), isEmpty);
    });

    test('keeps nothing of a file that does not match the index', () async {
      remote.served[_medicineLayer] = 'schema: 1\n';
      final d = downloads();
      expect(
        await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']),
        isNotNull,
      );
      expect((await phone.manifest()).keys, isNot(contains(_medicineLayer)));
    });

    test('keeps nothing when the phone is full, and logs it', () async {
      phone.failPut = StateError('disk full');
      final d = downloads();
      expect(
        await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']),
        DeckDownloadFailure.storage,
      );
      expect(
        log.entries.any((e) => e.level == LogLevel.error),
        isTrue,
        reason: 'a failure is reported to the app log, never swallowed',
      );
    });

    test('is removed again, and only a hidden deck ever is', () async {
      final d = downloads();
      await d.downloadRest('zz', <String>['en']);
      await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']);
      await d.removeHidden('zz', 'zz-culture-ejemplo');
      expect((await phone.manifest()).keys, contains(_cultureCore));
      await d.removeHidden('zz', 'zz-medicine-registro');
      final onPhone = (await phone.manifest()).keys.toSet();
      expect(onPhone, isNot(contains(_medicineCore)));
      expect(onPhone, isNot(contains(_medicineLayer)));
      expect(onPhone, contains(_cultureLayer));
      expect(d.hiddenDecksOnPhone('zz'), isEmpty);
    });

    test('is updated with the language once it is on the phone', () async {
      final d = downloads();
      await d.downloadRest('zz', <String>['en']);
      await d.fetchHidden('zz', 'zz-medicine-registro', <String>['en']);
      final changed = remote.files[_medicineLayer]!.replaceFirst(
        'I would like to register',
        'I wish to register',
      );
      remote.files[_medicineLayer] = changed;
      remote.index = null;
      await d.checkForUpdates(<String>['en'], force: true);
      final fetch = d.updates['zz']!.fetch.map((f) => f.path).toList();
      expect(fetch, <String>[_medicineLayer]);
    });

    test('is not updated, nor fetched, when it was never added', () async {
      final d = downloads();
      await d.downloadRest('zz', <String>['en']);
      remote.files[_medicineLayer] = remote.files[_medicineLayer]!.replaceFirst(
        'I would like to register',
        'I wish to register',
      );
      await d.checkForUpdates(<String>['en'], force: true);
      expect(d.updates, isEmpty);
    });
  });
}
