import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import 'daos.dart';
import 'tables/card_states.dart';
import 'tables/cards.dart';
import 'tables/converters.dart';
import 'tables/decks.dart';
import 'tables/leech_actions.dart';
import 'tables/reviews.dart';
import 'tables/settings.dart';

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
  tables: [Decks, Cards, CardStates, Reviews, Settings, LeechActions],
  daos: [
    DecksDao,
    CardsDao,
    CardStatesDao,
    ReviewsDao,
    SettingsDao,
    LeechActionsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 1: the four tables, and the triggers that keep `reviews` append-only.
  /// 2: `settings` (#15).
  /// 3: `leech_actions`, append-only like `reviews` (#19).
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _appendOnly('reviews');
      await _appendOnly('leech_actions');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(settings);
      if (from < 3) {
        await m.createTable(leechActions);
        await _appendOnly('leech_actions');
      }
    },
  );

  /// Makes SQLite itself refuse to change [table], so that no code path,
  /// drift's own `update` and `delete` included, can rewrite history. The
  /// review log's triggers are `reviews_no_update` and `reviews_no_delete`.
  Future<void> _appendOnly(String table) async {
    for (final action in const <String>['UPDATE', 'DELETE']) {
      await customStatement(
        'CREATE TRIGGER ${table}_no_${action.toLowerCase()} '
        'BEFORE $action ON $table '
        "BEGIN SELECT RAISE(ABORT, '$table is append-only'); END",
      );
    }
  }
}
