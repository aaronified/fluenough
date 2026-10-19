import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/app/script_fonts.dart';
import 'package:fluenough/core/decks/deck_fetch.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/script_fonts.dart';
import 'package:fluenough/core/decks/sha256.dart';

import '../support/deck_remote.dart';

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

void main() {
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

  group('ScriptFonts', () {
    test('has a family for a script once its font is loaded', () async {
      final fonts = ScriptFonts(
        register: (family, bytes) async => registered[family] = bytes,
      );
      const font = IndexFont(
        path: _devanagari,
        size: 1,
        sha256: 'a',
        script: 'devanagari',
      );
      expect(fonts.familyFor('devanagari'), isNull);
      expect(fonts.familyFor(null), isNull);
      var notified = 0;
      fonts.addListener(() => notified++);
      expect(await fonts.load(font, Uint8List.fromList(<int>[1, 2])), isTrue);
      expect(fonts.familyFor('devanagari'), scriptFontFamily('devanagari'));
      expect(fonts.familyFor('bengali'), isNull);
      expect(registered.keys, <String>['FluenoughScript-devanagari']);
      expect(notified, 1);
      expect(fonts.isLoaded(font), isTrue);
      // The same file again is not loaded twice.
      await fonts.load(font, Uint8List.fromList(<int>[1, 2]));
      expect(registered, hasLength(1));
      expect(notified, 1);
    });

    test('a font the engine cannot read leaves its script in the phone\'s '
        'own font', () async {
      final fonts = ScriptFonts(
        register: (family, bytes) async => throw Exception('not a font'),
      );
      const font = IndexFont(
        path: _devanagari,
        size: 1,
        sha256: 'a',
        script: 'devanagari',
      );
      expect(await fonts.load(font, Uint8List(1)), isFalse);
      expect(fonts.familyFor('devanagari'), isNull);
      expect(fonts.hasFonts, isFalse);
    });
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

    test('counts the fonts among the files it downloads', () async {
      serve(<String, List<String>>{
        'hi': <String>[_devanagari],
      });
      final d = downloads();
      await d.open();
      final totals = <int>[];
      d.addListener(() {
        if (d.progressOf('hi') case final progress?) totals.add(progress.total);
      });
      await d.downloadFirst('hi', english);
      final first = d.index!.language('hi')!.firstFiles(english);
      expect(totals.first, first.length + 1);
    });

    test('a font shared by two courses downloads once', () async {
      serve(<String, List<String>>{
        'hi': <String>[_devanagari],
        'mr': <String>[_devanagari],
      });
      final d = downloads();
      await d.open();
      await d.downloadFirst('hi', english);
      await d.downloadFirst('mr', english);
      expect(remote.asked.where((p) => p == _devanagari), hasLength(1));
      expect(phone.fontFiles.keys, <String>[_devanagari]);
    });

    test('a font that does not match the index is thrown away and fails '
        'the download', () async {
      serve(<String, List<String>>{
        'hi': <String>[_devanagari],
      });
      remote.served[_devanagari] = 'something else';
      final d = downloads();
      await d.open();
      expect(await d.downloadFirst('hi', english), DeckDownloadFailure.badFile);
      expect(phone.fontFiles, isEmpty);
      expect(registered, isEmpty);
      expect(d.fonts.familyFor('devanagari'), isNull);
    });

    test('a font that cannot be reached says why, like a deck', () async {
      serve(<String, List<String>>{
        'hi': <String>[_devanagari],
      });
      remote.failures[_devanagari] = FetchFailure.offline;
      final d = downloads();
      await d.open();
      expect(await d.downloadFirst('hi', english), DeckDownloadFailure.offline);
      expect(d.failureOf('hi'), DeckDownloadFailure.offline);
    });

    test('a course with no font in the index downloads as before', () async {
      remote.index = indexFor(remote.files);
      final d = downloads();
      await d.open();
      expect(await d.downloadFirst('hi', english), isNull);
      expect(phone.fontFiles, isEmpty);
      expect(d.fonts.hasFonts, isFalse);
    });
  });

  group('at launch', () {
    test('loads the fonts on the phone, offline', () async {
      serve(<String, List<String>>{
        'hi': <String>[_devanagari],
      });
      final first = downloads();
      await first.open();
      await first.downloadFirst('hi', english);
      registered.clear();

      remote.failAll = FetchFailure.offline;
      final second = downloads();
      await second.open();
      expect(second.fonts.familyFor('devanagari'), isNotNull);
      expect(registered.keys, <String>['FluenoughScript-devanagari']);
    });
  });

  group('updates', () {
    test('bring the font a course did not have, and say so', () async {
      remote.index = indexFor(remote.files);
      final d = downloads();
      await d.open();
      await d.downloadFirst('hi', english);
      await d.downloadRest('hi', english);
      await d.checkForUpdates(english, force: true);
      expect(d.updates, isEmpty);

      serve(<String, List<String>>{
        'hi': <String>[_devanagari],
      });
      await d.checkForUpdates(english, force: true);
      final changes = d.updates['hi']!;
      expect(changes.fetch, isEmpty);
      expect(changes.fonts.map((f) => f.path), <String>[_devanagari]);
      expect(d.stateOf('hi', english), LanguageDownloadState.updateWaiting);

      final seen = <String>[];
      d.addListener(() {
        if (d.fontDownloading('hi') case final script?) seen.add(script);
      });
      expect(await d.update(<String>['hi']), isNull);
      expect(seen, contains('devanagari'));
      expect(phone.fontFiles.keys, <String>[_devanagari]);
      expect(d.updates, isEmpty);
      expect(d.fonts.familyFor('devanagari'), isNotNull);
    });
  });

  group('removing a course', () {
    test('keeps a font another course on the phone still uses', () async {
      serve(<String, List<String>>{
        'hi': <String>[_devanagari, _nastaliq],
        'mr': <String>[_devanagari],
      });
      final d = downloads();
      await d.open();
      await d.downloadFirst('hi', english);
      await d.downloadFirst('mr', english);
      await d.remove('hi');
      expect(phone.fontFiles.keys, <String>[_devanagari]);
      expect((await phone.fontManifest()).keys, <String>[_devanagari]);

      await d.remove('mr');
      expect(phone.fontFiles, isEmpty);
    });
  });
}
