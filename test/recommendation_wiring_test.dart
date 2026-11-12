// The completed works wired into the app (wiki Plan-Deck-Kinds-And-Topics.md,
// D13, T25): the marks are kept in the profile's database and ride in the
// backup and the log export; once a work is completed its open questions join
// the lessons and reviews as reading items, only while it is marked, only while
// the learner is offered it, and under their own permanent ids.

import 'package:drift/native.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/database_progress.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/recommendation_questions.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/backup/app_backup.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/core/models/recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/culture_world.dart';

Recommendation _work(AppState state, String id) =>
    state.catalogWithAboveLevel.recommendations['zz']!.byId(id)!;

/// A learner who has taught every card of the path, so that a lesson has
/// nothing left but what completed works add, with culture off so that the
/// culture decks are no lessons of their own.
Future<AppState> _finished() async {
  final progress = MemoryProgress();
  final state = await cultureApp(
    reach: 'b1',
    progress: progress,
    settings: SettingsNotifier(spokenLanguages: const <String>['en'])
      ..cultureItems = false,
  );
  for (final (deck, card) in const <(String, String)>[
    ('zz-en-words', 'zz-0001'),
    ('zz-en-words', 'zz-0002'),
    ('zz-en-more', 'zz-0102'),
    ('zz-en-last', 'zz-0202'),
  ]) {
    studyCard(progress, state, deck, card);
  }
  return state;
}

