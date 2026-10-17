import 'dart:convert';
import 'dart:typed_data';

import '../data/log_jsonl.dart';
import '../models/leech_action.dart';
import '../scheduling/replay.dart';
import '../scheduling/skill_parameters.dart';
import 'zip_files.dart';

/// What made a backup, which Recent backups names it by.
enum BackupKind {
  /// The learner's Back up now.
  you,

  /// Made as an app update began to download.
  update,

  /// The copy of what a restore was about to replace.
  restore,

  /// A file the learner restored from, kept as it was read.
  file,
}

/// A backup file is from a newer Fluenough than this one: nothing is read
/// from it, and the learner is told to update first.
class NewerBackupException implements Exception {
  const NewerBackupException({required this.version, this.appVersion});

  /// The backup format version the file has.
  final int version;

  /// The app that made it, such as `0.7.0`, if it says.
  final String? appVersion;

  @override
  String toString() => 'backup format $version is newer than this app reads';
}

/// What a backup's manifest says of it, read without its log: enough to
/// name it in Recent backups.
class BackupInfo {
  const BackupInfo({
    required this.appVersion,
    required this.createdAt,
    required this.kind,
    required this.forVersion,
    required this.reviews,
  });

  final String appVersion;
  final DateTime createdAt;
  final BackupKind kind;
  final String? forVersion;

  /// How many reviews the log holds.
  final int reviews;

  /// The manifest of the backup file [bytes]. Throws what
  /// [AppBackup.decode] throws for a file it would refuse.
  static BackupInfo peek(List<int> bytes) =>
      AppBackup._manifestOf(ZipFiles.decode(bytes)).info;
}

/// The whole app's backup (#470; docs/BACKUP-FORMAT.md): the review log,
/// every setting, the reviewer's code and answers, and the list of
/// downloaded languages, as one zip, `fluenough-backup-<date>.fnbackup`.
///
/// Deck files are never in it, and neither is anything that restricts a
/// profile: after a restore the decks download again. Plain data, in the
/// core so that it has no Flutter in it.
class AppBackup {
  AppBackup({
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.log,
    required this.settings,
    this.downloads = const <String>[],
    this.kind = BackupKind.you,
    this.forVersion,
  });

  /// The manifest's `format`.
  static const String format = 'fluenough-backup';

  /// The newest backup format this app reads and writes.
  static const int version = 1;

  /// The file extension, without its dot.
  static const String extension = 'fnbackup';

  /// The settings the reviewer part holds, apart from the rest. A setting
  /// not named here is in the settings part.
  static const Set<String> reviewerKeys = <String>{
    'review_decks',
    'rater_code',
    'review_intro_shown',
    'reviews',
  };

  /// The file's name for a backup made at [at].
  static String fileName(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'fluenough-backup-${at.year}-${two(at.month)}-${two(at.day)}'
        '.$extension';
  }

  /// The app version that made it.
  final String appVersion;

  /// The database's schema version then. Only informational: every part is
  /// read by its own format, never by table rows.
  final int schemaVersion;

  final DateTime createdAt;

  /// The review log, leech actions and fitted parameters, as `LogJsonl`
  /// writes them, unchanged.
  final String log;

  /// Every setting, as `SettingsNotifier.toStored` writes it, with the
  /// reviewer's among them.
  final Map<String, String> settings;

  /// The codes of the languages whose decks were on the phone.
  final List<String> downloads;

  final BackupKind kind;

  /// For an [BackupKind.update] backup, the version it was made for.
  final String? forVersion;

  late final ({
    List<LoggedReview> reviews,
    List<LeechAction> leechActions,
    Map<SkillKey, FittedParameters> fitted,
  })
  _parsed = LogJsonl.decode(log);

  /// The reviews in [log].
  List<LoggedReview> get reviews => _parsed.reviews;

  List<LeechAction> get leechActions => _parsed.leechActions;

  Map<SkillKey, FittedParameters> get fitted => _parsed.fitted;

