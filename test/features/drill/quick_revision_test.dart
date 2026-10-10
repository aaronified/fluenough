import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/today/quick_revision.dart';

import '../../support/harness.dart';

/// Quick revision (ADR-0029): words already taught, picked at random.
/// Every answer is recorded (ADR-0033).

Future<AppState> knowing(int count) async {
  final state = await withDeckTaught(
    (progress) => AppState.test(
      progress: progress,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['hi'],
      ),
    ),
    'hi-en-phrasebook',
    count: count,
    // Known in Write, one of the schedules (ADR-0034).
    mode: DrillMode.production,
  );
  await state.load();
  return state;
}

/// Eight Hindi words reviewed three days ago in each of [modes], the even
/// ones in [even] as well and the odd ones in [odd], with a Hindi voice and
/// recogniser, and speaking switched on.
Future<AppState> knowingIn(
  Set<DrillMode> modes, {
  Set<DrillMode> even = const <DrillMode>{},
  Set<DrillMode> odd = const <DrillMode>{},
}) async {
  AppState build(MemoryProgress progress) => AppState.test(
    progress: progress,
    tts: FixedTtsEngine(const <String>{'hi'}),
    speech: FixedSpeechEngine(onDevice: const <String>{'hi'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        Skill.speaking,
      },
    ),
  );
  final base = build(MemoryProgress());
  await base.load();
  final progress = MemoryProgress();
  final cards = base.deckById('hi-en-phrasebook')!.cards.take(8);
  for (final (i, card) in cards.indexed) {
    for (final mode in <DrillMode>{...modes, ...i.isEven ? even : odd}) {
      progress.record(
        deckId: card.deckId,
        cardId: card.id,
        mode: mode,
        grade: 4,
        now: base.now().subtract(const Duration(days: 3)),
      );
    }
  }
  final state = build(progress);
  await state.load();
  await state.startSpeech();
  return state;
}

