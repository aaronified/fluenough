import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import 'daos.dart';
import 'tables/card_states.dart';
import 'tables/cards.dart';
import 'tables/converters.dart';
import 'tables/decks.dart';
import 'tables/fsrs_parameters.dart';
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
  tables: [
    Decks,
    Cards,
    CardStates,
    Reviews,
    Settings,
    LeechActions,
    FsrsParameters,
  ],
  daos: [
    DecksDao,
    CardsDao,
    CardStatesDao,
    ReviewsDao,
    SettingsDao,
    LeechActionsDao,
    FsrsParametersDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 1: the four tables, and the triggers that keep `reviews` append-only.
  /// 2: `settings` (#15).
  /// 3: `leech_actions`, append-only like `reviews` (#19).
  /// 4: `card_states` keyed by `(card_id, mode)`, without the deck (ADR-0018).
  /// 5: FSRS in place of SM-2: `card_states` holds FSRS's state, and
  ///    `reviews` gains `stability_after` and `difficulty_after`.
  /// 6: `reviews` loses SM-2's `ease_before` and `ease_after`; every row is
  ///    kept (owner, 2026-10-09).
  /// 7: `fsrs_parameters`, FSRS fitted to the learner per language and
  ///    skill (`docs/plans/skill-model.md`).
  @override
  int get schemaVersion => 7;

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
      if (from < 5) {
        // A cache, refilled from `reviews` whenever progress opens: by
        // `(card_id, mode)` since 4, with FSRS's state since 5.
        await m.deleteTable('card_states');
        await m.createTable(cardStates);
        // Each column once: a step cut off part-way runs again from the
        // start, and SQLite cannot add a column only if it is missing.
        final has = <String>{
          for (final row in await customSelect(
            "SELECT name FROM pragma_table_info('reviews')",
          ).get())
            row.read<String>('name'),
        };
        for (final column in <GeneratedColumn<Object>>[
          reviews.stabilityAfter,
          reviews.difficultyAfter,
        ]) {
          if (!has.contains(column.name)) await m.addColumn(reviews, column);
        }
      }
      if (from < 6) {
        // Dropping a column rewrites no row, so the append-only triggers
        // stay and are not set off. Each once, as in step 5.
        final has = <String>{
          for (final row in await customSelect(
            "SELECT name FROM pragma_table_info('reviews')",
          ).get())
            row.read<String>('name'),
        };
        for (final column in const <String>['ease_before', 'ease_after']) {
          if (has.contains(column)) {
            await customStatement('ALTER TABLE reviews DROP COLUMN $column');
          }
        }
      }
      if (from < 7) {
        // Once, as in step 5: a step cut off part-way runs again.
        final exists = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'fsrs_parameters'",
        ).get();
        if (exists.isEmpty) await m.createTable(fsrsParameters);
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
