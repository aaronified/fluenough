// Fonts load after the first frame (#1699): open() leaves them, the fonts of
// the languages the learner learns and the content fonts load first, the rest
// after, a file two scripts share is read once, and the font list notifies in
// batches, not once per font.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deck_remote.dart';

class _CountingPhone extends MemoryDownloadedDecks {
  final List<String> reads = <String>[];

  @override
  Future<Uint8List?> readFont(String path) {
    reads.add(path);
    return super.readFont(path);
  }
}

String _hex(String c) => c * 64;

IndexFont _font(String script, String file, String sha) => IndexFont(
  path: 'decks/fonts/$script/$file.ttf',
  size: 1,
  sha256: _hex(sha),
  script: script,
);

void main() {
  final latin = _font('latin', 'NotoSans', 'a');
  final telugu = _font('telugu', 'NotoSansTelugu', 'b');
  final han = _font('han', 'NotoSansJP', 'c');
  final kana = _font('kana', 'NotoSansJP', 'c');
  final deva = _font('devanagari', 'NotoSansDevanagari', 'd');
  final bengali = _font('bengali', 'NotoSansBengali', 'e');
  final greek = _font('greek', 'NotoSansGreek', 'f');
  final cyrillic = _font('cyrillic', 'NotoSansCyrillic', '1');
  final all = <IndexFont>[
    latin,
    telugu,
    han,
    kana,
    deva,
    bengali,
    greek,
    cyrillic,
  ];

  late _CountingPhone phone;
  late List<String> registered;

  String index() => jsonEncode(<String, Object?>{
    'version': 1,
    'languages': <Object?>[
      <String, Object?>{
        'code': 'te',
        'name': 'Telugu',
        'files': <Object?>[],
        'fonts': <Object?>[telugu.toJson(), latin.toJson()],
      },
      <String, Object?>{
        'code': 'ja',
        'name': 'Japanese',
        'files': <Object?>[],
        'fonts': <Object?>[han.toJson(), kana.toJson()],
      },
      <String, Object?>{
        'code': 'hi',
        'name': 'Hindustani',
        'files': <Object?>[],
        'fonts': <Object?>[deva.toJson()],
      },
    ],
  });

  DeckDownloads downloads({bool defer = true}) {
    final d = DeckDownloads(
      fetcher: FakeDeckRemote(const <String, String>{}),
      files: phone,
      clock: () => DateTime(2026, 11, 22),
      deferFonts: defer,
      scriptFonts: ScriptFonts(
        register: (family, bytes) async => registered.add(family),
      ),
    )..learningLanguages = (() => const <String>['te']);
    addTearDown(d.dispose);
    return d;
  }

  setUp(() async {
    phone = _CountingPhone();
    registered = <String>[];
    phone.notes['index.json'] = index();
    await phone.putFonts(<IndexFont, List<int>>{
      for (final font in all) font: <int>[1, 2, 3],
    });
  });

  test('open leaves the fonts for after the first frame', () async {
    final d = downloads();
    await d.open();
    expect(registered, isEmpty);
    expect(d.fonts.hasFonts, isFalse);
    expect(phone.reads, isEmpty);
  });

  test('without deferring, open loads them all, as it always did', () async {
    final d = downloads(defer: false);
    await d.open();
    expect(registered, hasLength(all.length));
  });

  test('the learner\'s fonts and the content fonts come first, then the '
      'others, all of them', () async {
    final d = downloads();
    await d.open();
    await d.loadFontsInBackground();
    const first = <String>{
      'FluenoughScript-telugu',
      'FluenoughScript-latin',
      'FluenoughScript-greek',
      'FluenoughScript-cyrillic',
    };
    expect(registered.take(first.length).toSet(), first);
    expect(registered.toSet(), hasLength(all.length));
    expect(d.fonts.familyFor('han'), 'FluenoughScript-han');
    expect(d.fonts.familyFor('kana'), 'FluenoughScript-kana');
  });

  test('a file two scripts share is read once and registered for each '
      'script', () async {
    final d = downloads();
    await d.open();
    await d.loadFontsInBackground();
    expect(
      phone.reads.where((p) => p.endsWith('NotoSansJP.ttf')),
      hasLength(1),
    );
    expect(
      registered.where((f) => f == 'FluenoughScript-han' || f.endsWith('kana')),
      hasLength(2),
    );
  });

  test('the font list notifies in batches, not once per font', () async {
    final d = downloads();
    await d.open();
    var notified = 0;
    d.fonts.addListener(() => notified++);
    await d.loadFontsInBackground();
    expect(notified, greaterThan(0));
    expect(notified, lessThan(all.length));
  });

  test('without the index the learner\'s fonts are not known and all load '
      'in one pass', () async {
    phone.notes.remove('index.json');
    final d = downloads();
    await d.open();
    await d.loadFontsInBackground();
    expect(registered, hasLength(all.length));
  });

  test('nothing is loaded in the background without deferring', () async {
    final d = downloads(defer: false);
    await d.open();
    final before = registered.length;
    await d.loadFontsInBackground();
    expect(registered, hasLength(before));
  });

  group('ScriptFonts', () {
    test('notify: false waits for notifyLoaded, which tells once', () async {
      final fonts = ScriptFonts(register: (family, bytes) async {});
      var notified = 0;
      fonts.addListener(() => notified++);
      expect(await fonts.load(latin, Uint8List(1), notify: false), isTrue);
      expect(await fonts.load(telugu, Uint8List(1), notify: false), isTrue);
      expect(notified, 0);
      fonts.notifyLoaded();
      fonts.notifyLoaded();
      expect(notified, 1);
      expect(fonts.hasScript('latin'), isTrue);
      fonts.dispose();
    });

    test('load still notifies at once by default', () async {
      final fonts = ScriptFonts(register: (family, bytes) async {});
      var notified = 0;
      fonts.addListener(() => notified++);
      await fonts.load(latin, Uint8List(1));
      expect(notified, 1);
      fonts.dispose();
    });
  });
}
