import 'dart:math' as math;

import '../models/card.dart';
import '../models/reading.dart' show QuestionCard;
import 'unlocks.dart' show isSentenceCard;

// Cloze (#321, the sentence-building plan): a sentence with one word the
// learner knows left out, and a few words to choose it from. Pure: the
// words, the gap and the options are worked out here, from the cards and
// from a verdict on which cards are known (`Unlocks.isWordKnown`, the one
// rule of known), with a seeded random so that they can be tested.

/// How many known words a sentence has to hold, at least, for it to be asked
/// as a cloze: the gap is one of them, and the others are what is left to
/// understand it by.
const int kClozeMinKnown = 3;

/// How many words a cloze offers at most, the right one among them.
const int kClozeOptions = 4;

/// How many words it offers at least: the right one and two others.
const int kClozeMinOptions = 3;

/// How many wrong words the bank puts aside for a gap, nearest first, so that
/// a spelling a script lacks can be passed over.
const int _spare = 6;

/// The start and end of one word in a text, edge punctuation left out.
typedef WordSpan = ({int start, int end});

final RegExp _chunk = RegExp(r'\S+');
final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _wordCore = RegExp(
  r'[\p{L}\p{M}\p{N}].*[\p{L}\p{M}\p{N}]|[\p{L}\p{M}\p{N}]',
  unicode: true,
);
final RegExp _edgeMarks = RegExp(
  r'^[^\p{L}\p{M}\p{N}]+|[^\p{L}\p{M}\p{N}]+$',
  unicode: true,
);

/// [word] as a cloze compares and shows words: without the marks at its
/// edges, in lowercase, so that a capital never shows where a word goes.
String clozeKey(String word) => word.replaceAll(_edgeMarks, '').toLowerCase();

/// The words of [text], by where each stands in it, without the marks at
/// its edges: split at white space, a chunk with no letter (a dash standing
/// alone) left out, as [wordsOf] does. For a script written without spaces,
/// [given] are the text's words in order ([Card.words]); where they are not
/// the text's, the text is split at white space.
List<WordSpan> wordSpans(String text, {List<String>? given}) {
  if (given != null) {
    final spans = <WordSpan>[];
    var at = 0;
    for (final word in given) {
      final i = word.isEmpty ? -1 : text.indexOf(word, at);
      if (i < 0) return wordSpans(text);
      spans.add((start: i, end: i + word.length));
      at = i + word.length;
    }
    return spans;
  }
  final spans = <WordSpan>[];
  for (final chunk in _chunk.allMatches(text)) {
    final piece = chunk[0]!;
    if (!_letter.hasMatch(piece)) continue;
    final core = _wordCore.firstMatch(piece);
    if (core == null) continue;
    spans.add((start: chunk.start + core.start, end: chunk.start + core.end));
  }
  return spans;
}

/// A sentence a cloze can be made of: a sentence card's own target, or one
/// of a card's examples.
class ClozeSource {
  const ClozeSource({
    required this.target,
    required this.native,
    this.reading,
    this.words,
    this.targetScripts = const <String, String>{},
    this.bases = const <CardBase>[],
  });

  /// A sentence card's own sentence.
  factory ClozeSource.ofCard(Card card) => ClozeSource(
    target: card.target,
    native: card.native,
    reading: card.reading,
    words: card.words,
    targetScripts: card.targetScripts,
    bases: card.bases,
  );

  /// One of a card's examples.
  factory ClozeSource.ofExample(CardExample example) => ClozeSource(
    target: example.target,
    native: example.native,
    reading: example.reading,
    words: example.words,
    targetScripts: example.targetScripts,
    bases: example.bases,
  );

  /// The sentence, in the language's first script.
  final String target;

  /// Its meaning, in the learner's language: shown above it.
  final String native;

  /// The sentence romanised, where it has a reading.
  final String? reading;

  /// The target's words in order, for a script written without spaces.
  final List<String>? words;