  /// The backup as a file's bytes.
  Uint8List encode() {
    final reviewer = <String, String>{
      for (final MapEntry(:key, :value) in settings.entries)
        if (reviewerKeys.contains(key)) key: value,
    };
    final rest = <String, String>{
      for (final MapEntry(:key, :value) in settings.entries)
        if (!reviewerKeys.contains(key)) key: value,
    };
    String json(Object? value) => jsonEncode(value);
    final parts = <String, String>{
      'log.jsonl': log,
      'settings.json': json(rest),
      'reviewer.json': json(reviewer),
      'downloads.json': json(<String, Object>{'languages': downloads}),
    };
    final manifest = json(<String, Object?>{
      'format': format,
      'version': version,
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'kind': kind.name,
      if (forVersion != null) 'forVersion': forVersion,
      'reviews': reviews.length,
      'parts': parts.keys.toList(),
    });
    return ZipFiles.encode(<String, List<int>>{
      'manifest.json': utf8.encode(manifest),
      for (final MapEntry(:key, :value) in parts.entries)
        key: utf8.encode(value),
    }, at: createdAt.toUtc());
  }

  /// The backup in [bytes]. Throws [NewerBackupException] for one a newer
  /// app made, and [FormatException] for a file that is not a backup, or
  /// has a damaged part. A part that is missing, and a setting that is not
  /// there, are left to their defaults; a file or key it does not know is
  /// ignored.
  static AppBackup decode(List<int> bytes) {
    final files = ZipFiles.decode(bytes);
    final (:manifest, :info) = _manifestOf(files);
    final logBytes = files['log.jsonl'];
    final String log;
    if (logBytes == null) {
      log = LogJsonl.encode(const <LoggedReview>[], const <LeechAction>[]);
    } else {
      try {
        log = utf8.decode(logBytes);
      } on FormatException {
        throw const FormatException('log.jsonl is damaged');
      }
    }
    final settings = <String, String>{
      for (final part in <String>['settings.json', 'reviewer.json'])
        for (final MapEntry(:key, :value) in _object(files, part).entries)
          if (value is String) key: value,
    };
    final languages = _object(files, 'downloads.json')['languages'];
    final schema = manifest['schemaVersion'];
    final backup = AppBackup(
      appVersion: info.appVersion,
      schemaVersion: schema is int ? schema : 0,
      createdAt: info.createdAt,
      log: log,
      settings: settings,
      downloads: <String>[
        if (languages is List)
          for (final code in languages)
            if (code is String) code,
      ],
      kind: info.kind,
      forVersion: info.forVersion,
    );
    // A log that does not read fails here, before anything is changed.
    backup.reviews;
    return backup;
  }

  /// This backup as another [kind], made now: the copy a restore keeps of
  /// a file it was given.
  AppBackup copyAs(BackupKind kind, DateTime at) => AppBackup(
    appVersion: appVersion,
    schemaVersion: schemaVersion,
    createdAt: at,
    log: log,
    settings: settings,
    downloads: downloads,
    kind: kind,
  );

  static Map<String, Object?> _object(
    Map<String, Uint8List> files,
    String name, {
    bool required = false,
  }) {
    final raw = files[name];
    if (raw == null) {
      if (required) throw FormatException('not a backup file: no $name');
      return const <String, Object?>{};
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(raw));
    } on FormatException {
      throw FormatException('$name is damaged');
    }
    if (decoded is! Map<String, Object?>) {
      throw FormatException('$name is damaged');
    }
    return decoded;
  }

  static ({Map<String, Object?> manifest, BackupInfo info}) _manifestOf(
    Map<String, Uint8List> files,
  ) {
    final manifest = _object(files, 'manifest.json', required: true);
    if (manifest['format'] != format) {
      throw const FormatException('not a Fluenough backup');
    }
    final v = manifest['version'];
    if (v is! int || v < 1) {
      throw const FormatException('not a Fluenough backup: no version');
    }
    final app = manifest['appVersion'];
    if (v > version) {
      throw NewerBackupException(
        version: v,
        appVersion: app is String ? app : null,
      );
    }
    final created = DateTime.tryParse('${manifest['createdAt']}');
    final forVersion = manifest['forVersion'];
    final reviews = manifest['reviews'];
    return (
      manifest: manifest,
      info: BackupInfo(
        appVersion: app is String ? app : '',
        createdAt: created?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        kind: BackupKind.values.asNameMap()[manifest['kind']] ?? BackupKind.you,
        forVersion: forVersion is String ? forVersion : null,
        reviews: reviews is int ? reviews : 0,
      ),
    );
  }
}
