// The question bank of Find my level V3 as the app keeps it: the stored form,
// the background build with its progress, the kept copy read back at once, a
// copy dropped when the decks change or it is damaged, a failure that can be
// retried, and the real isolate path (over a fixture too small to give
// items: the path is what is tested).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/app/placement_bank.dart';
import 'package:fluenough/core/placement/item_bank.dart';
import 'package:fluenough/core/placement/item_codec.dart';
import 'package:fluenough/core/placement/item_registry.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/find_level_fixture.dart';
import 'support/memory_blob_store.dart';
import 'support/v3_small_bank.dart';

/// A runner that counts its calls and makes the small bank.
class _Runner {
  int calls = 0;
  Object? failWith;

  Future<List<RegItem>?> call(
    PlacementLanguageData data,
    void Function(double) onProgress,
    bool Function() cancelled,
    void Function(List<RegItem>) onStarter,
  ) async {
    calls++;
    onProgress(0.5);
    if (failWith != null) throw failWith!;
    return smallV3Bank();
  }
}

void main() {
  group('the stored form', () {
    test('every item reads back as it was', () {
      final items = smallV3Bank();
      final back = decodeItems(encodeItems(items))!;
      expect(back.length, items.length);
      for (var i = 0; i < items.length; i++) {
        final a = items[i];
        final b = back[i];
        expect(
          <Object?>[
            b.id,
            b.format,
            b.cardId,
            b.deck,
            b.prompt,
            b.options,
            b.correct,
            b.tiles,
            b.answerTiles,
            b.accepted,
            b.gapIndex,
            b.lemmas,
          ],
          <Object?>[
            a.id,
            a.format,
            a.cardId,
            a.deck,
            a.prompt,
            a.options,
            a.correct,
            a.tiles,
            a.answerTiles,
            a.accepted,
            a.gapIndex,
            a.lemmas,
          ],
        );
      }
    });

    test('damaged text and another schema are not a bank', () {
      expect(decodeItems('not json'), isNull);
      expect(decodeItems('{"schema": 999, "items": []}'), isNull);
      expect(
        decodeItems('{"schema": $kItemSchema, "items": [{"id": 1}]}'),
        isNull,
      );
    });

    test('a bank of the old schema, or an item of a removed format, is out', () {
      expect(decodeItems('{"schema": 3, "items": []}'), isNull);
      const gone =
          '{"id": "c1:F16", "f": "F16", "c": "c1", "d": 1, "p": "x"}';
      final text = '{"schema": $kItemSchema, "items": [$gone]}';
      expect(decodeItems(text), isEmpty);
    });
  });

  group('the banks of an app', () {
    test('a bank is made once, kept, and read back with no build', () async {
      final store = MemoryBlobStore();
      final runner = _Runner();
      final banks = PlacementBanks(store: store, runner: runner.call);
      final data = findLevelData();
      final job = banks.jobFor(data);
      expect(identical(banks.jobFor(data), job), isTrue);
      final items = await job.result;
      await Future<void>.delayed(Duration.zero);
      expect(items, isNotEmpty);
      expect(job.progress.value, 1);
      expect(runner.calls, 1);
      expect(store.data.keys.single, PlacementBanks.keyOf(data));

      // Another launch: the kept copy is read, the runner is not called.
      final later = _Runner();
      final again = PlacementBanks(store: store, runner: later.call);
      final read = await again.jobFor(data).result;
      expect(read.length, items.length);
      expect(later.calls, 0);
    });

    test('a changed deck set drops the old copy and builds again', () async {
      final store = MemoryBlobStore();
      final runner = _Runner();
      final banks = PlacementBanks(store: store, runner: runner.call);
      await banks.jobFor(findLevelData()).result;
      await Future<void>.delayed(Duration.zero);
      final before = store.data.keys.single;
      await banks.jobFor(findLevelData(decks: 7)).result;
      await Future<void>.delayed(Duration.zero);
      expect(runner.calls, 2);
      expect(store.data.keys.single, isNot(before));
      expect(
        PlacementBanks.keyOf(findLevelData(decks: 7)),
        store.data.keys.single,
      );
    });

    test('a damaged copy is dropped and built again', () async {
      final store = MemoryBlobStore();
      final data = findLevelData();
      store.data[PlacementBanks.keyOf(data)] = Uint8List.fromList(
        utf8.encode('{"schema": 1, "items": [broken'),
      );
      final runner = _Runner();
      final banks = PlacementBanks(store: store, runner: runner.call);
      expect(await banks.jobFor(data).result, isNotEmpty);
      expect(runner.calls, 1);
    });

    test(
      'storage that cannot be read or written still gives the bank',
      () async {
        final store = MemoryBlobStore()
          ..failReads = true
          ..failWrites = true;
        final runner = _Runner();
        final banks = PlacementBanks(store: store, runner: runner.call);
        expect(await banks.jobFor(findLevelData()).result, isNotEmpty);
      },
    );

    test('a failure is reported and a new request tries again', () async {
      final runner = _Runner()..failWith = StateError('boom');
      final banks = PlacementBanks(runner: runner.call);
      final data = findLevelData();
      final job = banks.jobFor(data);
      await expectLater(job.result, throwsStateError);
      expect(job.failed, isTrue);
      runner.failWith = null;
      final retry = banks.jobFor(data);
      expect(identical(retry, job), isFalse);
      expect(await retry.result, isNotEmpty);
    });

    test('a cancelled build is dropped and starts again on request', () async {
      final banks = PlacementBanks(
        runner: (data, onProgress, cancelled, onStarter) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return cancelled() ? null : smallV3Bank();
        },
      );
      final data = findLevelData();
      final job = banks.jobFor(data)..cancel();
      await expectLater(job.result, throwsStateError);
      expect(await banks.jobFor(data).result, isNotEmpty);
    });
  });

  group('the first formats', () {
    test('a run can begin on them while the rest is made', () async {
      final gate = Completer<void>();
      final banks = PlacementBanks(
        runner: (data, onProgress, cancelled, onStarter) async {
          onStarter(ItemBank.starterOf(smallV3Bank()));
          await gate.future;
          return smallV3Bank();
        },
      );
      final job = banks.jobFor(findLevelData());
      final first = await job.first;
      expect(first, isNotEmpty);
      expect(job.items, isNull);
      expect(job.startable, same(first));
      gate.complete();
      final all = await job.result;
      expect(all.length, greaterThan(first.length));
      expect(job.startable, same(all));
    });

    test('a kept bank is ready at once', () async {
      final store = MemoryBlobStore();
      final data = findLevelData();
      await PlacementBanks(
        store: store,
        runner: (d, p, c, s) async => smallV3Bank(),
      ).jobFor(data).result;
      await Future<void>.delayed(Duration.zero);
      final job = PlacementBanks(store: store).jobFor(data);
      expect((await job.first).length, (await job.result).length);
    });
  });

  group('the real build, in an isolate', () {
    test('reports progress and returns what the build made', () async {
      final banks = PlacementBanks();
      final job = banks.jobFor(findLevelData());
      final seen = <double>[];
      job.progress.addListener(() => seen.add(job.progress.value));
      final items = await job.result;
      // The fixture is too small for any item to pass the audit: the path
      // (isolate, progress, stored form) is what ran.
      expect(items, isEmpty);
      expect(job.progress.value, 1);
      expect(seen, isNotEmpty);
      expect(seen, orderedEquals(<double>[...seen]..sort()));
    });

    test(
      'the build in steps on this thread, as the browser does, runs to the end',
      () async {
        final progress = <double>[];
        final stepped = await runBankInSteps(
          findLevelData(),
          progress.add,
          () => false,
          (_) {},
        );
        expect(stepped, isEmpty);
        expect(progress.last, 1);
      },
    );
  });
}
