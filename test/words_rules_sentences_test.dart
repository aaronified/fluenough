// Words, rules and sentences (#416, #417, #418, parts of #413): the unlock
// gate, lessons without the quota, and the counts Progress, a unit and the
// end of a lesson show.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/unlocks.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/core/progress/recent_answers.dart';
import 'package:fluenough/core/progress/unlocks.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/rule_card.dart';
import 'package:fluenough/features/drill/teach_drill.dart';
import 'package:fluenough/features/stats/progress_tiles.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

final DateTime _start = DateTime(2026, 9, 1, 9);

/// A word taught in a vocab deck.
Card _word(String id) =>
    Card(id: id, deckId: 'xx-words', target: id, native: id, pos: 'noun');

/// A sentence naming [words] by their cards and [rules].
Card _sentence(
  String id, {
  List<String> words = const <String>[],
  List<String> rules = const <String>[],
  bool phrasebook = false,
}) => Card(
  id: id,
  deckId: 'xx-sentences',
  target: 'one two three',
  native: id,
  pos: 'phrase',
  phrasebook: phrasebook,
  bases: <CardBase>[for (final w in words) CardBase(word: w, ref: w)],
  rules: rules,
);

/// A cell of a rules table: [word] in [rule].
Card _cell(String id, String word, {String rule = 'xx-rule-in'}) => Card(
  id: id,
  deckId: 'xx-rules',
  target: '$word-in',
  native: 'in $word',
  rule: RuleCell(ruleId: rule, word: word, wordTarget: word, slot: 'in'),
);

/// Answers [id] with [grades] in turn, one a minute, from [from].
void _answer(
  MemoryProgress progress,
  String id,
  List<int> grades, {
  DateTime? from,
}) {
  for (final (i, grade) in grades.indexed) {
    progress.record(
      deckId: 'xx-words',
      cardId: id,
      mode: DrillMode.recognition,
      grade: grade,
      now: (from ?? _start).add(Duration(minutes: i)),
    );
  }
}

const List<int> _nineOfTen = <int>[4, 4, 4, 1, 4, 4, 4, 4, 4, 4];
const List<int> _sevenOfTen = <int>[4, 1, 4, 1, 4, 4, 1, 4, 4, 4];

