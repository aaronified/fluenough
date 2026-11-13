import 'package:drift/drift.dart';

import '../models/drill_mode.dart';
import '../models/leech_action.dart';
import 'daos.dart';
import 'restore_record.dart';
import 'review_erasure.dart';
import 'tables/card_states.dart';
import 'tables/cards.dart';
import 'tables/converters.dart';
import 'tables/decks.dart';
import 'tables/fsrs_parameters.dart';
import 'tables/leech_actions.dart';
import 'tables/placement_withdrawals.dart';
import 'tables/recommendation_marks.dart';
import 'tables/replay_snapshots.dart';
import 'tables/restores.dart';
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
    Restores,
    ReplaySnapshots,
    PlacementWithdrawals,
    RecommendationMarks,
  ],
  daos: [
    DecksDao,
    CardsDao,
    CardStatesDao,
    ReviewsDao,
    SettingsDao,
    LeechActionsDao,
    FsrsParametersDao,
    RestoresDao,
    ReplaySnapshotsDao,
    PlacementWithdrawalsDao,
    RecommendationMarksDao,
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
  ///    skill (ADR-0035).
  /// 8: `restores`, append-only: each restore that replaced the review log
  ///    (#470).
  /// 9: `reviews` gains `script` and `asked`: the script each answer was
  ///    shown or typed in, and how it was asked, for the script skills per
  ///    script (#653). Older rows keep null.
  /// 10: `replay_snapshots`, a cache of what replaying the review log gives,
  ///    checked against the log before each use (#857, ADR-0051). `reviews`
  ///    is not touched.
  /// 11: `placement_withdrawals`, append-only like `reviews`: placement
  ///    credit the learner took back, which the replay leaves out (wiki,
  ///    Plan-Placement-V2, point 17; issue #1063). `reviews` is not touched.
  /// 12: `recommendation_marks`, the recommended works a learner marked
  ///    completed (wiki Plan-Deck-Kinds-And-Topics.md, D13, T25). A plain
  ///    table, not append-only: un-marking deletes a row. `reviews` is not
  ///    touched.
  @override
  int get schemaVersion => currentSchemaVersion;

  /// [schemaVersion], for what needs it without a database: a backup says
  /// which schema it was made under (#470).
  static const int currentSchemaVersion = 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _appendOnly('reviews');
      await _appendOnly('leech_actions');
      await _appendOnly('restores');
      await _appendOnly('placement_withdrawals');
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
      if (from < 8) {
        // Once, as in step 5: the table and its triggers in one step.
        final exists = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'restores'",
        ).get();
        if (exists.isEmpty) {
          await m.createTable(restores);
          await _appendOnly('restores');
        }
      }
      if (from < 9) {
        // Each column once, as in step 5. Adding a column rewrites no row,
        // so the append-only triggers are not set off.
        final has = <String>{
          for (final row in await customSelect(
            "SELECT name FROM pragma_table_info('reviews')",
          ).get())
            row.read<String>('name'),
        };
        for (final column in <GeneratedColumn<Object>>[
          reviews.script,
          reviews.asked,
        ]) {
          if (!has.contains(column.name)) await m.addColumn(reviews, column);
        }
      }
      if (from < 10) {
        // Once, as in step 5: a step cut off part-way runs again. A new
        // table only: `reviews` and its triggers are not touched, and an
        // empty cache simply means the next launch replays the log.
        final exists = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'replay_snapshots'",
        ).get();
        if (exists.isEmpty) await m.createTable(replaySnapshots);
      }
      if (from < 11) {
        // Once, as in step 8: the table and its triggers in one step, so a
        // step cut off part-way runs again. `reviews` is not touched.
        final exists = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'placement_withdrawals'",
        ).get();
        if (exists.isEmpty) {
          await m.createTable(placementWithdrawals);
          await _appendOnly('placement_withdrawals');
        } else {
          // Cut off after the table: the triggers it lacks, each once.
          for (final action in const <String>['update', 'delete']) {
            final has = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'trigger' "
              "AND name = 'placement_withdrawals_no_$action'",
            ).get();
            if (has.isEmpty) {
              await _guard('placement_withdrawals', action.toUpperCase());
            }
          }
        }
      }
      if (from < 12) {
        // Once, as in step 10: a new table only, so a step cut off part-way
        // runs again. Nothing else is touched.
        final exists = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'recommendation_marks'",
        ).get();
        if (exists.isEmpty) await m.createTable(recommendationMarks);
      }
    },
  );

  /// Makes SQLite itself refuse to change [table], so that no code path,
  /// drift's own `update` and `delete` included, can rewrite history. The
  /// review log's triggers are `reviews_no_update` and `reviews_no_delete`.
  Future<void> _appendOnly(String table) async {
    for (final action in const <String>['UPDATE', 'DELETE']) {
      await _guard(table, action);
    }
  }

  Future<void> _guard(String table, String action) => customStatement(
    'CREATE TRIGGER ${table}_no_${action.toLowerCase()} '
    'BEFORE $action ON $table '
    "BEGIN SELECT RAISE(ABORT, '$table is append-only'); END",
  );

  /// The one exception to `reviews`, `leech_actions` and
  /// `placement_withdrawals` being append-only
  /// (AGENTS.md rule 9; owner, 2026-10-17: "Logged exception"): a restore
  /// the learner has confirmed, after a copy of what it replaces has been
  /// kept, empties both, and [refill] writes the backup's in their place.
  ///
  /// All in one transaction, with [restore] appended to `restores`, which
  /// counts the reviews before and after. Each table's delete trigger is
  /// dropped only for its own `DELETE` and created again at once, so the
  /// guard is back before [refill] runs; nothing else can delete a row, and
  /// a failure anywhere rolls everything back, the triggers included.
  /// Nothing but a restore calls this.
  Future<T> replaceLog<T>(RestoreRecord restore, Future<T> Function() refill) =>
      transaction(() async {
        final before = await _reviewCount();
        for (final table in <TableInfo<Table, Object?>>[
          reviews,
          leechActions,
          placementWithdrawals,
        ]) {
          final name = table.actualTableName;
          await customStatement('DROP TRIGGER ${name}_no_delete');
          await customUpdate(
            'DELETE FROM $name',
            updates: {table},
            updateKind: UpdateKind.delete,
          );
          await _guard(name, 'DELETE');
        }
        final result = await refill();
        await into(restores).insert(
          RestoresCompanion.insert(
            ts: restore.at,
            backupCreatedAt: restore.backupCreatedAt,
            backupKind: restore.backupKind,
            backupAppVersion: restore.backupAppVersion,
            fromFile: restore.fromFile,
            keptCopy: restore.keptCopy,
            reviewsBefore: before,
            reviewsAfter: await _reviewCount(),
          ),
        );
        return result;
      });

  /// The second exception to `reviews` being append-only (AGENTS.md rule 9;
  /// owner, 2026-11-07, #861): the learner deleted some of one language's
  /// reviews from its sheet in Languages I'm learning, after the app kept a
  /// backup of everything. Removes the reviews [erasure] selects and the
  /// language's leech actions whose pair has no review left (an action on a
  /// pair with no history means nothing), in one transaction, and returns
  /// how many reviews went. With the placement chosen, the language's
  /// `placement_withdrawals` go too: they only name credit that is gone.
  /// With only the answers chosen, the withdrawals stay with the credit. A review of another language is never touched.
  ///
  /// Each table's delete trigger is dropped only for this `DELETE` and
  /// created again at once, as [replaceLog] does, so the guard is back
  /// whatever happens next, and a failure rolls everything back, the
  /// triggers included. Nothing but a confirmed deletion calls this.
  Future<({int reviews, int withdrawals})> eraseReviews(
    ReviewErasure erasure,
  ) => transaction(() async {
    final code = erasure.language;
    final prefix = erasure.idPrefix;
    // A private package's cards (`fnpd-te-`) are found by their prefix alone:
    // the built-in `te-` cards beside them are another course's.
    final List<Variable<Object>> of = prefix == null
        ? [
            Variable<String>(code),
            Variable<int>(code.length + 1),
            Variable<String>('$code-'),
          ]
        : [Variable<int>(prefix.length), Variable<String>(prefix)];
    final ofLanguage = prefix == null
        ? 'card_id = ? OR substr(card_id, 1, ?) = ?'
        : 'substr(card_id, 1, ?) = ?';
    final rows = await customSelect(
      'SELECT id, card_id, ts, grade, elapsed_ms, answer_given, asked '
      'FROM reviews WHERE $ofLanguage',
      variables: of,
      readsFrom: {reviews},
    ).get();
    final ids = <int>[
      for (final row in rows)
        if (erasure.matches(
          row.read<String>('card_id'),
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('ts')),
          creditShape:
              row.read<int>('grade') == 5 &&
              row.read<int>('elapsed_ms') == 0 &&
              row.readNullable<String>('answer_given') == null &&
              (row.readNullable<String>('asked') ?? 'own') == 'own',
        ))
          row.read<int>('id'),
    ];
    // Placement's credit goes with its withdrawals, which only name it.
    final taken = erasure.placement
        ? <int>[
            for (final row in await customSelect(
              'SELECT id FROM placement_withdrawals WHERE language = ?',
              variables: [Variable<String>(code)],
              readsFrom: {placementWithdrawals},
            ).get())
              row.read<int>('id'),
          ]
        : <int>[];
    if (ids.isEmpty && taken.isEmpty) return (reviews: 0, withdrawals: 0);
    if (taken.isNotEmpty) await _deleteRows(placementWithdrawals, taken);
    if (ids.isNotEmpty) await _deleteRows(reviews, ids);
    final kept = <String>{
      for (final row in await customSelect(
        'SELECT DISTINCT card_id, mode FROM reviews WHERE $ofLanguage',
        variables: of,
        readsFrom: {reviews},
      ).get())
        '${row.read<String>('card_id')}|${row.read<String>('mode')}',
    };
    final orphaned = <int>[
      for (final row in await customSelect(
        'SELECT id, card_id, mode FROM leech_actions WHERE $ofLanguage',
        variables: of,
        readsFrom: {leechActions},
      ).get())
        if (!kept.contains(
          '${row.read<String>('card_id')}|${row.read<String>('mode')}',
        ))
          row.read<int>('id'),
    ];
    if (orphaned.isNotEmpty) await _deleteRows(leechActions, orphaned);
    return (reviews: ids.length, withdrawals: taken.length);
  });

  /// Deletes the rows of the append-only [table] with these [ids], 400 at a
  /// time, with the table's delete guard lifted for the statements and put
  /// back at once.
  Future<void> _deleteRows(
    TableInfo<Table, Object?> table,
    List<int> ids,
  ) async {
    final name = table.actualTableName;
    await customStatement('DROP TRIGGER ${name}_no_delete');
    for (var i = 0; i < ids.length; i += 400) {
      final end = i + 400 > ids.length ? ids.length : i + 400;
      final chunk = ids.sublist(i, end);
      await customUpdate(
        'DELETE FROM $name WHERE id IN '
        '(${List.filled(chunk.length, '?').join(',')})',
        variables: [for (final id in chunk) Variable<int>(id)],
        updates: {table},
        updateKind: UpdateKind.delete,
      );
    }
    await _guard(name, 'DELETE');
  }

  Future<int> _reviewCount() async => (await customSelect(
    'SELECT COUNT(*) AS n FROM reviews',
  ).getSingle()).read<int>('n');
}