  /// The sentence in the language's other scripts, by script id.
  final Map<String, String> targetScripts;

  /// The base words of its inflected words, as the deck gives them.
  final List<CardBase> bases;

  /// The sentence in [script]: [target] for the language's [firstScript],
  /// [targetScripts]'s spelling for another, or null where it has none.
  String? spellingIn(String script, String firstScript) =>
      script == firstScript ? target : targetScripts[script];

  /// Where each word of [target] stands in it.
  List<WordSpan> get spans => wordSpans(target, given: words);
}

/// The word a gap is: where it stands in a sentence, and the card of the
/// known word it is.
typedef ClozeGap = ({int index, Card word});

/// A cloze, chosen: the sentence, its gap and the wrong words put aside for
/// it. Shown by [view], in a script or in Latin letters.
class Cloze {
  const Cloze({
    required this.source,
    required this.gap,
    required this.distractors,
  });

  final ClozeSource source;
  final ClozeGap gap;

  /// Cards of other known words of the gap's kind, the likeliest wrong
  /// options first.
  final List<Card> distractors;

  /// The question as it is shown, or null where it cannot be shown so: in
  /// Latin letters ([reading]) where the sentence has no reading with as many
  /// words as its target, or in a [script] where the sentence has no
  /// spelling in it with as many words, or too few of the options have one.
  /// With neither, the sentence in the language's [firstScript].
  ClozeView? view({
    required String firstScript,
    required math.Random random,
    String? script,
    bool reading = false,
  }) {
    final spans = source.spans;
    if (gap.index >= spans.length) return null;
    final String text;
    final List<WordSpan> shown;
    final String Function(Card card) optionOf;
    final String inScript;
    if (reading) {
      final romanised = source.reading;
      if (romanised == null) return null;
      text = romanised;
      shown = wordSpans(romanised);
      optionOf = (card) => card.reading ?? '';
      inScript = firstScript;
    } else {
      inScript = script ?? firstScript;
      final spelling = source.spellingIn(inScript, firstScript);
      if (spelling == null) return null;
      text = spelling;
      shown = wordSpans(
        spelling,
        given: inScript == firstScript ? source.words : null,
      );
      optionOf = (card) =>
          card.targetIn(inScript, firstScript: firstScript) ?? '';
    }
    if (shown.length != spans.length) return null;
    final span = shown[gap.index];
    final answer = clozeKey(text.substring(span.start, span.end));
    if (answer.isEmpty) return null;
    final inSentence = <String>{
      for (final s in shown) clozeKey(text.substring(s.start, s.end)),
    };
    final wrong = <String>[];
    for (final card in distractors) {
      final raw = optionOf(card);
      // One word, as the answer is: a phrase or a missing spelling is not an
      // option.
      if (raw.isEmpty || wordSpans(raw).length != 1) continue;
      final option = clozeKey(raw);
      if (option.isEmpty ||
          inSentence.contains(option) ||
          wrong.contains(option)) {
        continue;
      }
      wrong.add(option);
      if (wrong.length == kClozeOptions - 1) break;
    }
    if (wrong.length < kClozeMinOptions - 1) return null;
    return ClozeView(
      before: text.substring(0, span.start),
      after: text.substring(span.end),
      answer: answer,
      options: <String>[answer, ...wrong]..shuffle(random),
      reading: reading,
      script: inScript,
    );
  }
}

/// A cloze as it is shown: the sentence around its gap, and the words to
/// choose, in the script or the Latin letters the learner writes in.
class ClozeView {
  const ClozeView({
    required this.before,
    required this.after,
    required this.answer,
    required this.options,
    required this.reading,
    required this.script,
  });

  /// The sentence up to the gap, and from it.
  final String before;
  final String after;

  /// The word that fills the gap, in lowercase.
  final String answer;

  /// The words to choose from, in the order shown, the answer among them.
  final List<String> options;

