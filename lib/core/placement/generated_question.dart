import 'assurance_model.dart';
import 'placement_questions.dart';
import 'question_outcome.dart';

// A concrete, answerable question of a "Find my level" run, as plain data
// (wiki/Plan-Placement-V2.md, "Step 2: question generators"). Named
// `GeneratedQuestion` because `PlacementQuestion` is already the existing
// flow's class in `lib/app/placement.dart`; a screen of step 3 imports both.

/// What the learner is shown or played.
enum PlacementPromptKind {
  /// A sentence written in the script, no reading and no audio (K1).
  writtenSentence,

  /// A sentence played, with no text (K2, R1).
  heardSentence,

  /// A word written in the script (W1).
  writtenWord,

  /// A word played (W2, a minimal pair, a split).
  heardWord,

  /// The English meaning, to be said or built in the language (R2, Say,
  /// the spelling splits).
  meaning,

  /// A sentence with one form blanked (G1).
  blankSentence,

  /// A pair of sentences, one correct (G3, a split of R2).
  sentencePair,
}

/// How the learner answers.
enum PlacementAnswerMode {
  /// Pick one of [GeneratedQuestion.options].
  pick,

  /// Say the meaning in English; [GeneratedQuestion.accepted] holds the
  /// accepted meanings. Without a microphone the same question is answered
  /// as a pick ([GeneratedQuestion.options] is always filled for it).
  sayEnglish,

  /// Say the word in the language; [GeneratedQuestion.accepted] holds the
  /// taught form and its alternatives and listed synonyms.
  say,

  /// Put [GeneratedQuestion.tiles] in order; [GeneratedQuestion.accepted]
  /// holds every accepted order, tiles joined by [GeneratedQuestion.joiner].
  tiles,
}

/// A sound to play: the voice says [text] in [language], or the card's
/// recording is played where [cardId] has one.
class PlacementAudio {
  const PlacementAudio({
    required this.text,
    required this.language,
    this.cardId,
    this.trusted = true,
  });

  final String text;
  final String language;
  final String? cardId;

  /// False for a minimal pair's audio until a device check says the system
  /// voice keeps the contrast (section 8, item 4): a native could fail a
  /// correct answer on a flattened contrast, so the caller may use
  /// [GeneratedQuestion.tilesFallback] instead.
  final bool trusted;
}

/// A split question a miss of this one would ask (section 3.1): the part it
/// isolates and the skills it tests.
class PlacementSplitRequest {
  const PlacementSplitRequest({
    required this.variant,
    required this.part,
    required this.kind,
    required this.skills,
  });

  final PlacementVariant variant;
  final PlacementPart part;
  final PlacementQuestionKind kind;
  final List<PlacementSkill> skills;
}

/// How hard an item is, and why (section 2.2).
class ItemDifficulty {
  const ItemDifficulty({
    required this.deck,
    required this.depth,
    required this.form,
    required this.closeness,
    required this.score,
    this.level = 0,
    this.shortOfLong = false,
  });

  /// The deck index of the item.
  final int deck;

  /// The deck's depth, 0 to 1.
  final double depth;

  /// The item's form, 0 to 1.
  final double form;

  /// How close the nearest wrong option is, 0 to 1.
  final double closeness;

  /// `0.35 depth + 0.30 form + 0.35 closeness`.
  final double score;

  /// 1, 2 or 3 for A1, A2 or B1 by the path's level marks; 0 when it marks
  /// none for the deck.
  final int level;

  /// A sentence asked as "long" with fewer than eight words, because the
  /// decks have no longer one (the language's sentences are short).
  final bool shortOfLong;
}

/// A word to build from tiles in place of a pair's audio (the written
/// fallback of section 8): the English meaning of one word of the pair, and
/// the letters to build it from, with the contrast's other letter among them.
class PlacementTilesFallback {
  const PlacementTilesFallback({
    required this.meaning,
    required this.tiles,
    required this.accepted,
  });

