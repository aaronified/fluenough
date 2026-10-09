// Grammar understood and produced (B1 format spec 4.7 and 4.8): a rules
// table's cell is understood by choosing what its form means, and produced
// by choosing its form among its word's, then typing it. Each is a schedule
// of its own, fitted per language, implying nothing of the other.
//
// The fixtures are Appendix A's, in test/fixtures/b1/appendix-a/, in the
// language `zz` (Testlang, in the Telugu script).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/data/pattern_expander.dart';
import 'package:fluenough/core/data/rule_expander.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';

import 'support/fit_learner.dart';

const appendix = 'test/fixtures/b1/appendix-a/zz';
const features = 'test/fixtures/b1/features/zz';
const rulesDeck = 'zz-en-grammar-case-endings';

String read(String path) => File(path).readAsStringSync();

final homeCore = read('$appendix/zz-home.yaml');
final homeLayer = read('$appendix/en/zz-en-home.yaml');
final rulesCore = read('$appendix/zz-grammar-case-endings.yaml');
final rulesLayer = read('$appendix/en/zz-en-grammar-case-endings.yaml');

Deck merge(String core, String layer) => mergeLayer(
  DeckParser.parseCore(core, source: 'core.yaml'),
  DeckParser.parseLayer(layer, source: 'layer.yaml'),
  source: 'layer.yaml',
);

/// The rules deck's cells, from [core] and [layer] as edited.
List<Card> cellsOf({String? core, String? layer}) {
  final home = merge(homeCore, homeLayer);
  return expandRules(
    merge(core ?? rulesCore, layer ?? rulesLayer),
    wordOf: (id) => home.cards.where((c) => c.id == id).firstOrNull,
  );
}

Card cell(List<Card> cells, String suffix) =>
    cells.firstWhere((c) => c.id == 'zz-grammar-case-endings-$suffix');

/// Every file of Appendix A, keyed as the catalog keys bundled decks.
Map<String, String> appendixFiles() => <String, String>{
  for (final file in Directory(appendix).parent.listSync(recursive: true))
    if (file is File && file.path.endsWith('.yaml'))
      'decks/${file.path.substring(Directory(appendix).parent.path.length + 1)}':
          file.readAsStringSync(),
};

FsrsState remembered(DateTime at) => FsrsState(
  stability: 5,
  difficulty: 5,
  intervalDays: 5,
  dueAt: at,
  lastReviewAt: at.subtract(const Duration(days: 5)),
  repetitions: 2,
);

FsrsState missed(DateTime at) => FsrsState(
  stability: 1,
  difficulty: 7,
  intervalDays: 1,
  dueAt: at,
  lastReviewAt: at.subtract(const Duration(days: 1)),
  lapses: 1,
);

