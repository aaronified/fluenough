import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/review_event.dart';
import '../scheduling/fsrs.dart';
import 'database.dart';

/// Reads the scheduling state of every `(card, mode)` pair.
///
/// Writes go through `ReviewLog`, which keeps this state and the log in step.
class CardStateRepository {
  CardStateRepository(this._db);

  final AppDatabase _db;

  /// One pair's state, or null if it has never been reviewed.
  Future<FsrsState?> stateOf(String cardId, DrillMode mode) async =>
      (await _db.cardStatesDao.of(cardId, mode))?.toFsrsState();

  /// Every pair that has been reviewed, with its state.
  Future<Map<ProgressKey, FsrsState>> all() async => <ProgressKey, FsrsState>{
    for (final row in await _db.cardStatesDao.all())
      (cardId: row.cardId, mode: row.mode): row.toFsrsState(),
  };
}

/// A `card_states` row as the scheduler sees it.
extension CardStateRowToFsrs on CardStateRow {
  FsrsState toFsrsState() => FsrsState(
    stability: stability,
    difficulty: difficulty,
    intervalDays: intervalDays,
    dueAt: dueAt,
    lastReviewAt: lastReviewAt,
    repetitions: repetitions,
    lapses: lapses,
  );
}

/// An [FsrsState] as the `card_states` row for [key].
extension FsrsStateToRow on FsrsState {
  CardStatesCompanion toRow(ProgressKey key) => CardStatesCompanion.insert(
    cardId: key.cardId,
    mode: key.mode,
    stability: stability,
    difficulty: difficulty,
    intervalDays: intervalDays,
    repetitions: repetitions,
    dueAt: dueAt,
    lastReviewAt: lastReviewAt,
    lapses: Value(lapses),
  );
}
