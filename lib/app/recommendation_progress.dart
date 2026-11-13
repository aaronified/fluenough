import 'package:flutter/foundation.dart';

import '../core/data/daos.dart';
import '../core/decks/recommendations.dart';
import '../core/models/completed_work.dart';
import '../core/models/reading.dart' show ReadingQuestion;
import '../core/models/recommendation.dart';
import 'app_log.dart';

/// Where the completed marks are kept (wiki Plan-Deck-Kinds-And-Topics.md,
/// D13, T25): learner state in the progress database, never in a deck.
abstract interface class RecommendationMarkStore {
  /// Every mark kept.
  Future<List<CompletedWork>> load();

  /// Keeps [work]; marking a work already marked changes nothing.
  Future<void> mark(CompletedWork work);

  /// Forgets the mark of [recommendationId].
  Future<void> unmark(String recommendationId);

  /// Keeps each of [works] not kept yet, changing none; how many were added.
  Future<int> addMissing(Iterable<CompletedWork> works);
}

/// Marks kept in memory, for the tests and for a profile with no database.
class MemoryRecommendationMarkStore implements RecommendationMarkStore {
  final Map<String, CompletedWork> _marks = <String, CompletedWork>{};

  @override
  Future<List<CompletedWork>> load() async => _marks.values.toList();

  @override
  Future<void> mark(CompletedWork work) async {
    _marks.putIfAbsent(work.recommendationId, () => work);
  }

  @override
  Future<void> unmark(String recommendationId) async {
    _marks.remove(recommendationId);
  }

  @override
  Future<int> addMissing(Iterable<CompletedWork> works) async {
    var added = 0;
    for (final work in works) {
      if (!_marks.containsKey(work.recommendationId)) {
        _marks[work.recommendationId] = work;
        added++;
      }
    }
    return added;
  }
}

/// Marks kept in the progress database's `recommendation_marks` table.
class DatabaseRecommendationMarkStore implements RecommendationMarkStore {
  DatabaseRecommendationMarkStore(this._dao);

  final RecommendationMarksDao _dao;

  @override
  Future<List<CompletedWork>> load() => _dao.all();

  @override
  Future<void> mark(CompletedWork work) => _dao.mark(work);

  @override
  Future<void> unmark(String recommendationId) async {
    await _dao.unmark(recommendationId);
  }

  @override
  Future<int> addMissing(Iterable<CompletedWork> works) =>
      _dao.addMissing(works);
}

/// The recommended works a learner completed: the marks the homepage lists,
/// and the gate on their questions, which are asked only on a completed work
/// and stop when the mark is taken away.
///
/// Memory changes at once and the store is written behind it; a failed write
/// is logged, never thrown at the learner, and the mark stays for the session.
class RecommendationProgress extends ChangeNotifier {
  RecommendationProgress(this._store, {this._log});

  final RecommendationMarkStore _store;
  final AppLog? _log;
  final Map<String, CompletedWork> _marks = <String, CompletedWork>{};
  Future<void> _writes = Future<void>.value();

  /// Reads the marks kept. Never throws: what cannot be read is logged and
  /// there are none.
  Future<void> load() async {
    try {
      final works = await _store.load();
      _marks
        ..clear()
        ..addEntries(
          works.map(
            (w) => MapEntry<String, CompletedWork>(w.recommendationId, w),
          ),
        );
      notifyListeners();
    } on Object catch (e) {
      _log?.warning('Completed works could not be read: $e');
    }
  }

  /// The ids of the works marked completed.
  Set<String> get completedIds => Set<String>.unmodifiable(_marks.keys);

  /// Every mark, oldest first.
  List<CompletedWork> get completed =>
      <CompletedWork>[..._marks.values]
        ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

  bool isCompleted(String recommendationId) =>
      _marks.containsKey(recommendationId);

  /// Marks [recommendation] completed at [now]; again changes nothing.
  void complete(Recommendation recommendation, String language, DateTime now) {
    if (_marks.containsKey(recommendation.id)) return;
    final work = CompletedWork(
      recommendationId: recommendation.id,
      language: language,
      completedAt: now,
    );
    _marks[recommendation.id] = work;
    _write(() => _store.mark(work), 'while saving a completed work');
    notifyListeners();
  }

  /// Takes the mark away: its questions stop.
  void unmark(String recommendationId) {
    if (_marks.remove(recommendationId) == null) return;
    _write(
      () => _store.unmark(recommendationId),
      'while removing a completed work',
    );
    notifyListeners();
  }

  /// The questions of [recommendation] that may be asked now: all when it is
  /// completed, none otherwise.
  List<ReadingQuestion> questionsOf(Recommendation recommendation) =>
      openQuestions(recommendation, completedIds);

  /// Merges the marks of a backup in: each work not marked here is added, none
  /// is changed or removed. Returns how many were added.
  Future<int> importMarks(Iterable<CompletedWork> works) async {
    try {
      // The marks taken so far reach the store first, so a work marked a
      // moment ago is not counted as new.
      await _writes;
      final added = await _store.addMissing(works);
      for (final work in works) {
        _marks.putIfAbsent(work.recommendationId, () => work);
      }
      if (added > 0) notifyListeners();
      return added;
    } on Object catch (e) {
      _log?.warning('Completed works could not be imported: $e');
      return 0;
    }
  }

  /// Waits for the writes so far, for a test.
  @visibleForTesting
  Future<void> get settled => _writes;

  void _write(Future<void> Function() write, String what) {
    _writes = _writes.then((_) async {
      try {
        await write();
      } on Object catch (e) {
        _log?.warning('Recommendation marks failed $what: $e');
      }
    });
  }
}
