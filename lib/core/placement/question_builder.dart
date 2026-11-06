import 'dart:math' as math;

import '../grading/canonical.dart';
import '../models/aksharas.dart';
import '../models/card.dart';
import '../models/drill_mode.dart';
import '../models/sound_contrasts.dart';
import 'assurance_model.dart';
import 'generated_question.dart';
import 'item_picker.dart';
import 'placement_data.dart';
import 'placement_questions.dart';
import 'question_outcome.dart';

// Turns a question request of the run controller into a concrete question
// (wiki/Plan-Placement-V2.md, "Step 2: question generators"). Pure: the
// learner's language is passed in as data, the questions already asked as a
// set of ids, and everything random comes from the seed and the request, so
// the same input always gives the same question.

/// The length, in words, from which a sentence is a "long sentence" (section
/// 2.1, topic 1).
const int longSentenceWords = 8;

/// A sentence this short or shorter is "short" for a split question.
const int shortSentenceWords = 3;

/// Builds the questions of a run from one learner's [data].
class QuestionBuilder {
  QuestionBuilder(
    this.data, {
    Set<PlacementSkill>? tested,
    this.microphone = true,
    this.requireTrustedPairAudio = false,
    this.seed = 0,
  }) : tested = tested ?? PlacementSkill.values.toSet(),
       _picker = PlacementItemPicker(data, seed: seed);

  final PlacementLanguageData data;

  /// The skills the learner marked as known: without Hear a "by audio" part
  /// is shown as the reading, as section 3.1 says.
  final Set<PlacementSkill> tested;

  /// Whether the speech recogniser works; with none the questions that ask to
  /// say the meaning in English are asked as picks.
  final bool microphone;

  /// Report a minimal pair as unavailable (so that the run asks Write tiles)
  /// while its audio is not trusted. Off by default: the pair is built and
  /// its audio is marked untrusted ([PlacementAudio.trusted]).
  final bool requireTrustedPairAudio;

  /// Seeds the order of equally good wrong options and the shuffles.
  final int seed;

  final PlacementItemPicker _picker;

  /// The question [request] asks for, or why there is none. [asked] is the
  /// no-repeat set: the `itemIds` of every question built so far in the run.
  /// [failed] is the question a split or an isolating question checks (the
  /// request's `originVariant` names it), which the caller kept; without it
  /// the questions that need its word, family or contrast are unavailable
  /// ([PlacementUnavailableReason.noOrigin]), never asked about some other
  /// item.
  QuestionOutcome build(
    PlacementQuestionRequest request, {
    Set<String> asked = const <String>{},
    GeneratedQuestion? failed,
  }) {
    final ctx = _Ctx(request, asked, failed, seed);
    switch (request.role) {
      case PlacementQuestionRole.split:
        return _split(ctx);
      case PlacementQuestionRole.isolating:
        return _isolating(ctx);
      case PlacementQuestionRole.grammar:
        return _blank(ctx, exactDeck: true);
      case PlacementQuestionRole.probe:
      case PlacementQuestionRole.topUp:
        return _vocabulary(ctx);
      case PlacementQuestionRole.base:
      case PlacementQuestionRole.recheck:
        return _byVariant(ctx);
    }
  }

  QuestionOutcome _byVariant(_Ctx ctx) {
    switch (ctx.request.variant) {
      case PlacementVariant.k1:
      case PlacementVariant.k1b:
        return _longSentence(ctx, heard: false);
      case PlacementVariant.k2:
      case PlacementVariant.k2b:
        return _longSentence(ctx, heard: true);
      case PlacementVariant.w1:
      case PlacementVariant.w1b:
        return _wordPick(ctx, heard: false);
      case PlacementVariant.w2:
      case PlacementVariant.w2b:
        return _wordPick(ctx, heard: true);
      case PlacementVariant.g1:
      case PlacementVariant.g1b:
        return _blank(ctx);
      case PlacementVariant.g2:
      case PlacementVariant.g2b:
        return _grammarTiles(ctx);
      case PlacementVariant.g3:
      case PlacementVariant.g3b:
        return _soundsRight(ctx);
      case PlacementVariant.r1:
        return _longSentenceTiles(ctx, heard: true);
      case PlacementVariant.r2:
      case PlacementVariant.r2b:
        return _longSentenceTiles(ctx, heard: false);
      case PlacementVariant.p1:
      case PlacementVariant.p2:
        return _pair(
          ctx,
          tiles: ctx.request.kind == PlacementQuestionKind.tilesWord,
        );
      case PlacementVariant.y1:
      case PlacementVariant.y2:
      case PlacementVariant.y3:
        return _say(ctx);
      case PlacementVariant.sr:
      case PlacementVariant.srb:
      case PlacementVariant.sx:
        return _scriptRead(ctx, script: 0);
      case PlacementVariant.sr2:
      case PlacementVariant.srb2:
      case PlacementVariant.sx2:
        return _scriptRead(ctx, script: 1);
      case PlacementVariant.sw:
        return _scriptWrite(ctx, script: 0);
      case PlacementVariant.sw2:
        return _scriptWrite(ctx, script: 1);
      case PlacementVariant.topUp:
      case PlacementVariant.probe:
        return _vocabulary(ctx);
      case PlacementVariant.grammar:
        return _blank(ctx, exactDeck: true);
      case PlacementVariant.s1:
      case PlacementVariant.s2:
        return _split(ctx);
      case PlacementVariant.isolating:
        return _isolating(ctx);
    }
  }

  // ---------------------------------------------------------------------------
  // The pool of an item.

  /// The decks an item may come from, nearest first: [deck] alone, then the
  /// last two decks, then the last quarter (section 2.2), then the path up
  /// to [deck]. A probe widens on both sides instead, so that its level
  /// stays where it was asked.
  List<List<int>> _ranges(int deck, {bool around = false}) {
    final last = data.deckCount - 1;
    final at = deck.clamp(0, last);
    List<int> span(int from, int to) => <int>[
      for (var i = math.max(0, from); i <= math.min(last, to); i++) i,
    ];
    final ranges = around
        ? <List<int>>[
            span(at, at),
            span(at - 1, at + 1),
            span(at - 3, at + 3),
            span(0, last),
          ]
        : <List<int>>[
            span(at, at),
            span(at - 1, at),
            span(at - data.deckCount ~/ 4, at),
            span(0, at),
          ];
    final seen = <String>{};
    return <List<int>>[
      for (final r in ranges)
        if (r.isNotEmpty && seen.add('${r.first}-${r.last}')) r,
    ];
  }

  bool _eligible(Card card, Set<String> asked) =>
      isAskable(card) &&
      !data.stableCardIds.contains(card.id) &&
      !asked.contains(card.id) &&
      !wordFamilies(card, data).any((f) => asked.contains('family:$f'));

  /// The hardest item among the cards that [keep] accepts, drawn from the
  /// widening [ranges] until one holds five candidates (the shortlist). Null
  /// where no card is left.
  RankedItem? _item(
    _Ctx ctx,
    List<List<int>> ranges, {
    required bool Function(Card card, PlacementDeck deck) keep,
    required List<Card>? Function(Card card, int deck) wrongFor,
    double Function(Card card, int deck)? formOverride,
  }) {
    List<RankedItem> best = const <RankedItem>[];
    for (final range in ranges) {
      final candidates = <({Card card, int deck})>[
        for (final i in range)
          for (final card in data.decks[i].cards)
            if (_eligible(card, ctx.asked) && keep(card, data.decks[i]))
              (card: card, deck: i),
      ];
      if (candidates.isEmpty) continue;
      final ranked = _picker.rank(
        candidates,
        wrongFor: wrongFor,
        formOverride: formOverride,
      );
      if (ranked.length > best.length) best = ranked;
      if (ranked.length >= 5) break;
    }
    return PlacementItemPicker.pickFromShortlist(
      best,
      ctx.request.shortlistPick,
    );
  }

