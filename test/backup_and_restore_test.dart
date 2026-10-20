// Backup, restore and the log: a backup round-trips everything and refuses
// a newer, damaged or foreign file; five are kept, three from updates; a
// restore keeps a copy first, replaces both logs through replaceLog, logs
// a restores row, and a failure part-way leaves both; every other delete is
// still refused; a log import merges in time order; answers survive a
// restart and a stale state cache is repaired from the log.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/backup_files.dart';
import 'package:fluenough/app/backup_store.dart';
import 'package:fluenough/app/backups.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/profile_storage.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/update_checker.dart';
import 'package:fluenough/core/backup/zip_files.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/updates/apk_install.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/features/settings/settings_fixtures.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/backup_fixture.dart';
import 'support/harness.dart';

// From app_backup_test.dart.
final DateTime at = DateTime.utc(2026, 10, 17, 18, 40, 12, 345);

final List<LoggedReview> reviews = <LoggedReview>[
  (
    key: (cardId: 'hi-0231', mode: DrillMode.production),
    deckId: 'hi-en-market',
    at: DateTime.utc(2026, 9, 28, 19, 4, 5),
    grade: 4,
    elapsed: const Duration(milliseconds: 3120),
    answerGiven: 'बाज़ार',
    script: null,
    asked: null,
  ),
  (
    key: (cardId: 'bn-0012', mode: DrillMode.recognition),
    deckId: 'bn-en-water',
    at: DateTime.utc(2026, 9, 29, 7, 1),
    grade: 3,
    elapsed: const Duration(seconds: 2),
    answerGiven: null,
    script: null,
    asked: null,
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
  return jsonEncode(<String, Object?>{
    ...m.cast<String, Object?>(),
    ...changes,
  });
}

// From backups_test.dart.
/// Monday 28 September 2026, 19:00: `AppState.test`'s clock.
final DateTime _now = DateTime(2026, 9, 28, 19);

void answer(ProgressStore p, String card, int grade, DateTime at) => p.record(
  deckId: 'hi-en-market',
  cardId: card,
  mode: DrillMode.production,
  grade: grade,
  now: at,
  elapsed: const Duration(seconds: 2),
);

Map<ProgressKey, (double, double, int, DateTime, int)> byValue(
  Map<ProgressKey, FsrsState> states,
) => <ProgressKey, (double, double, int, DateTime, int)>{
  for (final e in states.entries)
    e.key: (
      e.value.stability,
      e.value.difficulty,
      e.value.intervalDays,
      e.value.dueAt,
      e.value.lapses,
    ),
};

({AppState state, FixedBackupFiles files, MemoryBackupStore store}) app({
  ProgressStore? progress,
  DateTime? now,
}) {
  final files = FixedBackupFiles();
  final store = MemoryBackupStore();
  final state = AppState.test(
    progress: progress,
    backupFiles: files,
    backupStore: store,
    now: now ?? _now,
  );
  addTearDown(state.dispose);
  return (state: state, files: files, store: store);
}

Uint8List _withVersion(Uint8List bytes, int version) {
  final files = ZipFiles.decode(bytes);
  final manifest =
      jsonDecode(utf8.decode(files['manifest.json']!)) as Map<String, Object?>;
  return ZipFiles.encode(<String, List<int>>{
    ...files,
    'manifest.json': utf8.encode(
      jsonEncode(<String, Object?>{...manifest, 'version': version}),
    ),
  });
}

// From backup_section_test.dart.
/// The shipped registry, in which restore is on (owner, 2026-10-17:
/// "Logged exception").
const FeatureRegistry _restoreOn = FeatureRegistry.shipped();

// From restore_log_test.dart.
/// A restore is the one exception to `reviews` and `leech_actions` being
/// append-only (AGENTS.md rule 9; owner, 2026-10-17: "Logged exception"):
/// it replaces both, in one transaction, and keeps a record of itself in
/// `restores`. Nothing else can delete from them.

// From log_jsonl_test.dart.
const ProgressKey pair = (cardId: 'hi-0231', mode: DrillMode.production);

const String header = '{"format":"fluenough-review-log","version":1}';

/// Everything a review holds, so two compare by value.
(ProgressKey, int, int, int, String?) fieldsOf(LoggedReview r) => (
  r.key,
  r.at.millisecondsSinceEpoch,
  r.grade,
  r.elapsed.inMilliseconds,
  r.answerGiven,
);

Matcher failsWith(String message) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', message),
);

// From log_backup_test.dart.

List<(String, int, int)> reviewsOf(ProgressStore p) => [
  for (final e in p.log) (e.cardId, e.grade, e.at.millisecondsSinceEpoch),
];

