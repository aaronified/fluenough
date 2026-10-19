import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/script_fonts.dart';
import 'package:fluenough/core/decks/sha256.dart';

const String _sha =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

const String _telugu = 'decks/fonts/telugu/NotoSansTelugu.ttf';

Map<String, Object?> _font({
  String path = _telugu,
  String script = 'telugu',
  Object? size = 900,
  Object? sha = _sha,
}) => <String, Object?>{
  'path': path,
  'size': size,
  'sha256': sha,
  'script': script,
  'family': 'Noto Sans Telugu',
};

/// An index of one language, `zz`, with [fonts] and one deck.
String _index(List<Object?> fonts) => jsonEncode(<String, Object?>{
  'version': 1,
  'languages': <Object?>[
    <String, Object?>{
      'code': 'zz',
      'name': 'Testlang',
      'files': <Object?>[
        <String, Object?>{
          'path': 'decks/zz/zz-en-home.yaml',
          'size': 10,
          'sha256': _sha,
          'schema': 1,
          'kind': 'vocab',
          'native': 'en',
          'deck': 'zz-home',
        },
      ],
      'fonts': fonts,
    },
  ],
});

IndexFont _indexed({String sha = _sha}) =>
    IndexFont(path: _telugu, size: 900, sha256: sha, script: 'telugu');

void main() {
  group('the index reads fonts', () {
    test('listed under a language, apart from its files', () {
      final zz = DeckIndex.parse(_index(<Object?>[_font()])).language('zz')!;
      expect(zz.fonts, hasLength(1));
      final font = zz.fonts.single;
      expect(font.path, _telugu);
      expect(font.size, 900);
      expect(font.sha256, _sha);
      expect(font.script, 'telugu');
      expect(font.family, 'Noto Sans Telugu');
      // Fonts are not files: nothing downloads them as decks, and the
      // language's own size does not count them.
      expect(zz.files.map((f) => f.path), <String>['decks/zz/zz-en-home.yaml']);
      expect(zz.media, isEmpty);
      expect(zz.size, 10);
      final downloaded = zz.filesFor(<String>['en']).map((f) => f.path);
      expect(downloaded, isNot(contains(_telugu)));
    });

    test('a language with none lists none', () {
      final zz = DeckIndex.parse(_index(<Object?>[])).language('zz')!;
      expect(zz.fonts, isEmpty);
    });

    test('an entry that is no font is passed by, and the decks still read', () {
      final index = DeckIndex.parse(
        _index(<Object?>[
          'not a font',
          _font(path: '../x.ttf'),
          _font(path: 'decks/fonts/telugu/x.yaml'),
          // In another script's folder than the one it names.
          _font(script: 'kannada'),
          _font(size: 0),
          _font(sha: 'abc'),
          _font(),
        ]),
      );
      final zz = index.language('zz')!;
      expect(zz.fonts.map((f) => f.path), <String>[_telugu]);
      expect(zz.files, hasLength(1));
    });

    test('the committed index lists the fonts a course needs, as files '
        'that match', () {
      final text = File('decks/index.json').readAsStringSync();
      final index = DeckIndex.parse(text);
      expect(index.language('te')!.fonts.map((f) => f.script), <String>[
        'telugu',
      ]);
      expect(index.language('hi')!.fonts.map((f) => f.script), <String>[
        'devanagari',
        'perso_arabic',
      ]);
      expect(index.language('es')!.fonts, isEmpty);
      for (final language in index.languages) {
        for (final font in language.fonts) {
          final bytes = File(font.path).readAsBytesSync();
          expect(bytes.length, font.size, reason: font.path);
          expect(sha256Hex(bytes), font.sha256, reason: font.path);
          expect(bytes.length, lessThan(2 * 1024 * 1024), reason: font.path);
          final licence = font.path.replaceFirst(RegExp(r'[^/]+$'), 'OFL.txt');
          expect(
            File(licence).existsSync(),
            isTrue,
            reason: 'the licence beside ${font.path}',
          );
        }
        // Never among the files the released app downloads.
        expect(
          index.filesByPath.keys.where((p) => p.startsWith('decks/fonts/')),
          isEmpty,
        );
      }
    });
  });

  group('the family a script is drawn in', () {
    test('is one per script, whatever font draws it', () {
      expect(scriptFontFamily('telugu'), 'FluenoughScript-telugu');
      expect(scriptFontFamily('perso_arabic'), 'FluenoughScript-perso_arabic');
      expect(scriptFontFamily('telugu'), isNot(scriptFontFamily('kannada')));
    });
  });

  group('changes', () {
    IndexFile deck() => const IndexFile(
      path: 'decks/zz/zz-en-home.yaml',
      size: 10,
      sha256: _sha,
      kind: 'vocab',
      native: 'en',
      deck: 'zz-home',
    );

    test('a font not on the phone is an update by itself', () {
      final changes = changesFor(
        'zz',
        <IndexFile>[deck()],
        <String, IndexFile>{deck().path: deck()},
        fonts: <IndexFont>[_indexed()],
      );
      expect(changes.isEmpty, isFalse);
      expect(changes.fetch, isEmpty);
      expect(changes.fonts.single.path, _telugu);
      expect(changes.bytes, 900);
    });

    test('a font on the phone as listed is no change', () {
      final changes = changesFor(
        'zz',
        <IndexFile>[deck()],
        <String, IndexFile>{deck().path: deck()},
        fonts: <IndexFont>[_indexed()],
        fontsOnPhone: <String, IndexFont>{_telugu: _indexed()},
      );
      expect(changes.isEmpty, isTrue);
    });

    test('a font whose file changed is fetched again', () {
      final changes = changesFor(
        'zz',
        <IndexFile>[deck()],
        <String, IndexFile>{deck().path: deck()},
        fonts: <IndexFont>[_indexed(sha: 'a' * 64)],
        fontsOnPhone: <String, IndexFont>{_telugu: _indexed()},
      );
      expect(changes.fonts, hasLength(1));
    });
  });
}