  /// A closure giving the wrong options of a card, as meanings or as
  /// written forms; null where fewer than [count] can be found.
  List<Card>? Function(Card, int) _wrongOptions(
    _Ctx ctx, {
    required bool Function(Card) sameKind,
    required String Function(Card) show,
    int count = 3,
  }) {
    return (Card card, int deck) {
      var wrong = _picker.distractorsFor(
        card,
        deck,
        sameKind: sameKind,
        show: show,
        count: count,
        asked: ctx.asked,
      );
      if (wrong.length < count) {
        wrong = _picker.distractorsFor(
          card,
          deck,
          sameKind: sameKind,
          show: show,
          count: count,
          asked: ctx.asked,
          relaxAsked: true,
        );
      }
      return wrong.length < count ? null : wrong;
    };
  }

  static String _meaningOf(Card c) => c.native;

  QuestionOutcome _empty(_Ctx ctx, PlacementUnavailableReason reason) {
    final any = ctx.asked.isNotEmpty;
    return QuestionUnavailable(
      any && reason == PlacementUnavailableReason.noWords
          ? PlacementUnavailableReason.allAsked
          : reason,
      'no item for ${ctx.request.variant.label} at deck ${ctx.request.deck}',
    );
  }

  // ---------------------------------------------------------------------------
  // Assembling a question.

  PlacementAnswerMode _modeOf(PlacementQuestionKind kind) {
    switch (kind) {
      case PlacementQuestionKind.pickOne:
      case PlacementQuestionKind.pickMany:
      case PlacementQuestionKind.pair:
        return PlacementAnswerMode.pick;
      case PlacementQuestionKind.english:
        return microphone
            ? PlacementAnswerMode.sayEnglish
            : PlacementAnswerMode.pick;
      case PlacementQuestionKind.tilesSentence:
      case PlacementQuestionKind.tilesWord:
        return PlacementAnswerMode.tiles;
      case PlacementQuestionKind.say:
        return PlacementAnswerMode.say;
    }
  }

  List<PlacementSplitRequest> _splitsOf(PlacementQuestionRequest request) {
    if (request.role != PlacementQuestionRole.base) {
      return const <PlacementSplitRequest>[];
    }
    for (final base in buildBaseQuestions(tested, microphone: microphone)) {
      if (base.id != request.variant) continue;
      return <PlacementSplitRequest>[
        for (final s in base.splits)
          PlacementSplitRequest(
            variant: s.id,
            part: s.part,
            kind: s.kind,
            skills: s.skills,
          ),
      ];
    }
    return const <PlacementSplitRequest>[];
  }

  ItemDifficulty _difficulty(RankedItem item, {bool shortOfLong = false}) =>
      ItemDifficulty(
        deck: item.deck,
        depth: item.depth,
        form: item.form,
        closeness: item.closeness,
        score: item.score,
        level: data.levelOfDeck(item.deck),
        shortOfLong: shortOfLong,
      );

  Set<String> _ids(
    Card card,
    Iterable<Card> others, {
    String? concept,
    Iterable<String> extra = const <String>[],
  }) => <String>{
    card.id,
    for (final c in others) c.id,
    for (final f in wordFamilies(card, data)) 'family:$f',
    ?(concept == null ? null : 'concept:$concept'),
    ...extra,
  };

  PlacementAudio _audioOf(Card card, {bool trusted = true}) => PlacementAudio(
    text: card.target,
    language: data.language,
    cardId: card.audio == null ? null : card.id,
    trusted: trusted,
  );

  /// The prompt parts of a heard word or sentence: the audio where Hear is
  /// tested, else the reading (or the text where there is none) shown instead.
  ({
    PlacementPromptKind kind,
    PlacementAudio? audio,
    String? text,
    String? reading,
  })
  _heard(Card card, {required bool sentence}) {
    if (tested.contains(PlacementSkill.hear)) {
      return (
        kind: sentence
            ? PlacementPromptKind.heardSentence
            : PlacementPromptKind.heardWord,
        audio: _audioOf(card),
        text: null,
        reading: null,
      );
    }
    return (
      kind: sentence
          ? PlacementPromptKind.writtenSentence
          : PlacementPromptKind.writtenWord,
      audio: null,
      text: card.reading ?? card.target,
      reading: card.reading,
    );
  }

  /// A pick of meanings for [item]: its meaning among the wrong ones'.
  ({List<String> options, int correct}) _meaningOptions(
    _Ctx ctx,
    RankedItem item,
  ) {
    final options = <String>[
      item.card.native,
      for (final c in item.wrong) c.native,
    ]..shuffle(ctx.random);
    return (options: options, correct: options.indexOf(item.card.native));
  }

  /// Every accepted meaning of [card]: its meanings and its alternatives.
  List<String> _acceptedMeanings(Card card) => card.meanings;

  // ---------------------------------------------------------------------------
  // Topic 1: long-sentence recognition (K1, K2).

  bool _isLong(Card c, PlacementDeck d, int minWords) =>
      isSentenceCard(c) && c.wordCount >= minWords;

