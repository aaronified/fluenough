/// A restore that replaced the review log, as `restores` keeps it (#470).
///
/// A restore is the one exception to the log being append-only (AGENTS.md
/// rule 9), and only one the learner has confirmed, after a copy of what it
/// replaces has been kept. This says which backup it was and where that
/// copy is. [reviewsBefore] and [reviewsAfter] are counted by the database
/// as it replaces the log, and are null on a record not yet kept.
class RestoreRecord {
  const RestoreRecord({
    required this.at,
    required this.backupCreatedAt,
    required this.backupKind,
    required this.backupAppVersion,
    required this.fromFile,
    required this.keptCopy,
    this.reviewsBefore,
    this.reviewsAfter,
  });

  /// When the restore replaced the log.
  final DateTime at;

  /// When the backup restored from was made.
  final DateTime backupCreatedAt;

  /// What made that backup, by its manifest's `kind`: `you`, `update`,
  /// `restore` or `file`.
  final String backupKind;

  /// The app version that made it.
  final String backupAppVersion;

  /// Whether it was a file the learner picked, not a backup kept here.
  final bool fromFile;

  /// The name of the copy of what was replaced, among the backups kept on
  /// the phone.
  final String keptCopy;

  final int? reviewsBefore;
  final int? reviewsAfter;
}