  final String meaning;
  final List<String> tiles;
  final List<String> accepted;
}

/// A question of a run, ready to show: the prompt, the options or the
/// accepted answers, and what the run controller needs to know about it.
class GeneratedQuestion {
  const GeneratedQuestion({
    required this.request,
    required this.prompt,
    required this.mode,
    required this.itemIds,
    required this.difficulty,
    this.promptText,
    this.promptReading,
    this.audio,
    this.options = const <String>[],
    this.correctIndex,
    this.accepted = const <String>[],
    this.tiles = const <String>[],
    this.joiner = ' ',
    this.splits = const <PlacementSplitRequest>[],
    this.cardId,
    this.concept,
    this.optionsAreAudio = false,
    this.tilesFallback,
    this.dialectRisk = false,
    this.meaningHint,
  });

  /// The request it answers; its skills are the skills a right answer covers.
  final PlacementQuestionRequest request;

  final PlacementPromptKind prompt;
  final PlacementAnswerMode mode;

  /// What is shown. Never a reading for a question that asks to read the
  /// script alone (K1); null for a question that is only heard.
  final String? promptText;

  /// The prompt's reading in Latin letters, filled only where the question
  /// allows one: where Hear is not tested and a heard prompt is shown as a
  /// reading instead (section 3.1).
  final String? promptReading;

  final PlacementAudio? audio;

  /// The options of a pick, in the order shown; empty for a question with no
  /// pick. For a [PlacementAnswerMode.sayEnglish] question this is the
  /// no-microphone pick.
  final List<String> options;

  /// The index of the right option in [options]; null where there are none.
  final int? correctIndex;

  /// Every accepted answer: English meanings, words in the language, or tile
  /// orders joined by [joiner].
  final List<String> accepted;

  /// The tiles of a build, shuffled (never in the right order), with the close
  /// wrong ones among them.
  final List<String> tiles;
  final String joiner;

  /// The two split questions a miss would ask (section 3.1); empty for a
  /// question with no split.
  final List<PlacementSplitRequest> splits;

  /// The card the question is about.
  final String? cardId;

  /// The concept the question is about: a grammar family or a sound
  /// contrast; at most one first question per concept in a run (section 2.3).
  final String? concept;

  /// Whether [options] are two sounds to listen to, not two texts.
  final bool optionsAreAudio;

  /// A written version of a minimal pair, for when the audio is not trusted.
  final PlacementTilesFallback? tilesFallback;

  /// Say may fail a fluent speaker of another dialect (section 2.4): true for
  /// every question the learner says.
  final bool dialectRisk;

  /// The English meaning of a blanked or built sentence, shown with it so that
  /// only the grammar is tested.
  final String? meaningHint;

  final ItemDifficulty difficulty;

  /// What the question uses, for the no-repeat set the next call is given
  /// (`asked`): the cards asked and offered, `family:<id>` for each word
  /// family and `concept:<id>` for the concept (section 2.3).
  final Set<String> itemIds;

  /// Whether the pair audio of this question is not trusted (section 8).
  bool get audioUntrusted => audio != null && !audio!.trusted;

  /// Whether [answer], an option's index, is right.
  bool isRightPick(int answer) =>
      correctIndex != null && answer == correctIndex;
}

/// What the builder returns: a question, or why there is none.
sealed class QuestionOutcome {
  const QuestionOutcome();
}

/// The question was built.
class QuestionBuilt extends QuestionOutcome {
  const QuestionBuilt(this.question);

  final GeneratedQuestion question;
}

/// The learner's data does not support the question. The run controller maps
/// [reason] to the plan's stated fallback ([PlacementRun.markUnavailable]).
class QuestionUnavailable extends QuestionOutcome {
  const QuestionUnavailable(this.reason, [this.detail = '']);

  final PlacementUnavailableReason reason;

  /// What was missing, for a log or a note on the result sheet.
  final String detail;
}