  /// K1 (written only in the script) and K2 (heard): a long sentence of the
  /// late decks; its meaning is said in English or picked from four. A
  /// language whose decks hold no sentence of [longSentenceWords] words is
  /// asked its longest sentences, and the question says so
  /// ([ItemDifficulty.shortOfLong]).
  QuestionOutcome _longSentence(_Ctx ctx, {required bool heard}) {
    final wrongFor = _wrongOptions(
      ctx,
      sameKind: isSentenceCard,
      show: _meaningOf,
    );
    final ranges = _ranges(ctx.request.deck);
    var item = _item(
      ctx,
      ranges,
      keep: (c, d) => _isLong(c, d, longSentenceWords),
      wrongFor: wrongFor,
    );
    var shortOfLong = false;
    if (item == null) {
      item = _item(
        ctx,
        ranges,
        keep: (c, d) => _isLong(c, d, 4),
        wrongFor: wrongFor,
        formOverride: (c, d) => math.min(1.0, c.wordCount / longSentenceWords),
      );
      shortOfLong = item != null && item.card.wordCount < longSentenceWords;
    }
    if (item == null) {
      return _empty(ctx, PlacementUnavailableReason.noSentences);
    }
    final card = item.card;
    final picked = _meaningOptions(ctx, item);
    PlacementPromptKind kind = PlacementPromptKind.writtenSentence;
    PlacementAudio? audio;
    // Written only in the script: no reading, no audio.
    String? text = card.target;
    String? reading;
    if (heard) {
      final h = _heard(card, sentence: true);
      kind = h.kind;
      audio = h.audio;
      text = h.text;
      reading = h.reading;
    }
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: kind,
        promptText: text,
        promptReading: reading,
        audio: audio,
        mode: _modeOf(ctx.request.kind),
        options: picked.options,
        correctIndex: picked.correct,
        accepted: _acceptedMeanings(card),
        splits: _splitsOf(ctx.request),
        cardId: card.id,
        itemIds: _ids(card, item.wrong),
        difficulty: _difficulty(item, shortOfLong: shortOfLong),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Topic 5: complex words (W1, W2) and the word picks of the splits.

  /// A word to pick the meaning of: written (W1) or heard (W2). The hardest
  /// is the longest or most inflected of the late decks (section 2.2).
  QuestionOutcome _wordPick(
    _Ctx ctx, {
    required bool heard,
    bool short = false,
    Card? only,
  }) {
    final wrongFor = _wrongOptions(ctx, sameKind: isWordCard, show: _meaningOf);
    RankedItem? item;
    if (only != null) {
      final deck = data.deckIndexOf(only.id) ?? ctx.request.deck;
      final wrong = wrongFor(only, deck);
      if (wrong == null) {
        return _empty(ctx, PlacementUnavailableReason.tooFewDistractors);
      }
      item = _rankedOne(only, deck, wrong);
    } else {
      item = _item(
        ctx,
        _ranges(ctx.request.deck),
        keep: (c, d) =>
            isWordCard(c) &&
            (!short || c.target.runes.length <= 6) &&
            !_isPlaceholder(c),
        wrongFor: wrongFor,
        formOverride: short ? (c, d) => 0.0 : null,
      );
    }
    if (item == null) return _empty(ctx, PlacementUnavailableReason.noWords);
    final card = item.card;
    final picked = _meaningOptions(ctx, item);
    final PlacementPromptKind kind;
    PlacementAudio? audio;
    String? text;
    String? reading;
    if (heard) {
      final h = _heard(card, sentence: false);
      kind = h.kind;
      audio = h.audio;
      text = h.text;
      reading = h.reading;
    } else {
      kind = PlacementPromptKind.writtenWord;
      text = card.target;
    }
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: kind,
        promptText: text,
        promptReading: reading,
        audio: audio,
        mode: PlacementAnswerMode.pick,
        options: picked.options,
        correctIndex: picked.correct,
        accepted: _acceptedMeanings(card),
        splits: _splitsOf(ctx.request),
        cardId: card.id,
        itemIds: _ids(card, item.wrong),
        difficulty: _difficulty(item),
      ),
    );
  }

  bool _isPlaceholder(Card c) =>
      c.target.contains('…') || c.target.contains('...');

  RankedItem _rankedOne(Card card, int deck, List<Card> wrong) {
    var closeness = 0.0;
    for (final w in wrong) {
      closeness = math.max(closeness, _picker.closenessOf(card, w));
    }
    final depth = _picker.depthOf(deck);
    final form = _picker.formOf(card, deck);
    return RankedItem(
      card: card,
      deck: deck,
      depth: depth,
      form: form,
      closeness: closeness,
      score:
          depthWeight * depth + formWeight * form + closenessWeight * closeness,
      wrong: wrong,
    );
  }

  // ---------------------------------------------------------------------------
  // Topic 3: late-stage grammar (G1, G2, G3).

  /// The families the path's grammar units teach, with the decks of each.
  Map<String, List<int>> get _families {
    final out = <String, List<int>>{};
    for (final (i, deck) in data.decks.indexed) {
      for (final family in deck.grammarFamilies) {
        out.putIfAbsent(family, () => <int>[]).add(i);
      }
    }
    return out;
  }

  /// The family to ask next: the first family of the last grammar unit when
  /// no family has been asked yet in this run, then the family with most
  /// units (section 2.1, topic 3). A family already asked is never chosen
  /// again, and [prefer] (a split's family) wins where given.
  String? _familyFor(_Ctx ctx, {String? prefer, bool allowAsked = false}) {
    final families = _families;
    if (families.isEmpty) return null;
    if (prefer != null && families.containsKey(prefer)) return prefer;
    bool fresh(String f) =>
        allowAsked || !ctx.asked.contains('concept:grammar:$f');
    final remaining = <String>[
      for (final f in families.keys)
        if (fresh(f)) f,
    ];
    if (remaining.isEmpty) return null;
    final anyAsked = ctx.asked.any((id) => id.startsWith('concept:grammar:'));
    if (!anyAsked) {
      final lastUnit = families.values
          .map((decks) => decks.last)
          .reduce(math.max);
      final inLast = <String>[
        for (final f in remaining)
          if (data.decks[lastUnit].grammarFamilies.contains(f)) f,
      ];
      if (inLast.isNotEmpty) return inLast.first;
    }
    remaining.sort((a, b) {
      final c = families[b]!.length.compareTo(families[a]!.length);
      return c != 0 ? c : families[b]!.last.compareTo(families[a]!.last);
    });
    return remaining.first;
  }

  /// The word of [card]'s target that a G1 question blanks, and the forms
  /// offered for it: the form and what it could be mistaken for. The blanked
  /// word is a word the deck lists as a base of an inflected form of the
  /// sentence (`bases`), written once in the sentence; the wrong forms are
  /// the card's own confusables, then the forms of the family's other
  /// sentences.
  ({String form, List<String> wrong})? _blankOf(
    Card card,
    Iterable<Card> familyCards,
  ) {
    final target = card.target;
    final blanks = <String>[
      for (final b in card.bases)
        if (b.word.length > 1 &&
            RegExp(RegExp.escape(b.word)).allMatches(target).length == 1)
          b.word,
    ];
    if (blanks.isEmpty) return null;
    // Prefer an inflected form: it is the grammar.
    blanks.sort((a, b) {
      int rank(String w) {
        final base = card.bases.firstWhere((x) => x.word == w);
        final text =
            base.base ??
            (base.ref == null ? null : data.cardById(base.ref!)?.target);
        return text != null && text.toLowerCase() != w.toLowerCase() ? 0 : 1;
      }

      return rank(a).compareTo(rank(b));
    });
    final form = blanks.first;
    final wrong = <String>[];
    void add(String w) {
      if (w.isNotEmpty &&
          w != form &&
          !wrong.contains(w) &&
          !target.contains(w) &&
          wrong.length < 3) {
        wrong.add(w);
      }
    }

    for (final c in card.confusables) {
      add(c.word ?? (c.ref == null ? '' : data.cardById(c.ref!)?.target ?? ''));
    }
    for (final other in familyCards) {
      if (other.id == card.id) continue;
      for (final b in other.bases) {
        if (b.word.length > 1) add(b.word);
      }
    }
    return wrong.length < 3 ? null : (form: form, wrong: wrong);
  }

  /// G1 and the grammar bisection's probe: a sentence of a grammar unit with
  /// one form blanked, its meaning shown, four forms to pick from. For G1 the
  /// family is the one the plan names ([_familyFor]) and the sentence is the
  /// hardest of the family's latest unit; with [exactDeck] (the bisection)
  /// the sentence is of the unit [PlacementQuestionRequest.deck]. [shortOnly]
  /// and [earliest] are the splits: a short sentence of the family, and a
  /// sentence of the first unit that teaches it.
  QuestionOutcome _blank(
    _Ctx ctx, {
    bool exactDeck = false,
    String? family,
    bool shortOnly = false,
    bool earliest = false,
  }) {
    if (data.decks.every((d) => !d.isGrammar)) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noGrammarFamily,
        'the path has no grammar unit',
      );
    }
    final String? chosen;
    List<int> decks;
    if (exactDeck) {
      final at = ctx.request.deck.clamp(0, data.deckCount - 1);
      decks = <int>[at];
      final fams = data.decks[at].grammarFamilies;
      chosen = fams.isEmpty ? null : fams.first;
    } else {
      chosen = _familyFor(ctx, prefer: family);
      if (chosen == null) {
        return _empty(ctx, PlacementUnavailableReason.noGrammarFamily);
      }
      decks = <int>[
        for (final i in _families[chosen]!)
          if (i <= ctx.request.deck || earliest) i,
      ];
      if (decks.isEmpty) decks = <int>[_families[chosen]!.first];
      decks = earliest ? <int>[decks.first] : decks.reversed.toList();
    }
    final cards = <Card>[for (final i in decks) ...data.decks[i].cards];
    final blanks = <String, ({String form, List<String> wrong})>{};
    final candidates = <({Card card, int deck})>[];
    for (final i in decks) {
      for (final c in data.decks[i].cards) {
        if (!_eligible(c, ctx.asked) ||
            !isSentenceCard(c) ||
            (shortOnly && c.wordCount > shortSentenceWords + 1)) {
          continue;
        }
        final blank = _blankOf(c, cards);
        if (blank == null) continue;
        blanks[c.id] = blank;
        candidates.add((card: c, deck: i));
      }
    }
    final item = _blankItem(ctx, candidates, blanks, decks);
    if (item == null) {
      return _empty(ctx, PlacementUnavailableReason.noGrammarFamily);
    }
    final blank = blanks[item.card.id]!;
    final card = item.card;
    final options = <String>[blank.form, ...blank.wrong]..shuffle(ctx.random);
    final text = card.target.replaceFirst(blank.form, '____');
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: PlacementPromptKind.blankSentence,
        promptText: text,
        mode: PlacementAnswerMode.pick,
        options: options,
        correctIndex: options.indexOf(blank.form),
        accepted: <String>[blank.form],
        meaningHint: card.native,
        splits: _splitsOf(ctx.request),
        cardId: card.id,
        concept: chosen == null ? null : 'grammar:$chosen',
        itemIds: _ids(
          card,
          const <Card>[],
          concept: chosen == null ? null : 'grammar:$chosen',
        ),
        difficulty: _difficulty(item),
      ),
    );
  }

  RankedItem? _blankItem(
    _Ctx ctx,
    List<({Card card, int deck})> candidates,
    Map<String, ({String form, List<String> wrong})> blanks,
    List<int> decks,
  ) {
    if (candidates.isEmpty) return null;
    // The wrong forms are pseudo-cards of the same deck, so that the same
    // closeness (readings, then base, part of speech and tags) can be
    // measured between the right form and each of them.
    final ranked = _picker.rank(
      candidates,
      formOverride: (c, d) => 1.0,
      closenessBetween: (c, w) =>
          1 - normalisedEdit(blanks[c.id]!.form.toLowerCase(), w.target),
      wrongFor: (c, d) => <Card>[
        for (final w in blanks[c.id]!.wrong)
          Card(
            id: 'form:$w',
            deckId: c.deckId,
            target: w.toLowerCase(),
            native: '',
            pos: c.pos,
          ),
      ],
    );
    return PlacementItemPicker.pickFromShortlist(
      ranked,
      ctx.request.shortlistPick,
    );
  }

  /// G2: the meaning of a sentence of a late grammar unit is shown and its
  /// words are put in order from tiles, close wrong tiles among them.
  QuestionOutcome _grammarTiles(_Ctx ctx) {
    if (data.decks.every((d) => !d.isGrammar)) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noGrammarFamily,
        'the path has no grammar unit',
      );
    }
    final family = _familyFor(ctx);
    if (family == null) {
      return _empty(ctx, PlacementUnavailableReason.noGrammarFamily);
    }
    final decks = <int>[
      for (final i in _families[family]!)
        if (i <= ctx.request.deck) i,
    ].reversed.toList();
    final candidates = <({Card card, int deck})>[
      for (final i in decks.isEmpty ? _families[family]! : decks)
        for (final c in data.decks[i].cards)
          if (_eligible(c, ctx.asked) && _buildable(c)) (card: c, deck: i),
    ];
    final ranked = _picker.rank(
      candidates,
      formOverride: (c, d) => 1.0,
      wrongFor: (c, d) => const <Card>[],
    );
    final item = PlacementItemPicker.pickFromShortlist(
      ranked,
      ctx.request.shortlistPick,
    );
    if (item == null) {
      return _empty(ctx, PlacementUnavailableReason.noSentences);
    }
    return QuestionBuilt(
      _tilesQuestion(ctx, item, sentence: true, concept: 'grammar:$family'),
    );
  }

  /// A sentence put together from tiles: a card the drills ask by rearranging
  /// and that does not opt out of production.
  bool _buildable(Card c) =>
      isSentenceCard(c) && !c.modes.contains(DrillMode.production);

  /// The two options of "which sentence has its words in the right order":
  /// the sentence and the same words in another order. Both are written the
  /// same way, as [Card.tilesOfSpelling] gives the words (lowercase, marks at
  /// the edges apart, one space between tiles, with or without spaces in the
  /// script), so that nothing but the order tells the right one: not a
  /// capital, a mark stuck to a word, or the spacing of an unspaced script.
  /// Null where the words cannot be put in another order.
  ({String right, String wrong})? _orderOptions(Card card, math.Random random) {
    final tiles = card.tilesOfSpelling(card.target);
    final right = tiles.join(' ');
    final wrong = _shuffledNot(tiles, random).join(' ');
    return wrong == right ? null : (right: right, wrong: wrong);
  }

  /// G3, for a learner who can only hear: which of two sentences sounds
  /// right, the second being the first with its words out of order.
  QuestionOutcome _soundsRight(_Ctx ctx) {
    final family = _familyFor(ctx, allowAsked: true);
    final fromFamily = family == null ? null : _families[family];
    final decks = <int>[
      for (final i in fromFamily ?? _ranges(ctx.request.deck).last)
        if (i <= ctx.request.deck) i,
    ].reversed.toList();
    final candidates = <({Card card, int deck})>[
      for (final i in decks)
        for (final c in data.decks[i].cards)
          if (_eligible(c, ctx.asked) && _buildable(c) && c.wordCount >= 3)
            (card: c, deck: i),
    ];
    final ranked = _picker.rank(candidates, wrongFor: (c, d) => const <Card>[]);
    final item = PlacementItemPicker.pickFromShortlist(
      ranked,
      ctx.request.shortlistPick,
    );
    if (item == null) {
      return _empty(ctx, PlacementUnavailableReason.noSentences);
    }
    final card = item.card;
    final order = _orderOptions(card, ctx.random);
    if (order == null) {
      return _empty(ctx, PlacementUnavailableReason.noSentences);
    }
    final options = <String>[order.right, order.wrong]..shuffle(ctx.random);
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: PlacementPromptKind.sentencePair,
        mode: PlacementAnswerMode.pick,
        options: options,
        correctIndex: options.indexOf(order.right),
        optionsAreAudio: tested.contains(PlacementSkill.hear),
        audio: tested.contains(PlacementSkill.hear) ? _audioOf(card) : null,
        accepted: <String>[order.right],
        cardId: card.id,
        concept: family == null ? null : 'grammar:$family',
        itemIds: _ids(
          card,
          const <Card>[],
          concept: family == null ? null : 'grammar:$family',
        ),
        difficulty: _difficulty(item),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Topic 2: long-sentence reproduction (R1, R2).

  /// R1: a long sentence is heard and built with tiles; R2: its English
  /// meaning is shown and it is built in the language.
  QuestionOutcome _longSentenceTiles(_Ctx ctx, {required bool heard}) {
    final ranges = _ranges(ctx.request.deck);
    RankedItem? item;
    var shortOfLong = false;
    for (final minWords in <int>[longSentenceWords, 4]) {
      item = _item(
        ctx,
        ranges,
        keep: (c, d) => _buildable(c) && c.wordCount >= minWords,
        wrongFor: (c, d) => const <Card>[],
        formOverride: (c, d) => math.min(1.0, c.wordCount / longSentenceWords),
      );
      if (item != null) {
        shortOfLong = item.card.wordCount < longSentenceWords;
        break;
      }
    }
    if (item == null) {
      return _empty(ctx, PlacementUnavailableReason.noSentences);
    }
    return QuestionBuilt(
      _tilesQuestion(
        ctx,
        item,
        sentence: true,
        heard: heard,
        shortOfLong: shortOfLong,
      ),
    );
  }

  /// The tiles of [item]: the words (or letters) in a shuffled order with up
  /// to two close wrong tiles among them, and every accepted order.
  GeneratedQuestion _tilesQuestion(
    _Ctx ctx,
    RankedItem item, {
    required bool sentence,
    bool heard = false,
    String? concept,
    bool shortOfLong = false,
  }) {
    final card = item.card;
    final List<String> right;
    final String joiner;
    final List<String> accepted;
    if (sentence) {
      right = card.tilesOfSpelling(card.target);
      joiner = ' ';
      accepted = <String>{
        for (final s in <String>[
          card.target,
          ...card.altTarget,
          ...card.targetScripts.values,
        ])
          card.tilesOfSpelling(s).join(' '),
      }.toList();
    } else {
      right = aksharasOf(card.target);
      joiner = '';
      accepted = <String>{
        for (final s in <String>[
          card.target,
          ...card.altTarget,
          ...card.targetScripts.values,
        ])
          s,
      }.toList();
    }
    final extras = sentence ? _closeTiles(card, right) : const <String>[];
    final tiles = _shuffledNot(<String>[...right], ctx.random)
      ..addAll(extras)
      ..shuffle(ctx.random);
    final audible = heard ? _heard(card, sentence: sentence) : null;
    return GeneratedQuestion(
      request: ctx.request,
      prompt: heard ? audible!.kind : PlacementPromptKind.meaning,
      promptText: heard ? audible!.text : card.native,
      promptReading: heard ? audible!.reading : null,
      audio: audible?.audio,
      mode: PlacementAnswerMode.tiles,
      tiles: tiles,
      joiner: joiner,
      accepted: accepted,
      splits: _splitsOf(ctx.request),
      cardId: card.id,
      concept: concept,
      itemIds: _ids(card, const <Card>[], concept: concept),
      difficulty: _difficulty(item, shortOfLong: shortOfLong),
    );
  }

  /// Up to two tiles that look right and are not in the sentence: the words
  /// of the card's confusables, else words of the card's neighbours.
  List<String> _closeTiles(Card card, List<String> right) {
    final out = <String>[];
    void add(String w) {
      final word = w.toLowerCase();
      if (word.isNotEmpty && !right.contains(word) && !out.contains(word)) {
        out.add(word);
      }
    }

    for (final c in card.confusables) {
      if (out.length >= 2) break;
      final w =
          c.word ?? (c.ref == null ? null : data.cardById(c.ref!)?.target);
      if (w != null && wordsOf(w).length == 1) add(w);
    }
    if (out.length < 2) {
      final deck = data.deckIndexOf(card.id);
      if (deck != null) {
        for (final other in data.decks[deck].cards) {
          if (out.length >= 2) break;
          if (other.id == card.id || !isSentenceCard(other)) continue;
          for (final w in other.tilesOfSpelling(other.target)) {
            if (out.length < 2) add(w);
          }
        }
      }
    }
    return out;
  }

  /// [items] in an order that is not the given one (where it can be).
  List<String> _shuffledNot(List<String> items, math.Random random) {
    final out = <String>[...items];
    if (out.length < 2) return out;
    for (var i = 0; i < 8; i++) {
      out.shuffle(random);
      var same = true;
      for (var j = 0; j < out.length; j++) {
        if (out[j] != items[j]) {
          same = false;
          break;
        }
      }
      if (!same) break;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Topic 4: minimal pairs (P1, P2) and their written fallback.

  /// Every pair of words of the decks that differ by exactly one swap of a
  /// real contrast, both ways round (a pair is two entries), computed once
  /// for the language. With a sounds file the swaps are its letter pairs;
  /// with none (and [PlacementLanguageData.pairsFromDecks]) they are the
  /// language's explicit list of letter swaps that are two sounds
  /// ([PlacementLanguageData.effectiveDeckPairSwaps]), each such swap being a
  /// contrast of its own. Two words that differ only by an accent, a case, a
  /// silent letter or a spelling variant are never a pair: both could be the
  /// word that was heard.
  late final List<_Pair> _allPairs = _computePairs();

  /// [_allPairs] whose two words are both of the decks up to [deckLimit].
  List<_Pair> _pairs(int deckLimit) => <_Pair>[
    for (final p in _allPairs)
      if (p.deck <= deckLimit) p,
  ];

  List<_Pair> _computePairs() {
    final sounds = data.sounds;
    final words = <Card>[
      for (final deck in data.decks)
        for (final c in deck.cards)
          if (isAskable(c) && isWordCard(c) && wordsOf(c.target).length == 1) c,
    ];
    final byForm = <String, List<Card>>{};
    for (final c in words) {
      byForm.putIfAbsent(normaliseForContrast(c.target), () => <Card>[]).add(c);
    }
    final out = <_Pair>[];
    final seen = <String>{};
    void found(Card a, Card b, String contrast) {
      if (a.id == b.id || sameMeaning(a, b)) return;
      final key = a.id.compareTo(b.id) < 0
          ? '${a.id}|${b.id}'
          : '${b.id}|${a.id}';
      if (!seen.add(key)) return;
      final deck = math.max(
        data.deckIndexOf(a.id) ?? 0,
        data.deckIndexOf(b.id) ?? 0,
      );
      out.add((card: a, partner: b, contrast: contrast, deck: deck));
      out.add((card: b, partner: a, contrast: contrast, deck: deck));
    }

    if (sounds != null) {
      for (final contrast in sounds.contrasts) {
        for (final (rawX, rawY) in contrast.pairs) {
          final x = composed(rawX);
          final y = composed(rawY);
          for (final (from, to) in <(String, String)>[(x, y), (y, x)]) {
            for (final entry in byForm.entries) {
              final form = entry.key;
              final swapped = _swaps(form, from, to, contrast.withinWord);
              for (final s in swapped) {
                for (final partner in byForm[s] ?? const <Card>[]) {
                  for (final a in entry.value) {
                    if (sounds.between(partner.target, a.target)?.id ==
                        contrast.id) {
                      found(a, partner, contrast.id);
                    }
                  }
                }
              }
            }
          }
        }
      }
      return out;
    }
    // No sounds file: two words of one length that differ in one letter, and
    // only where the two letters are a listed swap of the language.
    final allowed = <String>{
      for (final (x, y) in data.effectiveDeckPairSwaps)
        ..._swapKeys(composed(x), composed(y)),
    };
    if (allowed.isEmpty) return out;
    // Words that agree everywhere but at one place share a key made of the
    // word with that place masked: no all-against-all comparison.
    final groups = <String, List<({String form, int rune})>>{};
    for (final form in byForm.keys) {
      final runes = form.runes.toList();
      for (var k = 0; k < runes.length; k++) {
        final masked = <int>[...runes]..[k] = 0;
        groups
            .putIfAbsent(
              '$k:${String.fromCharCodes(masked)}',
              () => <({String form, int rune})>[],
            )
            .add((form: form, rune: runes[k]));
      }
    }
    for (final group in groups.values) {
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          final x = String.fromCharCode(group[i].rune);
          final y = String.fromCharCode(group[j].rune);
          if (x == y || !allowed.contains('$x|$y')) continue;
          final sorted = <String>[x, y]..sort();
          for (final a in byForm[group[i].form]!) {
            for (final b in byForm[group[j].form]!) {
              found(a, b, 'swap:${sorted[0]}-${sorted[1]}');
            }
          }
        }
      }
    }
    return out;
  }

  static List<String> _swapKeys(String x, String y) => <String>[
    '$x|$y',
    '$y|$x',
  ];

  /// Every text that is [text] with one [from] replaced by [to].
  List<String> _swaps(String text, String from, String to, bool withinWord) {
    final out = <String>[];
    if (from.isEmpty) {
      for (var at = 1; at < text.length; at++) {
        out.add(text.substring(0, at) + to + text.substring(at));
      }
      return out;
    }
    for (
      var at = text.indexOf(from);
      at >= 0;
      at = text.indexOf(from, at + 1)
    ) {
      if (withinWord && to.isEmpty && at + from.length >= text.length) continue;
      out.add(text.substring(0, at) + to + text.substring(at + from.length));
    }
    return out;
  }

  /// P1 and P2: one of two words that differ by one contrast is said; which?
  /// With [tiles] the same contrast is asked as a spelling (the written
  /// fallback of section 8, and the isolating question after a closed pair
  /// case): the meaning of one word is shown and it is built from tiles, the
  /// contrast's other letter among them.
  QuestionOutcome _pair(_Ctx ctx, {required bool tiles}) {
    if (data.sounds == null && data.effectiveDeckPairSwaps.isEmpty) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noSoundsFile,
        'no sounds file and no list of letter swaps for pairs from the decks',
      );
    }
    if (!tiles && requireTrustedPairAudio && !data.pairAudioTrusted) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.pairAudioUntrusted,
        'the pair audio has not been checked on this device',
      );
    }
    if (!tiles && !tested.contains(PlacementSkill.hear)) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noAudio,
        'Hear is not tested',
      );
    }
    if (ctx.request.role == PlacementQuestionRole.isolating) {
      final concept = ctx.failed?.concept;
      if (ctx.failed == null || concept == null) {
        return const QuestionUnavailable(
          PlacementUnavailableReason.noOrigin,
          'the closed pair question was not given',
        );
      }
      if (!concept.startsWith('sound:')) {
        return const QuestionUnavailable(
          PlacementUnavailableReason.noPairFound,
          'the closed question was not about a sound contrast',
        );
      }
    }
    final isolating = ctx.request.role == PlacementQuestionRole.isolating;
    final all = _pairs(isolating ? data.deckCount : ctx.request.deck);
    if (all.isEmpty) {
      return QuestionUnavailable(
        data.sounds == null
            ? PlacementUnavailableReason.noSoundsFile
            : PlacementUnavailableReason.noPairFound,
        'no two words of the decks differ by one swap',
      );
    }
    final List<_Pair> pool;
    if (isolating) {
      // The contrast that was closed, asked as a spelling: the same word
      // when it is there, else another pair of the same contrast. Its words
      // were asked already, so nothing is left out for that.
      final closed = ctx.failed!.concept!.substring('sound:'.length);
      final same = <_Pair>[
        for (final p in all)
          if (p.contrast == closed) p,
      ];
      final sameWord = <_Pair>[
        for (final p in same)
          if (p.card.id == ctx.failed!.cardId) p,
      ];
      pool = sameWord.isNotEmpty ? sameWord : same;
    } else {
      final fresh = <_Pair>[
        for (final p in all)
          if (_eligible(p.card, ctx.asked) &&
              !ctx.asked.contains(p.partner.id) &&
              !ctx.asked.contains('concept:sound:${p.contrast}'))
            p,
      ];
      pool = fresh.isNotEmpty
          ? fresh
          : <_Pair>[
              for (final p in all)
                if (_eligible(p.card, ctx.asked) &&
                    !ctx.asked.contains(p.partner.id))
                  p,
            ];
    }
    if (pool.isEmpty) {
      return _empty(ctx, PlacementUnavailableReason.noPairFound);
    }
    // One partner per card: the first by id, so that the choice is stable.
    final byCard =
        <String, ({Card card, Card partner, String contrast, int deck})>{};
    for (final p in pool) {
      final held = byCard[p.card.id];
      if (held == null || p.partner.id.compareTo(held.partner.id) < 0) {
        byCard[p.card.id] = p;
      }
    }
    final ranked = _picker.rank(<({Card card, int deck})>[
      for (final p in byCard.values) (card: p.card, deck: p.deck),
    ], wrongFor: (c, d) => <Card>[byCard[c.id]!.partner]);
    final item = PlacementItemPicker.pickFromShortlist(
      ranked,
      ctx.request.shortlistPick,
    );
    if (item == null) {
      return _empty(ctx, PlacementUnavailableReason.noPairFound);
    }
    final chosen = byCard[item.card.id]!;
    final a = chosen.card;
    final b = chosen.partner;
    final concept = 'sound:${chosen.contrast}';
    final aUnits = aksharasOf(a.target);
    final bUnits = aksharasOf(b.target);
    final extra = <String>[
      for (final u in bUnits)
        if (!aUnits.contains(u)) u,
    ];
    final fallback = PlacementTilesFallback(
      meaning: a.native,
      tiles: (<String>[...aUnits, if (extra.isNotEmpty) extra.first]
        ..shuffle(ctx.random)),
      accepted: <String>[a.target, ...a.altTarget],
    );
    final ids = _ids(a, <Card>[b], concept: concept);
    if (tiles) {
      return QuestionBuilt(
        GeneratedQuestion(
          request: ctx.request,
          prompt: PlacementPromptKind.meaning,
          promptText: a.native,
          mode: PlacementAnswerMode.tiles,
          tiles: fallback.tiles,
          joiner: '',
          accepted: fallback.accepted,
          cardId: a.id,
          concept: concept,
          itemIds: ids,
          difficulty: _difficulty(item),
        ),
      );
    }
    final options = <String>[a.target, b.target]..shuffle(ctx.random);
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: PlacementPromptKind.heardWord,
        // Untrusted until a device check says the voice keeps the contrast.
        audio: _audioOf(a, trusted: data.pairAudioTrusted),
        mode: PlacementAnswerMode.pick,
        options: options,
        correctIndex: options.indexOf(a.target),
        accepted: <String>[a.target],
        tilesFallback: fallback,
        cardId: a.id,
        concept: concept,
        itemIds: ids,
        difficulty: _difficulty(item),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Topic 6: Say, by the meaning of a word (Y1 to Y3).

  /// The syllables of [card]'s word, counted from its IPA where it has one.
  int? _syllables(Card card) {
    final ipa = card.ipa;
    if (ipa == null) return null;
    final groups = RegExp(r'[aeiouyɑɐæɛɔəɪʊʌɜɒøœɨɯɤɵʉɚ]+')
        .allMatches(ipa)
        .length;
    return groups == 0 ? null : groups;
  }

  /// Every answer to accept when [card]'s meaning is shown: the taught form
  /// and its alternatives and spellings, the listed synonyms (by card or in
  /// full), and the taught form of every other card of the course that means
  /// the same (the fallback while cards list no synonyms).
  List<String> acceptedWordsFor(Card card) {
    final out = <String>[];
    void add(String w) {
      final word = w.trim();
      if (word.isNotEmpty && !out.contains(word)) out.add(word);
    }

    add(card.target);
    card.altTarget.forEach(add);
    card.targetScripts.values.forEach(add);
    for (final s in card.synonyms) {
      final ref = s.ref == null ? null : data.cardById(s.ref!);
      if (ref != null) {
        add(ref.target);
        ref.altTarget.forEach(add);
      }
      if (s.word != null) add(s.word!);
    }
    final key = foldMeaning(card.firstMeaning);
    for (final deck in data.decks) {
      for (final other in deck.cards) {
        if (other.id == card.id || !isAskable(other) || !isWordCard(other)) {
          continue;
        }
        if (foldMeaning(other.firstMeaning) == key) {
          add(other.target);
          other.altTarget.forEach(add);
        }
      }
    }
    return out;
  }

  /// Y1 to Y3: the English meaning of a short word of the late decks; the
  /// learner says the word. Graded against [acceptedWordsFor]. The word is
  /// a single word that the learner's cards allow producing; a word of at
  /// most two syllables is preferred, because the shorter the word the less
  /// the dialect matters (section 2.4).
  QuestionOutcome _say(_Ctx ctx) {
    final wrongFor = _wrongOptions(ctx, sameKind: isWordCard, show: _meaningOf);
    bool producible(Card c) =>
        isWordCard(c) &&
        c.wordCount == 1 &&
        !c.modes.contains(DrillMode.production) &&
        !_isPlaceholder(c);
    final ranges = _ranges(ctx.request.deck);
    var item = _item(
      ctx,
      ranges,
      keep: (c, d) => producible(c) && (_syllables(c) ?? 2) <= 2,
      wrongFor: wrongFor,
    );
    item ??= _item(
      ctx,
      ranges,
      keep: (c, d) => producible(c),
      wrongFor: wrongFor,
    );
    if (item == null) return _empty(ctx, PlacementUnavailableReason.noWords);
    final card = item.card;
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: PlacementPromptKind.meaning,
        promptText: card.native,
        mode: PlacementAnswerMode.say,
        accepted: acceptedWordsFor(card),
        dialectRisk: true,
        cardId: card.id,
        itemIds: _ids(card, const <Card>[]),
        difficulty: _difficulty(item),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Topic 7: the script (SR, SW, SX).

  bool _hasConjunct(String akshara) =>
      akshara.runes.any((r) => _viramas.contains(r));

  static const Set<int> _viramas = <int>{
    0x094D,
    0x09CD,
    0x0A4D,
    0x0ACD,
    0x0B4D,
    0x0BCD,
    0x0C4D,
    0x0CCD,
    0x0D4D,
    0x0DCA,
    0x1039,
  };

  /// How rare the rarest sign of [spelling] is among the script's words, with
  /// a conjunct counting most: 0 (every sign common) to 1.
  double Function(String) _rarity(PlacementScriptData script) {
    final counts = <String, int>{};
    for (final w in script.words) {
      for (final a in aksharasOf(w.spelling.replaceAll(' ', ''))) {
        counts[a] = (counts[a] ?? 0) + 1;
      }
    }
    final most = counts.values.fold<int>(1, math.max);
    return (String spelling) {
      var rarest = 0.0;
      var conjunct = false;
      for (final a in aksharasOf(spelling.replaceAll(' ', ''))) {
        rarest = math.max(rarest, 1 - (counts[a] ?? 1) / most);
        conjunct = conjunct || _hasConjunct(a);
      }
      return math.min(1.0, (conjunct ? 0.6 : 0.0) + 0.4 * rarest);
    };
  }

  /// SR, SRb and SX: a word with the rarest sign or conjunct of the script,
  /// shown in the script with no reading; its meaning is picked (or said in
  /// English, for the second script's production question).
  QuestionOutcome _scriptRead(_Ctx ctx, {required int script}) {
    if (script >= data.scripts.length || data.scripts[script].words.isEmpty) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noScript,
        'the course has no script with words',
      );
    }
    final scriptData = data.scripts[script];
    final spellings = <String, String>{
      for (final w in scriptData.words) w.card.id: w.spelling,
    };
    final rarity = _rarity(scriptData);
    final wrongFor = _wrongOptions(
      ctx,
      sameKind: (c) => spellings.containsKey(c.id) && isWordCard(c),
      show: _meaningOf,
    );
    final candidates = <({Card card, int deck})>[
      for (final w in scriptData.words)
        if (_eligible(w.card, ctx.asked) && isWordCard(w.card))
          (card: w.card, deck: data.deckIndexOf(w.card.id) ?? 0),
    ];
    final ranked = _picker.rank(
      candidates,
      formOverride: (c, d) => rarity(spellings[c.id]!),
      wrongFor: wrongFor,
    );
    final item = PlacementItemPicker.pickFromShortlist(
      ranked,
      ctx.request.shortlistPick,
    );
    if (item == null) {
      return _empty(
        ctx,
        candidates.isEmpty
            ? PlacementUnavailableReason.noScript
            : PlacementUnavailableReason.tooFewDistractors,
      );
    }
    final card = item.card;
    final picked = _meaningOptions(ctx, item);
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: PlacementPromptKind.writtenWord,
        promptText: spellings[card.id],
        mode: _modeOf(ctx.request.kind),
        options: picked.options,
        correctIndex: picked.correct,
        accepted: _acceptedMeanings(card),
        cardId: card.id,
        itemIds: _ids(card, item.wrong),
        difficulty: _difficulty(item),
      ),
    );
  }

  /// SW: a word with a conjunct or contrast letter is built from tiles in
  /// the script from its meaning.
  QuestionOutcome _scriptWrite(_Ctx ctx, {required int script}) {
    if (script >= data.scripts.length || data.scripts[script].words.isEmpty) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noScript,
        'the course has no script with words',
      );
    }
    final scriptData = data.scripts[script];
    final spellings = <String, String>{
      for (final w in scriptData.words) w.card.id: w.spelling,
    };
    final rarity = _rarity(scriptData);
    final candidates = <({Card card, int deck})>[
      for (final w in scriptData.words)
        if (_eligible(w.card, ctx.asked) &&
            isWordCard(w.card) &&
            !w.card.modes.contains(DrillMode.production) &&
            !w.spelling.contains(' '))
          (card: w.card, deck: data.deckIndexOf(w.card.id) ?? 0),
    ];
    final ranked = _picker.rank(
      candidates,
      formOverride: (c, d) => rarity(spellings[c.id]!),
      wrongFor: (c, d) => const <Card>[],
    );
    final item = PlacementItemPicker.pickFromShortlist(
      ranked,
      ctx.request.shortlistPick,
    );
    if (item == null) return _empty(ctx, PlacementUnavailableReason.noScript);
    final card = item.card;
    final spelling = spellings[card.id]!;
    final right = aksharasOf(spelling);
    // Close wrong tiles: signs of other words that differ from a tile of this
    // one by one letter, else any other sign.
    final extras = <String>[];
    final pool = <String>{
      for (final w in scriptData.words)
        if (w.card.id != card.id) ...aksharasOf(w.spelling),
    }.where((a) => !right.contains(a)).toList()..sort();
    pool.sort((x, y) {
      int near(String a) =>
          right.map((r) => editDistance(r, a)).reduce(math.min);
      final c = near(x).compareTo(near(y));
      return c != 0 ? c : x.compareTo(y);
    });
    extras.addAll(pool.take(2));
    final tiles = _shuffledNot(<String>[...right], ctx.random)
      ..addAll(extras)
      ..shuffle(ctx.random);
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: PlacementPromptKind.meaning,
        promptText: card.native,
        mode: PlacementAnswerMode.tiles,
        tiles: tiles,
        joiner: '',
        accepted: <String>[spelling],
        cardId: card.id,
        itemIds: _ids(card, const <Card>[]),
        difficulty: _difficulty(item),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Positioning and top-ups: one vocabulary question of one skill at a deck.

  QuestionOutcome _vocabulary(_Ctx ctx) {
    final skill = ctx.request.skills.isEmpty
        ? PlacementSkill.read
        : ctx.request.skills.first;
    switch (skill) {
      case PlacementSkill.read:
        return _wordPick(ctx, heard: false);
      case PlacementSkill.hear:
        return _wordPick(ctx, heard: true);
      case PlacementSkill.say:
        return _say(ctx);
      case PlacementSkill.write:
        return _tilesWord(ctx);
      case PlacementSkill.script:
        return _scriptRead(ctx, script: 0);
      case PlacementSkill.secondScript:
        return _scriptRead(ctx, script: 1);
    }
  }

  /// A short word built from tiles from its meaning (Write only).
  QuestionOutcome _tilesWord(_Ctx ctx, {bool short = true}) {
    final item = _item(
      ctx,
      _ranges(
        ctx.request.deck,
        around: ctx.request.role == PlacementQuestionRole.probe,
      ),
      keep: (c, d) =>
          isWordCard(c) &&
          c.wordCount == 1 &&
          !c.modes.contains(DrillMode.production) &&
          (!short || c.target.runes.length <= 8) &&
          !_isPlaceholder(c),
      wrongFor: (c, d) => const <Card>[],
    );
    if (item == null) return _empty(ctx, PlacementUnavailableReason.noWords);
    return QuestionBuilt(_tilesQuestion(ctx, item, sentence: false));
  }

  // ---------------------------------------------------------------------------
  // The two questions after a composite miss (section 3.1).

  /// The question asked after a closed single-skill case (section 3.2): a
  /// closed pair case gets the same contrast as a spelling with the swapped
  /// letter among the tiles (hearing against spelling); a closed Say case
  /// gets the same word heard, its meaning picked (pronunciation against
  /// vocabulary).
  QuestionOutcome _isolating(_Ctx ctx) {
    if (ctx.request.topic == PlacementTopic.minimalPairs) {
      return _pair(ctx, tiles: true);
    }
    final word = _originCard(ctx);
    if (word == null) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noOrigin,
        'the closed Say question was not given',
      );
    }
    return _wordPick(ctx, heard: true, only: word);
  }

  QuestionOutcome _split(_Ctx ctx) {
    final request = ctx.request;
    final first = request.variant == PlacementVariant.s1;
    final origin = request.originVariant;
    if (origin == null) {
      return const QuestionUnavailable(
        PlacementUnavailableReason.noOrigin,
        'a split names the question it checks',
      );
    }
    final failed = ctx.failed;
    QuestionOutcome needsFailed() => const QuestionUnavailable(
      PlacementUnavailableReason.noOrigin,
      'this split asks about the word or family of the question it checks, '
      'which was not given',
    );
    final concept = failed?.concept;
    final family = concept != null && concept.startsWith('grammar:')
        ? concept.substring('grammar:'.length)
        : null;
    switch (origin) {
      case PlacementVariant.k1:
      case PlacementVariant.k1b:
        return first
            ? _sentencePick(ctx, heard: tested.contains(PlacementSkill.hear))
            : _wordPick(ctx, heard: false, short: true);
      case PlacementVariant.k2:
      case PlacementVariant.k2b:
        return first
            ? _sentencePick(ctx, heard: true)
            : _wordPick(ctx, heard: true, short: true);
      case PlacementVariant.w1:
      case PlacementVariant.w1b:
        if (_originCard(ctx) == null) return needsFailed();
        return first
            ? _baseWordPick(ctx, heard: false)
            : _wordPick(ctx, heard: true, only: _originCard(ctx));
      case PlacementVariant.w2:
      case PlacementVariant.w2b:
        if (_originCard(ctx) == null) return needsFailed();
        return first
            ? _baseWordPick(ctx, heard: true)
            : _wordPick(ctx, heard: false, only: _originCard(ctx));
      case PlacementVariant.g1:
      case PlacementVariant.g1b:
        if (family == null) return needsFailed();
        return first
            ? _blank(ctx, family: family, shortOnly: true)
            : _blank(ctx, family: family, earliest: true);
      case PlacementVariant.g2:
      case PlacementVariant.g2b:
        if (family == null) return needsFailed();
        return first ? _blank(ctx, family: family) : _tilesWord(ctx);
      case PlacementVariant.r1:
        return first
            ? _wordPick(ctx, heard: true, short: true)
            : _tilesWord(ctx);
      case PlacementVariant.r2:
      case PlacementVariant.r2b:
        return first ? _tilesWord(ctx) : _orderPair(ctx);
      default:
        return _wordPick(ctx, heard: false, short: true);
    }
  }

  Card? _originCard(_Ctx ctx) {
    final id = ctx.failed?.cardId;
    return id == null ? null : data.cardById(id);
  }

  /// A long sentence by audio (or as its reading) with its meaning picked.
  QuestionOutcome _sentencePick(_Ctx ctx, {required bool heard}) {
    final outcome = _longSentence(ctx, heard: heard);
    if (outcome is! QuestionBuilt) return outcome;
    final q = outcome.question;
    // A split is always a pick, whatever the base question asked.
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: q.prompt,
        promptText: q.promptText,
        promptReading: q.promptReading,
        audio: q.audio,
        mode: PlacementAnswerMode.pick,
        options: q.options,
        correctIndex: q.correctIndex,
        accepted: q.accepted,
        cardId: q.cardId,
        itemIds: q.itemIds,
        difficulty: q.difficulty,
      ),
    );
  }

  /// The base form of the origin's word, written or heard, its meaning
  /// picked. Without an origin or a base with a card, another short word.
  QuestionOutcome _baseWordPick(_Ctx ctx, {required bool heard}) {
    final origin = _originCard(ctx);
    if (origin != null) {
      for (final b in origin.bases) {
        final base = b.ref == null ? null : data.cardById(b.ref!);
        if (base != null &&
            base.id != origin.id &&
            isWordCard(base) &&
            !ctx.asked.contains(base.id)) {
          return _wordPick(ctx, heard: heard, only: base);
        }
      }
    }
    return _wordPick(ctx, heard: heard, short: true);
  }

  /// R2's second split: which of two sentences has its words in the right
  /// order (grammar without spelling).
  QuestionOutcome _orderPair(_Ctx ctx) {
    final item = _item(
      ctx,
      _ranges(ctx.request.deck),
      keep: (c, d) => _buildable(c) && c.wordCount >= 3,
      wrongFor: (c, d) => const <Card>[],
    );
    if (item == null) {
      return _empty(ctx, PlacementUnavailableReason.noSentences);
    }
    final card = item.card;
    final order = _orderOptions(card, ctx.random);
    if (order == null) {
      return _empty(ctx, PlacementUnavailableReason.noSentences);
    }
    final options = <String>[order.right, order.wrong]..shuffle(ctx.random);
    return QuestionBuilt(
      GeneratedQuestion(
        request: ctx.request,
        prompt: PlacementPromptKind.sentencePair,
        mode: PlacementAnswerMode.pick,
        options: options,
        correctIndex: options.indexOf(order.right),
        accepted: <String>[order.right],
        meaningHint: card.native,
        cardId: card.id,
        itemIds: _ids(card, const <Card>[]),
        difficulty: _difficulty(item),
      ),
    );
  }
}

/// Two words of the decks that differ by one swap of [contrast].
typedef _Pair = ({Card card, Card partner, String contrast, int deck});

/// What one call of [QuestionBuilder.build] knows.
class _Ctx {
  _Ctx(this.request, this.asked, this.failed, int seed)
    : random = seededRandom(
        seed,
        '${request.number}:${request.variant.label}:${request.role.name}',
      );

  final PlacementQuestionRequest request;
  final Set<String> asked;

  /// The question a split or an isolating question checks, if given.
  final GeneratedQuestion? failed;
  final math.Random random;
}
