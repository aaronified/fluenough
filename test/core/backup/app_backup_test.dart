import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/backup/app_backup.dart';
import 'package:fluenough/core/backup/zip_files.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';
import 'package:fluenough/core/scheduling/replay.dart';

final DateTime at = DateTime.utc(2026, 10, 17, 18, 40, 12, 345);

final List<LoggedReview> reviews = <LoggedReview>[
  (
    key: (cardId: 'hi-0231', mode: DrillMode.production),
    deckId: 'hi-en-market',
    at: DateTime.utc(2026, 9, 28, 19, 4, 5),
    grade: 4,
    elapsed: const Duration(milliseconds: 3120),
    answerGiven: 'बाज़ार',
  ),
  (
    key: (cardId: 'bn-0012', mode: DrillMode.recognition),
    deckId: 'bn-en-water',
    at: DateTime.utc(2026, 9, 29, 7, 1),
    grade: 3,
    elapsed: const Duration(seconds: 2),
    answerGiven: null,
  ),
];

final List<LeechAction> actions = <LeechAction>[
  LeechAction(
    at: DateTime.utc(2026, 9, 30),
    key: (cardId: 'hi-0231', mode: DrillMode.production),
    kind: LeechActionKind.reset,
  ),
];

/// Settings as `toStored` writes them, the reviewer's among them.
const Map<String, String> settings = <String, String>{
  'learning_languages': 'bn,hi',
  'language_choice': 'hi',
  'review_pairs': 'default',
  'collapsed_levels': '{"hi":["a1"]}',
  'theme_mode': 'dark',
  'review_decks': 'true',
  'rater_code': 'FL-7K3M-Q9TD-6',
  'review_intro_shown': 'true',
  'reviews': '{"hi-en-market":{"hi-0231":{"right":true}}}',
};

AppBackup make({
  String? log,
  Map<String, String> stored = settings,
  BackupKind kind = BackupKind.you,
  String? forVersion,
}) => AppBackup(
  appVersion: '0.5.0',
  schemaVersion: 7,
  createdAt: at,
  log: log ?? LogJsonl.encode(reviews, actions),
  settings: stored,
  downloads: const <String>['bn', 'hi'],
  kind: kind,
  forVersion: forVersion,
);

/// A backup file with [overrides] of its parts, as `ZipFiles` would hold it.
Uint8List file(Map<String, String?> overrides) {
  final files = ZipFiles.decode(make().encode());
  final out = <String, List<int>>{...files};
  for (final MapEntry(:key, :value) in overrides.entries) {
    if (value == null) {
      out.remove(key);
    } else {
      out[key] = utf8.encode(value);
    }
  }
  return ZipFiles.encode(out);
}

String manifestWith(Map<String, Object?> changes) {
  final files = ZipFiles.decode(make().encode());
  final m = jsonDecode(utf8.decode(files['manifest.json']!)) as Map;
  return jsonEncode(<String, Object?>{...m, ...changes});
}

