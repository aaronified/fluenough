import 'dart:convert';
import 'dart:typed_data';

import '../data/log_jsonl.dart';
import '../models/completed_work.dart';
import '../models/leech_action.dart';
import '../scheduling/placement_withdrawal.dart';
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

  /// The copy made before a language's data was deleted from its sheet
  /// (#861). An older app reads it as made by the learner.
  delete,
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
    this.privateLanguages = const <String>[],
  });

  final String appVersion;
  final DateTime createdAt;
  final BackupKind kind;
  final String? forVersion;

  /// How many reviews the log holds.
  final int reviews;

  /// The names of the private languages the backup holds the packages of
  /// (#1017), for the restore screen; empty for a backup without any.
  final List<String> privateLanguages;

  /// The manifest of the backup file [bytes]. Throws what
  /// [AppBackup.decode] throws for a file it would refuse.
  static BackupInfo peek(List<int> bytes) =>
      AppBackup._manifestOf(ZipFiles.decode(bytes)).info;
}

/// A private language package a backup holds (#1017, Plan-Private-Languages
/// task 20): the `.fnzip` as the learner imported it, with what the phone
/// kept of it besides, which the file cannot say.
class BackupPrivatePackage {
  const BackupPrivatePackage({
    required this.id,
    required this.name,
    required this.revision,
    required this.kind,
    required this.active,
    required this.archive,
    this.retired = const <String>[],
  });

  /// `fnpd-<code>`.
  final String id;

  /// The language's name, for the restore screen.
  final String name;

  final int revision;

  /// `new-language` or `modified-language`.
  final String kind;

  /// Whether the catalog read it when the backup was made.
  final bool active;

  /// The `.fnzip`.
  final Uint8List archive;

  /// The card ids an update dropped: they stay retired after a restore.
  final List<String> retired;

  /// Whether [id] is a name a package is kept under, so that a backup that
  /// names a file outside its own folder is never followed.
  static bool isPackageId(String id) =>
      RegExp(r'^fnpd-[a-z]{2,3}$').hasMatch(id);
}

