import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/sha256.dart';

IndexFile _file(String path, String text, {String? deck, String? native}) {
  final bytes = utf8.encode(text);
  return IndexFile(
    path: path,
    size: bytes.length,
    sha256: sha256Hex(bytes),
    deck: deck,
    native: native,
  );
}

void main() {
  late Directory dir;
  late FileDownloadedDecks store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fluenough-downloads');
    store = FileDownloadedDecks(Directory('${dir.path}/downloaded'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('keeps files under their repository paths', () async {
    final a = _file('decks/hi/hi-en-a.yaml', 'a: 1\n', deck: 'hi-a');
    final b = _file('decks/hi/en/hi-en-b.yaml', 'b: 2\n', deck: 'hi-b');
    await store.putAll(<IndexFile, List<int>>{
      a: utf8.encode('a: 1\n'),
      b: utf8.encode('b: 2\n'),
    });
    expect(await store.list(), <String>[
      'decks/hi/en/hi-en-b.yaml',
      'decks/hi/hi-en-a.yaml',
    ]);
    expect(await store.read('decks/hi/hi-en-a.yaml'), 'a: 1\n');
    expect(
      File('${dir.path}/downloaded/decks/hi/en/hi-en-b.yaml').existsSync(),
      isTrue,
    );
  });

  test('remembers what the index said of each file, after a restart', () async {
    final a = _file('decks/hi/hi-en-a.yaml', 'a\n', deck: 'hi-a', native: 'en');
    await store.putAll(<IndexFile, List<int>>{a: utf8.encode('a\n')});
    final again = FileDownloadedDecks(Directory('${dir.path}/downloaded'));
    final manifest = await again.manifest();
    expect(manifest['decks/hi/hi-en-a.yaml']!.deck, 'hi-a');
    expect(manifest['decks/hi/hi-en-a.yaml']!.native, 'en');
    expect(manifest['decks/hi/hi-en-a.yaml']!.sha256, a.sha256);
  });

  test('a file the manifest lost is known by its hash', () async {
    final a = _file('decks/hi/hi-en-a.yaml', 'a\n');
    await store.putAll(<IndexFile, List<int>>{a: utf8.encode('a\n')});
    File('${dir.path}/downloaded/files.json').deleteSync();
    final again = FileDownloadedDecks(Directory('${dir.path}/downloaded'));
    expect((await again.manifest())['decks/hi/hi-en-a.yaml']!.sha256, a.sha256);
  });

  test('a download cut short leaves no file in use', () async {
    // What a crash mid-write leaves: the file written beside its place.
    final part = File('${dir.path}/downloaded/decks/hi/hi-en-a.yaml.part')
      ..createSync(recursive: true)
      ..writeAsStringSync('half a fi');
    expect(await store.list(), isEmpty);
    await store.clean();
    expect(part.existsSync(), isFalse);
  });

  test('replaces a file whole, and removes what it is told to', () async {
    final old = _file('decks/hi/hi-en-a.yaml', 'old\n');
    final gone = _file('decks/hi/hi-en-gone.yaml', 'gone\n');
    await store.putAll(<IndexFile, List<int>>{
      old: utf8.encode('old\n'),
      gone: utf8.encode('gone\n'),
    });
    final updated = _file('decks/hi/hi-en-a.yaml', 'new\n');
    await store.putAll(
      <IndexFile, List<int>>{updated: utf8.encode('new\n')},
      remove: <String>['decks/hi/hi-en-gone.yaml'],
    );
    expect(await store.list(), <String>['decks/hi/hi-en-a.yaml']);
    expect(await store.read('decks/hi/hi-en-a.yaml'), 'new\n');
    expect(
      Directory('${dir.path}/downloaded')
          .listSync(recursive: true)
          .where((e) => e.path.endsWith('.part')),
      isEmpty,
    );
  });

  test('removing a language deletes its folder only', () async {
    await store.putAll(<IndexFile, List<int>>{
      _file('decks/hi/hi-en-a.yaml', 'a\n'): utf8.encode('a\n'),
      _file('decks/te/te-en-a.yaml', 'a\n'): utf8.encode('a\n'),
    });
    await store.removeLanguage('hi');
    expect(await store.list(), <String>['decks/te/te-en-a.yaml']);
    expect(Directory('${dir.path}/downloaded/decks/hi').existsSync(), isFalse);
  });

  test('refuses a path outside the decks', () async {
    final evil = IndexFile(path: '../evil.yaml', size: 1, sha256: 'a' * 64);
    await expectLater(
      store.putAll(<IndexFile, List<int>>{evil: utf8.encode('x')}),
      throwsArgumentError,
    );
    expect(() => store.read('decks/../../etc/passwd'), throwsArgumentError);
  });

  test('keeps notes beside the files', () async {
    expect(await store.readNote('state.json'), isNull);
    await store.writeNote('state.json', '{}');
    expect(await store.readNote('state.json'), '{}');
  });

  test('its manifest reads back as an index', () {
    final text = manifestJson(<IndexFile>[
      _file('decks/hi/hi-en-a.yaml', 'a', deck: 'hi-a', native: 'en'),
      const IndexFile(
        path: 'decks/hi/hi-a.yaml',
        size: 1,
        sha256:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        deck: 'hi-a',
        core: true,
      ),
    ]);
    final files = DeckIndex.parse(text).filesByPath;
    expect(files['decks/hi/hi-a.yaml']!.core, isTrue);
    expect(files['decks/hi/hi-en-a.yaml']!.native, 'en');
  });
}
