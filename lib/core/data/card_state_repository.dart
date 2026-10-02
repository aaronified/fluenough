import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/review_event.dart';
import '../scheduling/sm2.dart';
import 'database.dart';

/// Reads the scheduling state of every `(card, mode)` pair.
///
/// Writes go through `ReviewLog`, which keeps this state and the log in step.
class CardStateRepository {
  CardStateRepository(this._db);

  final AppDatabase _db;

  /// One pair's state, or null if it has never been reviewed.
  Future<Sm2State?> stateOf(String cardId, DrillMode mode) async =>
      (await _db.cardStatesDao.of(cardId, mode))?.toSm2State();

  /// Every pair that has been reviewed, with its state.
  Future<Map<ProgressKey, Sm2State>> all() async => <ProgressKey, Sm2State>{
    for (final row in await _db.cardStatesDao.all())
      (cardId: row.cardId, mode: row.mode): row.toSm2State(),
  };
}

/// A `card_states` row as the scheduler sees it.
extension CardStateRowToSm2 on CardStateRow {
  Sm2State toSm2State() => Sm2State(
    repetitions: repetitions,
    easeFactor: easeFactor,
    intervalDays: intervalDays,
    dueAt: dueAt,
    lapses: lapses,
  );
}

/// An [Sm2State] as the `card_states` row for [key].
extension Sm2StateToRow on Sm2State {
  CardStatesCompanion toRow(ProgressKey key) => CardStatesCompanion.insert(
    cardId: key.cardId,
    mode: key.mode,
    intervalDays: intervalDays,
    easeFactor: easeFactor,
    repetitions: repetitions,
    dueAt: dueAt,
    lapses: Value(lapses),
  );
}
