import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/decks/path_model.dart';
import 'package:fluenough/features/decks/word_mastery.dart';

/// What the Decks tab reads out of a course's path: units and their status,
/// what each teaches, milestones, and levels where a plan marks them.

Future<AppState> loaded([AppState? state]) async {
  final s = state ?? AppState.test();
  await s.load();
  return s;
}

/// The Telugu learner of the design, on the bundled decks.
Future<AppState> telugu({String upTo = PathFixtures.familyDeck}) async {
  final app = await loaded();
  return loaded(PathFixtures.state(app, upTo: upTo));
}

void main() {
  // The bundled decks are read as assets.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh course: the first unit is up next, every other ahead, '
      'and the units are the course\'s, in order', () async {
    final state = await loaded();
    final view = courseView(state, 'te')!;
    final units = view.units.toList();
    expect(
      units.map((u) => u.decks.map((e) => e.id).toList()),
      state.courseUnits('te').map((u) => u.map((e) => e.id).toList()),
    );
    expect(units.first.status, UnitStatus.upNext);
    expect(units.skip(1).map((u) => u.status), everyElement(UnitStatus.ahead));
    expect(units.map((u) => u.number), [
      for (var i = 1; i <= units.length; i++) i,
    ]);
    expect(view.doneCount, 0);
    expect(view.upNext, same(units.first));
    // Every unit is on the path, so each opens its screen.
    expect(units.map((u) => u.onPath), everyElement(isTrue));
    // No plan marks levels yet: none is drawn.
    expect(view.steps.whereType<LevelStep>(), isEmpty);
    expect(view.steps.whereType<AchievementStep>(), isEmpty);
  });

  test(
    'a unit\'s content: words, sentences, and a grammar deck as a rule',
    () async {
      final state = await loaded();
      final family = state
          .courseUnits('te')
          .firstWhere((u) => u.any((e) => e.id == 'te-en-family'));
      final content = UnitContent(family);
      expect(content.rules.map((e) => e.id), ['te-en-grammar-be']);
      expect(content.words, isNotEmpty);
      expect(content.sentences, isNotEmpty);
      expect(content.words.where(isSentence), isEmpty);
      expect(content.sentences.every(isSentence), isTrue);
      // Each card once, whichever decks list it.
      final ids = [...content.words, ...content.sentences].map((c) => c.id);
      expect(ids.toSet(), hasLength(ids.length));
      expect(content.isScript, isFalse);

      final vowels = state
          .courseUnits('te')
          .firstWhere((u) => u.any((e) => e.id == 'te-en-script-vowels'));
      expect(UnitContent(vowels).isScript, isTrue);
      expect(unitTitle(state, family), 'Family');
    },
  );

  test(
    'milestones: the first deck after the first unit, the script after '
    'its units, and each word count after the unit that reaches it',
    () async {
      final state = await loaded();
      final view = courseView(state, 'te')!;
      final steps = view.steps;
      final units = view.units.toList();
      expect(steps[1], isA<MilestoneStep>());
      expect((steps[1] as MilestoneStep).kind, MilestoneKind.firstDeck);

      final script = steps.whereType<MilestoneStep>().singleWhere(
        (m) => m.kind == MilestoneKind.script,
      );
      final before = steps.sublist(0, steps.indexOf(script)).last;
      // Right after the last unit of the first run of script units.
      expect(before, isA<UnitStep>());
      expect((before as UnitStep).decks.every(state.needsAlphabet), isTrue);
      final after = steps
          .skip(steps.indexOf(script) + 1)
          .whereType<UnitStep>()
          .first;
      expect(after.decks.every(state.needsAlphabet), isFalse);
      expect(script.earned, isFalse);
      expect(script.toGo, 2);

      // Word counts in order, each placed after the unit whose words reach it.
      final counts = steps
          .whereType<MilestoneStep>()
          .where((m) => m.kind == MilestoneKind.words)
          .toList();
      expect(counts.map((m) => m.count), [50, 100, 250]);
      for (final milestone in counts) {
        final unit = steps
            .sublist(0, steps.indexOf(milestone))
            .whereType<UnitStep>()
            .last;
        var words = <String>{};
        for (final u in units.take(units.indexOf(unit) + 1)) {
          words = {...words, ...u.content.words.map((c) => c.id)};
        }
        expect(words.length, greaterThanOrEqualTo(milestone.count));
        expect(milestone.earned, isFalse);
        expect(milestone.toGo, milestone.count);
      }
    },
  );

  test('learned units are done, the next is up next, and milestones are '
      'earned with the day the log says', () async {
    final state = await telugu();
    final view = courseView(state, 'te')!;
    final units = view.units.toList();
    final family = units.indexWhere(
      (u) => u.decks.any((e) => e.id == 'te-en-family'),
    );
    expect(
      units.take(family).map((u) => u.status),
      everyElement(UnitStatus.done),
    );
    expect(units[family].status, UnitStatus.upNext);
    expect(view.doneCount, family);

    final first = view.steps.whereType<MilestoneStep>().first;
    expect(first.kind, MilestoneKind.firstDeck);
    expect(first.earned, isTrue);
    expect(first.earnedAt, isNotNull);

    final fifty = view.steps.whereType<MilestoneStep>().firstWhere(
      (m) => m.kind == MilestoneKind.words && m.count == 50,
    );
    expect(fifty.earned, isTrue);
    // The 50th word's first right answer.
    final answers = RecentAnswers(state.progress.log);
    final words = <String>{
      for (final unit in units)
        for (final card in unit.content.words) card.id,
    };
    // Of the words learned now, as the Learned counts take them.
    final learned = <String>{
      for (final entry in state.progress.states.entries)
        if (entry.value.repetitions > 0) entry.key.cardId,
    };
    final passed =
        words.where(learned.contains).map(answers.firstPassed).nonNulls.toList()
          ..sort();
    expect(fifty.earnedAt, passed[49]);
    expect(fifty.toGo, 0);
  });

  test('a plan marks levels: each level starts with its header, its units '
      'carry it, coming units follow its last, then its achievement', () async {
    final state = await telugu();
    final view = courseView(state, 'te', plan: PathFixtures.telugu)!;
    final steps = view.steps;
    expect(view.levels, CefrLevel.values);
    expect(steps.first, isA<LevelStep>());

    final units = view.units.toList();
    final a1End = units.indexWhere(
      (u) => u.decks.any((e) => e.id == 'te-en-numbers-big'),
    );
    final a2End = units.indexWhere(
      (u) => u.decks.any((e) => e.id == 'te-en-help'),
    );
    for (final (i, unit) in units.indexed) {
      expect(
        unit.level,
        i <= a1End
            ? CefrLevel.a1
            : i <= a2End
            ? CefrLevel.a2
            : CefrLevel.b1,
        reason: unit.title,
      );
    }
    final achievements = steps.whereType<AchievementStep>().toList();
    expect(achievements.map((a) => a.level), CefrLevel.values);
    final a1 = achievements.first;
    expect(a1.earned, isFalse);
    expect(
      a1.unitsToGo,
      units.take(a1End + 1).where((u) => u.status != UnitStatus.done).length,
    );
    // The coming units sit between B1's last written unit and its
    // achievement, and count toward it.
    final coming = steps.whereType<ComingStep>().toList();
    expect(coming.map((c) => c.unit.title), [
      for (final c in PathFixtures.telugu.coming) c.title,
    ]);
    expect(steps.indexOf(coming.first), greaterThan(steps.indexOf(units.last)));
    expect(steps.last, same(achievements.last));
    expect(achievements.last.coming, 7);
    // The level the learner is in is highlighted.
    final headers = steps.whereType<LevelStep>().toList();
    expect(headers.map((h) => h.current), [true, false, false]);
    expect(headers.last.coming, 7);
  });

  test('A1 is reached once its units are done', () async {
    final state = await telugu(upTo: 'te-en-market');
    final view = courseView(state, 'te', plan: PathFixtures.telugu)!;
    final a1 = view.steps.whereType<AchievementStep>().first;
    expect(a1.level, CefrLevel.a1);
    expect(a1.earned, isTrue);
    expect(a1.earnedAt, isNotNull);
    expect(view.upNext!.decks.first.id, 'te-en-market');
    expect(view.upNext!.level, CefrLevel.a2);
    expect(view.steps.whereType<LevelStep>().map((h) => h.current), [
      false,
      true,
      false,
    ]);
  });

  test('learned without the alphabet: no script milestone, and the script '
      'decks are listed apart, opening their own screens', () async {
    final state = await loaded(
      AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['te'],
          learningChosen: true,
          noAlphabet: const <String>{'te'},
        ),
      ),
    );
    final view = courseView(state, 'te')!;
    expect(
      view.steps.whereType<MilestoneStep>().where(
        (m) => m.kind == MilestoneKind.script,
      ),
      isEmpty,
    );
    expect(
      view.otherDecks.map((e) => e.id),
      containsAll(<String>['te-en-script-vowels', 'te-en-spelling']),
    );
    expect(view.otherDecks.every(state.needsAlphabet), isTrue);
  });

  test('ten rules known, after the unit whose rules reach ten, and the '
      'first passage read, after the first unit with one', () async {
    final state = await loaded();
    MilestoneStep only(CourseView view, MilestoneKind kind) => view.steps
        .whereType<MilestoneStep>()
        .singleWhere((m) => m.kind == kind);
    UnitStep before(CourseView view, MilestoneStep step) => view.steps
        .sublist(0, view.steps.indexOf(step))
        .whereType<UnitStep>()
        .last;

    final fresh = courseView(state, 'te')!;
    final units = fresh.units.toList();
    final rules = only(fresh, MilestoneKind.rules);
    expect(rules.count, 10);
    expect(rules.earned, isFalse);
    expect(rules.toGo, 10);
    // Right after the unit holding the course's tenth rule.
    final tenth = before(fresh, rules);
    final upToTenth = units
        .take(units.indexOf(tenth) + 1)
        .expand((u) => u.content.rules);
    expect(upToTenth, hasLength(10));
    expect(tenth.content.rules, isNotEmpty);

    final passage = only(fresh, MilestoneKind.firstPassage);
    expect(passage.earned, isFalse);
    final reading = before(fresh, passage);
    expect(reading.content.passages, greaterThan(0));
    expect(
      units.take(units.indexOf(reading)).map((u) => u.content.passages),
      everyElement(0),
    );

    // Every rule right on its recent answers, and one question answered.
    final progress = MemoryProgress();
    final at = DateTime(2026, 9, 20);
    for (final rule in units.expand((u) => u.content.rules).take(10)) {
      for (final card in rule.cards) {
        progress.record(
          deckId: rule.id,
          cardId: card.id,
          mode: DrillMode.grammar,
          grade: 4,
          now: at,
        );
      }
    }
    final story = reading.decks.firstWhere(
      (e) => e.deck.kind == DeckKind.reading,
    );
    progress.record(
      deckId: story.id,
      cardId: story.cards.first.id,
      mode: DrillMode.recognition,
      grade: 1,
      now: at,
    );
    final later = courseView(
      state,
      'te',
      answers: RecentAnswers(progress.log),
    )!;
    final known = only(later, MilestoneKind.rules);
    expect(known.earned, isTrue);
    expect(known.toGo, 0);
    final read = only(later, MilestoneKind.firstPassage);
    // Read, whether or not its answer was right.
    expect(read.earned, isTrue);
    expect(read.earnedAt, at);
  });

  test('a unit is found by any of its decks; a deck outside any path opens '
      'its own screen', () async {
    final state = await loaded();
    final unit = unitOfDeck(state, 'te-en-grammar-be')!;
    expect(unit.decks.map((e) => e.id), ['te-en-family', 'te-en-grammar-be']);
    expect(
      unitOfDeck(state, 'te-en-grammar-be', plan: PathFixtures.telugu)!.level,
      CefrLevel.a1,
    );
    expect(unit.level, isNull);
    expect(opensUnit(state, 'te-en-family'), isTrue);
    expect(unitOfDeck(state, 'no-such-deck'), isNull);

    // A course with no path: each deck is a unit of its own, and opens its
    // own screen.
    final bare = await loaded(
      AppState.test(
        decks: MemoryDeckSource(const <String, String>{
          'decks/xx/xx-en-solo.yaml': '''
schema: 1
id: xx-en-solo
name: Solo
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-9001
    target: "sí"
    native: "yes"
''',
        }),
      ),
    );
    final solo = courseView(bare, 'es')!.units.single;
    expect(solo.onPath, isFalse);
    expect(opensUnit(bare, 'xx-en-solo'), isFalse);
  });
}