/// The whole app's backup (#470; docs/BACKUP-FORMAT.md): the review log,
/// every setting, the reviewer's code and answers, and the list of
/// downloaded languages, as one zip, `fluenough-backup-<date>.fnbackup`.
///
/// Deck files are never in it, and neither is anything that restricts a
/// profile: after a restore the decks download again. The one exception is
/// the learner's own private language packages (#1017), which exist nowhere
/// else: each is a `.fnzip` under `own-decks/`, with `own-decks.json` as the
/// index. An older reader ignores both. Plain data, in the core so that it
/// has no Flutter in it.
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
    this.privatePackages = const <BackupPrivatePackage>[],
    this.privateTombstones = const <String, List<String>>{},
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

  /// The private language packages on the phone, as imported (#1017).
  final List<BackupPrivatePackage> privatePackages;

  /// The card ids of private packages the learner removed, by package id: a
  /// package imported again may not give one of them to another card.
  final Map<String, List<String>> privateTombstones;

  /// The part that lists [privatePackages] and [privateTombstones].
  static const String privatePart = 'own-decks.json';

  /// The folder of the packages' files.
  static const String privateFolder = 'own-decks/';

  late final ({
    List<LoggedReview> reviews,
    List<LeechAction> leechActions,
    Map<SkillKey, FittedParameters> fitted,
    List<PlacementWithdrawal> withdrawals,
  })
  _parsed = LogJsonl.decode(log);

  /// The reviews in [log].
  List<LoggedReview> get reviews => _parsed.reviews;

  List<LeechAction> get leechActions => _parsed.leechActions;

  Map<SkillKey, FittedParameters> get fitted => _parsed.fitted;

  /// The placement credit the learner took back, as the log says. A backup
  /// from 0.9.1 or older has none.
  List<PlacementWithdrawal> get withdrawals => _parsed.withdrawals;

  /// The recommended works the learner marked completed, as the log's
  /// `completed` lines say (deck-kinds plan, D13, T25). A backup from before
  /// them has none; a line that does not read is skipped, never a failed
  /// restore.
  late final List<CompletedWork> completedWorks = LogJsonl.decodeCompletedWorks(
    log,
  );

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
      if (privatePackages.isNotEmpty || privateTombstones.isNotEmpty)
        privatePart: json(<String, Object?>{
          'packages': <Object?>[
            for (final p in privatePackages)
              <String, Object?>{
                'id': p.id,
                'name': p.name,
                'revision': p.revision,
                'kind': p.kind,
                'active': p.active,
                if (p.retired.isNotEmpty) 'retired': p.retired,
                'file': '$privateFolder${p.id}.fnzip',
              },
          ],
          if (privateTombstones.isNotEmpty) 'tombstones': privateTombstones,
        }),
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
      if (privatePackages.isNotEmpty)
        'privateLanguages': <String>[for (final p in privatePackages) p.name],
      'parts': parts.keys.toList(),
    });
    return ZipFiles.encode(<String, List<int>>{
      'manifest.json': utf8.encode(manifest),
      for (final MapEntry(:key, :value) in parts.entries)
        key: utf8.encode(value),
      // A `.fnzip` is deflated already: stored here, not squeezed twice.
      for (final p in privatePackages) '$privateFolder${p.id}.fnzip': p.archive,
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
      privatePackages: _privateOf(files),
      privateTombstones: _tombstonesOf(files),
    );
    // A log that does not read fails here, before anything is changed.
    backup.reviews;
    return backup;
  }

  /// This backup with the private language packages [packages] and the
  /// retired ids of removed ones, [tombstones] (#1017).
  AppBackup withPrivate(
    List<BackupPrivatePackage> packages,
    Map<String, List<String>> tombstones,
  ) => AppBackup(
    appVersion: appVersion,
    schemaVersion: schemaVersion,
    createdAt: createdAt,
    log: log,
    settings: settings,
    downloads: downloads,
    kind: kind,
    forVersion: forVersion,
    privatePackages: packages,
    privateTombstones: tombstones,
  );

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
    privatePackages: privatePackages,
    privateTombstones: privateTombstones,
  );

  /// The private packages [files] hold. A package the index lists whose file
  /// is not there, or whose id is not a package id, is left out: a part
  /// that does not read costs only itself, never the restore.
  static List<BackupPrivatePackage> _privateOf(Map<String, Uint8List> files) {
    final Map<String, Object?> index;
    try {
      index = _object(files, privatePart);
    } on FormatException {
      return const <BackupPrivatePackage>[];
    }
    final list = index['packages'];
    if (list is! List<Object?>) return const <BackupPrivatePackage>[];
    final found = <BackupPrivatePackage>[];
    for (final item in list) {
      if (item is! Map<String, Object?>) continue;
      final id = item['id'];
      final revision = item['revision'];
      if (id is! String ||
          !BackupPrivatePackage.isPackageId(id) ||
          revision is! int) {
        continue;
      }
      final archive = files['$privateFolder$id.fnzip'];
      if (archive == null) continue;
      final name = item['name'];
      final kind = item['kind'];
      final retired = item['retired'];
      found.add(
        BackupPrivatePackage(
          id: id,
          name: name is String ? name : id,
          revision: revision,
          kind: kind is String ? kind : 'new-language',
          active: item['active'] != false,
          archive: archive,
          retired: <String>[
            if (retired is List<Object?>)
              for (final r in retired)
                if (r is String) r,
          ],
        ),
      );
    }
    return found;
  }

  static Map<String, List<String>> _tombstonesOf(Map<String, Uint8List> files) {
    final Map<String, Object?> index;
    try {
      index = _object(files, privatePart);
    } on FormatException {
      return const <String, List<String>>{};
    }
    final raw = index['tombstones'];
    if (raw is! Map<String, Object?>) return const <String, List<String>>{};
    return <String, List<String>>{
      for (final MapEntry(:key, :value) in raw.entries)
        if (BackupPrivatePackage.isPackageId(key) && value is List<Object?>)
          key: <String>[
            for (final r in value)
              if (r is String) r,
          ],
    };
  }

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
    final privateLanguages = manifest['privateLanguages'];
    return (
      manifest: manifest,
      info: BackupInfo(
        appVersion: app is String ? app : '',
        createdAt: created?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        kind: BackupKind.values.asNameMap()[manifest['kind']] ?? BackupKind.you,
        forVersion: forVersion is String ? forVersion : null,
        reviews: reviews is int ? reviews : 0,
        privateLanguages: <String>[
          if (privateLanguages is List<Object?>)
            for (final name in privateLanguages)
              if (name is String) name,
        ],
      ),
    );
  }
}