/// Every word [items] asks, a match's words each.
List<SessionItem> asked(List<SessionItem> items) => <SessionItem>[
  for (final item in items)
    ...item.group.isEmpty ? <SessionItem>[item] : item.group,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('5 words revise 5 known words, each once', () async {
    final state = await knowing(8);
    expect(state.revisableCount, 8);
    final items = asked(state.sessionItems(const DrillRequest.revision(5)));
    expect(<String>{for (final item in items) item.card.id}, hasLength(5));
    for (final item in items) {
      expect(state.isTaught(item.card), isTrue);
    }
  });

  test('asking for more than are known revises all of them', () async {
    final state = await knowing(3);
    final items = asked(state.sessionItems(const DrillRequest.revision(20)));
    expect(<String>{for (final item in items) item.card.id}, hasLength(3));
  });

  test('nothing known, nothing to revise', () async {
    final state = await knowing(0);
    expect(state.revisableCount, 0);
    expect(state.sessionItems(const DrillRequest.revision(5)), isEmpty);
  });

  test('every answer is recorded (ADR-0033): a right one pushes the date '
      'out, a wrong one is a lapse', () async {
    final state = await knowing(8);
    final items = <SessionItem>[
      for (final item
          in state.buildSession(const DrillRequest.revision(5)).items.take(2))
        item.askedAs(Ask.chooseWord),
    ];
    final session = DrillSession(
      state: state,
      items: items,
      recorded: false,
      revising: true,
      recordsRevision: true,
    );
    final first = items[0];
    final before = state.progress.log.length;
    final due = state.progress.stateOf(first.card.id, first.mode)!.dueAt;
    session.pick(
      session.options.firstWhere((option) => option.id == first.card.id),
    );
    expect(state.progress.log, hasLength(before + 1));
    // A right choice in Write records Hard (ADR-0034).
    expect(state.progress.log.last.grade, DrillSession.scheduledChoiceGrade);
    expect(
      state.progress.stateOf(first.card.id, first.mode)!.dueAt.isAfter(due),
      isTrue,
    );

    session.next();
    final second = items[1];
    session.pick(
      session.options.firstWhere((option) => option.id != second.card.id),
    );
    expect(state.progress.log, hasLength(before + 2));
    final miss = state.progress.log.last;
    expect(miss.cardId, second.card.id);
    expect(miss.grade, lessThan(Fsrs.passingGrade));
  });

  testWidgets('from the page, a miss is recorded and ending part-way says '
      'the answers are kept', (tester) async {
    usePhone(tester);
    final state = await knowing(8);
    await pumpScreen(
      tester,
      const DrillPage(request: DrillRequest.revision(5)),
      state: state,
    );
    final l10n = l10nOf(tester);
    final before = state.progress.log.length;
    // Miss the first word, whichever way Write asks it.
    switch (tester.widget(
      find.byWidgetPredicate(
        (w) => w is TypedDrill || w is RearrangeDrill || w is ChoiceDrill,
      ),
    )) {
      case ChoiceDrill(:final session):
        session.pick(
          session.options.firstWhere(
            (option) => option.id != session.item.card.id,
          ),
        );
      case RearrangeDrill(:final session):
        session.dontKnow();
      default:
        await tester.tap(find.text(l10n.drillDontKnow));
    }
    await tester.pumpAndSettle();
    expect(state.progress.log, hasLength(before + 1));
    expect(state.progress.log.last.grade, lessThan(Fsrs.passingGrade));

    await tester.tap(find.byTooltip(l10n.drillEndSession));
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillEndBody), findsOneWidget);
    expect(find.text(l10n.drillEndBodyNotRecorded), findsNothing);
  });

  group('by skill (ADR-0030)', () {
    test(
      'one skill revises only that skill, and counts only its words',
      () async {
        final state = await knowingIn(<DrillMode>{
          DrillMode.speaking,
          DrillMode.production,
        });
        expect(state.revisableIn(<Skill>{Skill.production}), 8);
        expect(state.revisableIn(<Skill>{Skill.listening}), 0);
        final items = asked(
          state.sessionItems(
            const DrillRequest.revision(20, skills: <Skill>{Skill.production}),
          ),
        );
        expect(<String>{for (final item in items) item.card.id}, hasLength(8));
        expect(
          <DrillMode>{for (final item in items) item.mode},
          <DrillMode>{DrillMode.production},
        );
      },
    );

    test(
      'Spoken revises listening and speaking together, and nothing else',
      () async {
        expect(spokenSkills, <Skill>{Skill.listening, Skill.speaking});
        // A session asks a word in one skill, so half the words are known
        // by ear and half by mouth.
        final state = await knowingIn(
          <DrillMode>{DrillMode.production},
          even: <DrillMode>{DrillMode.listening},
          odd: <DrillMode>{DrillMode.speaking},
        );
        expect(state.revisableIn(spokenSkills), 8);
        final queue = state.buildSession(
          const DrillRequest(revise: true, skills: spokenSkills),
        );
        expect(
          <DrillMode>{for (final item in queue.items) item.mode},
          <DrillMode>{DrillMode.listening, DrillMode.speaking},
        );
      },
    );

    test("a skill's tile revises every word known in it, recording the "
        "misses; a deck's Revise records nothing", () async {
      const request = DrillRequest.reviseSkill(Skill.production);
      expect(request.revise, isTrue);
      expect(request.limit, isNull);
      expect(request.recordsRevision, isTrue);
      expect(DrillRequest.revise('hi-en-phrasebook').recordsRevision, isFalse);
      final state = await knowingIn(<DrillMode>{
        DrillMode.listening,
        DrillMode.production,
      });
      final items = asked(state.sessionItems(request));
      expect(<String>{for (final item in items) item.card.id}, hasLength(8));
      expect(
        <DrillMode>{for (final item in items) item.mode},
        <DrillMode>{DrillMode.production},
      );
    });
  });
}