  /// Whether the sentence is shown in Latin letters, its reading.
  final bool reading;

  /// The script it is shown in; the language's first one for a reading.
  final String script;

  /// Whether [option] fills the gap: the exact word, nothing else.
  bool isRight(String option) => option == answer;

  /// The sentence with [word] in the gap.
  String filled(String word) => '$before$word$after';
}

/// What a cloze is made from for a language: its known words, and the
/// sentences that hold them. Built once for a language's cards and the
/// learner's answers ([isKnown] is the one rule of known), then asked, in
/// the session's order, which cards can be asked as a cloze and for the
/// cloze itself.
class ClozeBank {
  /// A bank over [cards], the language's vocab cards. [isKnown] says whether
  /// the card with an id is known (`Unlocks.isWordKnown`).
  ClozeBank({
    required Iterable<Card> cards,
    required this.isKnown,
    this.minKnown = kClozeMinKnown,
  }) {
    for (final card in cards) {
      if (!_isWord(card)) continue;
      if (_byId.containsKey(card.id)) continue;
      _byId[card.id] = card;
      _words.add(card);
      for (final text in <String>[card.target, ...card.altTarget]) {
        final key = clozeKey(text);
        if (key.isNotEmpty) (_byWord[key] ??= <Card>[]).add(card);
      }
    }
  }

  /// Whether the card with this id is known.
  final bool Function(String id) isKnown;

  /// How many known words a sentence needs.
  final int minKnown;

  final Map<String, Card> _byId = <String, Card>{};
  final List<Card> _words = <Card>[];
  final Map<String, List<Card>> _byWord = <String, List<Card>>{};
  final Map<String, bool> _asked = <String, bool>{};
  List<Card>? _knownWords;

  /// Whether [card] is a word a gap can be, or a distractor: a single word
  /// that is not a sentence, a phrasebook chunk, a grammar cell, a sign or a
  /// reading question.
  static bool _isWord(Card card) =>
      card is! QuestionCard &&
      !isSentenceCard(card) &&
      !card.phrasebook &&
      !card.practiceOnly &&
      !card.isSign &&
      card.rule == null &&
      card.wordCount == 1;

  List<Card> get _known => _knownWords ??= <Card>[
    for (final card in _words)
      if (isKnown(card.id)) card,
  ];

  /// The sentences [card] is asked a cloze on, each with the one word of
  /// them a gap may be, or null for any known word. A sentence card's own
  /// sentence (a gap of any known word) and its examples; for any other
  /// card, its examples, with the card's own word as the gap, since what is
  /// reviewed is that word.
  List<(ClozeSource, String?)> sourcesOf(Card card) {
    if (card is QuestionCard ||
        card.rule != null ||
        card.practiceOnly ||
        card.isSign) {
      return const <(ClozeSource, String?)>[];
    }
    final sentence = isSentenceCard(card);
    return <(ClozeSource, String?)>[
      if (sentence) (ClozeSource.ofCard(card), null),
      for (final example in card.examples)
        // An example in another language (the IPA course's) is no sentence of
        // this one.
        if (example.language == null)
          (ClozeSource.ofExample(example), sentence ? null : card.id),
    ];
  }

  /// The card a word of [source] is: the card its base names, else the card
  /// whose target, or other accepted target, is the word. Null for a word no
  /// card of the language teaches.
  Card? _cardOf(ClozeSource source, String key) {
    for (final base in source.bases) {
      final ref = base.ref;
      if (ref != null && clozeKey(base.word) == key) return _byId[ref];
    }
    final found = _byWord[key];
    if (found == null || found.isEmpty) return null;
    for (final card in found) {
      if (isKnown(card.id)) return card;
    }
    return found.first;
  }