/// Imports [p]'s own export into [into]. How many reviews were new.
Future<int> restore(ProgressStore p, ProgressStore into) {
  final backup = LogJsonl.decode(p.exportJsonl());
  return into.importLog(
    backup.reviews,
    backup.leechActions,
    fitted: backup.fitted,
  );
}

// From database_progress_test.dart.
(double, double, int, DateTime, int, int) fields(FsrsState s) => (
  s.stability,
  s.difficulty,
  s.intervalDays,
  s.dueAt,
  s.repetitions,
  s.lapses,
);

// From stored_settings_test.dart.
/// Every setting changed from its default.
void changeAll(SettingsNotifier s) {
  s
    ..setSkillEnabled(Skill.listening, false)
    ..showRomanisation = false
    ..showIpa = false
    ..autoplay = true
    ..matchTapToHear = false
    ..countSpeakerTap()
    ..speechRate = 0.8
    ..themeMode = ThemeMode.dark
    ..seed = ThemeSeed.clay
    ..dynamicColour = true
    ..highContrast = true
    ..pureBlack = true
    ..setLearnsAlphabet('hi', false)
    ..cardTextScale = 1.2
    ..reminder = true
    ..reminderTime = const TimeOfDay(hour: 7, minute: 5)
    ..learningLanguages = const <String>['hi', 'bn']
    ..languageChoice = 'bn'
    ..placedDecks = const <String>{'hi-en-first-words', 'hi-en-questions'}
    ..learningChosen = true
    ..autoUpdateCheck = true
    ..autoAdjust = false
    ..lastUpdateCheck = DateTime(2026, 10, 1, 8, 30)
    ..latestRelease = '0.2.0'
    ..pendingUpdate = '0.2.0';
}

