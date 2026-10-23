import '../models/card.dart';
import '../models/deck.dart' show DeckKind, countsAsWord;
import '../models/review_event.dart';
import 'recent_answers.dart';

/// Whether [card] is a sentence or a phrase: what a lesson holds back until
/// the words and rules it uses are known, unless it is a phrasebook chunk.
bool isSentenceCard(Card card) => card.pos == 'phrase' || card.rearranges;

/// What a closed sentence waits for: a word or a rule.
enum NeedKind { word, rule }

/// One thing a sentence uses: a word, by the card that teaches its base, or
/// a rule, with where the learner stands in it.
typedef Need = ({NeedKind kind, String id, MasteryLevel level, int right});

/// A card with the kind of its deck, as the counts read it.
typedef KindedCard = ({Card card, DeckKind kind});

/// Words, rules and sentences, as Progress, a unit and a lesson's end count
/// them (docs/plans/words-rules-sentences.md): what is known, out of what is
/// taught so far.
typedef UnlockCounts = ({
  int wordsKnown,
  int wordsTaught,
  int rulesKnown,
  int rulesTaught,
  int sentencesOpen,
  int sentencesTotal,
});

const UnlockCounts noUnlockCounts = (
  wordsKnown: 0,
  wordsTaught: 0,
  rulesKnown: 0,
  rulesTaught: 0,
  sentencesOpen: 0,
  sentencesTotal: 0,
);

/// The unlock gate (docs/plans/words-rules-sentences.md, "Sentences"): a
/// sentence opens once every word in it, by its base, and every rule it uses
/// is known, at the mastery bar of 9 of the last 10 answers right ([knownShare]).
/// A phrasebook chunk is never held back, and a sentence that names no
/// word and no rule the learner's course teaches is not either.
///
/// A rules table's cell is taught only for a word the learner knows, so a
/// rule's table grows as words are learned. Read from the review log, never
/// stored.
class Unlocks {
  /// The gate for [log], over [cards]: every card of the learner's decks.
  Unlocks({required Iterable<ReviewEvent> log, required Iterable<Card> cards})
    : answers = RecentAnswers(log) {
    for (final card in cards) {
      _ids.add(card.id);
      final cell = card.rule;
      if (cell != null) (_cells[cell.ruleId] ??= <String>{}).add(card.id);
    }
  }

  /// The learner's answers.
  final RecentAnswers answers;

  final Set<String> _ids = <String>{};
  final Map<String, Set<String>> _cells = <String, Set<String>>{};

  /// Whether the word card [id] is known.
  bool isWordKnown(String id) => answers.of(id).level == MasteryLevel.known;

  /// The ids of the cells of [ruleId]'s table the learner's course has.
  Set<String> cellsOf(String ruleId) => _cells[ruleId] ?? const <String>{};

  /// Where the learner stands in [ruleId]: its last answers over every cell.
  Mastery ruleStanding(String ruleId) => answers.ofAll(cellsOf(ruleId));

  /// Whether [ruleId] is known.
  bool isRuleKnown(String ruleId) =>
      ruleStanding(ruleId).level == MasteryLevel.known;

  /// The words and rules [sentence] uses, each once, with where the learner
  /// stands in it. A word is a base its `bases` name by a card of the
  /// course; a rule, one its table has cells for, since a rule the learner's
  /// course does not teach cannot be waited for.
  List<Need> needsOf(Card sentence) {
    final words = <String>{
      for (final base in sentence.bases)
        if (base.ref case final ref?
            when ref != sentence.id && _ids.contains(ref))
          ref,
    };
    final rules = <String>{
      for (final id in sentence.rules)
        if (cellsOf(id).isNotEmpty) id,
    };
    return <Need>[
      for (final id in words)
        (
          kind: NeedKind.word,
          id: id,
          level: answers.of(id).level,
          right: answers.rightOf(id),
        ),
      for (final id in rules)
        (
          kind: NeedKind.rule,
          id: id,
          level: ruleStanding(id).level,
          right: answers.rightOfAll(cellsOf(id)),
        ),
    ];
  }

  /// What [sentence] still waits for: what of [needsOf] is not known yet.
  List<Need> waitingFor(Card sentence) => <Need>[
    for (final need in needsOf(sentence))
      if (need.level != MasteryLevel.known) need,
  ];

