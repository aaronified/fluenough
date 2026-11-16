import 'package:drift/drift.dart';

import 'converters.dart';

/// The recommended works a learner marked completed (wiki
/// Plan-Deck-Kinds-And-Topics.md, D13, T25). Added by migration 12.
///
/// Learner state, not deck data: the mark (the recommendation's id and the
/// date) lives here and in the backups, never in a deck or the index. Unlike
/// `reviews` it is a plain table, not append-only: un-marking a work deletes
/// its row, which stops its questions. It is not part of the review log, so a
/// restore of the log and an erase of a language's reviews leave it be.
@DataClassName('RecommendationMarkRow')
class RecommendationMarks extends Table {
  /// The recommendation's permanent id, `te-rec-kanyasulkam`.
  TextColumn get recommendationId => text()();

  /// Its language, by code, so that a language's marks are found without
  /// reading the id.
  TextColumn get language => text()();

  /// When the learner marked it completed.
  IntColumn get completedAt => integer().map(const EpochMs())();

  @override
  Set<Column<Object>> get primaryKey => {recommendationId};
}