  /// Every gap [source] allows: the words of it that are known, and, where
  /// [only] names a card, only that card's. Empty unless the sentence holds
  /// [minKnown] known words.
  List<ClozeGap> gapsIn(ClozeSource source, {String? only}) {
    final spans = source.spans;
    final target = source.target;
    final gaps = <ClozeGap>[];
    final known = <String>{};
    for (final (i, span) in spans.indexed) {
      final key = clozeKey(target.substring(span.start, span.end));
      final card = _cardOf(source, key);
      if (card == null || !isKnown(card.id)) continue;
      known.add(card.id);
      if (only == null || card.id == only) gaps.add((index: i, word: card));
    }
    return known.length < minKnown ? const <ClozeGap>[] : gaps;
  }

  /// Whether [card] can be asked as a cloze now: one of its sentences has a
  /// gap to offer and enough known words to choose among. Kept until the
  /// bank is made again, which is when the learner's answers change.
  bool canAsk(Card card) => _asked.putIfAbsent(card.id, () {
    for (final (source, only) in sourcesOf(card)) {
      if (gapsIn(source, only: only).isNotEmpty) return true;
    }
    return false;
  });

  /// The cloze of one of [card]'s sentences, drawn with [random]; null where
  /// it has no sentence with a gap and at least two other known words to
  /// offer with it. The gap is a word shown as it stands in the sentence, as
  /// the card teaches it, where the sentence has one: an inflected word is
  /// a gap only when it is the only kind there is.
  Cloze? make(Card card, {required math.Random random}) {
    final sources = List<(ClozeSource, String?)>.of(sourcesOf(card));
    sources.shuffle(random);
    for (final (source, only) in sources) {
      final gaps = gapsIn(source, only: only);
      if (gaps.isEmpty) continue;
      final plain = <ClozeGap>[
        for (final gap in gaps)
          if (_isPlain(source, gap)) gap,
      ];
      final pool = plain.isEmpty ? gaps : plain;
      final gap = pool[random.nextInt(pool.length)];
      final distractors = _distractorsFor(source, gap, random);
      if (distractors.length < kClozeMinOptions - 1) continue;
      return Cloze(source: source, gap: gap, distractors: distractors);
    }
    return null;
  }

  /// Whether [gap] stands in [source] as its card's own target: not an
  /// inflected form, whose look would give the answer away among the
  /// dictionary forms offered with it.
  bool _isPlain(ClozeSource source, ClozeGap gap) {
    final span = source.spans[gap.index];
    final key = clozeKey(source.target.substring(span.start, span.end));
    return key == clozeKey(gap.word.target);
  }

  /// The words that can stand beside [gap] as wrong options: other known
  /// words of its kind (part of speech), not in the sentence and not meaning
  /// what the answer means, those nearest it in length first, in the same
  /// script by being the same language's, so that no option is told apart by
  /// how it looks.
  List<Card> _distractorsFor(
    ClozeSource source,
    ClozeGap gap,
    math.Random random,
  ) {
    final span = source.spans[gap.index];
    final answer = clozeKey(source.target.substring(span.start, span.end));
    final inSentence = <String>{
      for (final s in source.spans)
        clozeKey(source.target.substring(s.start, s.end)),
    };
    final meanings = gap.word.meanings.toSet();
    final others = <Card>[
      for (final card in _known)
        if (card.id != gap.word.id &&
            card.pos == gap.word.pos &&
            !inSentence.contains(clozeKey(card.target)) &&
            !card.meanings.any(meanings.contains))
          card,
    ]..shuffle(random);
    final length = answer.runes.length;
    final ranked = <(int, int, Card)>[
      for (final (i, card) in others.indexed)
        ((clozeKey(card.target).runes.length - length).abs(), i, card),
    ]..sort((a, b) {
      final byLength = a.$1.compareTo(b.$1);
      return byLength != 0 ? byLength : a.$2.compareTo(b.$2);
    });
    final seen = <String>{answer};
    return <Card>[
      for (final (_, _, card) in ranked)
        if (seen.add(clozeKey(card.target))) card,
    ].take(_spare).toList();
  }
}
