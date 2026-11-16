/// A recommended work a learner marked completed (wiki
/// Plan-Deck-Kinds-And-Topics.md, D13, T25): learner state, kept in the
/// progress database and the backups, never in a deck or the index.
library;

class CompletedWork {
  const CompletedWork({
    required this.recommendationId,
    required this.language,
    required this.completedAt,
  });

  /// The recommendation's permanent id, `te-rec-kanyasulkam`.
  final String recommendationId;

  /// Its language, by code (`te`).
  final String language;

  /// When the learner marked it, in local time.
  final DateTime completedAt;

  @override
  bool operator ==(Object other) =>
      other is CompletedWork &&
      other.recommendationId == recommendationId &&
      other.language == language &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(recommendationId, language, completedAt);

  @override
  String toString() => 'CompletedWork($recommendationId)';
}
