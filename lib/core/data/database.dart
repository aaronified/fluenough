import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import 'daos.dart';
import 'tables/card_states.dart';
import 'tables/cards.dart';
import 'tables/converters.dart';
import 'tables/decks.dart';
import 'tables/reviews.dart';

part 'database.g.dart';

/// The loaded decks and the learner's progress, in SQLite through drift: the
/// four tables of `docs/DESIGN.md`, "Data model", and ADR-0005.
///
/// There is one database per profile. A profile's file holds its own
/// progress and nobody else's, so removing a profile removes one file.
/// Opening that file needs Flutter to find where files live, so it is the
/// app's job (#5, #6); this class takes any [QueryExecutor], and tests pass
/// `NativeDatabase.memory()`. Nothing here imports Flutter.
///
/// ## Migrations
///
/// [schemaVersion] is the number of the newest migration. A change to the
/// tables:
///
/// 1. is claimed in an issue first, since two migrations with one number
///    cannot both land (AGENTS.md rule 9);
/// 2. bumps [schemaVersion] by one and adds a step to `onUpgrade` for
///    `from < ` the new number, so that a phone on any older version
///    upgrades step by step;
/// 3. is additive: new tables, new nullable or defaulted columns, new
///    indexes. `reviews` is never dropped, rewritten or narrowed. `decks`,
///    `cards` and `card_states` may be rebuilt, since the first two come from
///    the deck files and the last from replaying `reviews`.
@DriftDatabase(
  tables: [Decks, Cards, CardStates, Reviews],
  daos: [DecksDao, CardsDao, CardStatesDao, ReviewsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 1: the four tables, and the triggers that keep `reviews` append-only.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _guardReviews();
    },
    onUpgrade: (m, from, to) async {
      // Version 1 is the first schema, so there is nothing to upgrade from.
    },
  );

  /// Makes SQLite itself refuse to change the review log, so that no code
  /// path, drift's own `update` and `delete` included, can rewrite history.
  Future<void> _guardReviews() async {
    for (final action in const <String>['UPDATE', 'DELETE']) {
      await customStatement(
        'CREATE TRIGGER reviews_no_${action.toLowerCase()} '
        'BEFORE $action ON reviews '
        "BEGIN SELECT RAISE(ABORT, 'reviews is append-only'); END",
      );
    }
  }
}
