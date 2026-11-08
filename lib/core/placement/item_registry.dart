import 'cognate_score.dart';
import 'joint_model.dart';
import 'placement_questions.dart';

// The item registry of "Find my level" V3 (wiki/Plan-Placement-V3.md, section
// (b), with the item-generation amendments of its adversarial review): the
// format inventory F1 to F20, what each format needs and leaks, and the items
// the generators produce from a language's decks.
//
// Pure Dart. The generators are in item_generators.dart, the admission audit
// in item_audit.dart, the bank builder in item_bank.dart.

/// One item format of the plan's inventory.
class FormatInfo {
  const FormatInfo(
    this.code,
    this.name,
    this.skills,
    this.slip,
    this.guess,
    this.seconds, {
    this.wordLevel = true,
    this.options = 0,
    this.needsAudio = false,
    this.needsMic = false,
    this.leakRisk = '',
    this.generated = true,
    this.notGeneratedBecause = '',
  });

  /// `F1` to `F20`, and `S2` for the word-order pair of the V2 bank.
  final String code;
  final String name;

  /// The skills a right answer is evidence for (noisy AND).
  final Set<PlacementSkill> skills;

  /// P(wrong) for a learner who knows the item, and P(right) by guessing
  /// (the design values, before calibration).
  final double slip;
  final double guess;

  /// The time table of the plan, in seconds.
  final double seconds;

  /// Whether the format asks about one word: near-cognates never appear in it.
  final bool wordLevel;

  /// The number of options of a pick; 0 for the other answer kinds.
  final int options;

  final bool needsAudio;
  final bool needsMic;

  /// What a gamer could use to answer without knowing the words.
  final String leakRisk;

  /// Whether the registry has a generator for it.
  final bool generated;

  /// Why not, when [generated] is false.
  final String notGeneratedBecause;

  /// The admission bound of the audit: the design guess plus 0.07 (0.32 for
  /// a four-option pick).
  double get admissionBound => options == 4 ? 0.32 : guess + 0.07;
}

const _read = PlacementSkill.read;
const _hear = PlacementSkill.hear;
const _say = PlacementSkill.say;
const _write = PlacementSkill.write;
const _script = PlacementSkill.script;