void main() {
  group('the unlock gate', () {
    final cards = <Card>[
      _word('xx-0001'),
      _word('xx-0002'),
      _cell('xx-r-1', 'xx-0001'),
      _cell('xx-r-2', 'xx-0002'),
      _sentence(
        'xx-s-1',
        words: <String>['xx-0001', 'xx-0002'],
        rules: <String>['xx-rule-in'],
      ),
      _sentence('xx-p-1', words: <String>['xx-0002'], phrasebook: true),
    ];

    test('a sentence opens only once its last word and its rule are known; '
        'the phrasebook is never held back', () {
      final progress = MemoryProgress();
      Unlocks gate() => Unlocks(log: progress.log, cards: cards);
      final sentence = cards[4];
      final chunk = cards[5];

      expect(gate().isClosed(sentence), isTrue);
      expect(gate().isClosed(chunk), isFalse, reason: 'a chunk never waits');
      expect(
        gate().waitingFor(sentence).map((n) => n.id),
        unorderedEquals(<String>['xx-0001', 'xx-0002', 'xx-rule-in']),
      );

      _answer(progress, 'xx-0001', _nineOfTen);
      _answer(progress, 'xx-0002', _nineOfTen);
      _answer(progress, 'xx-r-1', _sevenOfTen);
      expect(gate().waitingFor(sentence).map((n) => n.id), <String>[
        'xx-rule-in',
      ], reason: 'the rule is answered right on 7 of its last 10: not known');
      expect(gate().isClosed(sentence), isTrue);

      _answer(
        progress,
        'xx-r-1',
        _nineOfTen,
        from: _start.add(const Duration(days: 1)),
      );
      expect(gate().isClosed(sentence), isFalse);
      expect(gate().isOpen(sentence), isTrue);
    });

    test(
      'a word is known on 9 of its last 10 answers; old misses fall out',
      () {
        final progress = MemoryProgress();
        _answer(progress, 'xx-0001', <int>[1, 1, 1, ..._nineOfTen]);
        _answer(progress, 'xx-0002', _sevenOfTen);
        final answers = RecentAnswers(progress.log);
        expect(answers.of('xx-0001').level, MasteryLevel.known);
        expect(answers.rightOf('xx-0001'), 9);
        expect(answers.of('xx-0002').level, MasteryLevel.learning);
        expect(answers.rightOf('xx-0002'), 7);
      },
    );

    test('a rule that the learner\'s course does not teach is not waited '
        'for, and a word it does not have is not either', () {
      final lonely = _sentence(
        'xx-s-2',
        words: <String>['xx-9999'],
        rules: <String>['xx-rule-missing'],
      );
      final gate = Unlocks(log: MemoryProgress().log, cards: cards);
      expect(gate.needsOf(lonely), isEmpty);
      expect(gate.isClosed(lonely), isFalse);
    });

    test('a rule\'s table grows as words are learned: a cell is taught only '
        'for a word that is known', () {
      final progress = MemoryProgress();
      Unlocks gate() => Unlocks(log: progress.log, cards: cards);
      expect(gate().isCellOpen(cards[2]), isFalse);
      expect(gate().isCellOpen(cards[3]), isFalse);
      _answer(progress, 'xx-0001', _nineOfTen);
      expect(gate().isCellOpen(cards[2]), isTrue);
      expect(gate().isCellOpen(cards[3]), isFalse);
      expect(gate().isOpen(_word('xx-0003')), isTrue);
    });
  });

  group('the counts', () {
    final cards = <KindedCard>[
      (card: _word('xx-0001'), kind: DeckKind.vocab),
      (card: _word('xx-0002'), kind: DeckKind.vocab),
      (card: _word('xx-0003'), kind: DeckKind.vocab),
      (card: _cell('xx-r-1', 'xx-0001'), kind: DeckKind.rules),
      (
        card: _sentence(
          'xx-s-1',
          words: <String>['xx-0001'],
          rules: <String>['xx-rule-in'],
        ),
        kind: DeckKind.vocab,
      ),
      (
        card: _sentence('xx-s-2', words: <String>['xx-0003']),
        kind: DeckKind.vocab,
      ),
    ];

    UnlockCounts count(MemoryProgress progress) => Unlocks(
      log: progress.log,
      cards: <Card>[for (final e in cards) e.card],
    ).counts(cards);

    test('words, rules and sentences are counted against what is taught so '
        'far, words by their base word', () {
      final progress = MemoryProgress();
      expect(count(progress), noUnlockCounts);

      _answer(progress, 'xx-0001', _nineOfTen);
      _answer(progress, 'xx-0002', _sevenOfTen);
      _answer(progress, 'xx-r-1', _nineOfTen);
      // Two words taught, one of them known; the rule is known; the
      // sentences of the deck the learner began count, one of them open.
      progress.record(
        deckId: 'xx-sentences',
        cardId: 'xx-s-1',
        mode: DrillMode.recognition,
        grade: 4,
        now: _start.add(const Duration(days: 2)),
      );
      final counts = count(progress);
      expect(counts.wordsKnown, 1);
      expect(counts.wordsTaught, 2);
      expect(counts.rulesKnown, 1);
      expect(counts.rulesTaught, 1);
      expect(counts.sentencesTotal, 2);
      expect(counts.sentencesOpen, 1, reason: 'xx-s-2 waits for xx-0003');
    });

    test('two forms of one word are one word', () {
      const form = Card(
        id: 'xx-0004',
        deckId: 'xx-words',
        target: 'forms',
        native: 'forms',
        pos: 'noun',
        bases: <CardBase>[CardBase(word: 'forms', ref: 'xx-0001')],
      );
      final all = <KindedCard>[
        (card: _word('xx-0001'), kind: DeckKind.vocab),
        (card: form, kind: DeckKind.vocab),
      ];
      final progress = MemoryProgress();
      _answer(progress, 'xx-0001', _nineOfTen);
      _answer(progress, 'xx-0004', _nineOfTen);
      final counts = Unlocks(
        log: progress.log,
        cards: <Card>[for (final e in all) e.card],
      ).counts(all);
      expect(counts.wordsTaught, 1);
      expect(counts.wordsKnown, 1);
    });
  });

  group('a rule in a lesson', () {
    const nounForms = 'bn-en-grammar-noun-forms';

    Future<AppState> bengali() async {
      final state = AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['bn'],
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      return state;
    }

    /// Answers the word card [id] right ten times, so that it is known.
    void know(AppState state, String id) {
      final entry = state.decks.firstWhere(
        (e) => e.cards.any((c) => c.id == id),
      );
      for (var i = 0; i < 10; i++) {
        state.progress.record(
          deckId: entry.id,
          cardId: id,
          mode: DrillMode.recognition,
          grade: 4,
          now: state.now().subtract(Duration(days: 20 - i)),
        );
      }
    }

    DrillRequest lesson() =>
        DrillRequest.lesson(language: 'bn', deckId: nounForms);

    test('a rules table is taught only for a known word, three cells a '
        'lesson, each rule introduced by its rule card first', () async {
      final state = await bengali();
      expect(
        state.lessonFor(lesson()),
        isEmpty,
        reason: 'no word of the table is known yet',
      );

      final word = state.deckById(nounForms)!.cards.first.rule!.word;
      know(state, word);
      final items = state.lessonFor(lesson());
      final asked = <String>{
        for (final item in items)
          if (!item.ask.onlyShows) item.card.id,
      };
      expect(asked, hasLength(3), reason: 'three new cells a lesson');
      expect(
        items.where((i) => i.card.rule != null).map((i) => i.card.rule!.word),
        everyElement(word),
        reason: 'only the known word is asked',
      );
      final rules = <String>{};
      for (final item in items) {
        final rule = item.card.rule!.ruleId;
        if (item.ask == Ask.teachRule) {
          expect(rules.add(rule), isTrue, reason: 'one rule card a rule');
        } else {
          expect(rules, contains(rule), reason: 'the rule card comes first');
        }
      }
    });

    testWidgets('the rule card comes first; after an answer the word\'s '
        'forms in the rule are shown with the cell asked marked', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      final state = await bengali();
      know(state, state.deckById(nounForms)!.cards.first.rule!.word);
      await pumpScreen(tester, DrillPage(request: lesson()), state: state);
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);

      expect(find.byType(RuleCard), findsOneWidget);
      final session = tester
          .widget<TeachDrill>(find.byType(TeachDrill))
          .session;
      final card = session.item.card;
      final rule = state.ruleOf(card.rule!.ruleId)!.rule;
      expect(find.text(rule.name), findsOneWidget);
      expect(find.text(l10n.ruleCardWords), findsOneWidget);

      session.learnt();
      await tester.pumpAndSettle();
      final choice = tester.widget<ChoiceDrill>(find.byType(ChoiceDrill));
      final question = choice.session;
      expect(find.byType(RuleCard), findsNothing);
      final cell = question.item.card.rule!;
      final word = cell.wordReading == null
          ? cell.wordTarget
          : '${cell.wordTarget} (${cell.wordReading})';
      expect(find.text(l10n.ruleFormsTitle(word)), findsNothing);
      question.pick(
        question.options.firstWhere((o) => o.id == question.item.card.id),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.ruleFormsTitle(word)), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow at 1.4x');
    });

    testWidgets('a rule\'s table on the unit page hides words not taught, and '
        'grows as a word is known', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await bengali();
      await pumpScreen(
        tester,
        const UnitPage(deckId: nounForms, openTables: true),
        state: state,
      );
      final l10n = l10nOf(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.unitRuleGrows),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.unitCellNotAsked), findsNothing);

      know(state, state.deckById(nounForms)!.cards.first.rule!.word);
      await tester.pumpAndSettle();
      expect(find.text(l10n.unitCellNotAsked), findsWidgets);
    });
  });

  group('progress in words, rules and sentences', () {
    const nounForms = 'bn-en-grammar-noun-forms';

    Future<AppState> bengali() async {
      final state = AppState.test(
        features: FeatureRegistry.all(),
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['bn'],
        ),
      );
      addTearDown(state.dispose);
      await state.load();
      return state;
    }

    /// Answers the card [id] right ten times, ending [ago] before now.
    void know(AppState state, String id, {Duration ago = Duration.zero}) {
      final entry = state.decks.firstWhere(
        (e) => e.cards.any((c) => c.id == id),
      );
      for (var i = 0; i < 10; i++) {
        state.progress.record(
          deckId: entry.id,
          cardId: id,
          mode: DrillMode.recognition,
          grade: 4,
          now: state.now().subtract(ago + Duration(minutes: 10 - i)),
        );
      }
    }

    testWidgets('Progress shows three tiles, words, rules and sentences, '
        'counted against what is taught so far, at 1.4x', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await bengali();
      know(state, state.deckById(nounForms)!.cards.first.rule!.word);
      await pumpScreen(tester, const StatsPage(), state: state);
      final l10n = l10nOf(tester);

      final tiles = tester.widgetList<UnlockTile>(find.byType(UnlockTile));
      expect(tiles.map((t) => t.title), <String>[
        l10n.progressWordsTitle,
        l10n.progressRulesTitle,
        l10n.progressSentencesTitle,
      ]);
      final words = tiles.first;
      expect(words.figure, '1');
      expect(words.outOf, l10n.progressOfTaught('1'));
      expect(find.byType(LevelTile), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow at 1.4x');
    });

    testWidgets('the end of a lesson counts what it unlocked: the words that '
        'became known, not those known before', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = await bengali();
      final words = <String>{
        for (final entry in state.decks)
          if (entry.language.code == 'bn' && entry.deck.kind == DeckKind.vocab)
            for (final card in entry.cards)
              if (card.pos == 'noun') card.id,
      }.take(2).toList();
      // One word known long before the lesson, one during it.
      know(state, words[0], ago: const Duration(hours: 5));
      know(state, words[1]);
      final start = state.now().subtract(const Duration(hours: 1));
      await pumpScreen(
        tester,
        SummaryPage(
          result: SessionResult(
            answers: const <SessionAnswer>[
              SessionAnswer(skill: Skill.recognition, grade: 4),
            ],
            startedAt: start,
            endedAt: state.now(),
            language: 'bn',
          ),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.summaryUnlockedTitle), findsOneWidget);
      expect(find.text(l10n.summaryUnlockedWords(1)), findsOneWidget);
      expect(find.text(l10n.summaryUnlockedRules(1)), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