// From update_backup_test.dart.
final String _newer = SettingsFixtures.newerVersion;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the backup file', () {
    group('round trip', () {
      test(
        'everything comes back, and an older backup reads with defaults',
        () {
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

          {
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
          }
        },
      );
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
    });

    group('a file that is not a backup', () {
      test('random bytes, an empty or truncated file, a zip with no manifest '
          'or of another format, are not a backup', () {
        expect(() => AppBackup.decode(<int>[1, 2, 3]), throwsFormatException);
        expect(() => AppBackup.decode(const <int>[]), throwsFormatException);
        final good = make().encode();
        expect(
          () => AppBackup.decode(good.sublist(0, good.length ~/ 2)),
          throwsFormatException,
        );

        expect(
          () => AppBackup.decode(
            ZipFiles.encode(<String, List<int>>{'a.txt': utf8.encode('x')}),
          ),
          throwsFormatException,
        );
        expect(
          () => AppBackup.decode(
            file(<String, String?>{
              'manifest.json': manifestWith(<String, Object?>{
                'format': 'other',
              }),
            }),
          ),
          throwsFormatException,
        );
      });

      test('a damaged entry fails its checksum, and a path that climbs out is '
          'refused', () {
        final bytes = Uint8List.fromList(make().encode());
        // Flip a byte inside the manifest entry's data.
        bytes[60] ^= 0xff;
        expect(() => AppBackup.decode(bytes), throwsFormatException);

        {
          final bytes = ZipFiles.encode(<String, List<int>>{
            '../evil': utf8.encode('x'),
          });
          expect(() => ZipFiles.decode(bytes), throwsFormatException);
        }
      });
    });
  });

  group('backups', () {
    group('a backup of the app as it is', () {
      test('holds the log, every setting and the reviewer, byte for byte', () {
        final a = app();
        answer(a.state.progress, 'hi-0231', 4, _now);
        a.state.settings
          ..raterCode = 'FL-7K3M-Q9TD-6'
          ..reviewDecks = true
          ..speechRate = 0.8;
        final backup = a.state.backups.snapshot(BackupKind.you);
        expect(backup.log, a.state.progress.exportJsonl());
        expect(backup.settings, a.state.settings.toStored());
        expect(backup.settings['rater_code'], 'FL-7K3M-Q9TD-6');
        expect(backup.appVersion, isNotEmpty);
        expect(backup.schemaVersion, 9);
        final back = AppBackup.decode(backup.encode());
        expect(back.settings, a.state.settings.toStored());
        expect(back.reviews.single.key.cardId, 'hi-0231');
      });
    });

    group('the last ones are kept', () {
      test('five are kept, newest first, and only the last three an update '
          'made', () async {
        final a = app();
        var t = _now;
        Future<void> make(BackupKind kind) async {
          final one = AppState.test(
            backupStore: a.store,
            now: t = t.add(const Duration(minutes: 1)),
          );
          addTearDown(one.dispose);
          await one.backups.keep(kind);
        }

        for (var i = 0; i < 8; i++) {
          await make(BackupKind.you);
        }
        final list = await a.store.list();
        expect(list, hasLength(Backups.keepRecent));
        expect(Backups.keepRecent, 5);
        expect(list.first.createdAt, t);
        expect(
          list.map((b) => b.createdAt),
          orderedEquals(<DateTime>[
            for (var i = 0; i < 5; i++) t.subtract(Duration(minutes: i)),
          ]),
        );

        {
          final a = app();
          var t = _now;
          Future<void> make(BackupKind kind, [String? version]) async {
            final one = AppState.test(
              backupStore: a.store,
              now: t = t.add(const Duration(minutes: 1)),
            );
            addTearDown(one.dispose);
            await one.backups.keep(kind, forVersion: version);
          }

          await make(BackupKind.update, '0.5.1');
          await make(BackupKind.update, '0.5.2');
          await make(BackupKind.update, '0.5.3');
          await make(BackupKind.you);
          await make(BackupKind.update, '0.5.4');
          final list = await a.store.list();
          expect(Backups.keepUpdate, 3);
          expect(
            list,
            hasLength(4),
            reason: 'the oldest update went, not yours',
          );
          expect(
            list
                .where((b) => b.kind == BackupKind.update)
                .map((b) => b.info.forVersion),
            <String?>['0.5.4', '0.5.3', '0.5.2'],
          );
          expect(list.where((b) => b.kind == BackupKind.you), hasLength(1));
        }
      });
    });

    group(
      'restoring replaces everything, and keeps a copy of what it replaced',
      () {
        /// A learner with progress and settings, backed up, then another app.
        Future<
          (
            AppBackup,
            ({AppState state, FixedBackupFiles files, MemoryBackupStore store}),
          )
        >
        original() async {
          final source = app();
          for (var i = 0; i < 6; i++) {
            answer(
              source.state.progress,
              'hi-02${30 + i}',
              i.isEven ? 4 : 1,
              _now.add(Duration(days: i)),
            );
          }
          source.state.settings
            ..raterCode = 'FL-7K3M-Q9TD-6'
            ..reviewDecks = true
            ..speechRate = 0.7
            ..autoAdjust = false;
          final backup = AppBackup.decode(
            source.state.backups.snapshot(BackupKind.you).encode(),
          );
          final other = app();
          answer(other.state.progress, 'bn-0001', 3, _now);
          answer(other.state.progress, 'bn-0002', 3, _now);
          other.state.settings
            ..speechRate = 1.4
            ..showIpa = !other.state.settings.showIpa;
          return (backup, other);
        }

        test('a copy of what it replaced is kept first, and a file restored '
            'from is kept as it was read', () async {
          final (backup, other) = await original();
          final before = other.state.progress.exportJsonl();
          await other.state.backups.restore(backup, fromFile: true);
          final kept = await other.store.list();
          expect(
            kept.map((b) => b.kind),
            unorderedEquals(<BackupKind>[BackupKind.restore, BackupKind.file]),
          );
          final copy = AppBackup.decode(
            await other.store.read(
              kept.firstWhere((b) => b.kind == BackupKind.restore),
            ),
          );
          expect(copy.log, before, reason: 'the copy is of what was replaced');
          final file = AppBackup.decode(
            await other.store.read(
              kept.firstWhere((b) => b.kind == BackupKind.file),
            ),
          );
          expect(file.log, backup.log);
        });
      },
    );

    group('a file that cannot be restored changes nothing', () {
      test('a file that is not a backup, or from a newer Fluenough, changes '
          'nothing', () async {
        final a = app();
        a.files.toOpen = Uint8List.fromList(<int>[1, 2, 3, 4]);
        final before = a.state.settings.toStored();
        await expectLater(
          a.state.backups.pick(title: 'Pick'),
          throwsFormatException,
        );
        expect(a.state.settings.toStored(), before);
        expect(a.store.length, 0);

        {
          final a = app();
          final newer = AppBackup(
            appVersion: '0.7.0',
            schemaVersion: 7,
            createdAt: _now,
            log: a.state.progress.exportJsonl(),
            settings: const <String, String>{},
          ).encode();
          // Raise the manifest's version the way a newer app would.
          a.files.toOpen = _withVersion(newer, 2);
          await expectLater(
            a.state.backups.pick(title: 'Pick'),
            throwsA(isA<NewerBackupException>()),
          );
        }
      });
    });
  });

  group('Backup and restore', () {
    testWidgets('Back up now saves the file where the learner chooses, keeps a '
        'copy, and lists it', (tester) async {
      usePhone(tester);
      final files = FixedBackupFiles();
      final state = await pumpScreen(
        tester,
        const YourDataPage(),
        state: AppState.test(backupFiles: files),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.settingsDataBackupNow));
      await tester.pumpAndSettle();
      expect(files.saved, hasLength(1));
      expect(files.saved.single.name, endsWith('.fnbackup'));
      expect(find.text(l10n.settingsDataBackedUp), findsOneWidget);
      expect(state.backups.recent, hasLength(1));
      expect(find.text(l10n.settingsBackupMadeByYou('Sep 28')), findsOneWidget);
      expect(find.text(l10n.settingsBackupReviews(0)), findsOneWidget);
      expect(find.text(l10n.settingsDataRecentDesc), findsNothing);
    });

    group('Restore', () {
      testWidgets(
        'a restore shows what it holds first, keeps a copy, and when it '
        'fails leaves the app as it was',
        (tester) async {
          usePhone(tester);
          tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
          final app = await stateWithBackups(features: _restoreOn);
          await pumpScreen(tester, const YourDataPage(), state: app.state);
          final l10n = l10nOf(tester);
          final before = app.state.settings.toStored();
          await tester.tap(find.text(l10n.settingsBackupRestore).first);
          await tester.pumpAndSettle();

          expect(find.text(l10n.settingsRestoreTitle), findsOneWidget);
          expect(
            find.text(l10n.settingsBackupMadeByYou('Sep 28')),
            findsNWidgets(2),
          );
          expect(find.text(l10n.settingsRestoreByApp('0.5.0')), findsOneWidget);
          expect(
            find.text(
              l10n.settingsRestoreProgressIn(6, 'Bengali and Hindustani'),
            ),
            findsOneWidget,
          );
          expect(find.text(l10n.settingsRestoreAlsoText), findsOneWidget);
          expect(find.text(l10n.settingsRestoreNotRestored), findsOneWidget);
          expect(
            find.text(l10n.settingsRestoreDecks('Bengali and Hindustani')),
            findsOneWidget,
          );
          expect(find.text(l10n.settingsRestoreWarning), findsOneWidget);

          await tester.tap(find.text(l10n.commonCancel));
          await tester.pumpAndSettle();
          expect(find.text(l10n.settingsRestoreTitle), findsNothing);
          expect(app.state.settings.toStored(), before);
          expect(app.state.progress.log, isEmpty);
          expect(await app.store.list(), hasLength(5), reason: 'no copy kept');

          {
            usePhone(tester);
            tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
            final app = await stateWithBackups(features: _restoreOn);
            app.state.progress.record(
              deckId: 'hi-en-market',
              cardId: 'hi-0231',
              mode: DrillMode.production,
              grade: 3,
              now: DateTime(2026, 9, 28, 19),
            );
            await pumpScreen(tester, const YourDataPage(), state: app.state);
            final l10n = l10nOf(tester);
            await tester.tap(find.text(l10n.settingsBackupRestore).first);
            await tester.pumpAndSettle();
            await tester.tap(find.text(l10n.settingsRestoreConfirm));
            await tester.pumpAndSettle();

            expect(find.text(l10n.settingsDataRestored), findsOneWidget);
            expect(app.state.progress.log, hasLength(6));
            expect(
              app.state.progress.log.map((e) => e.cardId),
              isNot(contains('hi-0231')),
            );
            expect(app.state.settings.speechRate, 0.6);
            expect(
              find.text(l10n.settingsBackupBeforeRestore('Sep 28')),
              findsOneWidget,
            );
          }

          {
            usePhone(tester);
            final files = FixedBackupFiles();
            final state = AppState.test(
              features: _restoreOn,
              backupFiles: files,
              progress: FailingProgress(),
            );
            files.toOpen = fixtureBackup(at: DateTime(2026, 8, 1)).encode();
            state.settings.speechRate = 1.3;
            await pumpScreen(tester, const YourDataPage(), state: state);
            final l10n = l10nOf(tester);
            await tester.tap(find.text(l10n.settingsDataRestore));
            await tester.pumpAndSettle();
            await tester.tap(find.text(l10n.settingsRestoreConfirm));
            await tester.pumpAndSettle();
            expect(find.text(l10n.settingsDataRestoreFailed), findsOneWidget);
            expect(state.settings.speechRate, 1.3);
          }
        },
      );
    });
  });

  group('restoring the log', () {
    final at = DateTime(2026, 9, 28, 19);
    late AppDatabase db;
    late ReviewLog log;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      log = ReviewLog(db);
    });
    tearDown(() => db.close());

    LoggedReview logged(String card, int grade, DateTime when) => (
      key: (cardId: card, mode: DrillMode.production),
      deckId: 'hi-en-market',
      at: when,
      grade: grade,
      elapsed: const Duration(seconds: 2),
      answerGiven: null,
      script: null,
      asked: null,
    );

    RestoreRecord record() => RestoreRecord(
      at: at.add(const Duration(days: 10)),
      backupCreatedAt: at.add(const Duration(days: 3)),
      backupKind: 'you',
      backupAppVersion: '0.5.0',
      fromFile: true,
      keptCopy: 'fluenough-backup-20261008-190000-000-0-restore.fnbackup',
    );

    /// The learner's own progress: two reviews of Bengali and a leech set
    /// aside.
    Future<void> ownProgress() async {
      for (final card in <String>['bn-0001', 'bn-0002']) {
        await log.record(
          deckId: 'bn-en-core',
          cardId: card,
          mode: DrillMode.production,
          grade: 3,
          now: at,
        );
      }
      await log.act(
        LeechAction(
          at: at,
          key: (cardId: 'bn-0001', mode: DrillMode.production),
          kind: LeechActionKind.setAside,
        ),
      );
    }

    /// The backup's: three reviews of Hindi and a leech reset.
    final backupReviews = <LoggedReview>[
      logged('hi-0231', 4, at.add(const Duration(days: 1))),
      logged('hi-0232', 1, at.add(const Duration(days: 1, hours: 1))),
      logged('hi-0231', 5, at.add(const Duration(days: 2))),
    ];
    final backupActions = <LeechAction>[
      LeechAction(
        at: at.add(const Duration(days: 2, hours: 1)),
        key: (cardId: 'hi-0232', mode: DrillMode.production),
        kind: LeechActionKind.reset,
      ),
    ];

    Future<List<String>> triggers() => db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' ORDER BY name",
        )
        .map((r) => r.read<String>('name'))
        .get();

    const guards = <String>[
      'leech_actions_no_delete',
      'leech_actions_no_update',
      'restores_no_delete',
      'restores_no_update',
      'reviews_no_delete',
      'reviews_no_update',
    ];

    Matcher appendOnly(String table) => throwsA(
      predicate((Object e) => '$e'.contains('$table is append-only')),
    );

    /// A trigger runs once per row, so each table checked holds a row;
    /// `restores` is checked once a restore is in it.
    Future<void> expectEveryDeleteRefused({required bool restored}) async {
      for (final table in <String>[
        'reviews',
        'leech_actions',
        if (restored) 'restores',
      ]) {
        await expectLater(
          db.customStatement('DELETE FROM $table'),
          appendOnly(table),
          reason: table,
        );
      }
      await expectLater(db.delete(db.reviews).go(), appendOnly('reviews'));
      await expectLater(
        db.delete(db.leechActions).go(),
        appendOnly('leech_actions'),
      );
      await expectLater(
        db.update(db.reviews).write(const ReviewsCompanion(grade: Value(0))),
        appendOnly('reviews'),
      );
      if (!restored) return;
      await expectLater(
        db
            .update(db.restores)
            .write(const RestoresCompanion(keptCopy: Value('elsewhere'))),
        appendOnly('restores'),
      );
    }

    test('a confirmed restore replaces both logs with the backup\'s and logs '
        'when, from which backup, and where the copy is', () async {
      await ownProgress();
      await log.replaceAll(backupReviews, backupActions, restore: record());

      final reviews = await db.reviewsDao.all();
      expect(
        reviews.map((r) => (r.cardId, r.grade, r.ts)),
        backupReviews.map((r) => (r.key.cardId, r.grade, r.at)),
      );
      expect(reviews.first.intervalBefore, isNull);
      final actions = await db.leechActionsDao.all();
      expect(actions.map((a) => (a.key.cardId, a.kind, a.at)), <Object>[
        ('hi-0232', LeechActionKind.reset, backupActions.single.at),
      ]);
      // hi-0232 was reset after its last review, so only hi-0231 has a
      // schedule; Bengali has none.
      expect(
        (await db.cardStatesDao.all()).map((s) => s.cardId).toSet(),
        <String>{'hi-0231'},
        reason: 'the schedules are rebuilt from the backup\'s log alone',
      );

      final kept = (await db.restoresDao.all()).single;
      expect(kept.at, at.add(const Duration(days: 10)));
      expect(kept.backupCreatedAt, at.add(const Duration(days: 3)));
      expect(kept.backupKind, 'you');
      expect(kept.backupAppVersion, '0.5.0');
      expect(kept.fromFile, isTrue);
      expect(kept.keptCopy, record().keptCopy);
      expect((kept.reviewsBefore, kept.reviewsAfter), (2, 3));

      // A second restore adds a second record; the first is still there.
      await log.replaceAll(
        const <LoggedReview>[],
        const <LeechAction>[],
        restore: record(),
      );
      final both = await db.restoresDao.all();
      expect(both, hasLength(2));
      expect((both.last.reviewsBefore, both.last.reviewsAfter), (3, 0));
    });

    test('every other delete or update is still refused, before and after a '
        'restore, and the restore log itself is append-only', () async {
      await ownProgress();
      expect(await triggers(), guards);
      await expectEveryDeleteRefused(restored: false);

      await log.replaceAll(backupReviews, backupActions, restore: record());
      expect(await triggers(), guards, reason: 'the guards are back');
      await expectEveryDeleteRefused(restored: true);
      expect(await db.reviewsDao.all(), hasLength(3));
      expect(await db.leechActionsDao.all(), hasLength(1));
      expect(await db.restoresDao.all(), hasLength(1));
    });

    test('a restore that fails part-way leaves both logs, their guards and the '
        'restore log as they were', () async {
      await ownProgress();
      final reviewsBefore = await db.reviewsDao.all();
      final actionsBefore = await db.leechActionsDao.all();
      final statesBefore = await db.cardStatesDao.all();

      // Grade 9 is refused as the backup's reviews are written: after both
      // logs were emptied, inside the same transaction.
      await expectLater(
        log.replaceAll(
          <LoggedReview>[...backupReviews, logged('hi-0233', 9, at)],
          backupActions,
          restore: record(),
        ),
        throwsA(anything),
      );

      final reviewsAfter = await db.reviewsDao.all();
      expect(
        reviewsAfter.map((r) => (r.id, r.cardId, r.grade)),
        reviewsBefore.map((r) => (r.id, r.cardId, r.grade)),
      );
      expect(
        (await db.leechActionsDao.all()).map((a) => (a.key.cardId, a.kind)),
        actionsBefore.map((a) => (a.key.cardId, a.kind)),
      );
      expect(
        (await db.cardStatesDao.all()).map((s) => s.cardId),
        statesBefore.map((s) => s.cardId),
      );
      expect(await db.restoresDao.all(), isEmpty, reason: 'nothing is logged');
      expect(await triggers(), guards, reason: 'the dropped guard comes back');
      await expectEveryDeleteRefused(restored: false);
    });
  });

  group('the log file', () {
    final at = DateTime(2026, 9, 28, 19, 4, 5, 678);
    final reviews = <LoggedReview>[
      (
        key: pair,
        deckId: 'hi-en-market',
        at: at,
        grade: 4,
        elapsed: const Duration(milliseconds: 3120),
        answerGiven: 'बाज़ार',
        script: null,
        asked: null,
      ),
      (
        key: (cardId: 'bn-0246', mode: DrillMode.recognition),
        deckId: 'bn-en-market',
        at: at.add(const Duration(days: 1)),
        grade: 1,
        elapsed: Duration.zero,
        answerGiven: null,
        script: null,
        asked: null,
      ),
    ];
    final actions = <LeechAction>[
      LeechAction(
        at: at.add(const Duration(days: 2)),
        key: pair,
        kind: LeechActionKind.setAside,
      ),
    ];

    test('what is written reads back the same, fitted parameters included', () {
      final text = LogJsonl.encode(reviews, actions);
      final back = LogJsonl.decode(text);
      expect(back.reviews.map(fieldsOf), reviews.map(fieldsOf));
      expect(back.reviews.first.at.isUtc, isFalse, reason: 'local on reading');
      expect(back.leechActions, hasLength(1));
      final action = back.leechActions.single;
      expect(action.key, pair);
      expect(action.kind, LeechActionKind.setAside);
      expect(action.at, actions.single.at);

      final hear = FittedParameters(
        values: <double>[
          for (final (i, v) in Fsrs.w.indexed) v * (1 + i / 100),
        ],
        fittedAt: at.add(const Duration(days: 3)),
        reviewCount: 1234,
        lossBefore: 0.4123456789,
        lossAfter: 0.3987654321,
      );
      final fitted = <SkillKey, FittedParameters>{
        (language: 'hi', mode: DrillMode.production): FittedParameters(
          values: Fsrs.w,
          fittedAt: at.add(const Duration(days: 4)),
          reviewCount: 800,
        ),
        (language: 'hi', mode: DrillMode.listening): hear,
      };
      {
        final text = LogJsonl.encode(reviews, actions, fitted: fitted);
        final lines = const LineSplitter().convert(text);
        expect(lines, hasLength(6));
        // By language, then in the order of the modes.
        expect(jsonDecode(lines[5]), {
          'type': 'parameters',
          'ts': hear.fittedAt.toUtc().toIso8601String(),
          'language': 'hi',
          'mode': 'listening',
          'w': hear.values,
          'reviews': 1234,
          'loss_before': 0.4123456789,
          'loss_after': 0.3987654321,
        });
        expect(
          (jsonDecode(lines[4]) as Map).containsKey('loss_before'),
          isFalse,
        );
        expect((jsonDecode(lines[4]) as Map)['mode'], 'production');

        final back = LogJsonl.decode(text);
        expect(back.reviews.map(fieldsOf), reviews.map(fieldsOf));
        expect(back.fitted, fitted);
        final values =
            back.fitted[(language: 'hi', mode: DrillMode.listening)]!.values;
        for (var i = 0; i < 21; i++) {
          expect(values[i], hear.values[i], reason: 'w$i, to the last bit');
        }
      }
    });

    group('a file that is not a review log is refused, saying why', () {
      test('a log with no header, or from a newer version, is refused', () {
        expect(
          () => LogJsonl.decode(''),
          failsWith('not a Fluenough review log'),
        );
        expect(
          () => LogJsonl.decode('{"format":"anki"}'),
          failsWith('not a Fluenough review log'),
        );

        expect(
          () =>
              LogJsonl.decode('{"format":"fluenough-review-log","version":2}'),
          failsWith('log version 2 is newer than this app reads'),
        );
      });
    });
  });

  group('importing a log', () {
    // Each test opens two databases, each on its own in-memory executor, which
    // is what drift's warning is about.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final at = DateTime(2026, 9, 28, 19);
    DateTime day(int n) => at.add(Duration(days: n));

    const key = (cardId: 'hi-0231', mode: DrillMode.production);

    void answer(ProgressStore p, String card, int grade, DateTime now) =>
        p.record(
          deckId: 'hi-en-market',
          cardId: card,
          mode: DrillMode.production,
          grade: grade,
          now: now,
          answerGiven: 'बाज़ार',
        );

    Future<DatabaseProgress> openDb([AppDatabase? db]) async {
      final progress = await DatabaseProgress.open(
        db ?? AppDatabase(NativeDatabase.memory()),
      );
      addTearDown(progress.dispose);
      addTearDown(progress.close);
      return progress;
    }

    test('older history merged in takes its place in time, on the database and '
        'in memory', () async {
      // The phone that was lost answered on days 0 and 1; the new one on day 3.
      final old = MemoryProgress();
      answer(old, key.cardId, 4, day(0));
      answer(old, key.cardId, 5, day(1));

      // What one phone would hold had it answered all three.
      final whole = MemoryProgress();
      answer(whole, key.cardId, 4, day(0));
      answer(whole, key.cardId, 5, day(1));
      answer(whole, key.cardId, 2, day(3));

      for (final ProgressStore target in <ProgressStore>[
        await openDb(),
        MemoryProgress(),
      ]) {
        answer(target, key.cardId, 2, day(3));
        var told = 0;
        target.addListener(() => told++);

        expect(await restore(old, target), 2);
        expect(told, greaterThan(0), reason: '${target.runtimeType} notifies');
        expect(reviewsOf(target), reviewsOf(whole));
        expect(byValue(target.states), byValue(whole.states));
        expect(
          target.log.map((e) => e.before?.intervalDays),
          whole.log.map((e) => e.before?.intervalDays),
        );
      }
    });
  });

  group('answers in the database', () {
    final at = DateTime(2026, 9, 28, 19);
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('fluenough'));
    tearDown(() => dir.deleteSync(recursive: true));

    /// A database in a real file, so that it can be closed and opened again.
    AppDatabase fileDb() =>
        AppDatabase(NativeDatabase(File('${dir.path}/progress.sqlite')));

    void answer(ProgressStore p, String card, int grade, DateTime now) =>
        p.record(
          deckId: 'hi-en-market',
          cardId: card,
          mode: DrillMode.production,
          grade: grade,
          now: now,
        );

    test('answers survive closing the app and opening it again', () async {
      final first = await DatabaseProgress.open(fileDb());
      answer(first, 'hi-0231', 4, at);
      answer(first, 'hi-0232', 1, at);
      answer(first, 'hi-0231', 5, at.add(const Duration(days: 1)));
      final before = {
        for (final e in first.states.entries) e.key: fields(e.value),
      };
      await first.close();
      first.dispose();

      final again = await DatabaseProgress.open(fileDb());
      addTearDown(again.dispose);
      addTearDown(again.close);
      expect(again.persists, isTrue);
      expect(again.log.map((e) => (e.cardId, e.grade)), [
        ('hi-0231', 4),
        ('hi-0232', 1),
        ('hi-0231', 5),
      ]);
      expect({
        for (final e in again.states.entries) e.key: fields(e.value),
      }, before);
    });

    test('opening repairs a state cache that disagrees with the log; each '
        'profile has its own file', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await ReviewLog(db).record(
        deckId: 'hi-en-market',
        cardId: 'hi-0231',
        mode: DrillMode.recognition,
        grade: 5,
        now: at,
      );
      await db.cardStatesDao.clear();

      final progress = await DatabaseProgress.open(db);
      addTearDown(progress.dispose);
      addTearDown(progress.close);
      expect(await db.cardStatesDao.all(), hasLength(1));
      expect(progress.states, hasLength(1));

      expect(
        databaseFileName(const Profile(id: 'mira', name: 'Mira')),
        isNot(databaseFileName(Profile.defaultProfile)),
      );
    });
  });

  group('settings', () {
    test('every setting survives a restore; an unreadable value keeps a '
        'sensible setting', () {
      final changed = SettingsNotifier();
      changeAll(changed);
      // Saved at all: a key left out of toStored would round-trip as its
      // default on both sides, and pass.
      expect(changed.toStored()['pure_black'], 'true');
      expect(changed.toStored()['auto_adjust'], 'false');
      expect(SettingsNotifier().autoAdjust, isTrue, reason: 'on by default');
      final restored = SettingsNotifier()..restore(changed.toStored());
      expect(restored.toStored(), changed.toStored());
      expect(restored.toStored(), isNot(SettingsNotifier().toStored()));

      final s = SettingsNotifier()
        ..restore(const <String, String>{
          'speech_rate': 'NaN',
          'theme_mode': 'purple',
          'seed': '',
          'reminder_time': '25:00',
          'card_text_scale': '9',
          'show_romanisation': 'maybe',
          'show_ipa': 'maybe',
          'enabled_skills': 'recognition,unknown',
          'learning_languages': 'hi,Hindi,,bn',
          'placed_decks': 'hi-en-market,Not A Deck',
          'auto_update_check': 'sometimes',
          'last_update_check': 'yesterday',
          'latest_release': 'latest',
          'pending_update': 'app-release.apk',
        });
      final defaults = SettingsNotifier();
      expect(s.speechRate, defaults.speechRate);
      expect(s.themeMode, defaults.themeMode);
      expect(s.seed, defaults.seed);
      expect(s.reminderTime, defaults.reminderTime);
      expect(s.cardTextScale, SettingsNotifier.maxCardTextScale);
      expect(s.showRomanisation, defaults.showRomanisation);
      expect(s.showIpa, defaults.showIpa);
      // Reading is newer than a list with no marks, so it keeps its default.
      // Seen words, grammar and matching pairs have no switch, so they are
      // always on (#243).
      expect(s.enabledSkills, {
        Skill.recognition,
        Skill.grammar,
        Skill.reading,
        Skill.pair,
      });
      expect(s.learningLanguages, ['hi', 'bn']);
      expect(s.placedDecks, {'hi-en-market'});
      expect(s.autoUpdateCheck, isFalse);
      expect(s.lastUpdateCheck, isNull);
      expect(s.latestRelease, isNull);
      expect(s.pendingUpdate, isNull);
    });
  });

  group('the update backup', () {
    /// An app with a newer version offered, an installer that reports [events]
    /// after [gate], and [store] for the backups.
    (AppState, FixedApkInstaller) app({
      BackupStore? store,
      List<InstallEvent> events = const <InstallEvent>[
        InstallEvent.downloading(10),
        InstallEvent.installing(),
      ],
      Completer<void>? gate,
      DateTime? now,
    }) {
      final installer = FixedApkInstaller(events, gate: gate);
      final state = AppState.test(
        releases: FixedReleaseCheck(LatestRelease(_newer)),
        installer: installer,
        backupStore: store,
        now: now,
      );
      addTearDown(state.dispose);
      return (state, installer);
    }

    test('an update starts a backup with the download; a failed backup never '
        'blocks the update', () async {
      final gate = Completer<void>();
      final store = MemoryBackupStore();
      final (state, installer) = app(store: store, gate: gate);
      final done = state.updates.checkAndInstall();
      // The download is held at its first event; the backup is already kept.
      await pumpEventQueue();
      expect(state.updates.status, UpdateStatus.downloading);
      expect(installer.asked, hasLength(1));
      expect(store.length, 1);
      gate.complete();
      await done;
      expect(state.updates.status, UpdateStatus.installing);

      final (failing, failingInstaller) = app(store: FullBackupStore());
      await failing.updates.checkAndInstall();
      await pumpEventQueue();
      expect(failingInstaller.asked, hasLength(1));
      expect(failing.updates.status, UpdateStatus.installing);
      expect(failing.updates.backupFailed, isTrue);
    });
  });
}