/// The inventory of the plan, F1 to F20, the word-order pair `S2`, and the
/// cheap Write item `F21` of build step 4b.
const List<FormatInfo> kFormatInventory = <FormatInfo>[
  FormatInfo(
    'F1',
    'Written yes/no, real word or pseudoword',
    {_read},
    0.10,
    0.50,
    3,
    leakRisk:
        'a cognate says yes; a pseudoword that breaks the language\'s '
        'letter patterns says no',
  ),
  FormatInfo(
    'F2',
    'Written word, pick its English meaning',
    {_read},
    0.05,
    0.25,
    6,
    options: 4,
    leakRisk: 'cognates; the odd option by length or part of speech',
  ),
  FormatInfo(
    'F3',
    'English meaning, pick the written word',
    {_read},
    0.05,
    0.25,
    6,
    options: 4,
    leakRisk: 'cognates; spelling cues',
  ),
  FormatInfo(
    'F4',
    'English meaning, build the word from tiles',
    {_write},
    0.05,
    0.10,
    15,
    leakRisk: 'an anagram solver when the tiles are only the word\'s letters',
  ),
  FormatInfo(
    'F5',
    'Written sentence, pick its English meaning',
    {_read},
    0.10,
    0.25,
    8,
    wordLevel: false,
    options: 4,
    leakRisk: 'topic guessing; the longest option; cognate words',
  ),
  FormatInfo(
    'F6',
    'Cloze: pick the word for the blank',
    {_read},
    0.10,
    0.25,
    8,
    wordLevel: false,
    options: 4,
    leakRisk: 'endings that agree with the sentence; an English hint',
  ),
  FormatInfo(
    'F6g',
    'Cloze: the article of a noun whose ending does not show its gender',
    {_read},
    0.10,
    0.50,
    6,
    options: 2,
    leakRisk: 'the ending rule (it is wrong on exceptions by design)',
  ),
  FormatInfo(
    'F7',
    'English meaning, type the word',
    {_write},
    0.15,
    0.03,
    12,
    leakRisk: 'a spelling-rule guess from an English cognate',
  ),
  FormatInfo(
    'F21',
    'English meaning and the word with one unit left out, type the unit',
    {_write},
    0.08,
    0.10,
    6,
    leakRisk:
        'the letter patterns of the language fill the gap; chosen so that '
        'none of them does',
  ),
  FormatInfo(
    'F8',
    'English sentence, build it from tiles',
    {_write, _read},
    0.10,
    0.05,
    15,
    wordLevel: false,
    leakRisk: 'word order from the English; decoy elimination',
  ),
  FormatInfo(
    'F9',
    'Matching, four word and meaning pairs',
    {_read},
    0.05,
    0.25,
    15,
    options: 4,
    leakRisk: 'elimination; part of speech; cognates',
  ),
  FormatInfo(
    'F10',
    'Matching, letter and sound',
    {_script},
    0.05,
    0.25,
    10,
    generated: false,
    notGeneratedBecause:
        'needs the script decks (letters), read by the app, not by the '
        'language data of this registry; built with the screens of step 6',
  ),
  FormatInfo(
    'F11',
    'Matching, word and picture',
    {_read},
    0.05,
    0.25,
    12,
    generated: false,
    notGeneratedBecause:
        'needs the decks\' pictures, which the language data does not carry',
  ),
  FormatInfo(
    'F12',
    'Letter to sound, pick the romanisation',
    {_script},
    0.03,
    0.25,
    5,
    options: 4,
    generated: false,
    notGeneratedBecause: 'needs the script decks; trivial in a Latin script',
  ),
  FormatInfo(
    'F13',
    'Heard word, pick its English meaning',
    {_hear},
    0.05,
    0.25,
    6,
    options: 4,
    needsAudio: true,
    leakRisk: 'cognates heard; poor text to speech',
  ),
  FormatInfo(
    'F14',
    'Heard yes/no, real word or pseudoword',
    {_hear},
    0.10,
    0.50,
    3,
    needsAudio: true,
    leakRisk: 'a pseudoword the voice cannot say',
  ),
  FormatInfo(
    'F15',
    'Minimal pair, which of two was said',
    {_hear},
    0.05,
    0.50,
    6,
    options: 2,
    needsAudio: true,
    generated: false,
    notGeneratedBecause:
        'the V2 question builder makes pairs from the language\'s sounds file '
        'and audio trust (question_builder.dart); it joins this registry '
        'with the audio screens of step 6',
  ),
  FormatInfo(
    'F16',
    'Dictation: hear a sentence, build it from tiles',
    {_hear, _write},
    0.10,
    0.05,
    15,
    wordLevel: false,
    needsAudio: true,
    leakRisk: 'decoy elimination',
  ),
  FormatInfo(
    'F17',
    'Heard sentence, pick its English meaning',
    {_hear},
    0.10,
    0.25,
    8,
    wordLevel: false,
    options: 4,
    needsAudio: true,
    leakRisk: 'topic guessing; cognate words heard',
  ),
  FormatInfo(
    'F18',
    'English meaning, say the word',
    {_say},
    0.15,
    0.03,
    10,
    needsAudio: true,
    needsMic: true,
    leakRisk: 'a cognate said as spelled',
  ),
  FormatInfo(
    'F19',
    'Say, then pick which audio was meant',
    {_say},
    0.05,
    0.33,
    12,
    options: 3,
    needsAudio: true,
    needsMic: true,
    generated: false,
    notGeneratedBecause: 'needs three synthesised audios per item (step 6)',
  ),
  FormatInfo(
    'F20',
    'Read a sentence aloud, self-rate',
    {_say, _read},
    0.10,
    0.30,
    10,
    wordLevel: false,
    needsAudio: true,
    needsMic: true,
    generated: false,
    notGeneratedBecause:
        'a self-rated item is never evidence (the joint model ignores it), '
        'so it needs no admission audit; it is a screen of step 6',
  ),
  FormatInfo(
    'S2',
    'Word order: which of two sentences is correct',
    {_read},
    0.10,
    0.50,
    6,
    wordLevel: false,
    options: 2,
    leakRisk: 'end marks left in the wrong place; bigram plausibility',
  ),
];

/// The inventory entry for [code].
FormatInfo formatInfo(String code) =>
    kFormatInventory.firstWhere((f) => f.code == code);

