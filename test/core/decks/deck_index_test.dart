import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/sha256.dart';

import '../../support/deck_remote.dart';

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

void main() {
  group('the committed index', () {
    late DeckIndex index;
    setUpAll(
      () =>
          index = DeckIndex.parse(File('decks/index.json').readAsStringSync()),
    );

    test('reads, and matches every file it lists', () {
      expect(index.languages, isNotEmpty);
      for (final file in index.filesByPath.values) {
        final bytes = File(file.path).readAsBytesSync();
        expect(bytes.length, file.size, reason: file.path);
        expect(sha256Hex(bytes), file.sha256, reason: file.path);
        // tools/deck_index.py's content hash, as the test remote makes it.
        expect(
          sha256Hex(utf8.encode(contentOf(utf8.decode(bytes)))),
          file.contentSha256,
          reason: file.path,
        );
      }
    });

    test('lists every language folder but the hidden ones', () {
      final folders = <String>[
        for (final dir in Directory('decks').listSync())
          if (dir is Directory) dir.path.split('/').last,
      ]..remove('ja');
      expect(index.languages.map((l) => l.code).toSet(), folders.toSet());
    });

    test('leaves out the bundled theme list', () {
      expect(index.filesByPath.keys, isNot(contains('decks/themes.yaml')));
    });

    test("ready after five of Hindi's decks, its own files with them", () {
      final hi = index.language('hi')!;
      final first = hi.firstFiles(const <String>['en']);
      final decks = <String>{
        for (final f in first)
          if (f.deck != null) f.deck!,
      };
      expect(decks, hi.path.take(5).toSet());
      expect(
        first.where((f) => f.isLanguageFile).map((f) => f.kind).toSet(),
        containsAll(<String>['path', 'facts', 'romanisation']),
      );
    });
  });

  group('parsing', () {
    test('reads a file', () {
      final index = DeckIndex.parse(
        _index(<Map<String, Object?>>[
          _file(
            'decks/zz/en/zz-en-a.yaml',
            native: 'en',
            deck: 'zz-a',
            kind: 'layer',
          ),
          _file('decks/zz/zz-a.yaml', deck: 'zz-a', core: true),
        ]),
      );
      final zz = index.language('zz')!;
      expect(zz.name, 'Testlang');
      expect(zz.files.first.native, 'en');
      expect(zz.files.first.language, 'zz');
      expect(zz.files.last.core, isTrue);
    });

    test('refuses a path outside a language folder', () {
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
    });

    test("refuses a file in another language's folder", () {
      expect(
        () => DeckIndex.parse(
          _index(<Map<String, Object?>>[_file('decks/hi/hi-en-a.yaml')]),
        ),
        throwsFormatException,
      );
    });

    test('refuses a bad hash', () {
      expect(
        () => DeckIndex.parse(
          _index(<Map<String, Object?>>[
            _file('decks/zz/zz-en-a.yaml', sha: 'nothex'),
          ]),
        ),
        throwsFormatException,
      );
    });

    test('reads a content hash, which is the hash where none is given', () {
      final content = 'c' * 64;
      final index = DeckIndex.parse(
        _index(<Map<String, Object?>>[
          <String, Object?>{
            ..._file('decks/zz/zz-a.yaml', deck: 'zz-a'),
            'content_sha256': content,
          },
          _file('decks/zz/zz-b.yaml', deck: 'zz-b'),
        ]),
      );
      final files = index.language('zz')!.files;
      expect(files.first.contentSha256, content);
      expect(files.last.contentSha256, _sha);
      // The phone keeps it beside the file, in the same form (#444).
      final kept = DeckIndex.parse(
        jsonEncode(<String, Object?>{
          'version': 1,
          'languages': <Object?>[
            <String, Object?>{
              'code': 'zz',
              'name': 'Testlang',
              'files': <Object?>[for (final f in files) f.toJson()],
            },
          ],
        }),
      ).language('zz')!.files;
      expect(kept.first.contentSha256, content);
      expect(kept.first.sha256, _sha);
    });

    test('refuses a bad content hash', () {
      expect(
        () => DeckIndex.parse(
          _index(<Map<String, Object?>>[
            <String, Object?>{
              ..._file('decks/zz/zz-en-a.yaml'),
              'content_sha256': 'nothex',
            },
          ]),
        ),
        throwsFormatException,
      );
    });

    test('refuses what is not an index', () {
      expect(() => DeckIndex.parse('<html>'), throwsFormatException);
      expect(() => DeckIndex.parse('[]'), throwsFormatException);
      expect(() => DeckIndex.parse('{}'), throwsFormatException);
    });

    test('asks for an app update for a newer index', () {
      expect(
        () =>
            DeckIndex.parse(_index(const <Map<String, Object?>>[], version: 2)),
        throwsA(isA<IndexTooNewException>()),
      );
    });
  });

  group('a language', () {
    final zz = DeckIndex.parse(
      _index(<Map<String, Object?>>[
        _file('decks/zz/zz-path.yaml', kind: 'path'),
        _file('decks/zz/zz-a.yaml', deck: 'zz-a', core: true),
        _file(
          'decks/zz/en/zz-en-a.yaml',
          native: 'en',
          deck: 'zz-a',
          kind: 'layer',
        ),
        _file(
          'decks/zz/bn/zz-bn-a.yaml',
          native: 'bn',
          deck: 'zz-a',
          kind: 'layer',
        ),
        _file('decks/zz/zz-en-b.yaml', native: 'en', deck: 'zz-b'),
        _file('decks/zz/zz-c.yaml', deck: 'zz-c', core: true),
        _file(
          'decks/zz/en/zz-en-c.yaml',
          native: 'en',
          deck: 'zz-c',
          kind: 'layer',
          schema: 2,
        ),
      ]),
    ).language('zz')!;

    test('is taught from the languages the learner speaks', () {
      expect(zz.nativesFor(const <String>['bn', 'en']), <String>['bn', 'en']);
      expect(zz.nativesFor(const <String>['bn']), <String>['bn']);
      expect(zz.taughtFromOther(const <String>['bn']), isFalse);
    });

    test('else from English, and says so', () {
      expect(zz.nativesFor(const <String>['hi']), <String>['en']);
      expect(zz.taughtFromOther(const <String>['hi']), isTrue);
    });

    test("downloads its own files, cores and the learner's layers", () {
      expect(zz.filesFor(const <String>['bn']).map((f) => f.path), <String>[
        'decks/zz/zz-path.yaml',
        'decks/zz/zz-a.yaml',
        'decks/zz/bn/zz-bn-a.yaml',
        'decks/zz/zz-c.yaml',
      ]);
    });

    test('skips a file of a newer schema, and says the app needs one', () {
      expect(
        zz.filesFor(const <String>['en']).map((f) => f.path),
        isNot(contains('decks/zz/en/zz-en-c.yaml')),
      );
      expect(zz.unreadable(const <String>['en']).map((f) => f.path), <String>[
        'decks/zz/en/zz-en-c.yaml',
      ]);
    });

    test('is ready after its first decks, a core alone not counting', () {
      expect(
        zz.firstFiles(const <String>['en'], count: 1).map((f) => f.path),
        <String>[
          'decks/zz/zz-path.yaml',
          'decks/zz/zz-a.yaml',
          'decks/zz/en/zz-en-a.yaml',
        ],
      );
      // From Bengali, zz-b teaches nobody and zz-c is a core alone.
      expect(
        zz.firstFiles(const <String>['bn'], count: 5).map((f) => f.path),
        <String>[
          'decks/zz/zz-path.yaml',
          'decks/zz/zz-a.yaml',
          'decks/zz/bn/zz-bn-a.yaml',
        ],
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

    test('fetches new and changed files only', () {
      final changes = changesFor('zz', wanted, <String, IndexFile>{
        'decks/zz/zz-path.yaml': _phone('decks/zz/zz-path.yaml', kind: 'path'),
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
    });

    test('keeps a deck GitHub no longer lists', () {
      final changes = changesFor('zz', wanted, <String, IndexFile>{
        'decks/zz/zz-en-gone.yaml': _phone(
          'decks/zz/zz-en-gone.yaml',
          native: 'en',
          deck: 'zz-gone',
        ),
      });
      expect(changes.remove, isEmpty);
    });

    test('removes a deck that a core and its layer replace', () {
      final changes = changesFor('zz', wanted, <String, IndexFile>{
        'decks/zz/zz-en-a.yaml': _phone(
          'decks/zz/zz-en-a.yaml',
          native: 'en',
          deck: 'zz-a',
        ),
        'decks/zz/zz-en-path.yaml': _phone(
          'decks/zz/zz-en-path.yaml',
          kind: 'path',
        ),
        'decks/hi/hi-path.yaml': _phone('decks/hi/hi-path.yaml', kind: 'path'),
      });
      expect(changes.remove, <String>[
        'decks/zz/zz-en-a.yaml',
        'decks/zz/zz-en-path.yaml',
      ]);
    });

    group('proposals (#444)', () {
      // What reviewers propose is in the file, so it changes the file's
      // sha256; learners never see it, so it leaves its content hash.
      final proposed = 'd' * 64;
      final content = 'c' * 64;
      Map<String, IndexFile> phone() => <String, IndexFile>{
        for (final file in wanted)
          file.path: _phone(
            file.path,
            native: file.native,
            deck: file.deck,
            kind: file.kind,
            core: file.core,
            sha: file.path.endsWith('zz-en-a.yaml') ? _sha : proposed,
            content: content,
          ),
      };
      List<IndexFile> now({String layerContent = 'c'}) => <IndexFile>[
        for (final file in wanted)
          _phone(
            file.path,
            native: file.native,
            deck: file.deck,
            kind: file.kind,
            core: file.core,
            sha: file.path.endsWith('zz-en-a.yaml') ? old : _sha,
            content: file.path.endsWith('zz-en-a.yaml')
                ? layerContent * 64
                : content,
          ),
      ];

      test('a proposal alone is no update for a learner', () {
        // Every file's sha256 changed, none of their content.
        final changes = changesFor('zz', now(), phone());
        expect(changes.isEmpty, isTrue);
        expect(changes.bytes, 0);
      });

      test('a change a learner sees is, and brings the rest along', () {
        final changes = changesFor('zz', now(layerContent: 'e'), phone());
        expect(changes.fetch.map((f) => f.path), <String>[
          'decks/zz/zz-path.yaml',
          'decks/zz/zz-a.yaml',
          'decks/zz/en/zz-en-a.yaml',
        ]);
        expect(changes.quiet.map((f) => f.path), <String>[
          'decks/zz/zz-path.yaml',
          'decks/zz/zz-a.yaml',
        ]);
      });

      test('a proposal is an update for a reviewer', () {
        final changes = changesFor('zz', now(), phone(), reviewer: true);
        expect(changes.fetch, hasLength(3));
        expect(changes.quiet, hasLength(3));
      });

      test('a file not on the phone is fetched with its quiet ones', () {
        final onPhone = phone()..remove('decks/zz/en/zz-en-a.yaml');
        final changes = changesFor('zz', now(), onPhone);
        expect(changes.fetch, hasLength(3));
        expect(changes.quiet.map((f) => f.path), <String>[
          'decks/zz/zz-path.yaml',
          'decks/zz/zz-a.yaml',
        ]);
      });

      test('a file kept before content hashes counts as changed', () {
        // A phone that downloaded it before #444 knows only its sha256.
        final onPhone = <String, IndexFile>{
          for (final MapEntry(:key, :value) in phone().entries)
            key: _phone(
              key,
              native: value.native,
              deck: value.deck,
              kind: value.kind,
              core: value.core,
              sha: value.sha256,
            ),
        };
        expect(changesFor('zz', now(), onPhone).fetch, hasLength(3));
      });
    });

    test('keeps a whole language GitHub no longer offers', () {
      final changes = changesFor('zz', const <IndexFile>[], <String, IndexFile>{
        'decks/zz/zz-en-a.yaml': _phone(
          'decks/zz/zz-en-a.yaml',
          native: 'en',
          deck: 'zz-a',
        ),
      });
      expect(changes.isEmpty, isTrue);
    });
  });
}
