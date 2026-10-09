import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart';

import '../support/deck_remote.dart';

/// A single-file Testlang deck, as decks were before the B1 split.
const String _singleHome = '''
schema: 1
id: "zz-en-home"
name: "Home"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu", tts: "te-IN", icon: "తె" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC0-1.0"
cards:
  - { id: "zz-9001", target: "ఇల్లు", reading: "illu", native: "home" }
''';

/// The B1 fixture's files: a path, two cores and their English layers.
Map<String, String> _appendix() => <String, String>{
  for (final file in Directory(
    'test/fixtures/b1/appendix-a/zz',
  ).listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/zz/${file.path.substring('test/fixtures/b1/appendix-a/zz/'.length)}':
          file.readAsStringSync(),
};

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

void main() {
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
    test('is ready once its first five decks are in', () async {
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
    });

    test('downloads the rest behind it', () async {
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
    });

    test('says so with no network, keeps nothing, and tries again', () async {
      remote.failAll = FetchFailure.offline;
      final d = downloads();
      await d.open();
      expect(await d.downloadFirst('hi', english), DeckDownloadFailure.offline);
      expect(d.indexStatus, IndexStatus.failed);
      expect(d.indexFailure, DeckDownloadFailure.offline);
      expect(phone.files, isEmpty);
      remote.failAll = null;
      expect(await d.downloadFirst('hi', english), isNull);
      expect(d.isReady('hi', english), isTrue);
    });

    test('says when GitHub limits it, keeping nothing of the batch', () async {
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
    });

    test('a download cut short keeps the decks that came whole', () async {
      final d = downloads();
      await d.open();
      await d.downloadFirst('hi', english);
      final first = phone.files.length;
      remote.failAfter = remote.asked.length + 15;
      expect(await d.downloadRest('hi', english), DeckDownloadFailure.offline);
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
      expect(await d.downloadFirst('hi', english), DeckDownloadFailure.badFile);
      expect(phone.files, isEmpty);
      // The index was read again once, in case it was old, and no more.
      expect(remote.asked.where((p) => p == 'decks/index.json'), hasLength(2));
    });

    test('keeps nothing when a file fails its check', () async {
      remote = FakeDeckRemote(<String, String>{
        ...repoFiles(const <String>['es']),
        // Listed with its own hash, so it arrives whole: but no deck.
        'decks/es/es-en-core-100.yaml': 'schema: 1\nid: es-en-core-100\n',
      });
      final d = downloads();
      await d.open();
      expect(await d.downloadFirst('es', english), DeckDownloadFailure.invalid);
      expect(phone.files, isEmpty);
    });

    test('says when the phone cannot keep the files', () async {
      phone.failPut = const FileSystemException('No space left on device');
      final d = downloads();
      await d.open();
      expect(await d.downloadFirst('es', english), DeckDownloadFailure.storage);
    });

    test('skips a deck newer than the app, and says so', () async {
      final index = jsonDecode(indexFor(remote.files)) as Map<String, Object?>;
      for (final language in index['languages']! as List<Object?>) {
        for (final file in (language! as Map)['files'] as List<Object?>) {
          final entry = file! as Map<String, Object?>;
          if (entry['path'] == 'decks/hi/hi-en-slang.yaml') entry['schema'] = 2;
        }
      }
      remote.index = jsonEncode(index);
      final d = downloads();
      await d.open();
      expect(await d.download('hi', english), isNull);
      await d.downloadRest('hi', english);
      expect(d.needsNewerApp('hi', english), isTrue);
      expect(phone.files.keys, isNot(contains('decks/hi/hi-en-slang.yaml')));
    });

    test('asks for an app update for an index it cannot read', () async {
      remote.index = indexFor(remote.files, version: 2);
      final d = downloads();
      await d.open();
      expect(
        await d.downloadFirst('hi', english),
        DeckDownloadFailure.appTooOld,
      );
    });

    test('a language GitHub does not offer', () async {
      final d = downloads();
      await d.open();
      expect(
        await d.downloadFirst('xx', english),
        DeckDownloadFailure.notOffered,
      );
    });

    test('removing it deletes its files', () async {
      final d = downloads();
      await d.open();
      await d.download('es', english);
      await d.downloadRest('es', english);
      await d.download('hi', english);
      reloads = 0;
      await d.remove('es');
      expect(phone.files.keys.where((p) => p.startsWith('decks/es/')), isEmpty);
      expect(
        phone.files.keys.where((p) => p.startsWith('decks/hi/')),
        isNotEmpty,
      );
      expect(d.stateOf('es', english), LanguageDownloadState.notOnPhone);
      expect(reloads, 1);
    });
  });

  group('offline', () {
    test('knows its languages from the index kept', () async {
      await downloads().download('es', english);
      remote.failAll = FetchFailure.offline;
      final d = downloads();
      await d.open();
      expect(d.index!.language('hi'), isNotNull);
      expect(d.isReady('es', english), isTrue);
      expect(d.languagesOnPhone, <String>{'es'});
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

    const deck = 'decks/es/es-en-core-100.yaml';

    test('are looked for at most once a day', () async {
      final d = await withEs();
      final asked = remote.asked.length;
      await d.checkForUpdates(english);
      expect(remote.asked.length, asked);
      now = now.add(const Duration(hours: 25));
      await d.checkForUpdates(english);
      expect(remote.asked.length, asked + 1);
      expect(d.updates, isEmpty);
    });

    test('ask, and wait in Settings after "Not now"', () async {
      final d = await withEs();
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      await d.checkForUpdates(english, force: true);
      expect(d.updates.keys, <String>['es']);
      expect(d.updates['es']!.fetch.single.path, deck);
      expect(d.askToUpdate, isTrue);
      expect(d.stateOf('es', english), LanguageDownloadState.updateWaiting);
      await d.declineUpdate();
      expect(d.askToUpdate, isFalse);
      expect(d.updates, isNotEmpty);

      // Not asked again for the same update, after a restart.
      now = now.add(const Duration(days: 2));
      final again = downloads();
      await again.open();
      await again.checkForUpdates(english);
      expect(again.updates, isNotEmpty);
      expect(again.askToUpdate, isFalse);

      // Asked again once something else changes.
      remote.files[deck] = '${remote.files[deck]!}# another\n';
      await again.checkForUpdates(english, force: true);
      expect(again.askToUpdate, isTrue);
    });

    test('replace the files, and keep every card id', () async {
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
    });

    test('that fail their check leave the decks as they were', () async {
      final d = await withEs();
      final was = await phone.read(deck);
      remote.files[deck] = 'schema: 1\nid: es-en-core-100\n';
      await d.checkForUpdates(english, force: true);
      expect(await d.update(), DeckDownloadFailure.invalid);
      expect(await phone.read(deck), was);
      expect(d.updates, isNotEmpty);
    });

    test('cut short leave the decks as they were', () async {
      final d = await withEs();
      final was = await phone.read(deck);
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      await d.checkForUpdates(english, force: true);
      remote.failAll = FetchFailure.offline;
      expect(await d.update(), DeckDownloadFailure.offline);
      expect(await phone.read(deck), was);
    });

    test('keep a deck GitHub removed', () async {
      final d = await withEs();
      const gone = 'decks/es/es-en-grammar-present-ar.yaml';
      remote.files.remove(gone);
      await d.checkForUpdates(english, force: true);
      expect(d.updates, isEmpty);
      expect(phone.files.keys, contains(gone));
    });

    test('keep a language GitHub removed', () async {
      final d = await withEs();
      remote.files.removeWhere((path, _) => path.startsWith('decks/es/'));
      await d.checkForUpdates(english, force: true);
      expect(d.updates, isEmpty);
      expect(d.stateOf('es', english), LanguageDownloadState.notOffered);
      expect(phone.files, isNotEmpty);
    });

    test('replace a deck split into a core and its layer', () async {
      remote = FakeDeckRemote(<String, String>{
        'decks/zz/zz-path.yaml': _appendix()['decks/zz/zz-path.yaml']!,
        'decks/zz/zz-en-home.yaml': _singleHome,
      });
      final d = downloads();
      await d.open();
      await d.download('zz', english);
      await d.downloadRest('zz', english);
      expect(phone.files.keys, contains('decks/zz/zz-en-home.yaml'));

      remote = FakeDeckRemote(_appendix());
      final after = downloads();
      await after.open();
      await after.checkForUpdates(english, force: true);
      expect(after.updates['zz']!.remove, <String>['decks/zz/zz-en-home.yaml']);
      expect(await after.update(), isNull);
      expect(phone.files.keys, isNot(contains('decks/zz/zz-en-home.yaml')));
      expect(phone.files.keys, contains('decks/zz/en/zz-en-home.yaml'));
      final catalog = DeckCatalog.parseAll(<String, String>{
        for (final path in await phone.list()) path: await phone.read(path),
      });
      expect(catalog.broken, isEmpty);
      expect(catalog.byId('zz-en-home'), isNotNull);
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

    test('is read again for the rest of a language', () async {
      final d = downloads();
      await d.open();
      await d.downloadFirst('hi', english);
      final rest = d.missing('hi', english).last.path;
      remote.files[rest] = '${remote.files[rest]!}# a fix\n';
      expect(await d.downloadRest('hi', english), isNull);
      expect(await phone.read(rest), endsWith('# a fix\n'));
      expect(d.missing('hi', english), isEmpty);
    });

    test('is read again for an update found before', () async {
      final d = downloads();
      await d.open();
      await d.download('es', english);
      await d.downloadRest('es', english);
      const deck = 'decks/es/es-en-core-100.yaml';
      final was = remote.files[deck]!;
      remote.files[deck] = '$was# a fix\n';
      await d.checkForUpdates(english, force: true);
      // "Not now", and days later main has changed the deck again.
      remote.files[deck] = '$was# another fix\n';
      expect(await d.update(), isNull);
      expect(await phone.read(deck), endsWith('# another fix\n'));
      expect(d.updates, isEmpty);
      expect(d.stateOf('es', english), LanguageDownloadState.upToDate);
    });

    test('says why when it cannot be read again', () async {
      final d = downloads();
      await d.open();
      await d.refreshIndex();
      remote.files[path] = '${remote.files[path]!}# a fix\n';
      remote.failures['decks/index.json'] = FetchFailure.offline;
      expect(await d.downloadFirst('hi', english), DeckDownloadFailure.offline);
      expect(d.failureOf('hi'), DeckDownloadFailure.offline);
      expect(phone.files, isEmpty);
    });
  });

  group('Try again', () {
    test('after a failed update tries the update again', () async {
      final d = downloads();
      await d.open();
      await d.download('es', english);
      await d.downloadRest('es', english);
      const deck = 'decks/es/es-en-core-100.yaml';
      remote.files[deck] = '${remote.files[deck]!}# a fix\n';
      await d.checkForUpdates(english, force: true);
      remote.failAll = FetchFailure.offline;
      expect(await d.update(), DeckDownloadFailure.offline);
      expect(d.stateOf('es', english), LanguageDownloadState.failed);

      // Nothing is missing, so the rest alone would fetch nothing.
      remote.failAll = null;
      expect(await d.retry('es', english), isNull);
      expect(await phone.read(deck), endsWith('# a fix\n'));
      expect(d.updates, isEmpty);
      expect(d.stateOf('es', english), LanguageDownloadState.upToDate);
    });

    test('after a download cut short downloads the rest', () async {
      final d = downloads();
      await d.open();
      await d.downloadFirst('hi', english);
      remote.failAll = FetchFailure.offline;
      expect(await d.downloadRest('hi', english), DeckDownloadFailure.offline);
      remote.failAll = null;
      expect(await d.retry('hi', english), isNull);
      expect(d.missing('hi', english), isEmpty);
    });
  });

  group('cancel', () {
    test('keeps the decks that came whole, and stops the rest', () async {
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

      // Settings > Deck downloads asks for the rest.
      expect(await again.retry('hi', english), isNull);
      expect(again.isPaused('hi'), isFalse);
      expect(again.missing('hi', english), isEmpty);
    });

    test('before the first decks are in, keeps whole decks and downloads '
        'no more', () async {
      late DeckDownloads d;
      d = DeckDownloads(
        fetcher: _CallAfter(remote, 4, () => d.cancel('hi')),
        files: phone,
        clock: () => now,
      );
      await d.open();
      expect(await d.download('hi', english), isNull);
      expect(d.isReady('hi', english), isFalse);
      expect(d.isDownloading('hi'), isFalse);
      final kept = phone.files.length;
      await Future<void>.delayed(Duration.zero);
      expect(phone.files.length, kept, reason: 'the rest did not start');
      expect(d.stateOf('hi', english), isNot(LanguageDownloadState.failed));
    });
  });

  group('cancel, before and after', () {
    test('a download has a job from the moment it is asked for, before its '
        'files are known', () async {
      final d = downloads();
      await d.open();
      final job = d.download('hi', english);
      expect(d.isDownloading('hi'), isFalse, reason: 'its files not known');
      expect(d.hasJob('hi'), isTrue);
      expect(await job, isNull);
      // The rest, behind it, is a job too, until it is done.
      for (var i = 0; i < 100 && d.hasJob('hi'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(d.hasJob('hi'), isFalse);
      expect(d.missing('hi', english), isEmpty);
    });

    test('removing a language cancelled forgets that it was', () async {
      late DeckDownloads d;
      d = DeckDownloads(
        fetcher: _CallAfter(remote, 4, () => d.cancel('hi')),
        files: phone,
        clock: () => now,
      );
      await d.open();
      await d.download('hi', english);
      expect(d.isPaused('hi'), isTrue);

      await d.remove('hi');
      expect(d.isPaused('hi'), isFalse);
      final again = downloads();
      await again.open();
      expect(again.isPaused('hi'), isFalse, reason: 'nor the state note');
    });
  });

  group('how much of a language is in', () {
    test('counts decks and bytes, and where it is ready', () async {
      final d = downloads();
      await d.open();
      expect(await d.ensureIndex(), isTrue);
      final none = d.languageDownload('hi', english)!;
      expect(none.decks, 0);
      expect(none.bytes, 0);
      expect(none.ready, isFalse);
      expect(none.totalDecks, greaterThan(decksBeforeReady));
      expect(none.readyBytes, inExclusiveRange(0, none.totalBytes));

      await d.downloadFirst('hi', english);
      final first = d.languageDownload('hi', english)!;
      expect(first.decks, decksBeforeReady);
      expect(first.bytes, first.readyBytes);
      expect(first.ready, isTrue);

      await d.downloadRest('hi', english);
      final all = d.languageDownload('hi', english)!;
      expect(all.decks, all.totalDecks);
      expect(all.bytes, all.totalBytes);
      expect(d.languageDownload('xx', english), isNull);
    });

    test('counts what has arrived of a download under way', () async {
      late DeckDownloads d;
      final seen = <int>[];
      d = DeckDownloads(
        fetcher: _CallAfter(remote, 3, () async {
          seen.add(d.languageDownload('hi', english)!.bytes);
        }),
        files: phone,
        clock: () => now,
      );
      await d.open();
      await d.downloadFirst('hi', english);
      // The third file is still being fetched: the first two are counted.
      expect(seen.single, greaterThan(0));
    });
  });

  group('the daily check', () {
    test('is on unless turned off, and stays off', () async {
      final d = downloads();
      await d.open();
      expect(d.checksAutomatically, isTrue);
      await d.setChecksAutomatically(false);
      final again = downloads();
      await again.open();
      expect(again.checksAutomatically, isFalse);
      await again.setChecksAutomatically(true);
      final third = downloads();
      await third.open();
      expect(third.checksAutomatically, isTrue);
    });
  });

  group('state', () {
    test('survives a restart', () async {
      final d = downloads();
      await d.open();
      await d.download('es', english);
      await d.downloadRest('es', english);
      final again = downloads();
      await again.open();
      expect(again.checkedAt, now);
      expect(again.stateOf('es', english), LanguageDownloadState.upToDate);
      expect(again.index!.language('es'), isNotNull);
    });

    test('a manifest index reads as a deck index', () {
      expect(
        () => DeckIndex.parse(manifestJson(const <IndexFile>[])),
        returnsNormally,
      );
    });
  });
}