void main() {
  final now = DateTime(2026, 10, 9, 18);
  final cells = cellsOf();
  // అమ్మతో (ammatō), "with mother", among అమ్మలో, అమ్మకి, అమ్మ నుంచి.
  final withMother = cell(cells, '9004-2');

  group('which cells take which schedule (4.8, 3)', () {
    test('a cell whose row\'s forms differ in meaning takes both', () {
      for (final c in cells) {
        expect(c.modesIn(ttsAvailable: false), {
          DrillMode.grammarUnderstood,
          DrillMode.grammar,
        }, reason: c.id);
      }
      expect(withMother.choosesMeaning, isTrue);
      expect(withMother.choosesForm, isTrue);
    });

    test('a one-form row is never asked to choose', () {
      // Every rule but -తో left out: each row has one cell.
      final layer = rulesLayer.replaceAllMapped(
        RegExp(r'  "zz-rule-(lo|ki|nunci)":\n.*\n.*\n'),
        (_) => '',
      );
      final alone = cellsOf(layer: layer);
      expect(alone, hasLength(2));
      for (final c in alone) {
        expect(c.rule!.options, isEmpty);
        expect(c.choosesForm, isFalse);
        expect(c.choosesMeaning, isFalse);
        expect(c.modesIn(ttsAvailable: true), {DrillMode.grammar});
        expect(lessonQuestions(c), [(mode: DrillMode.grammar, ask: Ask.own)]);
      }
      final asked = reviewAsks([
        SessionItem(card: alone.first, mode: DrillMode.grammar, state: null),
      ], canChoose: (_) => true);
      expect(asked.single.ask, Ask.own);
    });

    test('a row whose other cells share its meaning gets no meaning '
        'question', () {
      final layer = rulesLayer
          .replaceFirst('"in {meaning}"', '"by {meaning}"')
          .replaceFirst('"to {meaning}"', '"by {meaning}"')
          .replaceFirst('"with {meaning}"', '"by {meaning}"')
          .replaceFirst('"from {meaning}"', '"by {meaning}"');
      final same = cellsOf(layer: layer);
      final mother = cell(same, '9004-2');
      expect(mother.native, 'by mother');
      expect(mother.choosesMeaning, isFalse);
      expect(mother.choosesForm, isTrue);
      expect(mother.modesIn(ttsAvailable: true), {DrillMode.grammar});
      expect(lessonQuestions(mother), [
        (mode: DrillMode.grammar, ask: Ask.chooseForm),
      ]);
    });

    test('an existing grammar deck is unchanged: typed, grammar only', () {
      final past = expandPattern(
        merge(
          read('$features/zz-grammar-past.yaml'),
          read('$features/en/zz-en-grammar-past.yaml'),
        ),
      );
      for (final c in past) {
        expect(c.rule, isNull);
        expect(c.modesIn(ttsAvailable: true), {DrillMode.grammar});
        expect(c.promptFor(DrillMode.grammar), c.native);
        expect(lessonQuestions(c), [(mode: DrillMode.grammar, ask: Ask.own)]);
        expect(formChoices(c, Ask.chooseForm, past), isEmpty);
      }
      final asked = reviewAsks([
        for (final c in past)
          SessionItem(card: c, mode: DrillMode.grammar, state: null),
      ], canChoose: (_) => true);
      expect(asked.map((i) => i.ask), everyElement(Ask.own));
    });
  });

  group('the meaning question, Ask.chooseFormMeaning (4.8, 1)', () {
    test('shows the form with its reading; the meaning is the answer', () {
      expect(
        withMother.promptFor(DrillMode.grammarUnderstood),
        'అమ్మతో (ammatō)',
      );
      expect(withMother.acceptedAnswers(DrillMode.grammarUnderstood), [
        'with mother',
      ]);
      expect(Ask.chooseFormMeaning.chooses, isTrue);
      expect(Ask.chooseFormMeaning.choosesMeaning, isTrue);
      expect(Ask.chooseFormMeaning.optionOf(withMother), 'with mother');
    });

    test('offers only meanings of the same row\'s cells, distinct', () {
      final options = formChoices(withMother, Ask.chooseFormMeaning, cells);
      expect(options.map((c) => c.native), [
        'in mother',
        'to mother',
        'from mother',
      ]);
      expect(options.map((c) => c.rule!.word), everyElement('zz-9004'));
      // Never another word's: the home row's meanings are not offered.
      expect(
        options.map((c) => c.native),
        isNot(contains(anyOf('at home', 'with home', 'from home'))),
      );
    });

    test('never a meaning of a rule the layer leaves out', () {
      final layer = rulesLayer.replaceFirst(
        RegExp(r'  "zz-rule-ki":\n.*\n.*\n'),
        '',
      );
      final without = cellsOf(layer: layer);
      final mother = cell(without, '9004-2');
      expect(
        formChoices(
          mother,
          Ask.chooseFormMeaning,
          without,
        ).map((c) => c.native),
        ['in mother', 'from mother'],
      );
    });

    test('two cells of the row with one meaning are offered once', () {
      final layer = rulesLayer.replaceFirst(
        '"from {meaning}"',
        '"in {meaning}"',
      );
      final shared = cellsOf(layer: layer);
      final mother = cell(shared, '9004-2');
      expect(
        formChoices(mother, Ask.chooseFormMeaning, shared).map((c) => c.native),
        ['in mother', 'to mother'],
      );
      // And none equal to the cell's own meaning.
      final inMother = cell(shared, '9004-0');
      expect(
        formChoices(
          inMother,
          Ask.chooseFormMeaning,
          shared,
        ).map((c) => c.native),
        ['to mother', 'with mother'],
      );
    });

    test('a review always asks it; a right one records Good (4)', () {
      final asked = reviewAsks([
        SessionItem(
          card: withMother,
          mode: DrillMode.grammarUnderstood,
          state: remembered(now),
        ),
      ], canChoose: (_) => true);
      expect(asked.single.ask, Ask.chooseFormMeaning);
      expect(asked.single.mode, DrillMode.grammarUnderstood);
      expect(
        Ask.chooseFormMeaning.rightChoiceGrade(DrillMode.grammarUnderstood),
        4,
      );
    });
  });

  group('the form question, Ask.chooseForm (4.8, 2 and 4)', () {
    test('shows the word and the meaning; offers the row\'s forms', () {
      expect(
        withMother.promptFor(DrillMode.grammar),
        'అమ్మ (amma): with mother',
      );
      expect(Ask.chooseForm.chooses, isTrue);
      expect(Ask.chooseForm.choosesMeaning, isFalse);
      final options = formChoices(withMother, Ask.chooseForm, cells);
      expect(options.map((c) => c.target), ['అమ్మలో', 'అమ్మకి', 'అమ్మ నుంచి']);
      expect(options.map((c) => c.reading), ['ammalō', 'ammaki', 'amma nuñci']);
    });

    test('records grammar, Hard (3) when right', () {
      expect(Ask.chooseForm.rightChoiceGrade(DrillMode.grammar), 3);
      // The grades of the other choices are as before.
      expect(Ask.chooseMeaning.rightChoiceGrade(DrillMode.recognition), 4);
      expect(Ask.chooseWord.rightChoiceGrade(DrillMode.production), 3);
      expect(Ask.hearMeaning.rightChoiceGrade(DrillMode.listening), 3);
    });

    test('chosen while new or last missed, typed once remembered', () {
      SessionItem item(FsrsState? state) =>
          SessionItem(card: withMother, mode: DrillMode.grammar, state: state);
      final asked = reviewAsks([
        item(null),
        item(missed(now)),
        item(remembered(now)),
      ], canChoose: (_) => true);
      expect(asked.map((i) => (i.mode, i.ask)), [
        (DrillMode.grammar, Ask.chooseForm),
        (DrillMode.grammar, Ask.chooseForm),
        (DrillMode.grammar, Ask.own),
      ]);
    });

    test('a new pair starts typed where the learner recalls well', () {
      final asked = reviewAsks(
        [SessionItem(card: withMother, mode: DrillMode.grammar, state: null)],
        canChoose: (_) => true,
        recallsFirst: (_) => true,
      );
      expect(asked.single.ask, Ask.own);
    });
  });

  group('lessons (4.8, 5)', () {
    test('understood, then produced', () {
      expect(lessonQuestions(withMother), [
        (mode: DrillMode.grammarUnderstood, ask: Ask.chooseFormMeaning),
        (mode: DrillMode.grammar, ask: Ask.chooseForm),
      ]);
      final plan = lessonPlan(
        [withMother],
        modesOf: (c) => c.modesIn(ttsAvailable: false),
        canChoose: (card, ask) =>
            formChoices(card, ask, cells).isNotEmpty || !ask.choosesAmongForms,
      );
      expect(plan.map((i) => (i.mode, i.ask)), [
        (DrillMode.grammarUnderstood, Ask.teach),
        (DrillMode.grammarUnderstood, Ask.chooseFormMeaning),
        (DrillMode.grammar, Ask.chooseForm),
      ]);
    });
  });

  group('the skill model (4.7)', () {
    test('neither grammar schedule implies anything', () {
      const skills = SkillMap(formHeardIn: {rulesDeck});
      expect(skills.impliedBy(DrillMode.grammarUnderstood, rulesDeck), isEmpty);
      expect(skills.impliedBy(DrillMode.grammar, rulesDeck), isEmpty);

      // A right answer in either moves no other pair of the cell.
      final id = withMother.id;
      final states = <ProgressKey, FsrsState>{
        (cardId: id, mode: DrillMode.grammarUnderstood): remembered(now),
        (cardId: id, mode: DrillMode.grammar): remembered(now),
      };
      final before = Map.of(states);
      for (final mode in [DrillMode.grammar, DrillMode.grammarUnderstood]) {
        implyReview(states, skills, (
          key: (cardId: id, mode: mode),
          deckId: rulesDeck,
          at: now,
          grade: 4,
          elapsed: Duration.zero,
          answerGiven: 'x',
        ));
      }
      expect(states, before);
    });

    test('both are the Grammar skill, one tile and one switch (4.8, 7)', () {
      expect(Skill.of(DrillMode.grammarUnderstood), Skill.grammar);
      expect(Skill.of(DrillMode.grammar), Skill.grammar);
      expect(Skill.grammar.modes, {
        DrillMode.grammarUnderstood,
        DrillMode.grammar,
      });
      for (final skill in Skill.values) {
        if (skill != Skill.grammar) expect(skill.modes, {?skill.mode});
      }
      // Every mode is some skill's, and one skill's only.
      final covered = [for (final skill in Skill.values) ...skill.modes];
      expect(covered.toSet(), DrillMode.values.toSet());
      expect(covered, hasLength(DrillMode.values.length));
    });
  });

  group('fitting per language and skill (4.7)', () {
    final start = DateTime(2026, 1, 1, 9);
    final until = DateTime(2026, 10, 1);

    test('(language, grammarUnderstood) is fitted on its own', () {
      final understood = simulate(
        language: 'te',
        start: start,
        until: until,
        mode: DrillMode.grammarUnderstood,
        recall: 0.99,
      );
      final produced = simulate(
        language: 'te',
        start: start,
        until: until,
        mode: DrillMode.grammar,
        recall: 0.7,
        seed: 2,
      );
      final histories = SkillFit.histories(
        inTimeOrder([...understood, ...produced]),
      );
      const understoodKey = (language: 'te', mode: DrillMode.grammarUnderstood);
      const producedKey = (language: 'te', mode: DrillMode.grammar);
      expect(
        histories.keys,
        unorderedEquals(<Object>[understoodKey, producedKey]),
      );
      expect(histories[understoodKey]!.reviewCount, understood.length);
      expect(histories[producedKey]!.reviewCount, produced.length);

      final fit = SkillFit.run(
        SkillFit.job(histories[understoodKey]!, Fsrs.w, now),
      );
      expect(fit.key, understoodKey);
      expect(fit.fitted, isNotNull);
      final parameters = SkillParameters.none.withFit(
        understoodKey,
        fit.fitted!,
      );
      // The fit schedules understood, and nothing else: produced keeps
      // FSRS-6's defaults until it is fitted itself.
      expect(
        parameters.of('te', DrillMode.grammarUnderstood),
        fit.fitted!.values,
      );
      expect(parameters.of('te', DrillMode.grammar), Fsrs.w);
      expect(parameters.sourceOf('te', DrillMode.grammar), isNull);
      // A language with no fit of its own borrows understood's from the
      // language studied most recently, as every skill does.
      expect(parameters.sourceOf('bn', DrillMode.grammarUnderstood), 'te');
    });

    test('the backup keeps its fit by the mode\'s name', () {
      const key = (language: 'te', mode: DrillMode.grammarUnderstood);
      final fitted = FittedParameters(
        values: Fsrs.w,
        fittedAt: now,
        reviewCount: 400,
      );
      final text = LogJsonl.encode(const [], const [], fitted: {key: fitted});
      expect(text, contains('"grammarUnderstood"'));
      expect(LogJsonl.decode(text).fitted, {key: fitted});
    });
  });

  group('the log replays as it is', () {
    test('an old grammar answer stays grammar', () {
      final id = 'te-grammar-case-endings-0042-1';
      final old = [
        review(id, DrillMode.grammar, now, 4),
        review(id, DrillMode.grammar, now.add(const Duration(days: 3)), 3),
      ];
      final text = LogJsonl.encode([
        for (final r in old)
          (
            deckId: 'te-en-grammar',
            at: r.at,
            grade: r.grade,
            elapsed: r.elapsed,
            answerGiven: r.answerGiven,
            key: r.key,
          ),
      ], const []);
      expect(text, contains('"grammar"'));
      expect(text, isNot(contains('grammarUnderstood')));
      final decoded = LogJsonl.decode(text).reviews;
      expect(decoded.map((r) => r.key.mode), everyElement(DrillMode.grammar));
      final replayed = replayReviews(decoded, skills: const SkillMap());
      expect(replayed.states.keys, [(cardId: id, mode: DrillMode.grammar)]);
      expect(
        replayed.events.map((e) => e.mode),
        everyElement(DrillMode.grammar),
      );
    });
  });

  group('the app (4.8, 6 and 7)', () {
    Future<AppState> loaded({SettingsNotifier? settings}) async {
      final state = AppState.test(
        decks: MemoryDeckSource(appendixFiles()),
        progress: MemoryProgress(),
        settings: settings,
        now: now,
      );
      await state.load();
      return state;
    }

    test('a session holds both schedules; its asks are the rule\'s', () async {
      final state = await loaded();
      expect(state.sessionModes, contains(DrillMode.grammarUnderstood));
      final entry = state.deckById(rulesDeck)!;
      final card = entry.cards.firstWhere((c) => c.id == withMother.id);
      expect(
        state.choicePool(card, Ask.chooseFormMeaning).map((c) => c.native),
        unorderedEquals(['in mother', 'to mother', 'from mother']),
      );
      expect(
        state.choicePool(card, Ask.chooseForm).map((c) => c.target),
        unorderedEquals(['అమ్మలో', 'అమ్మకి', 'అమ్మ నుంచి']),
      );
      expect(state.canChoose(card, Ask.chooseFormMeaning), isTrue);

      final items = state.sessionItems(
        const DrillRequest(deckIds: {rulesDeck}, untaught: true),
      );
      expect(items, isNotEmpty);
      for (final item in items) {
        // A new cell is understood first, its meaning chosen.
        expect(item.mode, DrillMode.grammarUnderstood);
        expect(item.ask, Ask.chooseFormMeaning);
      }
    });

    test('the Grammar switch covers both', () async {
      final settings = SettingsNotifier();
      final state = await loaded(settings: settings);
      expect(
        state.sessionModes,
        containsAll(<DrillMode>[
          DrillMode.grammarUnderstood,
          DrillMode.grammar,
        ]),
      );
      settings.setSkillEnabled(Skill.grammar, false);
      expect(state.sessionModes, isNot(contains(DrillMode.grammarUnderstood)));
      expect(state.sessionModes, isNot(contains(DrillMode.grammar)));
      expect(
        state.sessionItems(
          const DrillRequest(deckIds: {rulesDeck}, untaught: true),
        ),
        isEmpty,
      );
    });

    test(
      'grammar switched off before this update stays off for both',
      () async {
        final settings = SettingsNotifier();
        settings.restore(<String, String>{
          'enabled_skills': '+,recognition,production,listening,!speaking,!grammar,reading,pair',
        });
        final state = await loaded(settings: settings);
        expect(settings.isEnabled(Skill.grammar), isFalse);
        expect(
          state.sessionModes,
          isNot(contains(DrillMode.grammarUnderstood)),
        );
        expect(
          state.sessionItems(
            const DrillRequest(deckIds: {rulesDeck}, untaught: true),
          ),
          isEmpty,
        );
      },
    );

    test('a request for Grammar asks grammar understood too', () async {
      final state = await loaded();
      final items = state.sessionItems(
        const DrillRequest(
          deckIds: {rulesDeck},
          skill: Skill.grammar,
          untaught: true,
        ),
      );
      expect(items, isNotEmpty);
      expect(items.first.mode, DrillMode.grammarUnderstood);
    });

    test('the grammar feature gates both', () {
      expect(Skill.grammar.feature, Feature.drillGrammar);
    });
  });
}
