// A card's own recording (#518): read from its deck, listed in the index
// under `media`, downloaded with the decks, kept beside them, credited, and
// played in place of the phone's voice.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/card_media.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_downloads.dart';
import 'package:fluenough/app/downloaded_decks.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/decks/deck_index.dart';
import 'package:fluenough/core/decks/sha256.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/tts/clip_player.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/settings/sources_page.dart';

import '../support/deck_remote.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';
const recording = 'decks/zz/audio/zz-9001.opus';

const credit =
    '{ source: "https://commons.wikimedia.org/wiki/File:Te-ఇల్లు.ogg", '
    'license: "CC-BY-SA-4.0", credit: "A. Speaker" }';

/// The B1 fixture's files, its home core's ఇల్లు (illu) with a recording.
Map<String, String> withRecording() => <String, String>{
  for (final file in Directory(appendix).listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/zz/${file.path.substring('$appendix/'.length)}': file
          .readAsStringSync()
          .replaceFirst(
            '    reading: "illu"\n',
            '    reading: "illu"\n    audio: "$recording"\n'
                '    audio_credit: $credit\n',
          ),
  recording: 'OggS, as it were',
};

/// Finds every recording at [path] on the phone.
class _At implements CardMedia {
  const _At(this.path);

  final String path;

  @override
  String? localPath(String path) => '${this.path}/$path';
}

const testlang = LanguageInfo(
  code: 'zz',
  iso639_3: 'zzz',
  name: 'Testlang',
  script: 'telugu',
  tts: 'te-IN',
);

void main() {
  group('a deck', () {
    test('reads a core card\'s recording and its credit', () {
      final files = withRecording();
      final catalog = DeckCatalog.parseAll(<String, String>{
        for (final MapEntry(:key, :value) in files.entries)
          if (key.endsWith('.yaml')) key: value,
      });
      expect(catalog.broken, isEmpty);
      final house = catalog.decks
          .expand((d) => d.cards)
          .firstWhere((c) => c.id == 'zz-9001');
      expect(house.audio, recording);
      expect(house.audioCredit?.credit, 'A. Speaker');
      expect(house.audioCredit?.license, 'CC-BY-SA-4.0');
      expect(house.audioCredit?.source, contains('commons.wikimedia.org'));
    });

    test('reads a single-file card\'s, and refuses a credit of another '
        'shape', () {
      String deck(String credit) =>
          '''
schema: 1
id: "zz-en-home"
name: "Home"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "telugu" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC-BY-SA-4.0"
cards:
  - { id: "zz-9001", target: "ఇల్లు", reading: "illu", native: "home", audio: "$recording", audio_credit: $credit }
''';
      final card = DeckParser.parse(deck(credit), source: 'x').cards.single;
      expect(card.audioCredit?.credit, 'A. Speaker');
      expect(
        () => DeckParser.parse(
          deck('{ source: "x", license: "y", by: "z" }'),
          source: 'x',
        ),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  group('the index', () {
    test('lists recordings under media, which download after the decks', () {
      final index = DeckIndex.parse(indexFor(withRecording()));
      final zz = index.language('zz')!;
      expect(zz.media.map((f) => f.path), <String>[recording]);
      expect(zz.files.map((f) => f.path), isNot(contains(recording)));
      expect(zz.media.single.isMedia, isTrue);
      expect(zz.filesFor(const <String>['en']).last.path, recording);
      expect(
        zz.firstFiles(const <String>['en']).map((f) => f.path),
        isNot(contains(recording)),
      );
      expect(index.filesByPath[recording]?.kind, 'audio');
    });

    test('refuses a media path outside a language\'s folders', () {
      final json = jsonDecode(indexFor(withRecording())) as Map;
      final zz = (json['languages'] as List).single as Map;
      (zz['media'] as List).single['path'] = 'decks/zz/audio/../x.opus';
      expect(
        () => DeckIndex.parse(jsonEncode(json)),
        throwsA(isA<FormatException>()),
      );
      (zz['media'] as List).single['path'] = 'decks/zz/zz-home.yaml';
      expect(
        () => DeckIndex.parse(jsonEncode(json)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('downloads', () {
    test('fetch a language\'s recordings, kept beside its decks', () async {
      final remote = FakeDeckRemote(withRecording());
      final phone = MemoryDownloadedDecks();
      final d = DeckDownloads(
        fetcher: remote,
        files: phone,
        clock: () => DateTime(2026, 10, 15),
      );
      await d.open();
      expect(await d.downloadFirst('zz', const <String>['en']), isNull);
      expect(phone.files.keys, isNot(contains(recording)));
      expect(d.missing('zz', const <String>['en']).single.path, recording);
      expect(await d.downloadRest('zz', const <String>['en']), isNull);
      expect(utf8.decode(phone.files[recording]!), 'OggS, as it were');
      expect(d.missing('zz', const <String>['en']), isEmpty);
      // A recording is no deck: the catalog never reads it as one.
      expect(await phone.list(), isNot(contains(recording)));
      expect(
        d.stateOf('zz', const <String>['en']),
        LanguageDownloadState.upToDate,
      );
    });

    test('on the phone, a recording is found by its path, and kept '
        'after a restart', () async {
      final dir = Directory.systemTemp.createTempSync('fluenough-media');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileDownloadedDecks(Directory('${dir.path}/downloaded'));
      final bytes = utf8.encode('OggS');
      final file = IndexFile(
        path: recording,
        size: bytes.length,
        sha256: sha256Hex(bytes),
        kind: 'audio',
      );
      await store.putAll(<IndexFile, List<int>>{file: bytes});
      expect(
        store.localPath(recording),
        '${dir.path}/downloaded/$recording',
      );
      expect(store.localPath('decks/zz/audio/zz-9002.opus'), isNull);
      expect(store.localPath('decks/zz/zz-home.yaml'), isNull);
      expect(await store.list(), isEmpty);
      final again = FileDownloadedDecks(Directory('${dir.path}/downloaded'));
      expect((await again.manifest())[recording]?.sha256, file.sha256);
      await again.removeLanguage('zz');
      expect(again.localPath(recording), isNull);
    });
  });

  group('playing a card', () {
    Card house({String? audio = recording}) => Card(
      id: 'zz-9001',
      deckId: 'zz-en-home',
      target: 'ఇల్లు',
      native: 'home',
      audio: audio,
    );

    test('plays its recording in place of the phone\'s voice', () async {
      final clips = FakeClipPlayer();
      final tts = FixedTtsEngine(const <String>{'te'});
      final state = AppState.test(
        tts: tts,
        clips: clips,
        media: const _At('/phone'),
      );
      addTearDown(state.dispose);
      expect(await state.speakCard(house(), testlang), isNull);
      expect(clips.played, <(String, double)>[('/phone/$recording', 1.0)]);
      expect(tts.spoken, isEmpty);
      await state.speakCard(house(), testlang, slower: true);
      expect(clips.played.last.$2, 0.7);
    });

    test('speaks it with the phone\'s voice without one on the phone, or '
        'when it cannot play', () async {
      final clips = FakeClipPlayer();
      final tts = FixedTtsEngine(const <String>{'te'});
      final state = AppState.test(tts: tts, clips: clips);
      addTearDown(state.dispose);
      await state.speakCard(house(), testlang);
      expect(clips.played, isEmpty);
      expect(tts.spoken.single.text, 'ఇల్లు');

      final failing = FakeClipPlayer()..failure = StateError('no codec');
      final other = AppState.test(
        tts: tts,
        clips: failing,
        media: const _At('/phone'),
      );
      addTearDown(other.dispose);
      await other.speakCard(house(), testlang);
      expect(tts.spoken, hasLength(2));
      await other.speakCard(house(audio: null), testlang);
      expect(tts.spoken, hasLength(3));
    });
  });

  group('credits', () {
    test('a recording credits Wikimedia Commons, and its speaker by '
        'language', () {
      final catalog = DeckCatalog.parseAll(<String, String>{
        for (final MapEntry(:key, :value) in withRecording().entries)
          if (key.endsWith('.yaml')) key: value,
      });
      expect(creditsOf(catalog.decks), contains(ContentCredit.commons));
      final media = mediaCreditsOf(catalog.decks);
      expect(media.single.language.code, 'zz');
      expect(media.single.lines, <MediaCreditLine>[
        (credit: 'A. Speaker', license: 'CC-BY-SA-4.0'),
      ]);
    });
  });
}