  /// Whether [card] is a sentence not offered yet: a sentence that is not a
  /// phrasebook chunk, waiting for a word or a rule.
  bool isClosed(Card card) =>
      !card.phrasebook &&
      isSentenceCard(card) &&
      (card.bases.isNotEmpty || card.rules.isNotEmpty) &&
      waitingFor(card).isNotEmpty;

  /// Whether [sentence] is open: it was taught already, or it is not closed.
  bool isOffered(Card sentence) =>
      answers.of(sentence.id).level != MasteryLevel.fresh ||
      !isClosed(sentence);

  /// Whether the rules table's cell [card] may be taught now: its word is
  /// known. Any other card may.
  bool isCellOpen(Card card) {
    final cell = card.rule;
    return cell == null || isWordKnown(cell.word);
  }

  /// Whether [card] may be taught as new: neither a closed sentence nor a
  /// cell of a word not known yet.
  bool isOpen(Card card) => !isClosed(card) && isCellOpen(card);

  /// The word [card] counts as: the base its single base names, else itself.
  /// Two forms of one word are one word.
  static String baseOf(Card card) =>
      card.bases.length == 1 &&
          card.bases.single.ref != null &&
          card.bases.single.ref != card.id
      ? card.bases.single.ref!
      : card.id;

  /// How many words and rules the learner has been taught but does not know
  /// yet, from [cards]: what a lesson waits on before it adds many new
  /// items. A rule is one, however many of its cells have been asked.
  int inProgress(Iterable<KindedCard> cards) {
    final words = <String>{};
    final rules = <String>{};
    for (final (:card, :kind) in cards) {
      if (card.rule case final cell?) {
        if (answers.of(card.id).level != MasteryLevel.fresh &&
            !isRuleKnown(cell.ruleId)) {
          rules.add(cell.ruleId);
        }
      } else if (countsAsWord(card, kind) &&
          answers.of(card.id).level == MasteryLevel.learning) {
        words.add(baseOf(card));
      }
    }
    return words.length + rules.length;
  }

  /// The counts of [cards], each card once: words by their base word, taught
  /// when answered and known when the base, or a form of it, is; rules
  /// taught when a cell was answered; sentences, out of those in the decks
  /// the learner has begun, open when [isClosed] is false.
  UnlockCounts counts(Iterable<KindedCard> cards) {
    final seen = <String>{};
    final wordBases = <String, bool>{};
    final rulesTaught = <String>{};
    final sentences = <Card>[];
    final started = <String>{};
    final list = <KindedCard>[
      for (final entry in cards)
        if (seen.add(entry.card.id)) entry,
    ];
    for (final (:card, :kind) in list) {
      final taught = answers.of(card.id).level != MasteryLevel.fresh;
      if (taught) started.add(card.deckId);
      if (card.rule case final cell?) {
        if (taught) rulesTaught.add(cell.ruleId);
      } else if (countsAsWord(card, kind)) {
        if (taught) {
          final base = baseOf(card);
          final known =
              answers.of(card.id).level == MasteryLevel.known ||
              isWordKnown(base);
          wordBases[base] = (wordBases[base] ?? false) || known;
        }
      } else if (kind == DeckKind.vocab &&
          !card.phrasebook &&
          !card.practiceOnly &&
          isSentenceCard(card)) {
        sentences.add(card);
      }
    }
    final inStarted = <Card>[
      for (final card in sentences)
        if (started.contains(card.deckId)) card,
    ];
    return (
      wordsKnown: wordBases.values.where((known) => known).length,
      wordsTaught: wordBases.length,
      rulesKnown: rulesTaught.where(isRuleKnown).length,
      rulesTaught: rulesTaught.length,
      sentencesOpen: inStarted.where(isOffered).length,
      sentencesTotal: inStarted.length,
    );
  }
}

/// The sum of [all], for Progress on All languages.
UnlockCounts sumUnlockCounts(Iterable<UnlockCounts> all) => all.fold(
  noUnlockCounts,
  (a, b) => (
    wordsKnown: a.wordsKnown + b.wordsKnown,
    wordsTaught: a.wordsTaught + b.wordsTaught,
    rulesKnown: a.rulesKnown + b.rulesKnown,
    rulesTaught: a.rulesTaught + b.rulesTaught,
    sentencesOpen: a.sentencesOpen + b.sentencesOpen,
    sentencesTotal: a.sentencesTotal + b.sentencesTotal,
  ),
);
