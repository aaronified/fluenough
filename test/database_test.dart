import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';

/// [db]'s `reviews` as it was before migration 5.
Future<void> withoutFsrsColumns(AppDatabase db) async {
  for (final column in <String>['stability_after', 'difficulty_after']) {
    await db.customStatement('ALTER TABLE reviews DROP COLUMN $column');
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Millisecond precision, in local time: what the columns keep.
  final at = DateTime(2026, 9, 29, 8, 30, 15, 250);

  ReviewsCompanion review({
    DrillMode mode = DrillMode.production,
    int grade = 4,
    DateTime? ts,
    bool first = true,
  }) => ReviewsCompanion.insert(
    ts: ts ?? at,
    deckId: 'hi-en-market',
    cardId: 'hi-0231',
    mode: mode,
    grade: grade,
    elapsedMs: 3200,
    answerGiven: const Value('kitne ka hai'),
    intervalBefore: first ? const Value.absent() : const Value(1),
    intervalAfter: 6,
    easeBefore: first ? const Value.absent() : const Value(2.5),
    easeAfter: 2.6,
  );

  LeechAction leechAction({LeechActionKind kind = LeechActionKind.setAside}) =>
      LeechAction(
        at: at,
        key: (cardId: 'hi-0231', mode: DrillMode.production),
        kind: kind,
      );

  test('opens at version 5 with its six tables', () async {
    expect(db.schemaVersion, 5);
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .map((r) => r.read<String>('name'))
        .get();
    expect(tables, <String>[
      'card_states',
      'cards',
      'decks',
      'leech_actions',
      'reviews',
      'settings',
    ]);
  });

  test('a version 1 database upgrades and keeps its reviews', () async {
    final dir = Directory.systemTemp.createTempSync('fluenough');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/old.sqlite');

    // Make a version 1 file: today's schema without what migrations 2, 3
    // and 5 add.
    final old = AppDatabase(NativeDatabase(file));
    await old.reviewsDao.append(review());
    await withoutFsrsColumns(old);
    await old.customStatement('DROP TABLE settings');
    await old.customStatement('DROP TABLE leech_actions');
    await old.customStatement('PRAGMA user_version = 1');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.settingsDao.put('speech_rate', '0.8');
    expect(await upgraded.settingsDao.all(), {'speech_rate': '0.8'});
    expect(await upgraded.reviewsDao.all(), hasLength(1));
    await expectLater(
      upgraded.customStatement('DELETE FROM reviews'),
      throwsA(anything),
      reason: 'the append-only triggers survive the upgrade',
    );
    await upgraded.leechActionsDao.append(leechAction());
    expect(await upgraded.leechActionsDao.all(), hasLength(1));
    await expectLater(
      upgraded.customStatement('DELETE FROM leech_actions'),
      throwsA(
        predicate((Object e) => '$e'.contains('leech_actions is append-only')),
      ),
      reason: 'migration 3 guards its table',
    );
  });

  test('a version 3 database\'s card_states is rebuilt without the deck '
      '(ADR-0018), and its reviews kept', () async {
    final dir = Directory.systemTemp.createTempSync('fluenough');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v3.sqlite');

    // Make a version 3 file: card_states keyed by deck, card and mode, with
    // one card in two decks.
    final old = AppDatabase(NativeDatabase(file));
    await old.reviewsDao.append(review());
    await withoutFsrsColumns(old);
    await old.customStatement('DROP TABLE card_states');
    await old.customStatement(
      'CREATE TABLE card_states (deck_id TEXT NOT NULL, card_id TEXT NOT NULL, '
      'mode TEXT NOT NULL, interval_days INTEGER NOT NULL, '
      'ease_factor REAL NOT NULL, repetitions INTEGER NOT NULL, '
      'due_at INTEGER NOT NULL, lapses INTEGER NOT NULL DEFAULT 0, '
      'PRIMARY KEY (deck_id, card_id, mode))',
    );
    for (final deck in <String>['hi-en-market', 'hi-en-groceries']) {
      await old.customStatement(
        "INSERT INTO card_states VALUES ('$deck', 'hi-0231', 'production', "
        '1, 2.5, 1, ${at.millisecondsSinceEpoch}, 0)',
      );
    }
    await old.customStatement('PRAGMA user_version = 3');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect(await upgraded.cardStatesDao.all(), isEmpty, reason: 'a cache');
    final columns = await upgraded
        .customSelect("SELECT name FROM pragma_table_info('card_states')")
        .get();
    expect(
      columns.map((r) => r.read<String>('name')),
      isNot(contains('deck_id')),
    );
    expect(await upgraded.reviewsDao.all(), hasLength(1));
  });

  test('a version 4 database gets FSRS\'s columns, its SM-2 state '
      'rebuilt and its reviews kept', () async {
    final dir = Directory.systemTemp.createTempSync('fluenough');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v4.sqlite');

    // Make a version 4 file: SM-2's card_states, and reviews without the
    // columns migration 5 adds.
    final old = AppDatabase(NativeDatabase(file));
    await old.reviewsDao.append(review());
    await withoutFsrsColumns(old);
    await old.customStatement('DROP TABLE card_states');
    await old.customStatement(
      'CREATE TABLE card_states (card_id TEXT NOT NULL, mode TEXT NOT NULL, '
      'interval_days INTEGER NOT NULL, ease_factor REAL NOT NULL, '
      'repetitions INTEGER NOT NULL, due_at INTEGER NOT NULL, '
      'lapses INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (card_id, mode))',
    );
    await old.customStatement(
      "INSERT INTO card_states VALUES ('hi-0231', 'production', "
      '1, 2.5, 1, ${at.millisecondsSinceEpoch}, 0)',
    );
    await old.customStatement('PRAGMA user_version = 4');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect(await upgraded.cardStatesDao.all(), isEmpty, reason: 'a cache');
    final reviews = await upgraded.reviewsDao.all();
    expect(reviews, hasLength(1));
    expect(reviews.single.stabilityAfter, isNull);
    expect(reviews.single.difficultyAfter, isNull);
    await expectLater(
      upgraded.customStatement('DELETE FROM reviews'),
      throwsA(anything),
      reason: 'the append-only triggers survive the upgrade',
    );
  });

  test('leech_actions: appended in order, never changed', () async {
    await db.leechActionsDao.append(leechAction(kind: LeechActionKind.reset));
    await db.leechActionsDao.append(
      leechAction(kind: LeechActionKind.undoReset),
    );
    final actions = await db.leechActionsDao.all();
    expect(actions.map((a) => a.kind), [
      LeechActionKind.reset,
      LeechActionKind.undoReset,
    ]);
    expect(actions.first.at, at);
    expect(actions.first.key.mode, DrillMode.production);
    for (final sql in [
      "UPDATE leech_actions SET kind = 'setAside'",
      'DELETE FROM leech_actions',
    ]) {
      await expectLater(
        db.customStatement(sql),
        throwsA(anything),
        reason: sql,
      );
    }
    expect(await db.leechActionsDao.all(), hasLength(2));
  });

  test('settings: stored by name, replaced on a second write', () async {
    await db.settingsDao.put('theme_mode', 'dark');
    await db.settingsDao.put('theme_mode', 'light');
    await db.settingsDao.put('seed', 'clay');
    expect(await db.settingsDao.all(), {'theme_mode': 'light', 'seed': 'clay'});
  });

  test('decks: written, read back, and replaced by id', () async {
    await db.decksDao.put(
      DecksCompanion.insert(
        id: 'hi-en-market',
        name: 'Market',
        kind: 'vocab',
        languageCode: 'hi',
        nativeCode: 'en',
        loadedAt: at,
      ),
    );
    final row = (await db.decksDao.byId('hi-en-market'))!;
    expect(row.name, 'Market');
    expect((row.languageCode, row.nativeCode), ('hi', 'en'));
    expect(row.loadedAt, at);

    await db.decksDao.put(
      row.copyWith(name: 'Market and money').toCompanion(true),
    );
    expect((await db.decksDao.all()).single.name, 'Market and money');
  });

  test('cards: a deck is replaced outright, in deck order', () async {
    CardsCompanion card(String id, int position, String target) =>
        CardsCompanion.insert(
          deckId: 'hi-en-market',
          cardId: id,
          position: position,
          target: target,
          native: 'how much',
        );
    await db.cardsDao.replaceDeck('hi-en-market', [
      card('hi-0232', 1, 'कितना'),
      card('hi-0231', 0, 'कितने का है?'),
    ]);
    expect(
      (await db.cardsDao.ofDeck('hi-en-market')).map((c) => c.cardId),
      <String>['hi-0231', 'hi-0232'],
    );
    expect(
      (await db.cardsDao.ofDeck('hi-en-market')).first.target,
      'कितने का है?',
    );

    await db.cardsDao.replaceDeck('hi-en-market', [
      card('hi-0233', 0, 'महँगा'),
    ]);
    expect(
      (await db.cardsDao.ofDeck('hi-en-market')).map((c) => c.cardId),
      <String>['hi-0233'],
    );
  });

  test('card_states: one row per card and mode', () async {
    CardStatesCompanion state(DrillMode mode, int interval) =>
        CardStatesCompanion.insert(
          cardId: 'hi-0231',
          mode: mode,
          stability: interval.toDouble(),
          difficulty: 5,
          intervalDays: interval,
          repetitions: 1,
          dueAt: at,
          lastReviewAt: at,
        );
    await db.cardStatesDao.put(state(DrillMode.recognition, 1));
    await db.cardStatesDao.put(state(DrillMode.production, 6));
    await db.cardStatesDao.put(state(DrillMode.recognition, 3));

    final recognition = (await db.cardStatesDao.of(
      'hi-0231',
      DrillMode.recognition,
    ))!;
    expect(recognition.intervalDays, 3, reason: 'replaced, not added');
    expect(recognition.dueAt, at);
    expect(recognition.lapses, 0);
    expect(await db.cardStatesDao.all(), hasLength(2));
    expect(await db.cardStatesDao.of('hi-0231', DrillMode.listening), isNull);
  });

  test(
    'reviews: appended and read back in order, first review nulls kept',
    () async {
      final first = await db.reviewsDao.append(review(grade: 3));
      final second = await db.reviewsDao.append(
        // An earlier clock time than the first: the log keeps append order.
        review(first: false, ts: at.subtract(const Duration(hours: 1))),
      );
      expect(second, greaterThan(first));

      final log = await db.reviewsDao.all();
      expect(log.map((r) => r.id), <int>[first, second]);
      expect(log.first.ts, at);
      expect(log.first.mode, DrillMode.production);
      expect(log.first.grade, 3);
      expect(log.first.elapsedMs, 3200);
      expect(log.first.answerGiven, 'kitne ka hai');
      expect((log.first.intervalBefore, log.first.easeBefore), (null, null));
      expect((log.last.intervalBefore, log.last.easeBefore), (1, 2.5));
      expect((log.last.intervalAfter, log.last.easeAfter), (6, 2.6));
    },
  );

  test('reviews: a grade outside 0 to 5 is refused', () async {
    for (final grade in <int>[-1, 6]) {
      await expectLater(
        db.reviewsDao.append(review(grade: grade)),
        throwsA(anything),
        reason: '$grade',
      );
    }
    expect(await db.reviewsDao.all(), isEmpty);
  });

  test(
    'reviews: SQLite refuses any update or delete, even from drift',
    () async {
      await db.reviewsDao.append(review());
      final Matcher appendOnly = throwsA(
        predicate(
          (Object e) => e.toString().contains('reviews is append-only'),
        ),
      );
      await expectLater(
        db.update(db.reviews).write(const ReviewsCompanion(grade: Value(0))),
        appendOnly,
      );
      await expectLater(db.delete(db.reviews).go(), appendOnly);
      await expectLater(db.customStatement('DELETE FROM reviews'), appendOnly);
      final log = await db.reviewsDao.all();
      expect(log.single.grade, 4);
    },
  );
}