void main() {
  group('the questions of a completed work', () {
    test(
      'join the lessons as reading items, and stop when un-marked',
      () async {
        final state = await _finished();
        expect(state.untaughtCards('zz'), isEmpty);
        expect(state.lessonFor(DrillRequest.lesson(language: 'zz')), isEmpty);

        final book = _work(state, 'zz-rec-camino');
        state.recommendationProgress.complete(book, 'zz', state.now());
        final cards = state.untaughtCards('zz');
        expect(cards.map((c) => c.id), <String>[
          'zz-rec-camino#q1',
          'zz-rec-camino#q2',
          'zz-rec-camino#q3',
        ]);
        expect(cards.every((c) => c is QuestionCard), isTrue);
        final lesson = state.lessonFor(DrillRequest.lesson(language: 'zz'));
        final reading = lesson.where((i) => i.mode == DrillMode.reading);
        expect(reading.map((i) => i.card.id).toSet(), <String>{
          'zz-rec-camino#q1',
          'zz-rec-camino#q2',
          'zz-rec-camino#q3',
        });

        state.recommendationProgress.unmark(book.id);
        expect(state.untaughtCards('zz'), isEmpty);
        expect(state.lessonFor(DrillRequest.lesson(language: 'zz')), isEmpty);
      },
    );

    test(
      'are found by their deck, which a session and a review read',
      () async {
        final state = await _finished();
        state.recommendationProgress.complete(
          _work(state, 'zz-rec-camino'),
          'zz',
          state.now(),
        );
        final card = state.untaughtCards('zz').first;
        final entry = state.deckOf(card)!;
        expect(entry.id, 'zz-en-works');
        expect(entry.deck.kind, DeckKind.reading);
        expect(entry.language.code, 'zz');
        expect(state.deckById('zz-en-works'), isNotNull);
        expect(state.drillDecks.map((e) => e.id), contains('zz-en-works'));
        // Hidden from every list a learner is given.
        expect(state.decks.map((e) => e.id), isNot(contains('zz-en-works')));
      },
    );

    test('are asked only of a work the learner is still offered', () async {
      final state = await _finished();
      final film = _work(state, 'zz-rec-pelicula');
      final novel = _work(state, 'zz-rec-novela');
      // Marked, but the learner is at B1: both are offered, so both ask.
      state.recommendationProgress
        ..complete(film, 'zz', state.now())
        ..complete(novel, 'zz', state.now());
      expect(state.completedWorksOf('zz').map((w) => w.id), <String>[
        'zz-rec-pelicula',
        'zz-rec-novela',
      ]);
      // A learner at A1 (a fresh one, with the same marks) is offered neither.
      final fresh = await cultureApp();
      fresh.recommendationProgress
        ..complete(film, 'zz', fresh.now())
        ..complete(novel, 'zz', fresh.now());
      expect(fresh.completedWorksOf('zz'), isEmpty);
      expect(fresh.workQuestionCards('zz'), isEmpty);
    });

    test('are none while nothing is completed', () async {
      final state = await _finished();
      expect(state.workQuestionCards('zz'), isEmpty);
    });
  });

  group('the marks', () {
    test('are kept in the profile database and come back', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final progress = await DatabaseProgress.open(db);
      addTearDown(progress.dispose);
      addTearDown(progress.close);
      final state = AppState.test(
        decks: MemoryDeckSource(cultureWorld()),
        progress: progress,
        settings: SettingsNotifier(spokenLanguages: const <String>['en']),
      );
      await state.load();
      state.recommendationProgress.complete(
        _work(state, 'zz-rec-camino'),
        'zz',
        state.now(),
      );
      await state.recommendationProgress.settled;
      expect(
        (await db.recommendationMarksDao.all()).map((w) => w.recommendationId),
        <String>['zz-rec-camino'],
      );

      final again = AppState.test(
        decks: MemoryDeckSource(cultureWorld()),
        progress: progress,
        settings: SettingsNotifier(spokenLanguages: const <String>['en']),
      );
      await again.load();
      expect(again.recommendationProgress.completedIds, <String>{
        'zz-rec-camino',
      });
    });

    test('ride in a backup and in the log export', () async {
      final state = await cultureApp(reach: 'b1');
      state.recommendationProgress.complete(
        _work(state, 'zz-rec-camino'),
        'zz',
        DateTime(2026, 11, 12, 9, 30),
      );
      final backup = state.backups.snapshot(BackupKind.you);
      expect(backup.log, contains('"type":"completed"'));
      final back = AppBackup.decode(backup.encode());
      expect(back.completedWorks.single.recommendationId, 'zz-rec-camino');
      expect(
        back.completedWorks.single.completedAt,
        DateTime(2026, 11, 12, 9, 30),
      );
      // The reviews and the rest of the log read as they always did.
      expect(back.reviews, hasLength(state.progress.log.length));

      final export = state.progress.exportJsonl(
        completedWorks: state.recommendationProgress.completed,
      );
      expect(
        LogJsonl.decodeCompletedWorks(export).single.recommendationId,
        'zz-rec-camino',
      );
      // Without them the export is the log alone.
      expect(state.progress.exportJsonl(), isNot(contains('"completed"')));
    });

    test('are made those of the backup a restore restores', () async {
      final source = await cultureApp(reach: 'b1');
      source.recommendationProgress.complete(
        _work(source, 'zz-rec-camino'),
        'zz',
        source.now(),
      );
      final backup = AppBackup.decode(
        source.backups.snapshot(BackupKind.you).encode(),
      );

      final other = await cultureApp(reach: 'b1');
      other.recommendationProgress.complete(
        _work(other, 'zz-rec-pelicula'),
        'zz',
        other.now(),
      );
      await other.backups.restore(backup, fromFile: false);
      expect(other.recommendationProgress.completedIds, <String>{
        'zz-rec-camino',
      });
      // And the questions of the one taken away are gone with it.
      expect(other.workQuestionCards('zz').map((c) => c.id), <String>[
        'zz-rec-camino#q1',
        'zz-rec-camino#q2',
        'zz-rec-camino#q3',
      ]);
    });

    test(
      'merge in from an imported log without changing what is marked',
      () async {
        final state = await cultureApp(reach: 'b1');
        final book = _work(state, 'zz-rec-camino');
        state.recommendationProgress.complete(
          book,
          'zz',
          DateTime(2026, 11, 1),
        );
        final other = await cultureApp(reach: 'b1');
        other.recommendationProgress
          ..complete(book, 'zz', DateTime(2026, 11, 5))
          ..complete(
            _work(other, 'zz-rec-pelicula'),
            'zz',
            DateTime(2026, 11, 6),
          );
        final text = other.progress.exportJsonl(
          completedWorks: other.recommendationProgress.completed,
        );
        final added = await state.recommendationProgress.importMarks(
          LogJsonl.decodeCompletedWorks(text),
        );
        expect(added, 1);
        expect(state.recommendationProgress.completedIds, hasLength(2));
        expect(
          state.recommendationProgress.completed.first.completedAt,
          DateTime(2026, 11, 1),
        );
      },
    );
  });
}
