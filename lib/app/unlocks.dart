import 'dart:math';

import '../core/models/card.dart';
import '../core/models/rule.dart';
import '../core/progress/recent_answers.dart'
    show MasteryLevel, ParametersOfReview, RecentAnswers;
import '../core/progress/unlocks.dart';
import 'app_state.dart';
import 'deck_catalog.dart';
import 'session.dart';

/// A rule of a rules deck, and the deck that gives it.
typedef RuleEntry = ({Rule rule, DeckEntry deck});

/// The unlock gate and the counts of words, rules and sentences
/// (docs/plans/words-rules-sentences.md), worked out from the learner's
/// log once, and again only after progress, settings or the decks change
/// ([AppState.derived]).
extension UnlockState on AppState {
  /// The parameters that schedule a review's pair, so that known here is
  /// known on Progress.
  ParametersOfReview get _parametersOf {
    final byDeck = <String, String>{
      for (final entry in decks) entry.id: entry.language.code,
    };
    return (event) => progress.parameters.of(
      byDeck[event.deckId] ?? event.deckId.split('-').first,
      event.mode,
    );
  }

  /// How well each card is known: the log's last review in each skill, as
  /// Progress counts known.
  RecentAnswers get recentAnswers => derived<RecentAnswers>(
    #recentAnswers,
    () => RecentAnswers(progress.log, parametersOf: _parametersOf),
  );

  /// The gate over every card of the decks.
  Unlocks get unlocks => derived<Unlocks>(
    #unlocks,
    () => Unlocks(
      log: progress.log,
      cards: <Card>[for (final entry in decks) ...entry.cards],
      parametersOf: _parametersOf,
    ),
  );

  List<KindedCard> _kindedCards(String language) => <KindedCard>[
    for (final entry in decks)
      if (entry.language.code == language)
        for (final card in entry.cards) (card: card, kind: entry.deck.kind),
  ];

  /// [language]'s words known, rules known and sentences open, out of what
  /// is taught so far.
  UnlockCounts unlockCountsFor(String language) => derived<UnlockCounts>((
    #unlockCounts,
    language,
  ), () => unlocks.counts(_kindedCards(language)));

  /// [unlockCountsFor] as they stood before [at]: what a lesson started at
  /// [at] unlocked is what changed since.
  UnlockCounts unlockCountsBefore(String language, DateTime at) => Unlocks(
    log: progress.log.where((event) => event.at.isBefore(at)),
    cards: <Card>[for (final entry in decks) ...entry.cards],
    parametersOf: _parametersOf,
  ).counts(_kindedCards(language));

  /// What the lesson that began at [since] unlocked in [language]: the words
  /// and rules that became known and the sentences that opened, or null when
  /// it unlocked none (#418).
  ({int words, int rules, int sentences})? unlockedSince(
    String language,
    DateTime since,
  ) {
    final before = unlockCountsBefore(language, since);
    final after = unlockCountsFor(language);
    final unlocked = (
      words: max(0, after.wordsKnown - before.wordsKnown),
      rules: max(0, after.rulesKnown - before.rulesKnown),
      sentences: max(0, after.sentencesOpen - before.sentencesOpen),
    );
    return unlocked.words + unlocked.rules + unlocked.sentences == 0
        ? null
        : unlocked;
  }

  /// The counts of every language the learner can choose, added up.
  UnlockCounts get unlockCountsAll => sumUnlockCounts(<UnlockCounts>[
    for (final choice in languageChoices) unlockCountsFor(choice.code),
  ]);

  /// How many words and rules of [language] are taught and not known yet:
  /// what a lesson's size waits on ([lessonRoom]).
  int inProgressIn(String language) => derived<int>((
    #inProgress,
    language,
  ), () => unlocks.inProgress(_kindedCards(language)));

  /// The rule [id], with the deck that gives it, from the course taught from
  /// the learner's language where it can; null if no deck has it.
  RuleEntry? ruleOf(String id) {
    final code = id.split('-').first;
    final native = courseNative(code);
    RuleEntry? found;
    for (final entry in decks) {
      for (final rule in entry.deck.rules) {
        if (rule.id != id) continue;
        if (entry.deck.native.code == native) return (rule: rule, deck: entry);
        found ??= (rule: rule, deck: entry);
      }
    }
    return found;
  }

  /// The card [id] from the decks, or null if none has it.
  Card? cardById(String id) => derived<Map<String, Card>>(#cardsById, () {
    final byId = <String, Card>{};
    for (final entry in decks) {
      for (final card in entry.cards) {
        byId.putIfAbsent(card.id, () => card);
      }
    }
    return byId;
  })[id];

  /// What [need] is called: a word as its card writes it, with its reading,
  /// a rule by its name. The id where no deck has it.
  String needName(Need need) {
    if (need.kind == NeedKind.rule) {
      return ruleOf(need.id)?.rule.name ?? need.id;
    }
    final card = cardById(need.id);
    if (card == null) return need.id;
    return card.reading == null
        ? card.target
        : '${card.target} (${card.reading})';
  }

  /// The session that practises the rule [id]: its cells taught so far
  /// revised, or, before any was taught, a lesson on its deck; null where
  /// there is nothing to practise or no deck gives the rule.
  DrillRequest? practiseRule(String id) {
    final found = ruleOf(id);
    if (found == null) return null;
    final deck = found.deck;
    if (unlocks.ruleStanding(id).level != MasteryLevel.fresh) {
      return DrillRequest.practice(deck.id);
    }
    final lesson = DrillRequest.lesson(
      language: deck.language.code,
      deckId: deck.id,
    );
    return lessonFor(lesson).isEmpty ? null : lesson;
  }

  /// Up to [count] forms of the rule [cell] belongs to, in its slot, on
  /// words the learner knows, [cell] first: what the rule card shows the
  /// rule making (#417).
  List<Card> ruleExamples(Card cell, {int count = 3}) {
    final rule = cell.rule;
    final entry = deckOf(cell);
    if (rule == null || entry == null) return <Card>[cell];
    final gate = unlocks;
    final words = <String>{rule.word};
    final forms = <Card>[cell];
    for (final other in entry.cards) {
      if (forms.length >= count) break;
      final made = other.rule;
      if (made != null &&
          made.ruleId == rule.ruleId &&
          made.slot == rule.slot &&
          gate.isWordKnown(made.word) &&
          words.add(made.word)) {
        forms.add(other);
      }
    }
    return forms;
  }

  /// Every form of [cell]'s word in its rules table, in the table's order:
  /// the cells its answer shows beside the one asked. A rule is often one
  /// column, so the forms are the word's whole row.
  List<Card> ruleFormsOf(Card cell) {
    final rule = cell.rule;
    final entry = deckOf(cell);
    if (rule == null || entry == null) return <Card>[cell];
    return <Card>[
      for (final other in entry.cards)
        if (other.rule?.word == rule.word) other,
    ];
  }
}