/// One askable item, as public data plus the key the audit and the picker
/// score it with.
class RegItem {
  RegItem({
    required this.id,
    required this.format,
    required this.cardId,
    required this.deck,
    required this.prompt,
    this.promptRoman,
    this.options = const <String>[],
    this.optionsRoman = const <String>[],
    this.correct = 0,
    this.tiles = const <String>[],
    this.answerTiles = const <String>[],
    this.accepted = const <String>[],
    this.leadingMark = '',
    this.trailingMark = '',
    this.pairs = const <(String, String)>[],
    this.cognateScore = 0,
    this.nonCognateContent = -1,
    this.weight = 1,
    this.pseudo = false,
    this.isReal = true,
    this.genderException = false,
    this.decoyCount = 0,
    this.gapIndex = -1,
    this.lemmas = const <String>{},
    this.coCards = const <String>{},
  });

  /// `<card>:<format>`, stable for a language's decks.
  final String id;

  /// The format code (`F2`...).
  final String format;

  /// The card the item asks (a card id; for a pseudoword, `pw<n>`).
  final String cardId;

  /// The deck index of the card: the item's difficulty.
  final int deck;

  /// What is shown or played: the word, the sentence, or the meaning.
  final String prompt;

  /// [prompt] romanised (a Devanagari word by its reading), for audits.
  final String? promptRoman;

  /// The options of a pick (or the two sentences of a word-order pair).
  final List<String> options;
  final List<String> optionsRoman;

  /// The index of the right option.
  final int correct;

  /// The tiles shown (shuffled) and the right order, for tile formats.
  final List<String> tiles;
  final List<String> answerTiles;

  /// The accepted typed or said answers.
  final List<String> accepted;

  /// The marks of a sentence kept fixed in place around the tiles.
  final String leadingMark;
  final String trailingMark;

  /// For a matching screen: (prompt, meaning) in the right pairing.
  final List<(String, String)> pairs;

  /// The cognate score of the card's word (word formats) or the highest of
  /// its content words (sentences), 0 to 1.
  final double cognateScore;

  /// The content words of a sentence that are not near-cognates; -1 for a
  /// word item.
  final int nonCognateContent;

  /// How much the item counts: 0.5 for a sentence with fewer than two
  /// non-cognate content words, else 1.
  final double weight;

  /// A yes/no pseudoword, and whether a yes/no real item is a real word.
  final bool pseudo;
  final bool isReal;

  /// A gender cloze on a noun whose gender its ending does not predict.
  final bool genderException;

  /// How many decoy tiles a word tile item carries.
  final int decoyCount;

  /// For a gap-spelling item (F21): the index of the unit left out of
  /// [answerTiles] (the word's units); [accepted] holds the unit to type.
  final int gapIndex;

  /// The base lemmas of the item's content words, for the family rule.
  final Set<String> lemmas;

  /// Other cards the item uses (the rest of a matching screen).
  final Set<String> coCards;

  FormatInfo get info => formatInfo(format);

  /// The cognate class of the item: `cognate` for a word near-cognate or a
  /// sentence with fewer than two non-cognate content words.
  String get cognateClass {
    if (info.wordLevel) {
      return cognateScore >= kCognateThreshold ? 'cognate' : 'clean';
    }
    return nonCognateContent >= 2 ? 'clean' : 'cognate';
  }

  /// The audit class: format and cognate class.
  String get auditClass => '$format:$cognateClass';

  /// The keys two items must not share in one run: the card, and the lemma
  /// of a word (so a word asked in one format never meets another form of
  /// the same lemma or a sentence that uses it).
  late final Set<String> conflictKeys = <String>{
    'c:$cardId',
    for (final c in coCards) 'c:$c',
    for (final l in lemmas) 'l:$l',
  };

  /// The model's view of the item, with the guess calibrated by [calibration]
  /// for the bank's format key. [formatKey] defaults to the format code.
  JointItem toJointItem({
    GuessCalibration calibration = GuessCalibration.seed,
    String? formatKey,
  }) {
    final cognate = cognateClass == 'cognate';
    final guess = calibration.guessFor(
      formatKey ?? format,
      cognate,
      info.guess,
    );
    if (pseudo) {
      return JointItem.pseudoword(skills: info.skills, cardId: cardId);
    }
    final yes = format == 'F1' || format == 'F14';
    return JointItem(
      skills: info.skills,
      deck: deck,
      slip: info.slip,
      guess: yes ? 0 : guess,
      weight: weight,
      clean: !cognate && guess <= kCleanGuessMax,
      yesNo: yes ? YesNoRole.realWord : YesNoRole.notYesNo,
      cardId: cardId,
    );
  }
}