void main() {
  group('round trip', () {
    test('everything comes back', () {
      final back = AppBackup.decode(make().encode());
      expect(back.appVersion, '0.5.0');
      expect(back.schemaVersion, 7);
      expect(back.createdAt.toUtc(), at);
      expect(back.settings, settings);
      expect(back.downloads, <String>['bn', 'hi']);
      expect(back.kind, BackupKind.you);
      expect(back.forVersion, isNull);
      expect(back.reviews, hasLength(2));
      expect(back.reviews.first.answerGiven, 'बाज़ार');
      expect(back.leechActions.single.kind, LeechActionKind.reset);
    });

    test('an update backup remembers its version', () {
      final back = AppBackup.decode(
        make(kind: BackupKind.update, forVersion: '0.5.1').encode(),
      );
      expect(back.kind, BackupKind.update);
      expect(back.forVersion, '0.5.1');
    });

    test('an empty app makes a backup that reads', () {
      final back = AppBackup.decode(
        make(
          log: LogJsonl.encode(const <LoggedReview>[], const <LeechAction>[]),
          stored: const <String, String>{},
        ).encode(),
      );
      expect(back.reviews, isEmpty);
      expect(back.settings, isEmpty);
    });

    test('the log part is byte-identical to LogJsonl.encode, so the old '
        'importer reads it', () {
      final expected = LogJsonl.encode(reviews, actions);
      final files = ZipFiles.decode(make().encode());
      expect(utf8.decode(files['log.jsonl']!), expected);
      expect(
        LogJsonl.decode(utf8.decode(files['log.jsonl']!)).reviews,
        hasLength(2),
      );
    });

    test('the parts are the plain files the format names, with the '
        'reviewer apart from the settings', () {
      final files = ZipFiles.decode(make().encode());
      expect(
        files.keys,
        unorderedEquals(<String>[
          'manifest.json',
          'log.jsonl',
          'settings.json',
          'reviewer.json',
          'downloads.json',
        ]),
      );
      final reviewer = jsonDecode(utf8.decode(files['reviewer.json']!)) as Map;
      expect(reviewer['rater_code'], 'FL-7K3M-Q9TD-6');
      expect(reviewer.keys.toSet(), AppBackup.reviewerKeys);
      final rest = jsonDecode(utf8.decode(files['settings.json']!)) as Map;
      expect(rest.keys, isNot(contains('rater_code')));
      expect(rest['learning_languages'], 'bn,hi');
      final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map;
      expect(manifest['format'], 'fluenough-backup');
      expect(manifest['version'], 1);
      expect(manifest['reviews'], 2);
    });

    test('it holds no deck files and nothing that restricts a profile', () {
      final files = ZipFiles.decode(make().encode());
      for (final name in files.keys) {
        expect(name, isNot(endsWith('.yaml')));
        expect(name, isNot(startsWith('decks/')));
      }
      final text = files.values.map(utf8.decode).join('\n');
      for (final word in <String>['pin', 'child', 'locked', 'held_off']) {
        expect(text.toLowerCase(), isNot(contains('"$word')), reason: word);
      }
    });

    test('the file name has the date and the extension', () {
      expect(
        AppBackup.fileName(DateTime(2026, 10, 7)),
        'fluenough-backup-2026-10-07.fnbackup',
      );
    });
  });

  group('versions', () {
    test('a newer backup format is refused, saying who made it', () {
      final bytes = file(<String, String?>{
        'manifest.json': manifestWith(<String, Object?>{
          'version': 2,
          'appVersion': '0.7.0',
        }),
      });
      expect(
        () => AppBackup.decode(bytes),
        throwsA(
          isA<NewerBackupException>()
              .having((e) => e.version, 'version', 2)
              .having((e) => e.appVersion, 'appVersion', '0.7.0'),
        ),
      );
    });

    test('unknown files, manifest keys and settings are ignored', () {
      final files = ZipFiles.decode(make().encode());
      final extra = <String, List<int>>{
        ...files,
        'profiles/ada/log.jsonl': utf8.encode('whatever'),
        'notes.txt': utf8.encode('hello'),
        'manifest.json': utf8.encode(
          manifestWith(<String, Object?>{
            'future': <int>[1, 2],
          }),
        ),
        'settings.json': utf8.encode(
          jsonEncode(<String, Object?>{
            'theme_mode': 'light',
            'a_later_setting': 'x',
            'a_number': 3,
          }),
        ),
      };
      final back = AppBackup.decode(ZipFiles.encode(extra));
      expect(back.settings['theme_mode'], 'light');
      expect(back.settings['a_later_setting'], 'x');
      expect(back.settings, isNot(contains('a_number')));
      expect(back.reviews, hasLength(2));
    });

    test('a missing part and a missing key read as their defaults', () {
      final back = AppBackup.decode(
        file(<String, String?>{
          'settings.json': null,
          'reviewer.json': null,
          'downloads.json': null,
          'log.jsonl': null,
        }),
      );
      expect(back.settings, isEmpty);
      expect(back.downloads, isEmpty);
      expect(back.reviews, isEmpty);
    });

    test('an older backup lacks a setting added later: it is not there', () {
      final back = AppBackup.decode(
        file(<String, String?>{
          'settings.json': jsonEncode(<String, String>{'theme_mode': 'dark'}),
        }),
      );
      expect(back.settings, isNot(contains('speech_rate')));
      expect(back.settings['theme_mode'], 'dark');
    });
  });

  group('a file that is not a backup', () {
    test('random bytes, empty and truncated files', () {
      expect(() => AppBackup.decode(<int>[1, 2, 3]), throwsFormatException);
      expect(() => AppBackup.decode(const <int>[]), throwsFormatException);
      final good = make().encode();
      expect(
        () => AppBackup.decode(good.sublist(0, good.length ~/ 2)),
        throwsFormatException,
      );
    });

    test('a zip with no manifest, or another format', () {
      expect(
        () => AppBackup.decode(
          ZipFiles.encode(<String, List<int>>{'a.txt': utf8.encode('x')}),
        ),
        throwsFormatException,
      );
      expect(
        () => AppBackup.decode(
          file(<String, String?>{
            'manifest.json': manifestWith(<String, Object?>{'format': 'other'}),
          }),
        ),
        throwsFormatException,
      );
    });

    test('a truncated log.jsonl, or a part that is not JSON', () {
      final good = LogJsonl.encode(reviews, actions);
      expect(
        () => AppBackup.decode(
          file(<String, String?>{
            'log.jsonl': good.substring(0, good.length - 40),
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => AppBackup.decode(
          file(<String, String?>{'settings.json': '{not json'}),
        ),
        throwsFormatException,
      );
    });

    test('a damaged entry fails its checksum', () {
      final bytes = Uint8List.fromList(make().encode());
      // Flip a byte inside the manifest entry's data.
      bytes[60] ^= 0xff;
      expect(() => AppBackup.decode(bytes), throwsFormatException);
    });
  });

  group('zip', () {
    test('files round trip, paths and UTF-8 included', () {
      final files = <String, List<int>>{
        'a.txt': utf8.encode('one'),
        'profiles/বাংলা/log.jsonl': utf8.encode('जल\n'),
        'empty': const <int>[],
      };
      final back = ZipFiles.decode(ZipFiles.encode(files));
      expect(back.keys, files.keys);
      for (final MapEntry(:key, :value) in files.entries) {
        expect(back[key], value, reason: key);
      }
    });

    test('a deflated entry, as another tool writes it, reads too', () {
      final data = utf8.encode('${'water ' * 200}\n');
      final stored = ZipFiles.encode(<String, List<int>>{'x': data});
      // Rewrite the one entry as deflate, by hand.
      final packed = ZLibCodec(raw: true).encode(data);
      final out = BytesBuilder();
      final view = ByteData.sublistView(stored);
      // local header
      final header = Uint8List.fromList(stored.sublist(0, 30 + 1));
      ByteData.sublistView(header)
        ..setUint16(8, 8, Endian.little)
        ..setUint32(18, packed.length, Endian.little);
      out
        ..add(header)
        ..add(packed);
      final directoryAt = out.length;
      final central = Uint8List.fromList(
        stored.sublist(
          view.getUint32(stored.length - 6, Endian.little),
          stored.length - 22,
        ),
      );
      ByteData.sublistView(central)
        ..setUint16(10, 8, Endian.little)
        ..setUint32(20, packed.length, Endian.little);
      out.add(central);
      final end = Uint8List.fromList(stored.sublist(stored.length - 22));
      ByteData.sublistView(end)
        ..setUint32(12, central.length, Endian.little)
        ..setUint32(16, directoryAt, Endian.little);
      out.add(end);
      expect(ZipFiles.decode(out.toBytes())['x'], data);
    });

    test('a path that climbs out is refused', () {
      final bytes = ZipFiles.encode(<String, List<int>>{
        '../evil': utf8.encode('x'),
      });
      expect(() => ZipFiles.decode(bytes), throwsFormatException);
    });

    test('crc32 matches the known value', () {
      expect(ZipFiles.crc32(utf8.encode('123456789')), 0xcbf43926);
    });
  });
}
